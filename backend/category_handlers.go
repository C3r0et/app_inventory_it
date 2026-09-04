package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// Category handlers

// GET /api/categories - Get all categories with hierarchical structure
func getCategories(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(`
		SELECT id, name, parent_id, type, icon 
		FROM categories 
		ORDER BY parent_id, name
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	categories := []Category{}
	for rows.Next() {
		var c Category
		err := rows.Scan(&c.ID, &c.Name, &c.ParentID, &c.Type, &c.Icon)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		categories = append(categories, c)
	}

	// Build hierarchical structure
	categoryMap := make(map[int]*Category)
	rootCategories := []Category{}

	// First pass: create map
	for i := range categories {
		categoryMap[categories[i].ID] = &categories[i]
	}

	// Second pass: build hierarchy
	for i := range categories {
		if categories[i].ParentID == nil {
			rootCategories = append(rootCategories, categories[i])
		} else {
			parent := categoryMap[*categories[i].ParentID]
			if parent != nil {
				parent.Children = append(parent.Children, categories[i])
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rootCategories)
}

// POST /api/categories - Create new category
func createCategory(w http.ResponseWriter, r *http.Request) {
	var category Category
	if err := json.NewDecoder(r.Body).Decode(&category); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	result, err := db.Exec(
		"INSERT INTO categories (name, parent_id, type, icon) VALUES (?, ?, ?, ?)",
		category.Name, category.ParentID, category.Type, category.Icon,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	id, _ := result.LastInsertId()
	category.ID = int(id)

	// Log activity with details
	parentInfo := ""
	if category.ParentID != nil {
		parentInfo = fmt.Sprintf(" (subcategory of ID %d)", *category.ParentID)
	}
	iconStr := "None"
	if category.Icon != nil {
		iconStr = *category.Icon
	}
	details := fmt.Sprintf("Created %s category '%s'%s - Icon: %s",
		category.Type, category.Name, parentInfo, iconStr)
	logActivity("admin", "CREATE", "category", strconv.Itoa(category.ID), details, "web")

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(category)
}

// PUT /api/categories/{id} - Update category
func updateCategory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid category ID", http.StatusBadRequest)
		return
	}

	var category Category
	if err := json.NewDecoder(r.Body).Decode(&category); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, err = db.Exec(
		"UPDATE categories SET name=?, parent_id=?, type=?, icon=? WHERE id=?",
		category.Name, category.ParentID, category.Type, category.Icon, id,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity with details
	iconStr := "None"
	if category.Icon != nil {
		iconStr = *category.Icon
	}
	details := fmt.Sprintf("Updated category '%s' (ID: %d) - Type: %s, Icon: %s",
		category.Name, id, category.Type, iconStr)
	logActivity("admin", "UPDATE", "category", strconv.Itoa(id), details, "web")

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(category)
}

// DELETE /api/categories/{id} - Delete category
func deleteCategory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	_, err := db.Exec("DELETE FROM categories WHERE id=?", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Log activity
	details := fmt.Sprintf("Deleted category ID %s from system", id)
	logActivity("admin", "DELETE", "category", id, details, "web")

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Category deleted"})
}

// GET /api/categories/{id}/subcategories - Get subcategories
func getSubcategories(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	parentID := vars["id"]

	rows, err := db.Query(
		"SELECT id, name, parent_id, type, icon FROM categories WHERE parent_id=?",
		parentID,
	)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var categories []Category
	for rows.Next() {
		var c Category
		err := rows.Scan(&c.ID, &c.Name, &c.ParentID, &c.Type, &c.Icon)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		categories = append(categories, c)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(categories)
}
