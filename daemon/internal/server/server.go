package server

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/DerTraurigeHund/buttondack/daemon/internal/actions"
	"github.com/DerTraurigeHund/buttondack/daemon/internal/config"
	"github.com/DerTraurigeHund/buttondack/daemon/internal/spotify"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins (LAN usage)
	},
}

// WSMessage is the JSON message format for WebSocket communication.
type WSMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// ActionPayload is sent when a button is pressed.
type ActionPayload struct {
	Profile  string `json:"profile"`
	ButtonID string `json:"button_id"`
}

// WSClient represents a connected WebSocket client.
type WSClient struct {
	conn *websocket.Conn
	send chan []byte
}

// Server handles all HTTP and WebSocket connections.
type Server struct {
	config      *config.Manager
	actions     *actions.Runner
	spotify     *spotify.Client
	clients     map[*WSClient]bool
	clientsMu   sync.RWMutex
	spotifyStop chan struct{}
	httpServer  *http.Server
}

// NewServer creates a new server instance.
func NewServer(cfg *config.Manager, act *actions.Runner, sp *spotify.Client) *Server {
	return &Server{
		config:      cfg,
		actions:     act,
		spotify:     sp,
		clients:     make(map[*WSClient]bool),
		spotifyStop: make(chan struct{}),
	}
}

// Start begins listening for connections.
func (s *Server) Start(host string, port int) error {
	mux := http.NewServeMux()

	// WebSocket endpoint
	mux.HandleFunc("/ws", s.handleWebSocket)

	// REST API
	mux.HandleFunc("/api/health", s.handleHealth)
	mux.HandleFunc("/api/config", s.handleGetConfig)
	mux.HandleFunc("/api/config/update", s.handleUpdateConfig)
	mux.HandleFunc("/api/action", s.handleAction)
	mux.HandleFunc("/api/spotify/auth", s.handleSpotifyAuth)
	mux.HandleFunc("/api/spotify/poll", s.handleSpotifyPoll)
	mux.HandleFunc("/api/spotify/status", s.handleSpotifyStatus)

	// CORS middleware wrapper
	handler := corsMiddleware(mux)

	addr := fmt.Sprintf("%s:%d", host, port)
	s.httpServer = &http.Server{
		Addr:    addr,
		Handler: handler,
	}

	// Start Spotify polling if enabled
	if s.spotify.IsEnabled() {
		go s.spotify.PollingLoop(2*time.Second, s.spotifyStop)
		// Subscribe to Spotify updates
		go s.handleSpotifyUpdates()
	}

	log.Printf("[ButtonDack] Daemon listening on %s", addr)
	return s.httpServer.ListenAndServe()
}

// Stop gracefully shuts down the server.
func (s *Server) Stop() error {
	close(s.spotifyStop)
	if s.httpServer != nil {
		return s.httpServer.Close()
	}
	return nil
}

// corsMiddleware adds CORS headers for local development.
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// --- WebSocket ---

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS] Upgrade error: %v", err)
		return
	}

	client := &WSClient{
		conn: conn,
		send: make(chan []byte, 256),
	}

	s.clientsMu.Lock()
	s.clients[client] = true
	s.clientsMu.Unlock()

	log.Printf("[WS] Client connected (%s)", r.RemoteAddr)

	// Send current config to newly connected client
	if initData, err := json.Marshal(map[string]interface{}{
		"type":    "config",
		"payload": s.config.Get(),
	}); err == nil {
		client.send <- initData
	}

	go s.writePump(client)
	go s.readPump(client)
}

func (s *Server) readPump(client *WSClient) {
	defer func() {
		s.clientsMu.Lock()
		delete(s.clients, client)
		s.clientsMu.Unlock()
		client.conn.Close()
	}()

	client.conn.SetReadLimit(4096)
	client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.conn.SetPongHandler(func(string) error {
		client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := client.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("[WS] Read error: %v", err)
			}
			break
		}

		var msg WSMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("[WS] Invalid message: %v", err)
			continue
		}

		s.handleWSMessage(client, msg)
	}
}

func (s *Server) writePump(client *WSClient) {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		client.conn.Close()
	}()

	for {
		select {
		case message, ok := <-client.send:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				client.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := client.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := client.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (s *Server) handleWSMessage(client *WSClient, msg WSMessage) {
	switch msg.Type {
	case "action":
		var payload ActionPayload
		if err := json.Unmarshal(msg.Payload, &payload); err != nil {
			s.sendTo(client, "error", map[string]string{"message": "invalid payload"})
			return
		}
		result := s.executeAction(payload.Profile, payload.ButtonID)
		s.sendTo(client, "action_result", result)

	case "ping":
		s.sendTo(client, "pong", nil)
	}
}

// --- Broadcasting ---

func (s *Server) broadcast(msgType string, payload interface{}) {
	data, err := json.Marshal(WSMessage{Type: msgType, Payload: toRaw(payload)})
	if err != nil {
		return
	}

	s.clientsMu.RLock()
	defer s.clientsMu.RUnlock()

	for client := range s.clients {
		select {
		case client.send <- data:
		default:
			// Client too slow, drop
		}
	}
}

func (s *Server) sendTo(client *WSClient, msgType string, payload interface{}) {
	data, err := json.Marshal(WSMessage{Type: msgType, Payload: toRaw(payload)})
	if err != nil {
		return
	}
	select {
	case client.send <- data:
	default:
	}
}

func (s *Server) handleSpotifyUpdates() {
	ch := s.spotify.Subscribe()
	defer s.spotify.Unsubscribe(ch)

	for track := range ch {
		s.broadcast("spotify_track", track)
	}
}

// --- REST Handlers ---

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "ok",
		"version": "1.0.0",
		"time":    time.Now().Unix(),
	})
}

func (s *Server) handleGetConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	json.NewEncoder(w).Encode(s.config.Get())
}

func (s *Server) handleUpdateConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var newConfig config.AppConfig
	if err := json.NewDecoder(r.Body).Decode(&newConfig); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	if err := s.config.Save(&newConfig); err != nil {
		http.Error(w, fmt.Sprintf("save failed: %v", err), http.StatusInternalServerError)
		return
	}

	// Update Spotify state if changed
	if newConfig.Spotify.Enabled != s.spotify.IsEnabled() {
		s.spotify.SetEnabled(newConfig.Spotify.Enabled)
	}

	json.NewEncoder(w).Encode(map[string]string{"status": "saved"})
}

func (s *Server) handleAction(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload ActionPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}

	result := s.executeAction(payload.Profile, payload.ButtonID)
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleSpotifyAuth(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		// Start device auth flow
		userCode, verifURL, err := s.spotify.StartDeviceAuth()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Start polling in background
		go func() {
			if err := s.spotify.PollDeviceAuth(); err != nil {
				log.Printf("[Spotify] Auth failed: %v", err)
			} else {
				log.Printf("[Spotify] Auth successful!")
				// Save credentials
				cfg := s.config.Get()
				cfg.Spotify.Enabled = true
				s.config.Save(cfg)

				// Start polling loop
				go s.spotify.PollingLoop(2*time.Second, s.spotifyStop)
				go s.handleSpotifyUpdates()
			}
		}()

		json.NewEncoder(w).Encode(map[string]string{
			"user_code":        userCode,
			"verification_url": verifURL,
		})
		return
	}

	http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
}

func (s *Server) handleSpotifyPoll(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	track, err := s.spotify.GetCurrentlyPlaying()
	if err != nil {
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	json.NewEncoder(w).Encode(track)
}

func (s *Server) handleSpotifyStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"enabled":       s.spotify.IsEnabled(),
		"authenticated": true, // Simplified
	})
}

// --- Action Execution ---

func (s *Server) executeAction(profile, buttonID string) map[string]interface{} {
	cfg := s.config.Get()

	// Find the button
	var btn *config.ButtonConfig
	for _, p := range cfg.Profiles {
		if p.Name == profile {
			if b, ok := p.Buttons[buttonID]; ok {
				btn = &b
				break
			}
		}
	}

	if btn == nil {
		return map[string]interface{}{
			"success": false,
			"error":   fmt.Sprintf("button %s/%s not found", profile, buttonID),
		}
	}

	// Execute hotkeys first
	if len(btn.Hotkeys) > 0 {
		result := s.actions.PressHotkeys(btn.Hotkeys)
		if !result.Success && btn.WithError {
			return map[string]interface{}{
				"success": false,
				"error":   result.ErrorMsg,
				"output":  result.Output,
			}
		}
	}

	// Then run command
	if btn.Command != "" {
		result := s.actions.RunCommand(btn.Command)
		if !result.Success && btn.WithError {
			return map[string]interface{}{
				"success": false,
				"error":   result.ErrorMsg,
				"output":  result.Output,
			}
		}
		return map[string]interface{}{
			"success": true,
			"output":  result.Output,
		}
	}

	return map[string]interface{}{"success": true, "output": "Action completed"}
}

// toRaw converts an interface{} to json.RawMessage.
func toRaw(v interface{}) json.RawMessage {
	data, _ := json.Marshal(v)
	return json.RawMessage(data)
}
