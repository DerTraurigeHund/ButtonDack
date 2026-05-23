package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/DerTraurigeHund/buttondack/daemon/internal/actions"
	"github.com/DerTraurigeHund/buttondack/daemon/internal/config"
	"github.com/DerTraurigeHund/buttondack/daemon/internal/server"
	"github.com/DerTraurigeHund/buttondack/daemon/internal/spotify"
)

var version = "1.0.0-dev"

func main() {
	configPath := flag.String("config", "", "path to config file (default: ~/.config/buttondack/config.yaml)")
	host := flag.String("host", "0.0.0.0", "host to bind to")
	port := flag.Int("port", 42069, "port to listen on")
	showVersion := flag.Bool("version", false, "show version")
	flag.Parse()

	if *showVersion {
		fmt.Printf("ButtonDack Daemon v%s\n", version)
		os.Exit(0)
	}

	// Determine config path
	cfgPath := *configPath
	if cfgPath == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			log.Fatalf("cannot determine home dir: %v", err)
		}
		cfgPath = filepath.Join(home, ".config", "buttondack", "config.yaml")
	}

	log.Printf("[ButtonDack] Starting daemon v%s", version)
	log.Printf("[ButtonDack] Config: %s", cfgPath)

	// Load configuration
	cfgManager := config.NewManager(cfgPath)
	cfg, err := cfgManager.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}
	log.Printf("[ButtonDack] Loaded %d profiles", len(cfg.Profiles))

	// Override host/port from flags if provided
	if flag.Lookup("host").Value.String() != "0.0.0.0" || flag.Lookup("port").Value.String() != "42069" {
		cfg.Daemon.Host = *host
		cfg.Daemon.Port = *port
	}
	_ = host  // Used via cfg
	_ = port

	// Initialize components
	actionRunner := actions.NewRunner()
	spotifyClient := spotify.NewClient(cfg.Spotify.ClientID, cfg.Spotify.ClientSecret, cfg.Spotify.Enabled)

	// Create and start HTTP/WS server
	srv := server.NewServer(cfgManager, actionRunner, spotifyClient)

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("[ButtonDack] Shutting down...")
		if err := srv.Stop(); err != nil {
			log.Printf("[ButtonDack] Shutdown error: %v", err)
		}
		os.Exit(0)
	}()

	if err := srv.Start(cfg.Daemon.Host, cfg.Daemon.Port); err != nil {
		log.Fatalf("[ButtonDack] Server error: %v", err)
	}
}
