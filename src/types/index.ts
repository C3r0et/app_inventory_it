export type AssetStatus = 'IN_USE' | 'BROKEN' | 'GHOST' | 'AVAILABLE' | 'LOW_STOCK' | 'REPAIRING';
export type DeskStatus = 'EMPTY' | 'OCCUPIED' | 'BROKEN';
export type CategoryType = 'HARDWARE' | 'SOFTWARE' | 'CABLES' | 'CONSUMABLES' | 'NETWORK';

export interface Desk {
  id: string; // e.g., "D-COL-001"
  area: string; // e.g., "COLLECTION"
  number: number;
  status: DeskStatus;
  assignedAssetId?: string;
}

export interface Category {
  id: number;
  name: string;
  parent_id?: number | null;
  type: CategoryType;
  icon?: string | null;
  children?: Category[];
}

export interface Asset {
  id: string; // e.g., "PC-001"
  type: string; // e.g., 'Monitor' | 'CPU' | 'Keyboard' | 'Mouse' | 'Headset'
  status: AssetStatus;
  location: string; // e.g. "Ruang IT", "Lantai 2", "Lantai 3", "Ruang Management"
  specs?: string;
  legacy_inv_code?: string; // e.g. "MN/0181/2025"
  sticker_status?: string;   // e.g. "STICKERED" | "UNSTICKERED"
  
  // Category fields
  category_id?: number;
  subcategory_id?: number;
  
  // Conditional fields
  serial_number?: string;      // Hardware
  license_key?: string;         // Software
  expiry_date?: string;         // Software
  quantity?: number;            // Consumables
  min_stock_level?: number;     // Consumables
  supplier?: string;            // Consumables
  warranty_date?: string;       // Hardware
  purchase_date?: string;       // Hardware / Purchase Date
  image_path?: string;          // Photos from mobile app (comma-separated)
  note?: string;                // Repair notes / activity history
  updated_at?: string;
}

export interface MaintenanceRecord {
  id: number;
  asset_id: string;
  type: string;
  performed_at: string;
  performed_by: string;
  notes: string;
}

export interface PartReplacementRecord {
  id: number;
  asset_id: string;
  part_name: string;
  action_type: string;
  old_spec: string;
  new_spec: string;
  reason: string;
  replaced_at: string;
  technician: string;
}

export interface LocationHistoryRecord {
  id: number;
  asset_id: string;
  from_location: string;
  to_location: string;
  moved_at: string;
  moved_by: string;
  reason: string;
}

export interface AssetFullHistory {
  asset_id: string;
  maintenance: MaintenanceRecord[];
  part_history: PartReplacementRecord[];
  location_history: LocationHistoryRecord[];
}

export interface Area {
  id: string;
  name: string;
  desks: Desk[];
}
