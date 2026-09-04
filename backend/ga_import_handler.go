package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/xuri/excelize/v2"
)

// GAImportResult summarizes result of GA Excel Master import
type GAImportResult struct {
	TotalProcessed int           `json:"total_processed"`
	SuccessCount   int           `json:"success_count"`
	UpdatedCount   int           `json:"updated_count"`
	ErrorCount     int           `json:"error_count"`
	Errors         []ImportError `json:"errors"`
	CategoryCounts map[string]int `json:"category_counts"`
}

// POST /api/assets/import-ga-master - Import GA Master Excel (5 Core Devices)
func importGAMaster(w http.ResponseWriter, r *http.Request) {
	err := r.ParseMultipartForm(20 << 20) // 20MB max
	if err != nil {
		http.Error(w, "File too large", http.StatusBadRequest)
		return
	}

	file, _, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "No file uploaded", http.StatusBadRequest)
		return
	}
	defer file.Close()

	fileBytes, err := io.ReadAll(file)
	if err != nil {
		http.Error(w, "Failed to read file", http.StatusInternalServerError)
		return
	}

	f, err := excelize.OpenReader(strings.NewReader(string(fileBytes)))
	if err != nil {
		http.Error(w, "Invalid Excel file", http.StatusBadRequest)
		return
	}
	defer f.Close()

	result := GAImportResult{
		Errors:         []ImportError{},
		CategoryCounts: make(map[string]int),
	}

	// Definition of 5 core device categories with prefixes and sheet pairs
	categories := []struct {
		TypeName   string
		Prefix     string
		NoInvSheet string
		InvSheet   string
	}{
		{"Monitor", "MN", "MONITOR - NO INV", "MONITOR - INVENTARIS"},
		{"CPU", "PC", "CPU - NO INV", "CPU - INVENTARIS"},
		{"Keyboard", "KB", "KEYBOARD - NO INV", "KEYBOARD - INVENTARIS"},
		{"Mouse", "MS", "MOUSE - NO INV", "MOUSE - INVENTARIS"},
		{"Headset", "HD", "HEADSET - NO INV", "HEADSET - INVENTARIS"},
	}

	for _, cat := range categories {
		// 1. Process "- NO INV" Sheet (Legacy Naming & Sticker Status)
		noInvRows, err := f.GetRows(cat.NoInvSheet)
		if err == nil && len(noInvRows) > 3 {
			for i, row := range noInvRows[3:] {
				if len(row) < 3 || strings.TrimSpace(row[2]) == "" {
					continue
				}

				rawCode := strings.TrimSpace(row[2]) // e.g. "MN/0181/2025"
				result.TotalProcessed++

				// Primary Asset ID e.g. "MN-0181"
				parts := strings.Split(rawCode, "/")
				assetID := rawCode
				if len(parts) >= 2 {
					assetID = fmt.Sprintf("%s-%s", parts[0], parts[1])
				}

				// Check sticker status
				stickerStatus := "UNSTICKERED"
				if len(row) > 3 && isTruthy(row[3]) {
					stickerStatus = "STICKERED"
				}

				note := ""
				if len(row) > 5 {
					note = strings.TrimSpace(row[5])
				}

				// Insert or Update in DB
				_, execErr := db.Exec(`
					INSERT INTO assets (id, type, status, location, specs, note, legacy_inv_code, sticker_status)
					VALUES (?, ?, 'AVAILABLE', 'Ruang IT', 'Source: GA Master NO INV', ?, ?, ?)
					ON DUPLICATE KEY UPDATE 
						legacy_inv_code = VALUES(legacy_inv_code),
						sticker_status = VALUES(sticker_status),
						note = COALESCE(NULLIF(VALUES(note), ''), note)
				`, assetID, cat.TypeName, note, rawCode, stickerStatus)

				if execErr != nil {
					result.ErrorCount++
					result.Errors = append(result.Errors, ImportError{
						Row:     i + 4,
						AssetID: assetID,
						Error:   execErr.Error(),
					})
				} else {
					result.SuccessCount++
					result.CategoryCounts[cat.TypeName]++
				}
			}
		}

		// 2. Process "- INVENTARIS" Sheet (Latest Operational Status & Simple Sequence)
		invRows, err := f.GetRows(cat.InvSheet)
		if err == nil && len(invRows) > 1 {
			for i, row := range invRows[1:] {
				if len(row) < 3 || strings.TrimSpace(row[2]) == "" {
					continue
				}

				noInvRaw := strings.TrimSpace(row[2]) // e.g. "9.0" or "9"
				if floatVal, parseErr := strconv.ParseFloat(noInvRaw, 64); parseErr == nil {
					noInvRaw = fmt.Sprintf("%04d", int(floatVal))
				} else if len(noInvRaw) < 4 {
					noInvRaw = fmt.Sprintf("%04s", noInvRaw)
				}

				assetID := fmt.Sprintf("%s-%s", cat.Prefix, noInvRaw)
				result.TotalProcessed++

				// Status mapping: TERPAKAI, RUSAK, PERBAIKI
				status := "AVAILABLE"
				if len(row) > 4 && isTruthy(row[4]) {
					status = "BROKEN"
				} else if len(row) > 5 && isTruthy(row[5]) {
					status = "REPAIRING"
				} else if len(row) > 3 && isTruthy(row[3]) {
					status = "IN_USE"
				}

				note := ""
				if len(row) > 6 {
					note = strings.TrimSpace(row[6])
				}

				_, execErr := db.Exec(`
					INSERT INTO assets (id, type, status, location, specs, note, sticker_status)
					VALUES (?, ?, ?, 'Ruang IT', 'Source: GA Master INVENTARIS', ?, 'STICKERED')
					ON DUPLICATE KEY UPDATE 
						status = VALUES(status),
						note = COALESCE(NULLIF(VALUES(note), ''), note)
				`, assetID, cat.TypeName, status, note)

				if execErr != nil {
					result.ErrorCount++
					result.Errors = append(result.Errors, ImportError{
						Row:     i + 2,
						AssetID: assetID,
						Error:   execErr.Error(),
					})
				} else {
					result.SuccessCount++
					result.CategoryCounts[cat.TypeName]++
				}
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func isTruthy(val string) bool {
	v := strings.TrimSpace(strings.ToUpper(val))
	return v == "TRUE" || v == "1" || v == "V" || v == "YA" || v == "YES"
}
