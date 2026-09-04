//go:build ignore

package main

import (
	"database/sql"
	"fmt"
	"log"
	"regexp"
	"strings"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	dsn := "userdb:sahabat25*@tcp(10.9.9.110:3306)/asset_inventory?parseTime=true"
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to MariaDB: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("MariaDB Ping failed: %v", err)
	}

	log.Println("⚡ Connected to Live MariaDB 10.9.9.110! Running SQL Cleanup Script...")

	// 1. Populate legacy_inv_code for all malformed double-prefix IDs
	prefixes := []string{"HD", "PC", "KB", "MN", "MS", "LAP", "MINI", "AIO"}
	for _, p := range prefixes {
		doublePattern := p + "-" + p + "/%"
		targetLegacyPrefix := p + "/"
		sourceReplacePattern := p + "-" + p + "/"

		res, err := db.Exec(`
			UPDATE assets 
			SET legacy_inv_code = REPLACE(id, ?, ?)
			WHERE id LIKE ? AND (legacy_inv_code IS NULL OR legacy_inv_code = '' OR legacy_inv_code = id)
		`, sourceReplacePattern, targetLegacyPrefix, doublePattern)
		if err == nil {
			affected, _ := res.RowsAffected()
			if affected > 0 {
				fmt.Printf("Updated legacy_inv_code for %d rows with prefix %s\n", affected, p)
			}
		}
	}

	// 2. Query all malformed IDs containing double prefixes or slash formats
	rows, err := db.Query(`
		SELECT id, COALESCE(legacy_inv_code, '') 
		FROM assets 
		WHERE id LIKE '%-%/%' 
		   OR id REGEXP '^(HD|PC|KB|MN|MS|LAP|MINI|AIO)-(HD|PC|KB|MN|MS|LAP|MINI|AIO)'
	`)
	if err != nil {
		log.Fatalf("Query failed: %v", err)
	}
	defer rows.Close()

	re := regexp.MustCompile(`^(HD|PC|KB|MN|MS|LAP|MINI|AIO)[^0-9]*([0-9]+)`)
	stmt, errStmt := db.Prepare("UPDATE assets SET id = ? WHERE id = ?")
	if errStmt != nil {
		log.Fatalf("Prepare failed: %v", errStmt)
	}
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
					// Check if cleanID already exists to avoid duplicate key error
					var exists int
					db.QueryRow("SELECT COUNT(*) FROM assets WHERE id = ?", cleanID).Scan(&exists)
					if exists == 0 {
						_, errUp := stmt.Exec(cleanID, oldID)
						if errUp == nil {
							cleanedCount++
						}
					} else {
						// If cleanID exists, append unique suffix
						altCleanID := fmt.Sprintf("%s-%s-A", p, numStr)
						_, errUp := stmt.Exec(altCleanID, oldID)
						if errUp == nil {
							cleanedCount++
						}
					}
				}
			}
		}
	}

	fmt.Printf("✅ SUCCESS: Cleaned %d malformed double-prefixed asset IDs in MariaDB 10.9.9.110!\n", cleanedCount)
}
