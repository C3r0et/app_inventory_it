import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { useStore } from '../../store/assetStore';
import { Download, Plus, Edit, Trash2, Upload, History } from 'lucide-react';
import { AssetFormModal, DeleteConfirmModal } from '../../components/AssetModals';
import { AssetHistoryModal } from '../../components/AssetHistoryModal';
import { BulkImportModal } from '../../components/BulkImportModal';
import type { Asset } from '../../types';
import { API_BASE_URL } from '../../services/apiClient';
import toast from 'react-hot-toast';

export const AssetsPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { assets, fetchAssets, deleteAsset } = useStore();
  
  // Pagination & Filtering
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [searchFilters, setSearchFilters] = useState({
    id: '',
    type: '',
    status: '',
    location: '',
    specs: '',
    purchaseYear: '',
  });
  const [sortConfig, setSortConfig] = useState<{
    key: keyof Asset | null;
    direction: 'asc' | 'desc';
  }>({ key: null, direction: 'asc' });

  // Modals
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [showBulkImportModal, setShowBulkImportModal] = useState(false);
  const [selectedAsset, setSelectedAsset] = useState<Asset | null>(null);

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchAssets();
  }, [isAuthenticated, navigate, fetchAssets]);

  // Auto-refresh asset list in real-time when SSE event arrives from mobile app
  useEffect(() => {
    const handleActivity = () => {
      fetchAssets();
    };
    window.addEventListener('asset-activity-updated', handleActivity);
    return () => {
      window.removeEventListener('asset-activity-updated', handleActivity);
    };
  }, [fetchAssets]);


  const normalizeCategory = (t: string) => {
    const s = (t || '').toUpperCase().trim();
    if (s === 'PC' || s === 'CPU') return 'PC';
    if (s === 'KEYBOARD' || s === 'KB') return 'KEYBOARD';
    if (s === 'MOUSE' || s === 'MS') return 'MOUSE';
    if (s === 'HEADSET' || s === 'HD' || s === 'HS') return 'HEADSET';
    if (s === 'MONITOR' || s === 'MN') return 'MONITOR';
    if (s === 'LAPTOP' || s === 'LAP') return 'LAPTOP';
    return s;
  };

  const getPurchaseYear = (asset: Asset): string => {
    if (asset.purchase_date) {
      const year = new Date(asset.purchase_date).getFullYear();
      if (!isNaN(year) && year > 2000) return year.toString();
    }
    if (asset.legacy_inv_code) {
      const match = asset.legacy_inv_code.match(/\/(\d{4})$/);
      if (match) return match[1];
    }
    if (asset.warranty_date) {
      const year = new Date(asset.warranty_date).getFullYear();
      if (!isNaN(year) && year > 2000) return year.toString();
    }
    return '2025';
  };

  const getAssetAge = (yearStr: string): { years: number; badgeClass: string; label: string } => {
    const currentYear = 2026;
    const year = parseInt(yearStr, 10);
    if (isNaN(year)) return { years: 0, badgeClass: 'bg-slate-700 text-slate-300', label: 'Baru' };
    const age = Math.max(0, currentYear - year);

    if (age >= 5) {
      return { years: age, badgeClass: 'bg-red-500/20 text-red-400 border border-red-500/30 font-bold', label: `${age} Thn (Tua)` };
    } else if (age >= 3) {
      return { years: age, badgeClass: 'bg-amber-500/20 text-amber-400 border border-amber-500/30 font-bold', label: `${age} Thn` };
    } else if (age >= 1) {
      return { years: age, badgeClass: 'bg-blue-500/20 text-blue-400 border border-blue-500/30 font-medium', label: `${age} Thn` };
    } else {
      return { years: 0, badgeClass: 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-bold', label: 'Baru (2026)' };
    }
  };

  // Filter assets
  const filteredAssets = assets.filter((asset) => {
    const searchId = searchFilters.id.toLowerCase().trim();
    const matchesIdOrLegacy = 
      asset.id.toLowerCase().includes(searchId) || 
      (asset.legacy_inv_code || '').toLowerCase().includes(searchId);

    const assetCat = normalizeCategory(asset.type);
    const filterCat = normalizeCategory(searchFilters.type);

    const matchesType = 
      searchFilters.type === '' || 
      assetCat === filterCat || 
      asset.type.toUpperCase().includes(searchFilters.type.toUpperCase());

    const assetYear = getPurchaseYear(asset);
    const matchesYear = searchFilters.purchaseYear === '' || assetYear === searchFilters.purchaseYear;

    return (
      matchesIdOrLegacy &&
      matchesType &&
      matchesYear &&
      (searchFilters.status === '' || asset.status === searchFilters.status) &&
      asset.location.toLowerCase().includes(searchFilters.location.toLowerCase().trim()) &&
      (asset.specs || '').toLowerCase().includes(searchFilters.specs.toLowerCase().trim())
    );
  });

  // Sort assets
  const sortedAssets = [...filteredAssets].sort((a, b) => {
    if (!sortConfig.key) return 0;
    
    const aValue = a[sortConfig.key] || '';
    const bValue = b[sortConfig.key] || '';
    
    if (aValue < bValue) return sortConfig.direction === 'asc' ? -1 : 1;
    if (aValue > bValue) return sortConfig.direction === 'asc' ? 1 : -1;
    return 0;
  });

  // Paginate assets
  const totalPages = Math.ceil(sortedAssets.length / itemsPerPage);
  const paginatedAssets = sortedAssets.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  const handleSort = (key: keyof Asset) => {
    setSortConfig({
      key,
      direction: sortConfig.key === key && sortConfig.direction === 'asc' ? 'desc' : 'asc',
    });
  };

  const handleCreate = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    
    const newAsset = {
      id: formData.get('id') as string,
      type: formData.get('type') as string,
      status: formData.get('status') as string,
      location: formData.get('location') as string,
      specs: formData.get('specs') as string || '',
      category_id: formData.get('category_id') ? Number(formData.get('category_id')) : null,
      subcategory_id: formData.get('subcategory_id') ? Number(formData.get('subcategory_id')) : null,
      serial_number: formData.get('serial_number') as string || null,
      license_key: formData.get('license_key') as string || null,
      expiry_date: formData.get('expiry_date') as string || null,
      quantity: formData.get('quantity') ? Number(formData.get('quantity')) : null,
      min_stock_level: formData.get('min_stock_level') ? Number(formData.get('min_stock_level')) : null,
      supplier: formData.get('supplier') as string || null,
      warranty_date: formData.get('warranty_date') as string || null,
      note: formData.get('note') as string || '',
      image_path: formData.get('image_path') as string || null,
      legacy_inv_code: formData.get('legacy_inv_code') as string || null,
    };

    try {
      const response = await fetch(`${API_BASE_URL}/api/assets`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Source': 'web' },
        body: JSON.stringify(newAsset),
      });
      if (!response.ok) throw new Error('Gagal membuat aset baru');
      await fetchAssets();
      setShowCreateModal(false);
      toast.success(`Aset ${newAsset.id} berhasil ditambahkan!`);
    } catch (error) {
      console.error('Error creating asset:', error);
      toast.error('Gagal menambahkan aset baru');
    }
  };

  const handleEdit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!selectedAsset) return;
    const formData = new FormData(e.currentTarget);
    
    const updatedAsset = {
      type: formData.get('type') as string,
      status: formData.get('status') as string,
      location: formData.get('location') as string,
      specs: formData.get('specs') as string || '',
      category_id: formData.get('category_id') ? Number(formData.get('category_id')) : null,
      subcategory_id: formData.get('subcategory_id') ? Number(formData.get('subcategory_id')) : null,
      serial_number: formData.get('serial_number') as string || null,
      license_key: formData.get('license_key') as string || null,
      expiry_date: formData.get('expiry_date') as string || null,
      quantity: formData.get('quantity') ? Number(formData.get('quantity')) : null,
      min_stock_level: formData.get('min_stock_level') ? Number(formData.get('min_stock_level')) : null,
      supplier: formData.get('supplier') as string || null,
      warranty_date: formData.get('warranty_date') as string || null,
      note: formData.get('note') as string || '',
      image_path: formData.get('image_path') as string || selectedAsset.image_path || null,
      legacy_inv_code: formData.get('legacy_inv_code') as string || selectedAsset.legacy_inv_code || null,
      sticker_status: formData.get('sticker_status') as string || selectedAsset.sticker_status || 'STICKERED',
    };

    try {
      const response = await fetch(`${API_BASE_URL}/api/assets/${selectedAsset.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', 'X-Source': 'web' },
        body: JSON.stringify(updatedAsset),
      });
      if (!response.ok) throw new Error('Gagal memperbarui aset');
      await fetchAssets();
      setShowEditModal(false);
      setSelectedAsset(null);
      toast.success(`Perubahan aset ${selectedAsset.id} berhasil disimpan!`);
    } catch (error) {
      console.error('Error updating asset:', error);
      toast.error('Gagal memperbarui data aset');
    }
  };

  const handleDelete = async () => {
    if (!selectedAsset) return;
    try {
      await deleteAsset(selectedAsset.id);
      setShowDeleteModal(false);
      setSelectedAsset(null);
    } catch (error) {
      console.error('Failed to delete asset:', error);
    }
  };

  const generateQRCode = (assetId: string) => {
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${assetId}`;
    window.open(qrUrl, '_blank');
  };

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold mb-2">Asset Management</h1>
          <p className="text-slate-400">Manage all assets in the system</p>
        </div>
        <div className="flex gap-2">
          <button 
            onClick={() => setShowBulkImportModal(true)}
            className="px-4 py-2 bg-green-600 hover:bg-green-500 rounded-lg transition flex items-center gap-2"
          >
            <Upload size={20} />
            Bulk Import
          </button>
          <button 
            onClick={() => setShowCreateModal(true)}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition flex items-center gap-2"
          >
            <Plus size={20} />
            Add Asset
          </button>
        </div>
      </div>

      {/* Asset Table */}
      <div className="bg-slate-800 rounded-lg border border-slate-700 overflow-hidden">
        <div className="p-4 border-b border-slate-700 flex justify-between items-center">
          <h2 className="text-xl font-semibold">Asset Inventory</h2>
          <div className="flex gap-4 items-center">
            <div className="flex items-center gap-2">
              <label className="text-sm text-slate-400">Show:</label>
              <select
                value={itemsPerPage}
                onChange={(e) => {
                  setItemsPerPage(Number(e.target.value));
                  setCurrentPage(1);
                }}
                className="px-3 py-1 bg-slate-900 border border-slate-600 rounded text-sm"
              >
                <option value={10}>10</option>
                <option value={25}>25</option>
                <option value={50}>50</option>
                <option value={100}>100</option>
              </select>
            </div>
            <button
              onClick={fetchAssets}
              className="px-3 py-1 bg-blue-600 hover:bg-blue-500 rounded text-sm transition"
            >
              Refresh
            </button>
          </div>
        </div>

        {/* Search Filters */}
        <div className="p-4 bg-slate-900/50 border-b border-slate-700">
          <div className="grid grid-cols-6 gap-3">
            <input
              type="text"
              placeholder="Search Asset ID..."
              value={searchFilters.id}
              onChange={(e) => setSearchFilters({ ...searchFilters, id: e.target.value })}
              className="px-3 py-2 bg-slate-900 border border-slate-600 rounded text-sm"
            />
            <select
              value={searchFilters.type}
              onChange={(e) => setSearchFilters({ ...searchFilters, type: e.target.value })}
              className="px-3 py-2 bg-slate-900 border border-slate-600 rounded text-sm"
            >
              <option value="">All Types</option>
              <option value="PC">PC</option>
              <option value="LAPTOP">Laptop</option>
              <option value="MONITOR">Monitor</option>
              <option value="KEYBOARD">Keyboard</option>
              <option value="MOUSE">Mouse</option>
              <option value="HEADSET">Headset</option>
            </select>
            <select
              value={searchFilters.status}
              onChange={(e) => setSearchFilters({ ...searchFilters, status: e.target.value })}
              className="px-3 py-2 bg-slate-900 border border-slate-600 rounded text-sm"
            >
              <option value="">All Status</option>
              <option value="AVAILABLE">Available</option>
              <option value="IN_USE">In Use</option>
              <option value="BROKEN">Broken</option>
              <option value="REPAIRING">Repairing</option>
            </select>
            <select
              value={searchFilters.purchaseYear}
              onChange={(e) => setSearchFilters({ ...searchFilters, purchaseYear: e.target.value })}
              className="px-3 py-2 bg-slate-900 border border-slate-600 rounded text-sm"
            >
              <option value="">Semua Tahun Beli</option>
              <option value="2026">Tahun 2026</option>
              <option value="2025">Tahun 2025</option>
              <option value="2024">Tahun 2024</option>
              <option value="2023">Tahun 2023</option>
              <option value="2022">Tahun 2022</option>
              <option value="2021">Tahun 2021</option>
              <option value="2020">Tahun 2020</option>
            </select>
            <input
              type="text"
              placeholder="Search Location..."
              value={searchFilters.location}
              onChange={(e) => setSearchFilters({ ...searchFilters, location: e.target.value })}
              className="px-3 py-2 bg-slate-900 border border-slate-600 rounded text-sm"
            />
            <input
              type="text"
              placeholder="Search Specs..."
              value={searchFilters.specs}
              onChange={(e) => setSearchFilters({ ...searchFilters, specs: e.target.value })}
              className="px-3 py-2 bg-slate-900 border border-slate-600 rounded text-sm"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-slate-900">
              <tr>
                <th 
                  className="px-4 py-3 text-left text-sm font-semibold cursor-pointer hover:bg-slate-800"
                  onClick={() => handleSort('id')}
                >
                  <div className="flex items-center gap-2">
                    Asset ID
                    {sortConfig.key === 'id' && (
                      <span>{sortConfig.direction === 'asc' ? '↑' : '↓'}</span>
                    )}
                  </div>
                </th>
                <th 
                  className="px-4 py-3 text-left text-sm font-semibold cursor-pointer hover:bg-slate-800"
                  onClick={() => handleSort('type')}
                >
                  <div className="flex items-center gap-2">
                    Type
                    {sortConfig.key === 'type' && (
                      <span>{sortConfig.direction === 'asc' ? '↑' : '↓'}</span>
                    )}
                  </div>
                </th>
                <th 
                  className="px-4 py-3 text-left text-sm font-semibold cursor-pointer hover:bg-slate-800"
                  onClick={() => handleSort('status')}
                >
                  <div className="flex items-center gap-2">
                    Status
                    {sortConfig.key === 'status' && (
                      <span>{sortConfig.direction === 'asc' ? '↑' : '↓'}</span>
                    )}
                  </div>
                </th>
                <th 
                  className="px-4 py-3 text-left text-sm font-semibold cursor-pointer hover:bg-slate-800"
                  onClick={() => handleSort('location')}
                >
                  <div className="flex items-center gap-2">
                    Location
                    {sortConfig.key === 'location' && (
                      <span>{sortConfig.direction === 'asc' ? '↑' : '↓'}</span>
                    )}
                  </div>
                </th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Stiker GA (No. Inv)</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Tahun Beli &amp; Umur</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Specs</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {paginatedAssets.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-4 py-8 text-center text-slate-400">
                    No assets found matching your filters.
                  </td>
                </tr>
              ) : (
                paginatedAssets.map((asset) => (
                  <tr key={asset.id} className="border-t border-slate-700 hover:bg-slate-700/50">
                    <td className="px-4 py-3 font-mono text-sm">
                      <div>{asset.id}</div>
                      {asset.legacy_inv_code && (
                        <div className="text-xs text-blue-400 font-sans">{asset.legacy_inv_code}</div>
                      )}
                    </td>
                    <td className="px-4 py-3 font-medium">{asset.type}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 rounded text-xs font-semibold ${
                        asset.status === 'AVAILABLE' ? 'bg-green-900 text-green-300 border border-green-700' :
                        asset.status === 'IN_USE' ? 'bg-blue-900 text-blue-300 border border-blue-700' :
                        asset.status === 'REPAIRING' ? 'bg-orange-900 text-orange-300 border border-orange-700' :
                        'bg-red-900 text-red-300 border border-red-700'
                      }`}>
                        {asset.status}
                      </span>
                    </td>
                    <td className="px-4 py-3">{asset.location}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded text-xs ${
                        asset.sticker_status === 'STICKERED' ? 'bg-emerald-950 text-emerald-300 border border-emerald-800' :
                        'bg-slate-700 text-slate-400'
                      }`}>
                        {asset.sticker_status === 'STICKERED' ? '✓ Tertempel' : 'Belum Stiker'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {(() => {
                        const yearStr = getPurchaseYear(asset);
                        const ageInfo = getAssetAge(yearStr);
                        return (
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-xs text-slate-200 font-semibold bg-slate-900 px-2 py-1 rounded border border-slate-700">
                              📅 {yearStr}
                            </span>
                            <span className={`px-2 py-0.5 rounded text-[11px] ${ageInfo.badgeClass}`}>
                              {ageInfo.label}
                            </span>
                          </div>
                        );
                      })()}
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-400">{asset.specs || '-'}</td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2">
                        <button
                          onClick={() => {
                            setSelectedAsset(asset);
                            setShowEditModal(true);
                          }}
                          className="p-1 hover:bg-slate-600 rounded transition"
                          title="Edit Asset"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          onClick={() => {
                            setSelectedAsset(asset);
                            setShowHistoryModal(true);
                          }}
                          className="p-1 hover:bg-slate-600 rounded transition text-blue-400"
                          title="View History"
                        >
                          <History size={16} />
                        </button>
                        <button
                          onClick={() => generateQRCode(asset.id)}
                          className="p-1 hover:bg-slate-600 rounded transition"
                          title="Generate QR Code"
                        >
                          <Download size={16} />
                        </button>
                        <button
                          onClick={() => {
                            setSelectedAsset(asset);
                            setShowDeleteModal(true);
                          }}
                          className="p-1 hover:bg-red-600 rounded transition text-red-400"
                          title="Delete Asset"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="p-4 border-t border-slate-700 flex justify-between items-center">
          <div className="text-sm text-slate-400">
            Showing {((currentPage - 1) * itemsPerPage) + 1} to {Math.min(currentPage * itemsPerPage, filteredAssets.length)} of {filteredAssets.length} assets
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setCurrentPage(1)}
              disabled={currentPage === 1}
              className="px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed transition"
            >
              First
            </button>
            <button
              onClick={() => setCurrentPage(currentPage - 1)}
              disabled={currentPage === 1}
              className="px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed transition"
            >
              Previous
            </button>
            <div className="flex items-center gap-2 px-3">
              <span className="text-sm">Page</span>
              <input
                type="number"
                min={1}
                max={totalPages}
                value={currentPage}
                onChange={(e) => {
                  const page = Number(e.target.value);
                  if (page >= 1 && page <= totalPages) {
                    setCurrentPage(page);
                  }
                }}
                className="w-16 px-2 py-1 bg-slate-900 border border-slate-600 rounded text-sm text-center"
              />
              <span className="text-sm">of {totalPages}</span>
            </div>
            <button
              onClick={() => setCurrentPage(currentPage + 1)}
              disabled={currentPage === totalPages}
              className="px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed transition"
            >
              Next
            </button>
            <button
              onClick={() => setCurrentPage(totalPages)}
              disabled={currentPage === totalPages}
              className="px-3 py-1 bg-slate-700 hover:bg-slate-600 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed transition"
            >
              Last
            </button>
          </div>
        </div>
      </div>

      {/* Modals */}
      <AssetFormModal
        show={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSubmit={handleCreate}
        title="Create New Asset"
      />

      <AssetFormModal
        show={showEditModal}
        onClose={() => { setShowEditModal(false); setSelectedAsset(null); }}
        onSubmit={handleEdit}
        title="Edit Asset"
        asset={selectedAsset}
      />

      <DeleteConfirmModal
        show={showDeleteModal}
        onClose={() => { setShowDeleteModal(false); setSelectedAsset(null); }}
        onConfirm={handleDelete}
        assetId={selectedAsset?.id}
      />

      <AssetHistoryModal
        show={showHistoryModal}
        onClose={() => { setShowHistoryModal(false); setSelectedAsset(null); }}
        assetId={selectedAsset?.id || ''}
      />

      <BulkImportModal
        show={showBulkImportModal}
        onClose={() => setShowBulkImportModal(false)}
        onSuccess={() => fetchAssets()}
      />
    </div>
  );
};
