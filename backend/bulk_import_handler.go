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

// BulkImportResult represents the result of bulk import
type BulkImportResult struct {
	SuccessCount int           `json:"success_count"`
	ErrorCount   int           `json:"error_count"`
	Errors       []ImportError `json:"errors"`
}

// ImportError represents an error for a specific row
type ImportError struct {
	Row     int    `json:"row"`
	AssetID string `json:"asset_id"`
	Error   string `json:"error"`
}

// BulkImportAsset represents asset data from Excel
type BulkImportAsset struct {
	ID              string  `json:"id"`
	CategoryName    string  `json:"category_name"`
	SubcategoryName string  `json:"subcategory_name"`
	Status          string  `json:"status"`
	Location        string  `json:"location"`
	SerialNumber    *string `json:"serial_number"`
	LicenseKey      *string `json:"license_key"`
	ExpiryDate      *string `json:"expiry_date"`
	Quantity        *int    `json:"quantity"`
	MinStockLevel   *int    `json:"min_stock_level"`
	Supplier        *string `json:"supplier"`
	WarrantyDate    *string `json:"warranty_date"`
	Specs           string  `json:"specs"`
}

// POST /api/assets/bulk-import - Bulk import assets from Excel
func bulkImportAssets(w http.ResponseWriter, r *http.Request) {
	// Parse multipart form (10MB max)
	err := r.ParseMultipartForm(10 << 20)
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

	// Read Excel file
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

	// Read rows from first sheet
	rows, err := f.GetRows("Sheet1")
	if err != nil || len(rows) < 2 {
		http.Error(w, "Invalid Excel format", http.StatusBadRequest)
		return
	}

	result := BulkImportResult{
		Errors: []ImportError{},
	}

	// Skip header row, process data rows
	for i, row := range rows[1:] {
		rowNum := i + 2 // Excel row number (1-indexed + header)

		if len(row) < 4 {
			result.ErrorCount++
			result.Errors = append(result.Errors, ImportError{
				Row:   rowNum,
				Error: "Missing required columns",
			})
			continue
		}

		assetID := strings.TrimSpace(row[0])
		categoryName := strings.TrimSpace(row[1])
		status := strings.TrimSpace(row[2])
		location := strings.TrimSpace(row[3])

		// Validate required fields
		if assetID == "" || categoryName == "" || status == "" || location == "" {
			result.ErrorCount++
			result.Errors = append(result.Errors, ImportError{
				Row:     rowNum,
				AssetID: assetID,
				Error:   "Missing required fields (ID, Category, Status, Location)",
			})
			continue
		}

		// Validate status
		if status != "AVAILABLE" && status != "IN_USE" && status != "BROKEN" {
			result.ErrorCount++
			result.Errors = append(result.Errors, ImportError{
				Row:     rowNum,
				AssetID: assetID,
				Error:   fmt.Sprintf("Invalid status: %s (must be AVAILABLE, IN_USE, or BROKEN)", status),
			})
			continue
		}

		// Find category by name
		var categoryID *int
		err := db.QueryRow("SELECT id FROM categories WHERE name = ? AND parent_id IS NULL", categoryName).Scan(&categoryID)
		if err != nil {
			result.ErrorCount++
			result.Errors = append(result.Errors, ImportError{
				Row:     rowNum,
				AssetID: assetID,
				Error:   fmt.Sprintf("Category not found: %s", categoryName),
			})
			continue
		}

		// Optional fields
		var subcategoryID *int
		var specs, serialNumber, licenseKey, expiryDate, supplier, warrantyDate *string
		var quantity, minStockLevel *int

		if len(row) > 4 && row[4] != "" {
			subcatName := strings.TrimSpace(row[4])
			db.QueryRow("SELECT id FROM categories WHERE name = ? AND parent_id = ?", subcatName, categoryID).Scan(&subcategoryID)
		}
		if len(row) > 5 && row[5] != "" {
			val := strings.TrimSpace(row[5])
			specs = &val
		}
		if len(row) > 6 && row[6] != "" {
			val := strings.TrimSpace(row[6])
			serialNumber = &val
		}
		if len(row) > 7 && row[7] != "" {
			val := strings.TrimSpace(row[7])
			licenseKey = &val
		}
		if len(row) > 8 && row[8] != "" {
			val := strings.TrimSpace(row[8])
			expiryDate = &val
		}
		if len(row) > 9 && row[9] != "" {
			if q, err := strconv.Atoi(strings.TrimSpace(row[9])); err == nil {
				quantity = &q
			}
		}
		if len(row) > 10 && row[10] != "" {
			if m, err := strconv.Atoi(strings.TrimSpace(row[10])); err == nil {
				minStockLevel = &m
			}
		}
		if len(row) > 11 && row[11] != "" {
			val := strings.TrimSpace(row[11])
			supplier = &val
		}
		if len(row) > 12 && row[12] != "" {
			val := strings.TrimSpace(row[12])
			warrantyDate = &val
		}

		// Insert asset
		_, err = db.Exec(`
			INSERT INTO assets (id, type, status, location, specs, category_id, subcategory_id, 
				serial_number, license_key, expiry_date, quantity, min_stock_level, supplier, warranty_date)
			VALUES (?, 'IMPORTED', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`, assetID, status, location, specs, categoryID, subcategoryID, serialNumber, licenseKey,
			expiryDate, quantity, minStockLevel, supplier, warrantyDate)

		if err != nil {
			result.ErrorCount++
			result.Errors = append(result.Errors, ImportError{
				Row:     rowNum,
				AssetID: assetID,
				Error:   fmt.Sprintf("Database error: %s (possibly duplicate Asset ID)", err.Error()),
			})
			continue
		}

		result.SuccessCount++
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// GET /api/assets/bulk-import/template - Download Excel template
func downloadTemplate(w http.ResponseWriter, r *http.Request) {
	f := excelize.NewFile()
	defer f.Close()

	// Create main sheet
	sheetName := "Asset Import Template"
	index, _ := f.NewSheet(sheetName)
	f.SetActiveSheet(index)
	f.DeleteSheet("Sheet1")

	// Set headers
	headers := []string{
		"Asset ID*", "Category*", "Status*", "Location*", "Subcategory",
		"Specs", "Serial Number", "License Key", "Expiry Date",
		"Quantity", "Min Stock Level", "Supplier", "Warranty Date",
	}

	for i, header := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheetName, cell, header)
	}

	// Style header row
	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 11},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"#4472C4"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
	})
	f.SetCellStyle(sheetName, "A1", "M1", headerStyle)

	// Add example row
	example := []interface{}{
		"CPU-001", "Hardware", "AVAILABLE", "D-COL-001", "Memory",
		"Intel i5, 8GB RAM", "SN123456", "", "",
		"", "", "", "",
	}
	for i, val := range example {
		cell, _ := excelize.CoordinatesToCellName(i+1, 2)
		f.SetCellValue(sheetName, cell, val)
	}

	// Get categories for dropdown
	rows, err := db.Query("SELECT name FROM categories WHERE parent_id IS NULL ORDER BY name")
	if err == nil {
		defer rows.Close()
		var categories []string
		for rows.Next() {
			var name string
			rows.Scan(&name)
			categories = append(categories, name)
		}

		// Add data validation for Category column
		if len(categories) > 0 {
			dvRange := excelize.NewDataValidation(true)
			dvRange.Sqref = "B2:B1000"
			dvRange.SetDropList(categories)
			f.AddDataValidation(sheetName, dvRange)
		}
	}

	// Add data validation for Status column
	statusDV := excelize.NewDataValidation(true)
	statusDV.Sqref = "C2:C1000"
	statusDV.SetDropList([]string{"AVAILABLE", "IN_USE", "BROKEN"})
	f.AddDataValidation(sheetName, statusDV)

	// Set column widths
	f.SetColWidth(sheetName, "A", "A", 15)
	f.SetColWidth(sheetName, "B", "D", 20)
	f.SetColWidth(sheetName, "E", "M", 15)

	// Add instructions sheet
	instrSheet := "Instructions"
	f.NewSheet(instrSheet)
	instructions := []string{
		"HOW TO USE THIS TEMPLATE:",
		"",
		"1. Fill in the required fields marked with * (Asset ID, Category, Status, Location)",
		"2. Use the dropdown for Category and Status columns",
		"3. Optional fields can be left empty",
		"4. Save the file and upload it to the Bulk Import page",
		"",
		"FIELD DESCRIPTIONS:",
		"- Asset ID: Unique identifier (e.g., CPU-001, MON-042)",
		"- Category: Main category (use dropdown)",
		"- Status: AVAILABLE, IN_USE, or BROKEN (use dropdown)",
		"- Location: Physical location (e.g., D-COL-001)",
		"- Subcategory: Optional subcategory name",
		"- Specs: Technical specifications",
		"- Serial Number: For hardware items",
		"- License Key: For software items",
		"- Expiry Date: For software licenses (YYYY-MM-DD)",
		"- Quantity: For consumables",
		"- Min Stock Level: Minimum quantity alert threshold",
		"- Supplier: Vendor/supplier name",
		"- Warranty Date: Warranty expiration (YYYY-MM-DD)",
	}

	for i, instruction := range instructions {
		f.SetCellValue(instrSheet, fmt.Sprintf("A%d", i+1), instruction)
	}
	f.SetColWidth(instrSheet, "A", "A", 80)

	// Write to response
	w.Header().Set("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	w.Header().Set("Content-Disposition", "attachment; filename=asset_import_template.xlsx")
	f.Write(w)
}
