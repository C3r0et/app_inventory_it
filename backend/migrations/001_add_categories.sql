-- Migration: Add Categories System
-- Run this after init.sql

USE asset_inventory;

-- Create categories table
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
);

-- Modify assets table - add new columns
ALTER TABLE assets 
    ADD COLUMN IF NOT EXISTS category_id INT,
    ADD COLUMN IF NOT EXISTS subcategory_id INT NULL,
    ADD COLUMN IF NOT EXISTS serial_number VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS license_key VARCHAR(255) NULL,
    ADD COLUMN IF NOT EXISTS expiry_date DATE NULL,
    ADD COLUMN IF NOT EXISTS quantity INT DEFAULT 1,
    ADD COLUMN IF NOT EXISTS min_stock_level INT NULL,
    ADD COLUMN IF NOT EXISTS supplier VARCHAR(255) NULL,
    ADD COLUMN IF NOT EXISTS warranty_date DATE NULL;

-- Add foreign keys
ALTER TABLE assets 
    ADD CONSTRAINT fk_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_subcategory FOREIGN KEY (subcategory_id) REFERENCES categories(id) ON DELETE SET NULL;

-- Add indexes for better query performance
ALTER TABLE assets
    ADD INDEX idx_category (category_id),
    ADD INDEX idx_subcategory (subcategory_id),
    ADD INDEX idx_serial (serial_number);

-- Seed initial categories
-- Main Categories
INSERT INTO categories (name, parent_id, type, icon) VALUES
('Hardware', NULL, 'HARDWARE', 'monitor'),
('Software Licenses', NULL, 'SOFTWARE', 'key'),
('Cables', NULL, 'CABLES', 'cable'),
('Consumables', NULL, 'CONSUMABLES', 'package'),
('Network Equipment', NULL, 'NETWORK', 'network');

-- Hardware Subcategories
INSERT INTO categories (name, parent_id, type, icon) VALUES
('PC', 1, 'HARDWARE', 'pc-case'),
('Laptop', 1, 'HARDWARE', 'laptop'),
('Monitor', 1, 'HARDWARE', 'monitor'),
('Keyboard', 1, 'HARDWARE', 'keyboard'),
('Mouse', 1, 'HARDWARE', 'mouse'),
('Headset', 1, 'HARDWARE', 'headphones'),
('CPU Components', 1, 'HARDWARE', 'cpu'),
('Storage', 1, 'HARDWARE', 'hard-drive'),
('Power Supply', 1, 'HARDWARE', 'zap');

-- Software Subcategories
INSERT INTO categories (name, parent_id, type, icon) VALUES
('Operating System', 2, 'SOFTWARE', 'windows'),
('Office Suite', 2, 'SOFTWARE', 'file-text'),
('Antivirus', 2, 'SOFTWARE', 'shield'),
('Design Software', 2, 'SOFTWARE', 'palette');

-- Cables Subcategories
INSERT INTO categories (name, parent_id, type, icon) VALUES
('Display Cables', 3, 'CABLES', 'monitor'),
('Network Cables', 3, 'CABLES', 'network'),
('Power Cables', 3, 'CABLES', 'zap'),
('Data Cables', 3, 'CABLES', 'usb');

-- Consumables Subcategories
INSERT INTO categories (name, parent_id, type, icon) VALUES
('Repair Supplies', 4, 'CONSUMABLES', 'wrench'),
('Cleaning Supplies', 4, 'CONSUMABLES', 'spray-can'),
('Solder & Tools', 4, 'CONSUMABLES', 'tool');

-- Network Equipment Subcategories
INSERT INTO categories (name, parent_id, type, icon) VALUES
('Switch', 5, 'NETWORK', 'network'),
('Router', 5, 'NETWORK', 'wifi'),
('Network Cards', 5, 'NETWORK', 'credit-card'),
('Hub', 5, 'NETWORK', 'share-2');

-- Migration: Map existing asset types to categories
-- This will update existing assets to use the new category system
UPDATE assets a
LEFT JOIN categories c ON c.name = a.type AND c.parent_id IS NOT NULL
SET a.category_id = c.parent_id, a.subcategory_id = c.id
WHERE a.type IN ('PC', 'LAPTOP', 'MONITOR', 'KEYBOARD', 'MOUSE', 'HEADSET');

-- For assets that don't match, set to Hardware category
UPDATE assets a
SET a.category_id = 1
WHERE a.category_id IS NULL;
