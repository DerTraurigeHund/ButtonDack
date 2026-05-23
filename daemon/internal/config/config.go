package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// ButtonConfig represents a single button definition.
type ButtonConfig struct {
	Name      string   `yaml:"name"`
	Image     string   `yaml:"image,omitempty"`
	Command   string   `yaml:"command,omitempty"`
	Hotkeys   [][]string `yaml:"hotkeys,omitempty"`
	WithError bool     `yaml:"with_error,omitempty"`
}

// Profile represents a named group of buttons.
type Profile struct {
	Name    string                  `yaml:"name"`
	Buttons map[string]ButtonConfig `yaml:"buttons"`
}

// SpotifyConfig holds Spotify API credentials.
type SpotifyConfig struct {
	ClientID     string `yaml:"client_id"`
	ClientSecret string `yaml:"client_secret"`
	Enabled      bool   `yaml:"enabled"`
}

// AppConfig is the root configuration structure.
type AppConfig struct {
	Daemon  DaemonConfig  `yaml:"daemon"`
	Spotify SpotifyConfig `yaml:"spotify"`
	Profiles []Profile    `yaml:"profiles"`
}

// DaemonConfig holds daemon-level settings.
type DaemonConfig struct {
	Host     string `yaml:"host"`
	Port     int    `yaml:"port"`
	ConfigDir string `yaml:"config_dir"`
}

// Manager handles loading and saving configuration.
type Manager struct {
	path     string
	config   *AppConfig
}

// NewManager creates a new config manager.
func NewManager(path string) *Manager {
	return &Manager{path: path}
}

// Load reads the YAML config from disk. Returns defaults if file doesn't exist.
func (m *Manager) Load() (*AppConfig, error) {
	data, err := os.ReadFile(m.path)
	if err != nil {
		if os.IsNotExist(err) {
			m.config = DefaultConfig()
			return m.config, nil
		}
		return nil, fmt.Errorf("reading config: %w", err)
	}

	cfg := &AppConfig{}
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parsing config: %w", err)
	}

	m.config = cfg
	return cfg, nil
}

// Save writes the current config to disk.
func (m *Manager) Save(cfg *AppConfig) error {
	if err := os.MkdirAll(filepath.Dir(m.path), 0755); err != nil {
		return fmt.Errorf("creating config dir: %w", err)
	}

	data, err := yaml.Marshal(cfg)
	if err != nil {
		return fmt.Errorf("marshaling config: %w", err)
	}

	if err := os.WriteFile(m.path, data, 0644); err != nil {
		return fmt.Errorf("writing config: %w", err)
	}

	m.config = cfg
	return nil
}

// Get returns the current loaded config.
func (m *Manager) Get() *AppConfig {
	if m.config == nil {
		m.config = DefaultConfig()
	}
	return m.config
}

// DefaultConfig returns a sensible default configuration.
func DefaultConfig() *AppConfig {
	home, _ := os.UserHomeDir()
	return &AppConfig{
		Daemon: DaemonConfig{
			Host:      "0.0.0.0",
			Port:      42069,
			ConfigDir: filepath.Join(home, ".config", "buttondack"),
		},
		Spotify: SpotifyConfig{
			Enabled: false,
		},
		Profiles: []Profile{
			{
				Name: "System",
				Buttons: map[string]ButtonConfig{
					"btn0": {Name: "Shutdown", Command: "systemctl poweroff -i", Image: "shutdown.png", WithError: true},
					"btn1": {Name: "Reboot", Command: "systemctl reboot -i", Image: "restart.png", WithError: true},
					"btn2": {Name: "Sleep", Command: "systemctl suspend -i", Image: "sleep.png", WithError: true},
				},
			},
			{
				Name: "Media",
				Buttons: map[string]ButtonConfig{
					"btn0": {Name: "Play/Pause", Command: "playerctl play-pause", Image: "play.png"},
					"btn1": {Name: "Next", Command: "playerctl next", Image: "next.png"},
					"btn2": {Name: "Previous", Command: "playerctl previous", Image: "previous.png"},
					"btn3": {Name: "Stop", Command: "playerctl stop", Image: "stop.png"},
					"btn4": {Name: "Vol Up", Command: "amixer set Master 5%+", Image: "volume_up.png"},
					"btn5": {Name: "Vol Down", Command: "amixer set Master 5%-", Image: "volume_down.png"},
				},
			},
		},
	}
}
