package main

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/gorilla/mux"
)

// POST /api/desks - Create single desk
func createDesk(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Number int    `json:"number"`
		Area   string `json:"area"`
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	deskID := fmt.Sprintf("D-%s-%03d", req.Area[:3], req.Number)
	_, err := db.Exec(
		"INSERT INTO desks (id, area, number, status) VALUES (?, ?, ?, ?)",
		deskID, req.Area, req.Number, req.Status,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity with details
	details := fmt.Sprintf("Created desk %s in area '%s'", deskID, req.Area)
	logActivity("admin", "CREATE", "desk", deskID, details, "web")

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Desk created", "id": deskID})
}

// PUT /api/desks/{id} - Update desk
func updateDesk(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var req struct {
		Number int    `json:"number"`
		Area   string `json:"area"`
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	newID := fmt.Sprintf("D-%s-%03d", req.Area[:3], req.Number)

	// If ID changed, delete old and create new
	if id != newID {
		_, err := db.Exec("DELETE FROM desks WHERE id = ?", id)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		_, err = db.Exec(
			"INSERT INTO desks (id, area, number, status) VALUES (?, ?, ?, ?)",
			newID, req.Area, req.Number, req.Status,
		)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		// Log activity
		logActivity("admin", "UPDATE", "desk", newID, fmt.Sprintf("Updated desk from %s to %s", id, newID), "web")
		// Log activity for desk ID change
		details := fmt.Sprintf("Updated desk ID from '%s' to '%s' in area %s", id, newID, req.Area)
		logActivity("admin", "UPDATE", "desk", newID, details, "web")
	} else {
		// Just update
		_, err := db.Exec(
			"UPDATE desks SET area = ?, number = ?, status = ? WHERE id = ?",
			req.Area, req.Number, req.Status, id,
		)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		// Log activity for desk update
		details := fmt.Sprintf("Updated desk '%s' - Area: %s", id, req.Area)
		logActivity("admin", "UPDATE", "desk", id, details, "web")
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Desk updated"})
}

// DELETE /api/desks/{id} - Delete desk
func deleteDesk(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("DELETE FROM desks WHERE id = ?", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity
	details := fmt.Sprintf("Deleted desk '%s' from system", id)
	logActivity("admin", "DELETE", "desk", id, details, "web")

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Desk deleted"})
}
