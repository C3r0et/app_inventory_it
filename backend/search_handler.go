package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
)

// AssetSearchResult represents search result with match info
type AssetSearchResult struct {
	Asset
	MatchedBy string `json:"matched_by"` // "serial_number" or "asset_id"
}

// GET /api/assets/search?q={query} - Smart search by SN or Asset ID
func searchAsset(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		http.Error(w, "Query parameter 'q' is required", http.StatusBadRequest)
		return
	}

	var asset Asset
	var matchedBy string

	// Try to find by Serial Number first
	err := db.QueryRow(`
		SELECT id, type, status, location, specs, category_id, subcategory_id,
			serial_number, license_key, expiry_date, quantity, min_stock_level,
			supplier, warranty_date, updated_at
		FROM assets 
		WHERE serial_number = ?
	`, query).Scan(
		&asset.ID, &asset.Type, &asset.Status, &asset.Location, &asset.Specs,
		&asset.CategoryID, &asset.SubcategoryID, &asset.SerialNumber,
		&asset.LicenseKey, &asset.ExpiryDate, &asset.Quantity, &asset.MinStockLevel,
		&asset.Supplier, &asset.WarrantyDate, &asset.UpdatedAt,
	)

	if err == nil {
		matchedBy = "serial_number"
	} else if err == sql.ErrNoRows {
		// Not found by SN, try Asset ID
		err = db.QueryRow(`
			SELECT id, type, status, location, specs, category_id, subcategory_id,
				serial_number, license_key, expiry_date, quantity, min_stock_level,
				supplier, warranty_date, updated_at
			FROM assets 
			WHERE id = ?
		`, query).Scan(
			&asset.ID, &asset.Type, &asset.Status, &asset.Location, &asset.Specs,
			&asset.CategoryID, &asset.SubcategoryID, &asset.SerialNumber,
			&asset.LicenseKey, &asset.ExpiryDate, &asset.Quantity, &asset.MinStockLevel,
			&asset.Supplier, &asset.WarrantyDate, &asset.UpdatedAt,
		)

		if err == nil {
			matchedBy = "asset_id"
		} else if err == sql.ErrNoRows {
			http.Error(w, "Asset not found", http.StatusNotFound)
			return
		} else {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	} else {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	result := AssetSearchResult{
		Asset:     asset,
		MatchedBy: matchedBy,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}
