# Dummy Data Import Guide

## Import Dummy Data ke Database

### Via PowerShell (Recommended)
```powershell
Get-Content dummy_data.sql | mysql -u root -p asset_inventory
```

### Via phpMyAdmin
1. Buka `http://localhost/phpmyadmin`
2. Pilih database `asset_inventory`
3. Klik tab "Import"
4. Pilih file `dummy_data.sql`
5. Klik "Go"

### Via MySQL Command Line
```bash
mysql -u root -p asset_inventory < dummy_data.sql
```

## Data yang Akan Dibuat

### Desks (120 total)
- **Desk 1-30**: OCCUPIED (dengan PC/Laptop assigned)
- **Desk 31-50**: EMPTY
- **Desk 51-52**: OCCUPIED
- **Desk 53-120**: EMPTY

### Assets

#### PCs (32 total)
- **29 PCs**: IN_USE (assigned to desks)
- **2 PCs**: AVAILABLE (di IT-STORAGE)
- **1 PC**: BROKEN (di IT-REPAIR)

#### Laptops (5 total)
- **3 Laptops**: IN_USE (assigned to desks)
- **1 Laptop**: AVAILABLE
- **1 Laptop**: BROKEN

#### Monitors (13 total)
- **10 Monitors**: IN_USE
- **2 Monitors**: AVAILABLE
- **1 Monitor**: BROKEN

#### Keyboards (5 total)
- **3 Keyboards**: IN_USE
- **2 Keyboards**: AVAILABLE

#### Mice (5 total)
- **3 Mice**: IN_USE
- **2 Mice**: AVAILABLE

#### Headsets (5 total)
- **3 Headsets**: IN_USE
- **1 Headset**: AVAILABLE
- **1 Headset**: BROKEN

## Total Summary
- **120 Desks** (32 Occupied, 88 Empty)
- **65 Assets** (48 In Use, 14 Available, 3 Broken)

## Setelah Import

Refresh web dashboard atau admin panel untuk melihat data:
- Dashboard: `http://localhost:5173/dashboard`
- Admin Panel: `http://localhost:5173/admin`
