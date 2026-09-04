package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"
)

// SSEBroker handles Server-Sent Events clients and broadcasting
type SSEBroker struct {
	clients map[chan string]bool
	mu      sync.RWMutex
}

var sseBroker *SSEBroker

func init() {
	sseBroker = &SSEBroker{
		clients: make(map[chan string]bool),
	}
}

// handleSSE serves the SSE connection endpoint
func (b *SSEBroker) handleSSE(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	// Set required headers for Server-Sent Events
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no") // Disable Nginx proxy buffering
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	// Create client channel
	messageChan := make(chan string, 20)

	b.mu.Lock()
	b.clients[messageChan] = true
	clientCount := len(b.clients)
	b.mu.Unlock()

	log.Printf("🔌 SSE Client connected (active clients: %d)", clientCount)

	// Send initial greeting
	fmt.Fprintf(w, "event: connected\ndata: {\"status\":\"connected\",\"clients\":%d}\n\n", clientCount)
	flusher.Flush()

	// Ticker for keepalive ping (every 20 seconds)
	keepAliveTicker := time.NewTicker(20 * time.Second)
	defer keepAliveTicker.Stop()

	// Clean up on disconnect
	defer func() {
		b.mu.Lock()
		delete(b.clients, messageChan)
		remCount := len(b.clients)
		b.mu.Unlock()
		close(messageChan)
		log.Printf("🔌 SSE Client disconnected (remaining clients: %d)", remCount)
	}()

	notify := r.Context().Done()

	for {
		select {
		case <-notify:
			return
		case <-keepAliveTicker.C:
			// Ping comment to keep connection alive through proxies/Nginx
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		case msg, ok := <-messageChan:
			if !ok {
				return
			}
			fmt.Fprintf(w, "%s", msg)
			flusher.Flush()
		}
	}
}

// broadcastActivity sends a formatted SSE event to all connected clients
func (b *SSEBroker) broadcastActivity(event string, data interface{}) {
	payload, err := json.Marshal(data)
	if err != nil {
		log.Printf("Error marshaling SSE data: %v", err)
		return
	}

	msg := fmt.Sprintf("event: %s\ndata: %s\n\n", event, string(payload))

	b.mu.RLock()
	defer b.mu.RUnlock()

	for ch := range b.clients {
		select {
		case ch <- msg:
		default:
			// Channel buffer full, skip to avoid blocking other clients
		}
	}
}
