import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { useStore } from '../../store/assetStore';
import { TrendingUp, AlertCircle } from 'lucide-react';

export const DashboardPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { assets, desks, fetchAssets, fetchDesks } = useStore();

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchAssets();
    fetchDesks();
  }, [isAuthenticated, navigate, fetchAssets, fetchDesks]);

  const stats = {
    totalAssets: assets.length,
    totalDesks: desks.length,
    occupiedDesks: desks.filter(d => d.status === 'OCCUPIED').length,
    availableAssets: assets.filter(a => a.status === 'AVAILABLE').length,
    inUseAssets: assets.filter(a => a.status === 'IN_USE').length,
    brokenAssets: assets.filter(a => a.status === 'BROKEN').length,
    repairingAssets: assets.filter(a => a.status === 'REPAIRING').length,
  };

  const occupancyRate = stats.totalDesks > 0 
    ? ((stats.occupiedDesks / stats.totalDesks) * 100).toFixed(1) 
    : 0;

  const assetsByType = assets.reduce((acc, asset) => {
    acc[asset.type] = (acc[asset.type] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Dashboard Summary</h1>
        <p className="text-slate-400">Inventory Health & Maintenance Overview</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-4 gap-6 mb-8">
        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between mb-2">
            <div className="text-sm text-slate-400">Total Assets</div>
            <TrendingUp className="text-green-400" size={20} />
          </div>
          <div className="text-3xl font-bold text-blue-400">{stats.totalAssets}</div>
          <div className="text-xs text-slate-500 mt-1">
            {stats.inUseAssets} in use, {stats.availableAssets} available
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700 border-l-4 border-l-orange-500">
          <div className="flex items-center justify-between mb-2">
            <div className="text-sm text-slate-400">Maintenance Mode</div>
            <AlertCircle className="text-orange-400" size={20} />
          </div>
          <div className="text-3xl font-bold text-orange-400">{stats.repairingAssets}</div>
          <div className="text-xs text-slate-500 mt-1">
            Assets currently being repaired
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between mb-2">
            <div className="text-sm text-slate-400">Occupancy Rate</div>
            <TrendingUp className="text-yellow-400" size={20} />
          </div>
          <div className="text-3xl font-bold text-yellow-400">{occupancyRate}%</div>
          <div className="text-xs text-slate-500 mt-1">
            {stats.occupiedDesks} desks occupied
          </div>
        </div>

        <div className="bg-slate-800 p-6 rounded-lg border border-slate-700">
          <div className="flex items-center justify-between mb-2">
            <div className="text-sm text-slate-400">Broken Assets</div>
            <AlertCircle className="text-red-400" size={20} />
          </div>
          <div className="text-3xl font-bold text-red-400">{stats.brokenAssets}</div>
          <div className="text-xs text-slate-500 mt-1">
            Requires attention
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-3 gap-6 mb-8">
        <button
          onClick={() => navigate('/admin/assets')}
          className="bg-slate-800 hover:bg-slate-700 p-6 rounded-lg border border-slate-700 transition text-left"
        >
          <h3 className="font-semibold mb-2 text-white">Manage Assets</h3>
          <p className="text-sm text-slate-400">View, create, and update assets</p>
        </button>

        <button
          onClick={() => navigate('/admin/batch')}
          className="bg-slate-800 hover:bg-slate-700 p-6 rounded-lg border border-slate-700 transition text-left"
        >
          <h3 className="font-semibold mb-2 text-white">Batch Operations</h3>
          <p className="text-sm text-slate-400">Bulk create or update assets</p>
        </button>

        <button
          onClick={() => navigate('/admin/reports')}
          className="bg-gradient-to-r from-blue-900/60 to-indigo-900/60 hover:from-blue-800/80 hover:to-indigo-800/80 p-6 rounded-lg border border-blue-500/40 transition text-left relative overflow-hidden shadow-lg"
        >
          <span className="absolute top-2 right-2 text-[10px] font-bold bg-blue-500 text-white px-2 py-0.5 rounded">NEW</span>
          <h3 className="font-bold mb-1 text-white flex items-center gap-2">📊 Laporan Analisis Aset IT</h3>
          <p className="text-xs text-blue-200">Analytics pemeliharaan aset &amp; evaluasi operasional</p>
        </button>
      </div>

      {/* Asset Distribution */}
      <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h2 className="text-xl font-semibold mb-4">Asset Distribution by Type</h2>
        <div className="grid grid-cols-6 gap-4">
          {Object.entries(assetsByType).map(([type, count]) => (
            <div key={type} className="bg-slate-900 p-4 rounded-lg text-center">
              <div className="text-2xl font-bold text-blue-400">{count}</div>
              <div className="text-sm text-slate-400 mt-1">{type}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
