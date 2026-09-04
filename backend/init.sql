-- Create database
CREATE DATABASE IF NOT EXISTS asset_inventory;
USE asset_inventory;

-- Assets table
CREATE TABLE IF NOT EXISTS assets (
    id VARCHAR(100) PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    location VARCHAR(100),
    specs TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    INDEX idx_location (location)
);

-- Desks table
CREATE TABLE IF NOT EXISTS desks (
    id VARCHAR(100) PRIMARY KEY,
    area VARCHAR(100) NOT NULL,
    number INT NOT NULL,
    status VARCHAR(50) NOT NULL,
    assigned_asset_id VARCHAR(100),
    UNIQUE KEY unique_desk (area, number),
    INDEX idx_area (area)
);

-- Sample data
INSERT INTO assets (id, type, status, location, specs) VALUES
('CPU-031', 'PC', 'AVAILABLE', 'IT-STORAGE', 'i7/16GB/512GB')
ON DUPLICATE KEY UPDATE id=id;
