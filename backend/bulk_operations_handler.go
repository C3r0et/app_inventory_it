package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// BulkStatusRequest represents bulk status update request
type BulkStatusRequest struct {
	AssetIDs  []string `json:"asset_ids"`
	NewStatus string   `json:"new_status"`
}

// BulkLocationRequest represents bulk location transfer request
type BulkLocationRequest struct {
	AssetIDs    []string `json:"asset_ids"`
	NewLocation string   `json:"new_location"`
}

// BulkOperationResult represents the result of bulk operation
type BulkOperationResult struct {
	SuccessCount int      `json:"success_count"`
	FailedCount  int      `json:"failed_count"`
	FailedIDs    []string `json:"failed_ids,omitempty"`
	Message      string   `json:"message"`
}

// POST /api/assets/bulk-status - Bulk update asset status
func bulkUpdateStatus(w http.ResponseWriter, r *http.Request) {
	var req BulkStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate status
	validStatuses := map[string]bool{
		"AVAILABLE": true,
		"IN_USE":    true,
		"BROKEN":    true,
		"GHOST":     true,
	}
	if !validStatuses[req.NewStatus] {
		http.Error(w, "Invalid status. Must be AVAILABLE, IN_USE, BROKEN, or GHOST", http.StatusBadRequest)
		return
	}

	// Validate asset IDs
	if len(req.AssetIDs) == 0 {
		http.Error(w, "No asset IDs provided", http.StatusBadRequest)
		return
	}

	// Start transaction
	tx, err := db.Begin()
	if err != nil {
		http.Error(w, "Failed to start transaction", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	successCount := 0
	failedCount := 0
	var failedIDs []string

	// Update each asset
	for _, assetID := range req.AssetIDs {
		result, err := tx.Exec("UPDATE assets SET status = ?, updated_at = NOW() WHERE id = ?", req.NewStatus, assetID)
		if err != nil {
			failedCount++
			failedIDs = append(failedIDs, assetID)
			continue
		}

		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			// Asset ID not found
			failedCount++
			failedIDs = append(failedIDs, assetID)
		} else {
			successCount++
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to commit transaction", http.StatusInternalServerError)
		return
	}

	// Log activity
	logActivity("admin", "UPDATE", "assets_bulk", fmt.Sprintf("%d assets", successCount),
		fmt.Sprintf("Bulk status update: %d assets to %s (failed: %d)", successCount, req.NewStatus, failedCount), "web")

	result := BulkOperationResult{
		SuccessCount: successCount,
		FailedCount:  failedCount,
		FailedIDs:    failedIDs,
		Message:      "Bulk status update completed",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// POST /api/assets/bulk-location - Bulk update asset location
func bulkUpdateLocation(w http.ResponseWriter, r *http.Request) {
	var req BulkLocationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate location
	if req.NewLocation == "" {
		http.Error(w, "New location is required", http.StatusBadRequest)
		return
	}

	// Validate asset IDs
	if len(req.AssetIDs) == 0 {
		http.Error(w, "No asset IDs provided", http.StatusBadRequest)
		return
	}

	// Start transaction
	tx, err := db.Begin()
	if err != nil {
		http.Error(w, "Failed to start transaction", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	successCount := 0
	failedCount := 0
	var failedIDs []string

	// Update each asset
	for _, assetID := range req.AssetIDs {
		result, err := tx.Exec("UPDATE assets SET location = ?, updated_at = NOW() WHERE id = ?", req.NewLocation, assetID)
		if err != nil {
			failedCount++
			failedIDs = append(failedIDs, assetID)
			continue
		}

		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			// Asset ID not found
			failedCount++
			failedIDs = append(failedIDs, assetID)
		} else {
			successCount++
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to commit transaction", http.StatusInternalServerError)
		return
	}

	// Log activity
	logActivity("admin", "UPDATE", "assets_bulk", fmt.Sprintf("%d assets", successCount),
		fmt.Sprintf("Bulk location transfer: %d assets to %s (failed: %d)", successCount, req.NewLocation, failedCount), "web")

	result := BulkOperationResult{
		SuccessCount: successCount,
		FailedCount:  failedCount,
		FailedIDs:    failedIDs,
		Message:      "Bulk location transfer completed",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}
