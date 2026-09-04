import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';
import { useStore } from '../store/assetStore';
import { LogOut, Plus, Download } from 'lucide-react';
import type { Asset } from '../types';

export const AdminPanel = () => {
  const navigate = useNavigate();
  const { isAuthenticated, username, logout } = useAuthStore();
  const { assets, desks, fetchAssets, fetchDesks, initDeskMaster, baselineAudit } = useStore();
  
  const [showDeskInit, setShowDeskInit] = useState(false);
  const [showBaselineAudit, setShowBaselineAudit] = useState(false);

  // Pagination & Filtering
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [searchFilters, setSearchFilters] = useState({
    id: '',
    type: '',
    status: '',
    location: '',
    specs: '',
  });
  const [sortConfig, setSortConfig] = useState<{
    key: keyof Asset | null;
    direction: 'asc' | 'desc';
  }>({ key: null, direction: 'asc' });

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchAssets();
    fetchDesks();
  }, [isAuthenticated, navigate, fetchAssets, fetchDesks]);

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

  // Filter assets
  const filteredAssets = assets.filter((asset) => {
    const searchId = searchFilters.id.toLowerCase().trim();
    const matchesIdOrLegacy = 
      asset.id.toLowerCase().includes(searchId) || 
      ((asset as any).legacy_inv_code || '').toLowerCase().includes(searchId);

    const assetCat = normalizeCategory(asset.type);
    const filterCat = normalizeCategory(searchFilters.type);

    const matchesType = 
      searchFilters.type === '' || 
      assetCat === filterCat || 
      asset.type.toUpperCase().includes(searchFilters.type.toUpperCase());

    return (
      matchesIdOrLegacy &&
      matchesType &&
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

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const handleDeskInit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    await initDeskMaster(
      Number(formData.get('start')),
      Number(formData.get('end')),
      formData.get('area') as string
    );
    setShowDeskInit(false);
    fetchDesks();
  };

  const handleBaselineAudit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const assetTypes: Asset['type'][] = [];
    if (formData.get('pc')) assetTypes.push('PC');
    if (formData.get('monitor')) assetTypes.push('MONITOR');
    if (formData.get('keyboard')) assetTypes.push('KEYBOARD');
    if (formData.get('mouse')) assetTypes.push('MOUSE');
    if (formData.get('headset')) assetTypes.push('HEADSET');

    await baselineAudit(
      Number(formData.get('deskNumber')),
      formData.get('area') as string,
      assetTypes
    );
    setShowBaselineAudit(false);
    fetchAssets();
    fetchDesks();
  };

  const generateQRCode = (assetId: string) => {
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${assetId}`;
    window.open(qrUrl, '_blank');
  };

  return (
    <div className="min-h-screen bg-slate-900 text-white">
      {/* Header */}
      <header className="bg-slate-800 border-b border-slate-700 p-4">
        <div className="max-w-7xl mx-auto flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-bold">Admin Panel</h1>
            <p className="text-slate-400 text-sm">Welcome, {username}</p>
          </div>
          <div className="flex gap-4">
            <button
              onClick={() => navigate('/dashboard')}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition"
            >
              View Dashboard
            </button>
            <button
              onClick={handleLogout}
              className="px-4 py-2 bg-red-600 hover:bg-red-500 rounded-lg transition flex items-center gap-2"
            >
              <LogOut size={18} />
              Logout
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto p-6">
        {/* Quick Actions */}
        <div className="grid grid-cols-2 gap-4 mb-8">
          <button
            onClick={() => setShowDeskInit(true)}
            className="bg-slate-800 hover:bg-slate-700 p-6 rounded-lg border border-slate-700 transition text-left"
          >
            <Plus className="mb-2 text-blue-400" size={24} />
            <h3 className="font-semibold mb-1">Initialize Desks</h3>
            <p className="text-sm text-slate-400">Batch create desk master data</p>
          </button>

          <button
            onClick={() => setShowBaselineAudit(true)}
            className="bg-slate-800 hover:bg-slate-700 p-6 rounded-lg border border-slate-700 transition text-left"
          >
            <Plus className="mb-2 text-green-400" size={24} />
            <h3 className="font-semibold mb-1">Baseline Audit</h3>
            <p className="text-sm text-slate-400">Batch create assets for desk</p>
          </button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-4 gap-4 mb-8">
          <div className="bg-slate-800 p-4 rounded-lg border border-slate-700">
            <div className="text-2xl font-bold text-blue-400">{desks.length}</div>
            <div className="text-sm text-slate-400">Total Desks</div>
          </div>
          <div className="bg-slate-800 p-4 rounded-lg border border-slate-700">
            <div className="text-2xl font-bold text-green-400">{assets.length}</div>
            <div className="text-sm text-slate-400">Total Assets</div>
          </div>
          <div className="bg-slate-800 p-4 rounded-lg border border-slate-700">
            <div className="text-2xl font-bold text-yellow-400">
              {desks.filter(d => d.status === 'OCCUPIED').length}
            </div>
            <div className="text-sm text-slate-400">Occupied Desks</div>
          </div>
          <div className="bg-slate-800 p-4 rounded-lg border border-slate-700">
            <div className="text-2xl font-bold text-red-400">
              {assets.filter(a => a.status === 'BROKEN').length}
            </div>
            <div className="text-sm text-slate-400">Broken Assets</div>
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
            <div className="grid grid-cols-5 gap-3">
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
                  <th className="px-4 py-3 text-left text-sm font-semibold">Specs</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold">Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedAssets.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-slate-400">
                      No assets found matching your filters.
                    </td>
                  </tr>
                ) : (
                  paginatedAssets.map((asset) => (
                    <tr key={asset.id} className="border-t border-slate-700 hover:bg-slate-700/50">
                      <td className="px-4 py-3 font-mono text-sm">{asset.id}</td>
                      <td className="px-4 py-3">{asset.type}</td>
                      <td className="px-4 py-3">
                        <span className={`px-2 py-1 rounded text-xs ${
                          asset.status === 'AVAILABLE' ? 'bg-green-900 text-green-300' :
                          asset.status === 'IN_USE' ? 'bg-blue-900 text-blue-300' :
                          'bg-red-900 text-red-300'
                        }`}>
                          {asset.status}
                        </span>
                      </td>
                      <td className="px-4 py-3">{asset.location}</td>
                      <td className="px-4 py-3 text-sm text-slate-400">{asset.specs || '-'}</td>
                      <td className="px-4 py-3">
                        <button
                          onClick={() => generateQRCode(asset.id)}
                          className="p-1 hover:bg-slate-600 rounded transition"
                          title="Generate QR Code"
                        >
                          <Download size={16} />
                        </button>
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
      </div>

      {/* Desk Init Modal */}
      {showDeskInit && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Initialize Desk Master</h3>
            <form onSubmit={handleDeskInit} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Start Number</label>
                <input
                  type="number"
                  name="start"
                  defaultValue={1}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">End Number</label>
                <input
                  type="number"
                  name="end"
                  defaultValue={120}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Area</label>
                <input
                  type="text"
                  name="area"
                  defaultValue="COLLECTION"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-500 py-2 rounded transition"
                >
                  Create Desks
                </button>
                <button
                  type="button"
                  onClick={() => setShowDeskInit(false)}
                  className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Baseline Audit Modal */}
      {showBaselineAudit && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Baseline Audit</h3>
            <form onSubmit={handleBaselineAudit} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Desk Number</label>
                <input
                  type="number"
                  name="deskNumber"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Area</label>
                <input
                  type="text"
                  name="area"
                  defaultValue="COLLECTION"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Asset Types</label>
                <div className="space-y-2">
                  {['pc', 'monitor', 'keyboard', 'mouse', 'headset'].map((type) => (
                    <label key={type} className="flex items-center gap-2">
                      <input type="checkbox" name={type} defaultChecked={type !== 'headset'} />
                      <span className="capitalize">{type}</span>
                    </label>
                  ))}
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-green-600 hover:bg-green-500 py-2 rounded transition"
                >
                  Create Assets
                </button>
                <button
                  type="button"
                  onClick={() => setShowBaselineAudit(false)}
                  className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
