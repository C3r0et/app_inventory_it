import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { useStore } from '../../store/assetStore';
import { API_BASE_URL } from '../../services/apiClient';
import { 
  ScanLine, 
  Package, 
  CheckCircle2, 
  Clock, 
  Wrench, 
  BarChart3, 
  Zap, 
  ArrowRight, 
  Cpu, 
  Monitor, 
  Keyboard, 
  Mouse, 
  Headphones, 
  Laptop, 
  Armchair,
  History,
  QrCode,
  Sparkles,
  RefreshCw
} from 'lucide-react';

interface RecentActivityItem {
  id?: number;
  timestamp: string;
  user: string;
  action: string;
  entity_type: string;
  entity_id: string;
  details: string;
  source?: string;
}

export const DashboardPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { assets, desks, fetchAssets, fetchDesks } = useStore();
  const [recentActivities, setRecentActivities] = useState<RecentActivityItem[]>([]);

  const fetchRecentActivities = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/history?limit=7`);
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data)) {
          setRecentActivities(data.slice(0, 6));
        }
      }
    } catch (_) {
      // Ignore background fetch error
    }
  };

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchAssets();
    fetchDesks();
    fetchRecentActivities();
  }, [isAuthenticated, navigate, fetchAssets, fetchDesks]);

  // Listen to live SSE events to refresh dashboard stats & recent activities instantly
  useEffect(() => {
    const handleActivity = (e: Event) => {
      const customEvent = e as CustomEvent<RecentActivityItem>;
      if (customEvent.detail) {
        setRecentActivities((prev) => [customEvent.detail, ...prev.slice(0, 5)]);
      }
      fetchAssets();
      fetchDesks();
    };
    window.addEventListener('asset-activity-updated', handleActivity);
    return () => window.removeEventListener('asset-activity-updated', handleActivity);
  }, [fetchAssets, fetchDesks]);

  // Layman-friendly statistics
  const stats = {
    totalAssets: assets.length,
    availableAssets: assets.filter(a => a.status === 'AVAILABLE').length,
    inUseAssets: assets.filter(a => a.status === 'IN_USE').length,
    repairingAssets: assets.filter(a => a.status === 'REPAIRING').length,
    brokenAssets: assets.filter(a => a.status === 'BROKEN').length,
    totalDesks: desks.length,
    occupiedDesks: desks.filter(d => d.status === 'OCCUPIED').length,
  };

  const deskOccupancyPercent = stats.totalDesks > 0 
    ? Math.round((stats.occupiedDesks / stats.totalDesks) * 100) 
    : 0;

  // Normalized Asset Breakdown
  const normalizeCat = (type: string) => {
    const s = (type || '').toUpperCase().trim();
    if (s.includes('PC') || s.includes('CPU')) return 'PC / CPU';
    if (s.includes('MON')) return 'Monitor';
    if (s.includes('KB') || s.includes('KEY')) return 'Keyboard';
    if (s.includes('MS') || s.includes('MOU')) return 'Mouse';
    if (s.includes('HD') || s.includes('HS') || s.includes('HEAD')) return 'Headset';
    if (s.includes('LAP')) return 'Laptop';
    return 'Lainnya';
  };

  const categoryBreakdown = assets.reduce((acc, a) => {
    const cat = normalizeCat(a.type);
    acc[cat] = (acc[cat] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const categoryIcons: Record<string, { icon: React.ReactNode; color: string; bg: string }> = {
    'PC / CPU': { icon: <Cpu size={22} />, color: 'text-blue-400', bg: 'bg-blue-500/15 border-blue-500/30' },
    'Monitor': { icon: <Monitor size={22} />, color: 'text-cyan-400', bg: 'bg-cyan-500/15 border-cyan-500/30' },
    'Keyboard': { icon: <Keyboard size={22} />, color: 'text-emerald-400', bg: 'bg-emerald-500/15 border-emerald-500/30' },
    'Mouse': { icon: <Mouse size={22} />, color: 'text-amber-400', bg: 'bg-amber-500/15 border-amber-500/30' },
    'Headset': { icon: <Headphones size={22} />, color: 'text-purple-400', bg: 'bg-purple-500/15 border-purple-500/30' },
    'Laptop': { icon: <Laptop size={22} />, color: 'text-indigo-400', bg: 'bg-indigo-500/15 border-indigo-500/30' },
    'Lainnya': { icon: <Package size={22} />, color: 'text-slate-400', bg: 'bg-slate-500/15 border-slate-500/30' },
  };

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Top Banner Greeting */}
      <div className="flex flex-col md:flex-row justify-between md:items-center gap-4 bg-gradient-to-r from-slate-900 via-slate-800 to-indigo-950/70 p-6 rounded-3xl border border-slate-700/80 shadow-xl relative overflow-hidden">
        <div className="space-y-1 relative z-10">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-blue-500/10 border border-blue-500/30 text-blue-300 text-xs font-semibold mb-1">
            <Sparkles size={13} className="text-blue-400" />
            Sistem Inventaris IT &amp; GA Sahabat Sakinah
          </div>
          <h1 className="text-2xl md:text-3xl font-black text-white tracking-tight">
            Ringkasan Inventaris &amp; Operasional IT
          </h1>
          <p className="text-sm text-slate-400 max-w-2xl">
            Pantau ketersediaan stok fisik di Ruang IT, perangkat yang sedang dipakai di meja kerja, serta unit yang membutuhkan perbaikan secara real-time.
          </p>
        </div>

        <div className="flex items-center gap-3 relative z-10">
          <button
            onClick={() => {
              fetchAssets();
              fetchDesks();
              fetchRecentActivities();
            }}
            className="px-4 py-2.5 bg-slate-800/90 hover:bg-slate-700 text-slate-200 rounded-xl text-xs font-semibold border border-slate-700 flex items-center gap-2 transition"
          >
            <RefreshCw size={14} />
            Perbarui Data
          </button>
        </div>
      </div>

      {/* Hero Quick Action: Penerimaan Aset Masuk Ruang IT */}
      <div className="bg-gradient-to-r from-blue-700 via-indigo-700 to-purple-800 rounded-3xl p-6 md:p-7 shadow-2xl text-white relative overflow-hidden flex flex-col md:flex-row items-center justify-between gap-6 border border-blue-400/30">
        <div className="absolute right-0 top-0 bottom-0 w-1/3 bg-gradient-to-l from-white/5 to-transparent pointer-events-none" />
        
        <div className="flex items-center gap-5 relative z-10">
          <div className="w-16 h-16 rounded-2xl bg-white/10 backdrop-blur-md flex items-center justify-center border border-white/20 shadow-inner shrink-0">
            <ScanLine size={36} className="text-cyan-300" />
          </div>
          <div>
            <div className="inline-block px-2.5 py-0.5 rounded-full bg-cyan-400/20 text-cyan-200 border border-cyan-400/30 text-[11px] font-extrabold uppercase tracking-wider mb-1">
              ⭐ Fitur Cepat Teknisi &amp; Admin
            </div>
            <h2 className="text-xl md:text-2xl font-black tracking-tight text-white">
              Penerimaan Aset ke Ruang IT (Fast Check-in)
            </h2>
            <p className="text-xs md:text-sm text-blue-100 max-w-2xl mt-0.5">
              Teknisi membawa tumpukan CPU, monitor, mouse, atau keyboard ke Ruang IT? Buka mode ini, colok scanner barcode USB, dan scan satu per satu tanpa repot klik-klik mouse!
            </p>
          </div>
        </div>

        <button
          onClick={() => navigate('/admin/intake')}
          className="shrink-0 px-6 py-3.5 bg-white text-blue-900 hover:bg-cyan-50 font-black rounded-2xl shadow-xl flex items-center gap-2.5 transition transform hover:scale-105 active:scale-95"
        >
          <span>Mulai Scan Penerimaan</span>
          <ArrowRight size={18} />
        </button>
      </div>

      {/* 4 Core Status Overview Cards (Ramah Orang Awam) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Card 1: Total Aset */}
        <div 
          onClick={() => navigate('/admin/assets')}
          className="bg-slate-800/80 p-5 rounded-2xl border border-slate-700/80 hover:border-blue-500/50 transition cursor-pointer shadow-md group"
        >
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">
              Total Seluruh Aset
            </span>
            <div className="p-2 rounded-xl bg-blue-500/10 text-blue-400 group-hover:scale-110 transition">
              <Package size={20} />
            </div>
          </div>
          <div className="text-3xl md:text-4xl font-black text-white">
            {stats.totalAssets.toLocaleString('id-ID')}
          </div>
          <div className="text-xs text-slate-400 mt-2 flex items-center gap-1.5">
            <span className="text-blue-400 font-semibold">Semua unit</span> terdaftar di sistem
          </div>
        </div>

        {/* Card 2: Siap Pakai (Available) */}
        <div 
          onClick={() => navigate('/admin/assets')}
          className="bg-slate-800/80 p-5 rounded-2xl border border-slate-700/80 hover:border-emerald-500/50 transition cursor-pointer shadow-md group border-l-4 border-l-emerald-500"
        >
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-emerald-400 uppercase tracking-wider">
              Siap Pakai (Stok Ready)
            </span>
            <div className="p-2 rounded-xl bg-emerald-500/10 text-emerald-400 group-hover:scale-110 transition">
              <CheckCircle2 size={20} />
            </div>
          </div>
          <div className="text-3xl md:text-4xl font-black text-emerald-400">
            {stats.availableAssets.toLocaleString('id-ID')}
          </div>
          <div className="text-xs text-slate-400 mt-2 flex items-center gap-1.5">
            Di Ruang IT / siap dipasang ke meja
          </div>
        </div>

        {/* Card 3: Sedang Dipakai (In Use) */}
        <div 
          onClick={() => navigate('/admin/assets')}
          className="bg-slate-800/80 p-5 rounded-2xl border border-slate-700/80 hover:border-cyan-500/50 transition cursor-pointer shadow-md group"
        >
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-cyan-400 uppercase tracking-wider">
              Sedang Dipakai Kerja
            </span>
            <div className="p-2 rounded-xl bg-cyan-500/10 text-cyan-400 group-hover:scale-110 transition">
              <Clock size={20} />
            </div>
          </div>
          <div className="text-3xl md:text-4xl font-black text-cyan-400">
            {stats.inUseAssets.toLocaleString('id-ID')}
          </div>
          <div className="text-xs text-slate-400 mt-2 flex items-center gap-1.5">
            Terpasang aktif di meja kerja
          </div>
        </div>

        {/* Card 4: Perlu Perawatan (Repairing / Broken) */}
        <div 
          onClick={() => navigate('/admin/assets')}
          className="bg-slate-800/80 p-5 rounded-2xl border border-slate-700/80 hover:border-amber-500/50 transition cursor-pointer shadow-md group border-l-4 border-l-amber-500"
        >
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-amber-400 uppercase tracking-wider">
              Perlu Perbaikan / Rusak
            </span>
            <div className="p-2 rounded-xl bg-amber-500/10 text-amber-400 group-hover:scale-110 transition">
              <Wrench size={20} />
            </div>
          </div>
          <div className="text-3xl md:text-4xl font-black text-amber-400">
            {(stats.repairingAssets + stats.brokenAssets).toLocaleString('id-ID')}
          </div>
          <div className="text-xs text-slate-400 mt-2 flex items-center gap-2">
            <span className="text-amber-300 font-semibold">{stats.repairingAssets} servis</span>
            <span>•</span>
            <span className="text-rose-400 font-semibold">{stats.brokenAssets} rusak</span>
          </div>
        </div>
      </div>

      {/* Category Breakdown & Live Stream Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Distribution by Hardware Category */}
        <div className="lg:col-span-2 bg-slate-800/80 p-6 rounded-3xl border border-slate-700/80 shadow-md space-y-4">
          <div className="flex justify-between items-center">
            <div>
              <h2 className="text-lg font-extrabold text-white">
                Sebaran Aset Berdasarkan Kategori
              </h2>
              <p className="text-xs text-slate-400">
                Jumlah total perangkat keras IT yang ada di kantor
              </p>
            </div>
            <button
              onClick={() => navigate('/admin/assets')}
              className="text-xs font-semibold text-blue-400 hover:text-blue-300 flex items-center gap-1"
            >
              Lihat Semua →
            </button>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3.5 pt-2">
            {Object.entries(categoryBreakdown).map(([type, count]) => {
              const meta = categoryIcons[type] || categoryIcons['Lainnya'];
              return (
                <div
                  key={type}
                  onClick={() => navigate(`/admin/assets`)}
                  className={`p-4 rounded-2xl border ${meta.bg} hover:border-blue-400/50 transition cursor-pointer flex items-center gap-3.5 group`}
                >
                  <div className={`p-2.5 rounded-xl bg-slate-900/60 ${meta.color} group-hover:scale-110 transition`}>
                    {meta.icon}
                  </div>
                  <div>
                    <div className="text-2xl font-black text-white">
                      {count.toLocaleString('id-ID')}
                    </div>
                    <div className="text-xs font-semibold text-slate-300">
                      {type}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Desk Occupancy Mini Bar */}
          <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-700/60 flex flex-col sm:flex-row items-center justify-between gap-4 mt-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-yellow-500/10 text-yellow-400">
                <Armchair size={22} />
              </div>
              <div>
                <h4 className="text-xs font-bold text-white uppercase tracking-wider">
                  Kapasitas Meja Kerja Karyawan
                </h4>
                <p className="text-xs text-slate-400">
                  {stats.occupiedDesks} dari {stats.totalDesks} meja sedang ditempati ({deskOccupancyPercent}%)
                </p>
              </div>
            </div>

            <div className="w-full sm:w-48 bg-slate-800 rounded-full h-3 overflow-hidden border border-slate-700">
              <div 
                className="bg-gradient-to-r from-yellow-500 to-amber-500 h-full rounded-full transition-all duration-500"
                style={{ width: `${deskOccupancyPercent}%` }}
              />
            </div>
          </div>
        </div>

        {/* Right 1 Col: Live Real-Time Activity Feed */}
        <div className="bg-slate-800/80 p-6 rounded-3xl border border-slate-700/80 shadow-md flex flex-col justify-between space-y-4">
          <div className="flex justify-between items-center border-b border-slate-700/60 pb-3">
            <div className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping" />
              <h3 className="font-extrabold text-white text-sm">
                Aktivitas Real-Time
              </h3>
            </div>
            <button
              onClick={() => navigate('/admin/history')}
              className="text-xs text-blue-400 hover:text-blue-300 font-semibold"
            >
              Semua Histori →
            </button>
          </div>

          <div className="flex-1 space-y-3 overflow-hidden">
            {recentActivities.length === 0 ? (
              <div className="text-center py-12 text-slate-500 text-xs">
                <History size={32} className="mx-auto mb-2 opacity-30 text-slate-400" />
                Belum ada aktivitas tercatat hari ini.
              </div>
            ) : (
              recentActivities.map((act, idx) => {
                const isMobile = act.source === 'mobile';
                const timeStr = act.timestamp ? act.timestamp.substring(11, 19) : '';
                return (
                  <div 
                    key={act.id || idx}
                    className="p-3 rounded-xl bg-slate-900/70 border border-slate-700/60 flex items-start gap-2.5 text-xs hover:border-slate-600 transition"
                  >
                    <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 border border-slate-700 shrink-0">
                      {isMobile ? '📱 HP' : '💻 Web'}
                    </span>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-1">
                        <span className="font-bold text-white truncate">
                          {act.entity_id || act.user}
                        </span>
                        <span className="text-[10px] text-slate-500 font-mono shrink-0">
                          {timeStr}
                        </span>
                      </div>
                      <p className="text-slate-400 truncate text-[11px] mt-0.5">
                        {act.details || act.action}
                      </p>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          <div className="pt-2 border-t border-slate-700/60 text-center">
            <span className="text-[11px] text-slate-500">
              ⚡ Terhubung otomatis dengan aplikasi HP teknisi
            </span>
          </div>
        </div>
      </div>

      {/* Other Quick Actions Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <button
          onClick={() => navigate('/admin/assets')}
          className="p-5 rounded-2xl bg-slate-800/80 hover:bg-slate-700/80 border border-slate-700/80 transition text-left group shadow-sm"
        >
          <div className="p-3 rounded-xl bg-blue-600/20 text-blue-400 w-fit mb-3 group-hover:scale-110 transition">
            <Package size={22} />
          </div>
          <h3 className="font-bold text-white text-base mb-1">Daftar &amp; Kelola Aset</h3>
          <p className="text-xs text-slate-400">Pencarian, filter tahun beli, edit status &amp; lokasi aset.</p>
        </button>

        <button
          onClick={() => navigate('/admin/batch')}
          className="p-5 rounded-2xl bg-slate-800/80 hover:bg-slate-700/80 border border-slate-700/80 transition text-left group shadow-sm"
        >
          <div className="p-3 rounded-xl bg-amber-600/20 text-amber-400 w-fit mb-3 group-hover:scale-110 transition">
            <Zap size={22} />
          </div>
          <h3 className="font-bold text-white text-base mb-1">Operasi Massal</h3>
          <p className="text-xs text-slate-400">Pindah lokasi massal, update status sekaligus, audit meja.</p>
        </button>

        <button
          onClick={() => navigate('/admin/reports')}
          className="p-5 rounded-2xl bg-slate-800/80 hover:bg-slate-700/80 border border-slate-700/80 transition text-left group shadow-sm"
        >
          <div className="p-3 rounded-xl bg-purple-600/20 text-purple-400 w-fit mb-3 group-hover:scale-110 transition">
            <BarChart3 size={22} />
          </div>
          <h3 className="font-bold text-white text-base mb-1">Laporan &amp; Analisis</h3>
          <p className="text-xs text-slate-400">Evaluasi umur aset, riwayat perbaikan &amp; berita acara.</p>
        </button>

        <button
          onClick={() => navigate('/admin/qr-generator')}
          className="p-5 rounded-2xl bg-slate-800/80 hover:bg-slate-700/80 border border-slate-700/80 transition text-left group shadow-sm"
        >
          <div className="p-3 rounded-xl bg-emerald-600/20 text-emerald-400 w-fit mb-3 group-hover:scale-110 transition">
            <QrCode size={22} />
          </div>
          <h3 className="font-bold text-white text-base mb-1">Cetak Barcode &amp; Stiker</h3>
          <p className="text-xs text-slate-400">Buat QR code stiker inventaris untuk ditempel ke fisik aset.</p>
        </button>
      </div>
    </div>
  );
};
