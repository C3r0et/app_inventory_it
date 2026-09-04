package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"image"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

// Models
type Asset struct {
	ID            string    `json:"id"`
	Type          string    `json:"type"`
	Status        string    `json:"status"`
	Location      string    `json:"location"`
	Specs         string    `json:"specs,omitempty"`
	CategoryID    *int      `json:"category_id,omitempty"`
	SubcategoryID *int      `json:"subcategory_id,omitempty"`
	LegacyInvCode *string   `json:"legacy_inv_code,omitempty"`
	StickerStatus string    `json:"sticker_status,omitempty"`
	// Conditional fields
	SerialNumber  *string   `json:"serial_number,omitempty"`
	LicenseKey    *string   `json:"license_key,omitempty"`
	ExpiryDate    *string   `json:"expiry_date,omitempty"`
	Quantity      *int      `json:"quantity,omitempty"`
	MinStockLevel *int      `json:"min_stock_level,omitempty"`
	Supplier      *string   `json:"supplier,omitempty"`
	WarrantyDate  *string   `json:"warranty_date,omitempty"`
	ImagePath     *string   `json:"image_path,omitempty"`
	Note          string    `json:"note,omitempty"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type Category struct {
	ID       int        `json:"id"`
	Name     string     `json:"name"`
	ParentID *int       `json:"parent_id,omitempty"`
	Type     string     `json:"type"`
	Icon     *string    `json:"icon,omitempty"`
	Children []Category `json:"children,omitempty"`
}

type Desk struct {
	ID              string `json:"id"`
	Area            string `json:"area"`
	Number          int    `json:"number"`
	Status          string `json:"status"`
	AssignedAssetID string `json:"assigned_asset_id,omitempty"`
}

type BaselineAuditRequest struct {
	DeskNumber int      `json:"desk_number"`
	Area       string   `json:"area"`
	AssetTypes []string `json:"asset_types"`
}

var db *sql.DB

func main() {
	// Database connection
	var err error
	dsn := os.Getenv("DB_DSN")
	if dsn == "" {
		dsn = "userdb:sahabat25*@tcp(10.9.9.110:3306)/asset_inventory?parseTime=true"
	}
	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Error connecting to database:", err)
	}
	defer db.Close()

	// Test connection
	if err = db.Ping(); err != nil {
		log.Fatal("Database ping failed:", err)
	}
	log.Println("✓ Connected to MariaDB")

	// Initialize tables
	initDB()

	// Router
	r := mux.NewRouter()

	// CORS middleware
	r.Use(corsMiddleware)

	// Routes - Specific Asset Routes First
	r.HandleFunc("/api/assets", getAssets).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/assets", createAsset).Methods("POST", "OPTIONS")

	// Smart search route (supports legacy_inv_code, OCR results)
	r.HandleFunc("/api/assets/search", searchAssetSmart).Methods("GET", "OPTIONS")

	// Bulk import & operations routes
	r.HandleFunc("/api/assets/bulk-import", bulkImportAssets).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/assets/bulk-import/template", downloadTemplate).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/assets/import-ga-master", importGAMaster).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/assets/bulk-status", bulkUpdateStatus).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/assets/bulk-location", bulkUpdateLocation).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/assets/bulk-create", bulkCreateAssets).Methods("POST", "OPTIONS")

	// Audit & Quick Field Audit routes
	r.HandleFunc("/api/assets/audit-submit", submitAudit).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/assets/{id:.*}/history", getAssetHistory).Methods("GET", "OPTIONS")

	// Catch-all Asset routes (Must be after specific sub-routes)
	r.HandleFunc("/api/assets/{id:.*}", updateAsset).Methods("PUT", "OPTIONS")
	r.HandleFunc("/api/assets/{id:.*}", deleteAsset).Methods("DELETE", "OPTIONS")

	r.HandleFunc("/api/desks", getDesks).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/desks", createDesk).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/desks/init", initDeskMaster).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/desks/{id:.*}", updateDesk).Methods("PUT", "OPTIONS")
	r.HandleFunc("/api/desks/{id:.*}", deleteDesk).Methods("DELETE", "OPTIONS")

	r.HandleFunc("/api/baseline-audit", baselineAudit).Methods("POST")

	// Category routes
	r.HandleFunc("/api/categories", getCategories).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/categories", createCategory).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/categories/{id}", updateCategory).Methods("PUT", "OPTIONS")
	r.HandleFunc("/api/categories/{id}", deleteCategory).Methods("DELETE", "OPTIONS")
	r.HandleFunc("/api/categories/{id}/subcategories", getSubcategories).Methods("GET", "OPTIONS")

	// History/Audit logs
	r.HandleFunc("/api/history", getHistory).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/history/log", createLog).Methods("POST", "OPTIONS")

	// File Upload
	r.HandleFunc("/api/upload", uploadFile).Methods("POST", "OPTIONS")
	// Serve static files
	r.PathPrefix("/uploads/").Handler(http.StripPrefix("/uploads/", http.FileServer(http.Dir("./uploads/"))))

	// Statistics & Executive Analytics
	r.HandleFunc("/api/stats", getStats).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/analytics/executive-report", getExecutiveAnalyticsReport).Methods("GET", "OPTIONS")
	r.HandleFunc("/api/analytics/bast-stats", getBastStats).Methods("GET", "OPTIONS")

	// Health check
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}).Methods("GET")

	// Ensure uploads directory exists
	if err := os.MkdirAll("./uploads", os.ModePerm); err != nil {
		log.Fatal("Failed to create uploads directory:", err)
	}

	// Serve Frontend SPA if dist directory exists
	if _, err := os.Stat("./dist"); err == nil {
		log.Println("✓ Serving Frontend SPA from ./dist")
		spa := spaHandler{staticPath: "./dist", indexPath: "index.html"}
		r.PathPrefix("/").Handler(spa)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 Server running on http://0.0.0.0:%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

type spaHandler struct {
	staticPath string
	indexPath  string
}

func (h spaHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := filepath.Join(h.staticPath, r.URL.Path)

	fi, err := os.Stat(path)
	if os.IsNotExist(err) || fi.IsDir() {
		http.ServeFile(w, r, filepath.Join(h.staticPath, h.indexPath))
		return
	}

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	http.FileServer(http.Dir(h.staticPath)).ServeHTTP(w, r)
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "3600")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func initDB() {
	// Create categories table FIRST
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS categories (
			id INT AUTO_INCREMENT PRIMARY KEY,
			name VARCHAR(100) NOT NULL,
			parent_id INT NULL,
			type ENUM('HARDWARE', 'SOFTWARE', 'CABLES', 'CONSUMABLES', 'NETWORK') NOT NULL,
			icon VARCHAR(50),
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE,
			INDEX idx_parent (parent_id),
			INDEX idx_type (type)
		)
	`)
	if err != nil {
		log.Println("Error creating categories table:", err)
	}

	// Create assets table
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS assets (
			id VARCHAR(100) PRIMARY KEY,
			type VARCHAR(50) NOT NULL,
			status VARCHAR(50) NOT NULL,
			location VARCHAR(100),
			specs TEXT,
			image_path TEXT,
			note TEXT,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		log.Fatal("Error creating assets table:", err)
	}

	// Alter to add all missing columns
	queries := []string{
		"ALTER TABLE assets ADD COLUMN image_path TEXT",
		"ALTER TABLE assets ADD COLUMN note TEXT",
		"ALTER TABLE assets ADD COLUMN category_id INT",
		"ALTER TABLE assets ADD COLUMN subcategory_id INT NULL",
		"ALTER TABLE assets ADD COLUMN serial_number VARCHAR(100) NULL",
		"ALTER TABLE assets ADD COLUMN license_key VARCHAR(255) NULL",
		"ALTER TABLE assets ADD COLUMN expiry_date DATE NULL",
		"ALTER TABLE assets ADD COLUMN quantity INT DEFAULT 1",
		"ALTER TABLE assets ADD COLUMN min_stock_level INT NULL",
		"ALTER TABLE assets ADD COLUMN supplier VARCHAR(255) NULL",
		"ALTER TABLE assets ADD COLUMN warranty_date DATE NULL",
		"ALTER TABLE assets ADD COLUMN legacy_inv_code VARCHAR(100) NULL",
		"ALTER TABLE assets ADD COLUMN sticker_status VARCHAR(50) DEFAULT 'UNKNOWN'",
	}

	for _, q := range queries {
		// Ignore error since Duplicate column error is expected
		db.Exec(q)
	}

	// Alter existing database to convert VARCHAR to TEXT
	_, _ = db.Exec("ALTER TABLE assets MODIFY COLUMN image_path TEXT")

	// Create desks table
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS desks (
			id VARCHAR(100) PRIMARY KEY,
			area VARCHAR(100) NOT NULL,
			number INT NOT NULL,
			status VARCHAR(50) NOT NULL,
			assigned_asset_id VARCHAR(100),
			UNIQUE KEY unique_desk (area, number)
		)
	`)
	if err != nil {
		log.Fatal("Error creating desks table:", err)
	}

	// Create audit_logs table
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS audit_logs (
			id INT AUTO_INCREMENT PRIMARY KEY,
			timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			user VARCHAR(100) NOT NULL,
			action VARCHAR(20) NOT NULL,
			entity_type VARCHAR(50) NOT NULL,
			entity_id VARCHAR(100),
			details TEXT,
			source VARCHAR(20) DEFAULT 'web',
			INDEX idx_timestamp (timestamp DESC),
			INDEX idx_user (user),
			INDEX idx_action (action),
			INDEX idx_source (source)
		)
	`)
	if err != nil {
		log.Fatal("Error creating audit_logs table:", err)
	}

	// Create asset_maintenance_logs table (Dust cleaning & routine maintenance)
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS asset_maintenance_logs (
			id INT AUTO_INCREMENT PRIMARY KEY,
			asset_id VARCHAR(100) NOT NULL,
			type VARCHAR(50) NOT NULL,
			performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			performed_by VARCHAR(100) NOT NULL,
			notes TEXT,
			INDEX idx_asset_maint (asset_id),
			INDEX idx_maint_date (performed_at DESC)
		)
	`)
	if err != nil {
		log.Println("Error creating asset_maintenance_logs table:", err)
	}

	// Create asset_part_replacements table (CPU Component Flashback History)
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS asset_part_replacements (
			id INT AUTO_INCREMENT PRIMARY KEY,
			asset_id VARCHAR(100) NOT NULL,
			part_name VARCHAR(100) NOT NULL,
			action_type VARCHAR(50) NOT NULL,
			old_spec VARCHAR(255),
			new_spec VARCHAR(255),
			reason TEXT,
			replaced_at DATETIME NOT NULL,
			technician VARCHAR(100) NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_asset_parts (asset_id)
		)
	`)
	if err != nil {
		log.Println("Error creating asset_part_replacements table:", err)
	}

	// Create asset_location_history table (Physical Location Movement History)
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS asset_location_history (
			id INT AUTO_INCREMENT PRIMARY KEY,
			asset_id VARCHAR(100) NOT NULL,
			from_location VARCHAR(100),
			to_location VARCHAR(100),
			moved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			moved_by VARCHAR(100) NOT NULL,
			reason TEXT,
			INDEX idx_asset_loc (asset_id)
		)
	`)
	if err != nil {
		log.Println("Error creating asset_location_history table:", err)
	}

	// Create bast_documents table (Berita Acara Serah Terima Aset)
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS bast_documents (
			id INT AUTO_INCREMENT PRIMARY KEY,
			bast_number VARCHAR(100) NOT NULL UNIQUE,
			asset_id VARCHAR(100) NOT NULL,
			recipient_name VARCHAR(150) NOT NULL,
			department VARCHAR(100),
			location VARCHAR(150),
			handover_type VARCHAR(50) NOT NULL DEFAULT 'PENYERAHAN_BARU',
			status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED',
			handover_date DATETIME NOT NULL,
			notes TEXT,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
			INDEX idx_bast_asset (asset_id)
		)
	`)
	if err != nil {
		log.Println("Error creating bast_documents table:", err)
	}

	log.Println("✓ Database tables initialized")
	cleanDuplicateAssetIDPrefixes(db)
}

func cleanDuplicateAssetIDPrefixes(db *sql.DB) {
	log.Println("⚡ Checking and cleaning double-prefixed asset IDs in MariaDB...")
	
	prefixes := []string{"HD", "PC", "KB", "MN", "MS", "LAP", "MINI", "AIO"}
	for _, p := range prefixes {
		doublePattern := p + "-" + p + "/%"
		targetLegacyPrefix := p + "/"
		sourceReplacePattern := p + "-" + p + "/"
		
		_, _ = db.Exec(`
			UPDATE assets 
			SET legacy_inv_code = REPLACE(id, ?, ?)
			WHERE id LIKE ? AND (legacy_inv_code IS NULL OR legacy_inv_code = '' OR legacy_inv_code = id)
		`, sourceReplacePattern, targetLegacyPrefix, doublePattern)
	}

	rows, err := db.Query(`
		SELECT id, COALESCE(legacy_inv_code, '') 
		FROM assets 
		WHERE id LIKE '%-%/%' OR id REGEXP '^(HD|PC|KB|MN|MS|LAP|MINI|AIO)-(HD|PC|KB|MN|MS|LAP|MINI|AIO)'
	`)
	if err == nil {
		defer rows.Close()
		re := regexp.MustCompile(`^(HD|PC|KB|MN|MS|LAP|MINI|AIO)[^0-9]*([0-9]+)`)
		
		stmt, errStmt := db.Prepare("UPDATE assets SET id = ? WHERE id = ?")
		if errStmt == nil {
			defer stmt.Close()
			cleanedCount := 0
			for rows.Next() {
				var oldID, legacy string
				if err := rows.Scan(&oldID, &legacy); err == nil {
					matches := re.FindStringSubmatch(strings.ToUpper(oldID))
					if len(matches) >= 3 {
						p := matches[1]
						numStr := matches[2]
						if len(numStr) < 4 {
							numStr = fmt.Sprintf("%04s", numStr)
						}
						cleanID := fmt.Sprintf("%s-%s", p, numStr)
						if cleanID != oldID {
							_, _ = stmt.Exec(cleanID, oldID)
							cleanedCount++
						}
					}
				}
			}
			if cleanedCount > 0 {
				log.Printf("✓ Cleaned %d malformed double-prefixed asset IDs in MariaDB!", cleanedCount)
			}
		}
	}
}

// Handlers
func getAssets(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(`
		SELECT 
			id, type, status, location, COALESCE(specs, ''), updated_at,
			category_id, subcategory_id, 
			serial_number, license_key, expiry_date,
			quantity, min_stock_level, supplier, warranty_date, image_path, COALESCE(note, ''),
			legacy_inv_code, COALESCE(sticker_status, 'UNKNOWN')
		FROM assets
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	assets := []Asset{}
	for rows.Next() {
		var a Asset
		err := rows.Scan(
			&a.ID, &a.Type, &a.Status, &a.Location, &a.Specs, &a.UpdatedAt,
			&a.CategoryID, &a.SubcategoryID,
			&a.SerialNumber, &a.LicenseKey, &a.ExpiryDate,
			&a.Quantity, &a.MinStockLevel, &a.Supplier, &a.WarrantyDate, &a.ImagePath, &a.Note,
			&a.LegacyInvCode, &a.StickerStatus,
		)
		if err != nil {
			continue
		}
		assets = append(assets, a)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(assets)
}

func createAsset(w http.ResponseWriter, r *http.Request) {
	var asset Asset
	if err := json.NewDecoder(r.Body).Decode(&asset); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if asset.StickerStatus == "" {
		asset.StickerStatus = "UNKNOWN"
	}

	_, err := db.Exec(`
		INSERT INTO assets (
			id, type, status, location, specs,
			category_id, subcategory_id,
			serial_number, license_key, expiry_date,
			quantity, min_stock_level, supplier, warranty_date, image_path, note,
			legacy_inv_code, sticker_status
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE
			type=VALUES(type), status=VALUES(status), location=VALUES(location), specs=VALUES(specs),
			category_id=VALUES(category_id), subcategory_id=VALUES(subcategory_id),
			serial_number=VALUES(serial_number), license_key=VALUES(license_key), expiry_date=VALUES(expiry_date),
			quantity=VALUES(quantity), min_stock_level=VALUES(min_stock_level), supplier=VALUES(supplier), warranty_date=VALUES(warranty_date),
			image_path=VALUES(image_path), note=VALUES(note), legacy_inv_code=VALUES(legacy_inv_code), sticker_status=VALUES(sticker_status)
	`,
		asset.ID, asset.Type, asset.Status, asset.Location, asset.Specs,
		asset.CategoryID, asset.SubcategoryID,
		asset.SerialNumber, asset.LicenseKey, asset.ExpiryDate,
		asset.Quantity, asset.MinStockLevel, asset.Supplier, asset.WarrantyDate, asset.ImagePath, asset.Note,
		asset.LegacyInvCode, asset.StickerStatus,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity with detailed info
	details := fmt.Sprintf("Created %s asset '%s' - Type: %s, Location: %s, Status: %s",
		asset.Type, asset.ID, asset.Type, asset.Location, asset.Status)

	source := r.Header.Get("X-Source")
	if source == "" {
		source = "web"
	}
	logActivity("admin", "CREATE", "asset", asset.ID, details, source)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(asset)
}

func updateAsset(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var asset Asset
	if err := json.NewDecoder(r.Body).Decode(&asset); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if asset.ID == "" {
		asset.ID = id
	}

	_, err := db.Exec(`
		INSERT INTO assets (
			id, type, status, location, specs,
			category_id, subcategory_id,
			serial_number, license_key, expiry_date,
			quantity, min_stock_level, supplier, warranty_date, image_path, note,
			legacy_inv_code, sticker_status
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE
			type=VALUES(type), status=VALUES(status), location=VALUES(location), specs=VALUES(specs),
			category_id=VALUES(category_id), subcategory_id=VALUES(subcategory_id),
			serial_number=VALUES(serial_number), license_key=VALUES(license_key), expiry_date=VALUES(expiry_date),
			quantity=VALUES(quantity), min_stock_level=VALUES(min_stock_level), supplier=VALUES(supplier), warranty_date=VALUES(warranty_date),
			image_path=VALUES(image_path), note=VALUES(note), legacy_inv_code=VALUES(legacy_inv_code), sticker_status=VALUES(sticker_status)
	`,
		asset.ID, asset.Type, asset.Status, asset.Location, asset.Specs,
		asset.CategoryID, asset.SubcategoryID,
		asset.SerialNumber, asset.LicenseKey, asset.ExpiryDate,
		asset.Quantity, asset.MinStockLevel, asset.Supplier, asset.WarrantyDate, asset.ImagePath, asset.Note,
		asset.LegacyInvCode, asset.StickerStatus,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity with change details
	details := fmt.Sprintf("Updated asset '%s' - Status: %s, Location: %s",
		id, asset.Status, asset.Location)
	
	if asset.Note != "" {
		details = fmt.Sprintf("%s | Note: %s", details, asset.Note)
	}

	source := r.Header.Get("X-Source")
	if source == "" {
		source = "web"
	}
	logActivity("admin", "UPDATE", "asset", id, details, source)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(asset)
}

func deleteAsset(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("DELETE FROM assets WHERE id=?", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity
	details := fmt.Sprintf("Deleted asset '%s' from inventory", id)

	source := r.Header.Get("X-Source")
	if source == "" {
		source = "web"
	}
	logActivity("admin", "DELETE", "asset", id, details, source)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Asset deleted"})
}

func getDesks(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, area, number, status, COALESCE(assigned_asset_id, '') FROM desks")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	desks := []Desk{}
	for rows.Next() {
		var d Desk
		if err := rows.Scan(&d.ID, &d.Area, &d.Number, &d.Status, &d.AssignedAssetID); err != nil {
			continue
		}
		desks = append(desks, d)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(desks)
}

func initDeskMaster(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Start int    `json:"start"`
		End   int    `json:"end"`
		Area  string `json:"area"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	for i := req.Start; i <= req.End; i++ {
		deskID := fmt.Sprintf("D-%s-%03d", req.Area[:3], i)
		_, err := db.Exec(
			"INSERT INTO desks (id, area, number, status) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE status=status",
			deskID, req.Area, i, "EMPTY",
		)
		if err != nil {
			log.Printf("Error inserting desk %s: %v", deskID, err)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Desks initialized"})
}

func baselineAudit(w http.ResponseWriter, r *http.Request) {
	var req BaselineAuditRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	deskID := fmt.Sprintf("D-%s-%03d", req.Area[:3], req.DeskNumber)

	// Create assets
	for idx, assetType := range req.AssetTypes {
		assetID := fmt.Sprintf("LEGACY-%s-%d-%d", assetType, req.DeskNumber, idx)
		_, err := db.Exec(
			"INSERT INTO assets (id, type, status, location, specs) VALUES (?, ?, ?, ?, ?)",
			assetID, assetType, "IN_USE", deskID, "Source: LEGACY",
		)
		if err != nil {
			log.Printf("Error creating asset %s: %v", assetID, err)
		}
	}

	// Update desk status
	_, err := db.Exec(
		"UPDATE desks SET status=?, assigned_asset_id=? WHERE id=?",
		"OCCUPIED", fmt.Sprintf("LEGACY-PC-%d-0", req.DeskNumber), deskID,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Baseline audit completed"})
}

func uploadFile(w http.ResponseWriter, r *http.Request) {
	// Parse multipart form (32 MB max memory)
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		http.Error(w, "Error parsing form: "+err.Error(), http.StatusBadRequest)
		return
	}

	file, handler, err := r.FormFile("image")
	if err != nil {
		http.Error(w, "Error retrieving file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	publicPath, err := compressAndSaveImage(file, handler.Filename)
	if err != nil {
		http.Error(w, "Error saving file: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"path": publicPath,
	})
}

// compressAndSaveImage resizes images larger than 1280px and compresses to optimized JPEG (quality 75)
// Saving 85-95% disk storage while preserving full clarity for serial numbers and watermarks.
func compressAndSaveImage(r io.Reader, originalFilename string) (string, error) {
	timestamp := time.Now().UnixNano()
	ext := strings.ToLower(filepath.Ext(originalFilename))

	// Buffer input so we can fallback if image decode fails
	data, err := io.ReadAll(r)
	if err != nil {
		return "", err
	}

	// If recognized image format, compress and scale
	if ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" || ext == ".gif" {
		img, _, err := image.Decode(strings.NewReader(string(data)))
		if err == nil {
			bounds := img.Bounds()
			origW := bounds.Dx()
			origH := bounds.Dy()

			// Max dimension 1280px (ideal balance: small file + readable labels/barcodes)
			maxDim := 1280
			targetW := origW
			targetH := origH

			if origW > maxDim || origH > maxDim {
				if origW > origH {
					targetW = maxDim
					targetH = int(float64(origH) * (float64(maxDim) / float64(origW)))
				} else {
					targetH = maxDim
					targetW = int(float64(origW) * (float64(maxDim) / float64(origH)))
				}
			}

			// Perform high-quality bilinear scaling
			dstImg := image.NewRGBA(image.Rect(0, 0, targetW, targetH))
			draw.BiLinear.Scale(dstImg, dstImg.Bounds(), img, bounds, draw.Over, nil)

			// Clean base filename
			baseName := strings.TrimSuffix(originalFilename, filepath.Ext(originalFilename))
			baseName = regexp.MustCompile(`[^a-zA-Z0-9_\-]`).ReplaceAllString(baseName, "_")
			finalFilename := fmt.Sprintf("%d_%s.jpg", timestamp, baseName)
			savePath := filepath.Join("./uploads", finalFilename)

			out, err := os.Create(savePath)
			if err != nil {
				return "", err
			}
			defer out.Close()

			// Encode as compressed JPEG with quality 75
			err = jpeg.Encode(out, dstImg, &jpeg.Options{Quality: 75})
			if err == nil {
				log.Printf("✓ Image compressed & saved: %s (Original: %dx%d -> %dx%d)", finalFilename, origW, origH, targetW, targetH)
				return fmt.Sprintf("/uploads/%s", finalFilename), nil
			}
		}
	}

	// Fallback for non-image or decoding error: raw file save
	finalFilename := fmt.Sprintf("%d_%s", timestamp, originalFilename)
	savePath := filepath.Join("./uploads", finalFilename)
	out, err := os.Create(savePath)
	if err != nil {
		return "", err
	}
	defer out.Close()

	if _, err := out.Write(data); err != nil {
		return "", err
	}
	return fmt.Sprintf("/uploads/%s", finalFilename), nil
}

func getStats(w http.ResponseWriter, r *http.Request) {
	var stats struct {
		TotalAssets     int            `json:"total_assets"`
		StatusCounts    map[string]int `json:"status_counts"`
		TotalRepairs    int            `json:"total_repairs"`
		FrequentRepairs []struct {
			AssetID string `json:"asset_id"`
			Count   int    `json:"count"`
		} `json:"frequent_repairs"`
	}

	stats.StatusCounts = make(map[string]int)

	// Get total and status counts
	rows, err := db.Query("SELECT status, COUNT(*) FROM assets GROUP BY status")
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var status string
			var count int
			if err := rows.Scan(&status, &count); err == nil {
				stats.StatusCounts[status] = count
				stats.TotalAssets += count
			}
		}
	}

	// Get total repairs (count of logs that transitioned status to REPAIRING or Mention REPAIR)
	_ = db.QueryRow("SELECT COUNT(*) FROM audit_logs WHERE details LIKE '%Status: REPAIRING%' OR details LIKE '%Note:%'").Scan(&stats.TotalRepairs)

	// Get most frequently repaired assets
	rows, err = db.Query(`
		SELECT entity_id, COUNT(*) as repair_count 
		FROM audit_logs 
		WHERE details LIKE '%Status: REPAIRING%' 
		GROUP BY entity_id 
		ORDER BY repair_count DESC 
		LIMIT 5
	`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var res struct {
				AssetID string `json:"asset_id"`
				Count   int    `json:"count"`
			}
			if err := rows.Scan(&res.AssetID, &res.Count); err == nil {
				stats.FrequentRepairs = append(stats.FrequentRepairs, res)
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}
