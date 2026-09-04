package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// BulkCreateRequest represents bulk asset creation request
type BulkCreateRequest struct {
	Assets []Asset `json:"assets"`
}

// BulkCreateResponse represents the result of bulk creation
type BulkCreateResponse struct {
	SuccessCount int      `json:"success_count"`
	FailedCount  int      `json:"failed_count"`
	FailedIDs    []string `json:"failed_ids,omitempty"`
	Message      string   `json:"message"`
}

// POST /api/assets/bulk-create - Bulk create assets from QR generator
func bulkCreateAssets(w http.ResponseWriter, r *http.Request) {
	var req BulkCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate assets
	if len(req.Assets) == 0 {
		http.Error(w, "No assets provided", http.StatusBadRequest)
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

	// Insert each asset
	for _, asset := range req.Assets {
		_, err := tx.Exec(`
			INSERT INTO assets (
				id, type, status, location, specs,
				category_id, subcategory_id, serial_number, license_key, expiry_date,
				quantity, min_stock_level, supplier, warranty_date,
				created_at, updated_at
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
		`,
			asset.ID, asset.Type, asset.Status, asset.Location, asset.Specs,
			asset.CategoryID, asset.SubcategoryID, asset.SerialNumber, asset.LicenseKey, asset.ExpiryDate,
			asset.Quantity, asset.MinStockLevel, asset.Supplier, asset.WarrantyDate,
		)

		if err != nil {
			failedCount++
			failedIDs = append(failedIDs, asset.ID)
			continue
		}
		successCount++
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to commit transaction", http.StatusInternalServerError)
		return
	}

	// Log activity
	details := fmt.Sprintf("Bulk created %d %s assets via QR Generator (failed: %d)",
		successCount, req.Assets[0].Type, failedCount)
	logActivity("admin", "CREATE", "assets_bulk", fmt.Sprintf("%d assets", successCount), details, "web")

	result := BulkCreateResponse{
		SuccessCount: successCount,
		FailedCount:  failedCount,
		FailedIDs:    failedIDs,
		Message:      fmt.Sprintf("Bulk asset creation completed: %d succeeded, %d failed", successCount, failedCount),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}
