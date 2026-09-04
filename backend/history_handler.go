package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"
	"time"
)

// AuditLog represents an activity log entry
type AuditLog struct {
	ID         int       `json:"id"`
	Timestamp  time.Time `json:"timestamp"`
	User       string    `json:"user"`
	Action     string    `json:"action"`
	EntityType string    `json:"entity_type"`
	EntityID   string    `json:"entity_id,omitempty"`
	Details    string    `json:"details"`
	Source     string    `json:"source"`
}

// LogActivityRequest for manual logging from mobile
type LogActivityRequest struct {
	User       string `json:"user"`
	Action     string `json:"action"`
	EntityType string `json:"entity_type"`
	EntityID   string `json:"entity_id"`
	Details    string `json:"details"`
	Source     string `json:"source"`
}

// Helper function to log activity and broadcast via SSE
func logActivity(user, action, entityType, entityID, details, source string) error {
	_, err := db.Exec(`
		INSERT INTO audit_logs (user, action, entity_type, entity_id, details, source)
		VALUES (?, ?, ?, ?, ?, ?)
	`, user, action, entityType, entityID, details, source)

	// Broadcast real-time activity to connected dashboards via SSE
	if sseBroker != nil {
		sseBroker.broadcastActivity("activity", map[string]interface{}{
			"timestamp":   time.Now().Format("2006-01-02 15:04:05"),
			"user":        user,
			"action":      action,
			"entity_type": entityType,
			"entity_id":   entityID,
			"details":     details,
			"source":      source,
		})
	}

	return err
}


// GET /api/history - Fetch audit logs with pagination
func getHistory(w http.ResponseWriter, r *http.Request) {
	// Get query parameters
	limit := r.URL.Query().Get("limit")
	if limit == "" {
		limit = "100"
	}

	source := r.URL.Query().Get("source")
	action := r.URL.Query().Get("action")
	assetID := r.URL.Query().Get("asset_id")

	// Build query
	query := "SELECT id, timestamp, user, action, entity_type, entity_id, details, source FROM audit_logs WHERE 1=1"
	args := []interface{}{}

	if source != "" {
		query += " AND source = ?"
		args = append(args, source)
	}
	if action != "" {
		query += " AND action = ?"
		args = append(args, action)
	}
	if assetID != "" {
		altID := strings.ReplaceAll(assetID, "/", "-")
		slashID := strings.ReplaceAll(assetID, "-", "/")
		query += " AND (entity_id = ? OR entity_id = ? OR entity_id = ? OR details LIKE ?)"
		args = append(args, assetID, altID, slashID, "%"+assetID+"%")
	}

	query += " ORDER BY timestamp DESC LIMIT ?"
	args = append(args, limit)

	rows, err := db.Query(query, args...)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		var entityID sql.NullString
		err := rows.Scan(&log.ID, &log.Timestamp, &log.User, &log.Action, &log.EntityType, &entityID, &log.Details, &log.Source)
		if err != nil {
			continue
		}
		if entityID.Valid {
			log.EntityID = entityID.String
		}
		logs = append(logs, log)
	}

	if logs == nil {
		logs = []AuditLog{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(logs)
}

// POST /api/history/log - Manual log creation (for mobile app)
func createLog(w http.ResponseWriter, r *http.Request) {
	var req LogActivityRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Default source to 'mobile' if not specified
	if req.Source == "" {
		req.Source = "mobile"
	}

	err := logActivity(req.User, req.Action, req.EntityType, req.EntityID, req.Details, req.Source)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Log created"})
}
