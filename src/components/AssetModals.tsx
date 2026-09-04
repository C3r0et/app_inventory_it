import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { useCategoryStore } from '../store/categoryStore';
import type { Asset, Category } from '../types';
import { API_BASE_URL } from '../services/apiClient';

// Asset Form Modal Component with Dynamic Categories
const AssetFormModal = ({ 
  show, 
  onClose, 
  onSubmit, 
  title, 
  asset 
}: { 
  show: boolean; 
  onClose: () => void; 
  onSubmit: (e: React.FormEvent<HTMLFormElement>) => void; 
  title: string; 
  asset?: Asset | null;
}) => {
  const { categories, fetchCategories } = useCategoryStore();
  const [selectedCategory, setSelectedCategory] = useState<number | null>(asset?.category_id || null);
  const [selectedCategoryType, setSelectedCategoryType] = useState<string>('');
  const [subcategories, setSubcategories] = useState<Category[]>([]);
  
  // Location States
  const [locationType, setLocationType] = useState<string>('Ruang IT');
  const [deskNumber, setDeskNumber] = useState<string>('');

  useEffect(() => {
    if (asset) {
      setSelectedCategory(asset.category_id || null);
      if (asset.location) {
        if (asset.location.startsWith('Floor')) {
          const parts = asset.location.split(' - Meja ');
          setLocationType(parts[0]);
          if (parts.length > 1) setDeskNumber(parts[1]);
        } else {
          setLocationType(asset.location);
          setDeskNumber('');
        }
      }
      
      // Auto-fill note if editing
      setTimeout(() => {
        const noteInput = document.getElementById('repair_note_input') as HTMLTextAreaElement;
        if (noteInput && asset.note) {
          noteInput.value = asset.note;
        }
      }, 100);
    } else {
      setSelectedCategory(null);
      setLocationType('Ruang IT');
      setDeskNumber('');
      setTimeout(() => {
        const noteInput = document.getElementById('repair_note_input') as HTMLTextAreaElement;
        if (noteInput) noteInput.value = '';
      }, 100);
    }
  }, [asset, show]);

  useEffect(() => {
    if (show) {
      fetchCategories();
    }
  }, [show, fetchCategories]);

  useEffect(() => {
    if (selectedCategory) {
      const category = findCategoryById(categories, selectedCategory);
      if (category) {
        setSelectedCategoryType(category.type);
        setSubcategories(category.children || []);
      }
    }
  }, [selectedCategory, categories]);

  const findCategoryById = (cats: Category[], id: number): Category | null => {
    for (const cat of cats) {
      if (cat.id === id) return cat;
      if (cat.children) {
        const found = findCategoryById(cat.children, id);
        if (found) return found;
      }
    }
    return null;
  };

  if (!show) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-800 rounded-lg p-6 max-w-2xl w-full border border-slate-700 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-xl font-semibold">{title}</h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-700 rounded">
            <X size={20} />
          </button>
        </div>
        <form onSubmit={onSubmit} className="space-y-4">
          {/* Category Selection */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm mb-2">Category *</label>
              <select
                name="category_id"
                value={selectedCategory || ''}
                onChange={(e) => setSelectedCategory(Number(e.target.value))}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                required
              >
                <option value="">Select Category</option>
                {categories.map((cat) => (
                  <option key={cat.id} value={cat.id}>
                    {cat.name} ({cat.type})
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm mb-2">Subcategory</label>
              <select
                name="subcategory_id"
                defaultValue={asset?.subcategory_id || ''}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                disabled={subcategories.length === 0}
              >
                <option value="">None</option>
                {subcategories.map((subcat) => (
                  <option key={subcat.id} value={subcat.id}>
                    {subcat.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Basic Fields */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm mb-2">Status *</label>
              <select
                name="status"
                defaultValue={asset?.status || 'AVAILABLE'}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                required
              >
                <option value="AVAILABLE">Available</option>
                <option value="IN_USE">In Use</option>
                <option value="BROKEN">Broken</option>
                <option value="REPAIRING">Repairing</option>
                <option value="LOW_STOCK">Low Stock</option>
              </select>
            </div>
            <div>
              <label className="block text-sm mb-2">Location *</label>
              <select
                value={locationType}
                onChange={(e) => setLocationType(e.target.value)}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded mb-2"
                required
              >
                <option value="Ruang IT">Ruang IT</option>
                <option value="Floor Lt2">Floor Lt2</option>
                <option value="Floor Lt3">Floor Lt3</option>
              </select>
              {(locationType === 'Floor Lt2' || locationType === 'Floor Lt3') && (
                <input
                  type="text"
                  value={deskNumber}
                  onChange={(e) => setDeskNumber(e.target.value)}
                  placeholder="Nomor Meja"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              )}
              {/* Hidden input to pass merged location text natively to the form submission */}
              <input 
                type="hidden" 
                name="location" 
                value={locationType === 'Ruang IT' ? locationType : `${locationType} - Meja ${deskNumber}`} 
              />
            </div>
          </div>

          {/* Repair Note (Visible when REPAIRING or editing) */}
          <div className="p-4 bg-orange-900/20 rounded border border-orange-700/50">
            <label className="block text-sm mb-2 text-orange-400 font-semibold">Repair Note / Activity Note</label>
            <textarea
              name="note"
              placeholder="Explain the repair reason or recent activity..."
              className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded mb-2"
              rows={2}
              id="repair_note_input"
              defaultValue={asset?.note || ''}
            />
            <div className="flex flex-wrap gap-2">
              <span className="text-xs text-slate-500 w-full mb-1">Quick Presets:</span>
              {['Kabel Putus', 'Layar Rusak', 'Baterai Drop', 'Tombol Macet', 'OS Corrupt'].map(preset => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => {
                    const input = document.getElementById('repair_note_input') as HTMLTextAreaElement;
                    if (input) input.value = preset;
                  }}
                  className="px-2 py-1 bg-slate-700 hover:bg-slate-600 rounded text-xs transition"
                >
                  {preset}
                </button>
              ))}
            </div>
          </div>

          {/* Conditional Fields Based on Category Type */}
          {selectedCategoryType === 'HARDWARE' && (
            <div className="grid grid-cols-2 gap-4 p-4 bg-slate-900 rounded border border-slate-700">
              <div className="col-span-2">
                <p className="text-sm text-blue-400 mb-2">Hardware Fields</p>
              </div>
              <div>
                <label className="block text-sm mb-2">Serial Number</label>
                <input
                  type="text"
                  name="serial_number"
                  defaultValue={asset?.serial_number || ''}
                  placeholder="e.g., SN123456789"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Warranty Date</label>
                <input
                  type="date"
                  name="warranty_date"
                  defaultValue={asset?.warranty_date || ''}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
            </div>
          )}

          {selectedCategoryType === 'SOFTWARE' && (
            <div className="grid grid-cols-2 gap-4 p-4 bg-slate-900 rounded border border-slate-700">
              <div className="col-span-2">
                <p className="text-sm text-purple-400 mb-2">Software License Fields</p>
              </div>
              <div>
                <label className="block text-sm mb-2">License Key</label>
                <input
                  type="text"
                  name="license_key"
                  defaultValue={asset?.license_key || ''}
                  placeholder="e.g., XXXXX-XXXXX-XXXXX"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Expiry Date</label>
                <input
                  type="date"
                  name="expiry_date"
                  defaultValue={asset?.expiry_date || ''}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
            </div>
          )}

          {selectedCategoryType === 'CONSUMABLES' && (
            <div className="grid grid-cols-3 gap-4 p-4 bg-slate-900 rounded border border-slate-700">
              <div className="col-span-3">
                <p className="text-sm text-green-400 mb-2">Consumables Inventory Fields</p>
              </div>
              <div>
                <label className="block text-sm mb-2">Quantity</label>
                <input
                  type="number"
                  name="quantity"
                  defaultValue={asset?.quantity || 1}
                  min="0"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Min Stock Level</label>
                <input
                  type="number"
                  name="min_stock_level"
                  defaultValue={asset?.min_stock_level || ''}
                  min="0"
                  placeholder="Alert threshold"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Supplier</label>
                <input
                  type="text"
                  name="supplier"
                  defaultValue={asset?.supplier || ''}
                  placeholder="Supplier name"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-600 rounded"
                />
              </div>
            </div>
          )}

          {/* Asset Photos */}
          {asset?.image_path && (
            <div className="p-4 bg-slate-900 rounded border border-slate-700">
              <p className="text-sm text-blue-400 mb-2">Asset Photos</p>
              <div className="flex flex-wrap gap-2 mt-2">
                {asset.image_path.split(',').filter(Boolean).map((path, index) => {
                  const imageUrl = path.startsWith('http') 
                    ? path 
                    : `${API_BASE_URL}${path.startsWith('/') ? path : '/' + path}`;
                  
                  return (
                    <a key={index} href={imageUrl} target="_blank" rel="noopener noreferrer" className="block relative group">
                      <img 
                        src={imageUrl} 
                        alt={`Asset ${index + 1}`} 
                        className="w-24 h-24 object-cover rounded border border-slate-600 group-hover:border-blue-500 transition"
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center rounded transition">
                        <span className="text-xs text-white">Full View</span>
                      </div>
                    </a>
                  );
                })}
              </div>
            </div>
          )}

          {/* Specifications (Common for all) */}
          <div>
            <label className="block text-sm mb-2">Specifications / Notes</label>
            <textarea
              name="specs"
              defaultValue={asset?.specs || ''}
              placeholder="Additional details..."
              className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
              rows={3}
            />
          </div>

          {/* Legacy Type Field (Hidden, for backward compatibility) */}
          <input type="hidden" name="type" value={asset?.type || 'PC'} />

          <div className="flex gap-2">
            <button
              type="submit"
              className="flex-1 bg-blue-600 hover:bg-blue-500 py-2 rounded transition"
            >
              {asset ? 'Update' : 'Create'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Delete Confirmation Modal Component
const DeleteConfirmModal = ({ 
  show, 
  onClose, 
  onConfirm, 
  assetId 
}: { 
  show: boolean; 
  onClose: () => void; 
  onConfirm: () => void; 
  assetId?: string;
}) => {
  if (!show) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-xl font-semibold text-red-400">Delete Asset</h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-700 rounded">
            <X size={20} />
          </button>
        </div>
        <p className="text-slate-300 mb-6">
          Are you sure you want to delete asset <span className="font-mono font-bold">{assetId}</span>? This action cannot be undone.
        </p>
        <div className="flex gap-2">
          <button
            onClick={onConfirm}
            className="flex-1 bg-red-600 hover:bg-red-500 py-2 rounded transition"
          >
            Delete
          </button>
          <button
            onClick={onClose}
            className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};

export { AssetFormModal, DeleteConfirmModal };
