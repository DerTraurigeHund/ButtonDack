package spotify

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// TrackInfo holds details about the currently playing track.
type TrackInfo struct {
	IsPlaying  bool   `json:"is_playing"`
	TrackName  string `json:"track_name"`
	Artist     string `json:"artist"`
	AlbumName  string `json:"album_name"`
	AlbumArtURL string `json:"album_art_url"`
	ProgressMs int    `json:"progress_ms"`
	DurationMs int    `json:"duration_ms"`
	TrackURL   string `json:"track_url"`
}

// TokenResponse is the OAuth token response from Spotify.
type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token,omitempty"`
	Scope        string `json:"scope,omitempty"`
}

// CurrentlyPlayingResponse is the Spotify API response for currently playing.
type CurrentlyPlayingResponse struct {
	IsPlaying  bool `json:"is_playing"`
	ProgressMs int  `json:"progress_ms"`
	Item       *struct {
		Name    string `json:"name"`
		DurationMs int `json:"duration_ms"`
		ExternalURLs struct {
			Spotify string `json:"spotify"`
		} `json:"external_urls"`
		Artists []struct {
			Name string `json:"name"`
		} `json:"artists"`
		Album *struct {
			Name   string `json:"name"`
			Images []struct {
				URL    string `json:"url"`
				Height int    `json:"height"`
				Width  int    `json:"width"`
			} `json:"images"`
		} `json:"album"`
	} `json:"item"`
}

// Client handles Spotify API communication.
type Client struct {
	clientID      string
	clientSecret  string
	accessToken   string
	refreshToken  string
	tokenExpiry   time.Time
	httpClient    *http.Client
	deviceCode    string
	userCode      string
	verificationURL string
	mu            sync.RWMutex
	enabled       bool
	lastTrack     *TrackInfo
	listeners     []chan TrackInfo
	listenersMu   sync.RWMutex
}

// NewClient creates a new Spotify client.
func NewClient(clientID, clientSecret string, enabled bool) *Client {
	return &Client{
		clientID:     clientID,
		clientSecret: clientSecret,
		enabled:      enabled,
		httpClient:   &http.Client{Timeout: 10 * time.Second},
	}
}

// IsEnabled returns whether Spotify integration is enabled.
func (c *Client) IsEnabled() bool {
	return c.enabled
}

// SetEnabled enables or disables Spotify integration.
func (c *Client) SetEnabled(enabled bool) {
	c.enabled = enabled
}

// SetCredentials updates the Spotify API credentials.
func (c *Client) SetCredentials(clientID, clientSecret string) {
	c.clientID = clientID
	c.clientSecret = clientSecret
}

// StartDeviceAuth initiates the Device Code OAuth flow.
// Returns the user code and verification URL for display.
func (c *Client) StartDeviceAuth() (userCode string, verificationURL string, err error) {
	if c.clientID == "" {
		return "", "", fmt.Errorf("Spotify Client ID not configured")
	}

	data := url.Values{
		"client_id": {c.clientID},
		"scope":     {"user-read-playback-state user-read-currently-playing"},
	}

	resp, err := c.httpClient.PostForm("https://accounts.spotify.com/api/device", data)
	if err != nil {
		return "", "", fmt.Errorf("device auth request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", fmt.Errorf("reading device auth response: %w", err)
	}

	var result struct {
		DeviceCode      string `json:"device_code"`
		UserCode        string `json:"user_code"`
		VerificationURL string `json:"verification_uri"`
		Interval        int    `json:"interval"`
		ExpiresIn      int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return "", "", fmt.Errorf("parsing device auth: %w", err)
	}

	c.deviceCode = result.DeviceCode
	c.userCode = result.UserCode
	c.verificationURL = result.VerificationURL

	return result.UserCode, result.VerificationURL, nil
}

// PollDeviceAuth polls the device auth token endpoint until the user authorizes.
func (c *Client) PollDeviceAuth() error {
	if c.deviceCode == "" {
		return fmt.Errorf("no active device auth flow")
	}

	data := url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:device_code"},
		"device_code": {c.deviceCode},
		"client_id":  {c.clientID},
	}

	// Poll at intervals (Spotify says every 5s)
	timeout := time.After(5 * time.Minute)
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			return fmt.Errorf("device auth timed out")
		case <-ticker.C:
			resp, err := c.httpClient.PostForm("https://accounts.spotify.com/api/token", data)
			if err != nil {
				continue
			}

			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()

			var tokenResp TokenResponse
			if err := json.Unmarshal(body, &tokenResp); err != nil {
				continue
			}

			if tokenResp.AccessToken != "" {
				c.mu.Lock()
				c.accessToken = tokenResp.AccessToken
				c.refreshToken = tokenResp.RefreshToken
				c.tokenExpiry = time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second)
				c.mu.Unlock()
				return nil
			}

			// Check for specific error responses
			var errResp struct {
				Error string `json:"error"`
			}
			if json.Unmarshal(body, &errResp) == nil {
				if errResp.Error == "authorization_pending" {
					continue // user hasn't authorized yet
				}
				if errResp.Error == "access_denied" {
					return fmt.Errorf("user denied authorization")
				}
			}
		}
	}
}

// RefreshAccessToken refreshes the access token using the refresh token.
func (c *Client) RefreshAccessToken() error {
	c.mu.RLock()
	refreshToken := c.refreshToken
	c.mu.RUnlock()

	if refreshToken == "" {
		return fmt.Errorf("no refresh token available")
	}

	data := url.Values{
		"grant_type":    {"refresh_token"},
		"refresh_token": {refreshToken},
		"client_id":     {c.clientID},
		"client_secret": {c.clientSecret},
	}

	resp, err := c.httpClient.PostForm("https://accounts.spotify.com/api/token", data)
	if err != nil {
		return fmt.Errorf("token refresh request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("reading token refresh: %w", err)
	}

	var tokenResp TokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return fmt.Errorf("parsing token refresh: %w", err)
	}

	c.mu.Lock()
	if tokenResp.AccessToken != "" {
		c.accessToken = tokenResp.AccessToken
	}
	if tokenResp.RefreshToken != "" {
		c.refreshToken = tokenResp.RefreshToken
	}
	c.tokenExpiry = time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second)
	c.mu.Unlock()

	return nil
}

// ensureValidToken checks if the token is still valid and refreshes if needed.
func (c *Client) ensureValidToken() error {
	c.mu.RLock()
	expired := time.Now().After(c.tokenExpiry)
	hasToken := c.accessToken != ""
	c.mu.RUnlock()

	if !hasToken {
		return fmt.Errorf("not authenticated")
	}

	if expired {
		return c.RefreshAccessToken()
	}
	return nil
}

// GetCurrentlyPlaying fetches the current playback state from Spotify.
func (c *Client) GetCurrentlyPlaying() (*TrackInfo, error) {
	if !c.enabled {
		return nil, fmt.Errorf("Spotify integration disabled")
	}

	if err := c.ensureValidToken(); err != nil {
		return nil, err
	}

	c.mu.RLock()
	token := c.accessToken
	c.mu.RUnlock()

	req, err := http.NewRequest("GET", "https://api.spotify.com/v1/me/player/currently-playing", nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetching currently playing: %w", err)
	}
	defer resp.Body.Close()

	// 204 No Content = nothing playing
	if resp.StatusCode == 204 {
		return &TrackInfo{}, nil
	}

	if resp.StatusCode == 401 {
		// Token might be expired, try refreshing
		if err := c.RefreshAccessToken(); err != nil {
			return nil, err
		}
		// Retry with new token
		return c.GetCurrentlyPlaying()
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}

	var playbackResp CurrentlyPlayingResponse
	if err := json.Unmarshal(body, &playbackResp); err != nil {
		return nil, fmt.Errorf("parsing response: %w", err)
	}

	track := &TrackInfo{
		IsPlaying:  playbackResp.IsPlaying,
		ProgressMs: playbackResp.ProgressMs,
	}

	if playbackResp.Item != nil {
		track.TrackName = playbackResp.Item.Name
		track.DurationMs = playbackResp.Item.DurationMs
		track.TrackURL = playbackResp.Item.ExternalURLs.Spotify

		if len(playbackResp.Item.Artists) > 0 {
			var artists []string
			for _, a := range playbackResp.Item.Artists {
				artists = append(artists, a.Name)
			}
			track.Artist = strings.Join(artists, ", ")
		}

		if playbackResp.Item.Album != nil {
			track.AlbumName = playbackResp.Item.Album.Name
			if len(playbackResp.Item.Album.Images) > 0 {
				// Pick the medium-sized image
				img := playbackResp.Item.Album.Images[0]
				for _, i := range playbackResp.Item.Album.Images {
					if i.Width >= 300 && i.Width <= 400 {
						img = i
						break
					}
				}
				track.AlbumArtURL = img.URL
			}
		}
	}

	c.mu.Lock()
	c.lastTrack = track
	c.mu.Unlock()

	return track, nil
}

// Subscribe returns a channel that receives track updates.
func (c *Client) Subscribe() chan TrackInfo {
	c.listenersMu.Lock()
	defer c.listenersMu.Unlock()
	ch := make(chan TrackInfo, 5)
	c.listeners = append(c.listeners, ch)
	return ch
}

// Unsubscribe removes a listener channel.
func (c *Client) Unsubscribe(ch chan TrackInfo) {
	c.listenersMu.Lock()
	defer c.listenersMu.Unlock()
	for i, listener := range c.listeners {
		if listener == ch {
			c.listeners = append(c.listeners[:i], c.listeners[i+1:]...)
			close(ch)
			break
		}
	}
}

// Broadcast sends a track update to all subscribers.
func (c *Client) Broadcast(track TrackInfo) {
	c.listenersMu.RLock()
	defer c.listenersMu.RUnlock()
	for _, listener := range c.listeners {
		select {
		case listener <- track:
		default:
			// Drop if listener is full
		}
	}
}

// PollingLoop continuously polls Spotify and broadcasts updates.
func (c *Client) PollingLoop(interval time.Duration, stop <-chan struct{}) {
	if !c.enabled {
		return
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Initial fetch
	if track, err := c.GetCurrentlyPlaying(); err == nil && track != nil {
		c.Broadcast(*track)
	}

	for {
		select {
		case <-stop:
			return
		case <-ticker.C:
			track, err := c.GetCurrentlyPlaying()
			if err != nil {
				continue
			}
			if track != nil {
				// Only broadcast if something changed
				c.mu.RLock()
				last := c.lastTrack
				c.mu.RUnlock()

				if last == nil || track.TrackName != last.TrackName || track.IsPlaying != last.IsPlaying {
					c.Broadcast(*track)
				}
			}
		}
	}
}
