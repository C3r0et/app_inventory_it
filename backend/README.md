# Asset Inventory API - Go Backend

## Prerequisites
- Go 1.21+
- XAMPP dengan MariaDB running
- Database `asset_inventory` sudah dibuat

## Setup Database

1. Buka phpMyAdmin atau MySQL client
2. Import file `init.sql`:
```bash
mysql -u root -p < backend/init.sql
```

Atau jalankan manual di phpMyAdmin.

## Running the API

```bash
cd backend
go run main.go
```

Server akan berjalan di `http://localhost:8080`

## API Endpoints

### Assets
- `GET /api/assets` - Get all assets
- `POST /api/assets` - Create new asset
- `PUT /api/assets/:id` - Update asset
- `DELETE /api/assets/:id` - Delete asset

### Desks
- `GET /api/desks` - Get all desks
- `POST /api/desks/init` - Initialize desk master
  ```json
  {
    "start": 1,
    "end": 120,
    "area": "COLLECTION"
  }
  ```

### Baseline Audit
- `POST /api/baseline-audit` - Create baseline audit
  ```json
  {
    "desk_number": 12,
    "area": "COLLECTION",
    "asset_types": ["PC", "MONITOR", "KEYBOARD", "MOUSE", "HEADSET"]
  }
  ```

## Testing

```bash
# Health check
curl http://localhost:8080/health

# Get assets
curl http://localhost:8080/api/assets

# Create asset
curl -X POST http://localhost:8080/api/assets \
  -H "Content-Type: application/json" \
  -d '{"id":"TEST-001","type":"PC","status":"AVAILABLE","location":"IT-STORAGE"}'
```
