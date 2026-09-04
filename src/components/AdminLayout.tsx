import type { ReactNode } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';
import { useSSE } from '../services/useSSE';
import { 
  LayoutDashboard, 
  Package, 
  Armchair, 
  Users, 
  Zap, 
  History, 
  BarChart3, 
  Settings, 
  LogOut,
  Menu,
  X,
  QrCode,
  Folder,
  Smartphone
} from 'lucide-react';
import { useState } from 'react';

interface AdminLayoutProps {
  children: ReactNode;
}

const menuItems = [
  { path: '/admin/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { path: '/admin/assets', icon: Package, label: 'Assets' },
  { path: '/admin/desks', icon: Armchair, label: 'Desks' },
  { path: '/admin/users', icon: Users, label: 'Users' },
  { path: '/admin/batch', icon: Zap, label: 'Batch Operations' },
  { path: '/admin/qr-generator', icon: QrCode, label: 'QR Generator' },
  { path: '/admin/categories', icon: Folder, label: 'Categories' },
  { path: '/admin/history', icon: History, label: 'History' },
  { path: '/admin/reports', icon: BarChart3, label: 'Reports' },
  { path: '/admin/settings', icon: Settings, label: 'Settings' },
];

export const AdminLayout = ({ children }: AdminLayoutProps) => {
  const navigate = useNavigate();
  const location = useLocation();
  const { username, logout } = useAuthStore();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const { isConnected } = useSSE();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-slate-900 text-white flex">
      {/* Sidebar */}
      <aside className={`${sidebarOpen ? 'w-64' : 'w-20'} bg-slate-800 border-r border-slate-700 transition-all duration-300 flex flex-col print:hidden`}>
        {/* Logo & Toggle */}
        <div className="p-4 border-b border-slate-700 flex items-center justify-between">
          {sidebarOpen && (
            <div>
              <h1 className="text-xl font-bold bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
                Asset Manager
              </h1>
              <div className="flex items-center gap-1.5 mt-1">
                <span className={`w-2 h-2 rounded-full ${isConnected ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`}></span>
                <span className="text-[10px] text-slate-400 font-medium">
                  {isConnected ? 'Real-time SSE Aktif' : 'Menghubungkan...'}
                </span>
              </div>
            </div>
          )}
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="p-2 hover:bg-slate-700 rounded-lg transition"
          >
            {sidebarOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4 space-y-2">
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <button
                key={item.path}
                onClick={() => navigate(item.path)}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg transition ${
                  isActive
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:bg-slate-700 hover:text-white'
                }`}
                title={!sidebarOpen ? item.label : undefined}
              >
                <Icon size={20} />
                {sidebarOpen && <span>{item.label}</span>}
              </button>
            );
          })}
        </nav>

        {/* Mobile App Download */}
        <div className="p-3 border-t border-slate-700/60">
          <a
            href="/uploads/Sahabat_Sakinah_Asset.apk"
            download="Sahabat_Sakinah_Asset.apk"
            className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg bg-blue-600/10 hover:bg-blue-600/20 text-blue-400 border border-blue-500/20 transition text-sm font-medium ${!sidebarOpen ? 'justify-center px-0' : ''}`}
            title="Download Mobile App (Android APK)"
          >
            <Smartphone size={18} className="shrink-0 text-blue-400" />
            {sidebarOpen && (
              <div className="flex-1 flex items-center justify-between text-xs">
                <span>Download App</span>
                <span className="bg-blue-500/20 text-blue-300 px-1.5 py-0.5 rounded text-[10px] font-semibold">APK</span>
              </div>
            )}
          </a>
        </div>

        {/* User Info & Logout */}
        <div className="p-4 border-t border-slate-700">
          {sidebarOpen && (
            <div className="mb-3 px-3 py-2 bg-slate-900 rounded-lg">
              <div className="text-xs text-slate-400">Logged in as</div>
              <div className="font-semibold">{username}</div>
            </div>
          )}
          <button
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-red-400 hover:bg-red-900/20 transition"
            title={!sidebarOpen ? 'Logout' : undefined}
          >
            <LogOut size={20} />
            {sidebarOpen && <span>Logout</span>}
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-auto">
        {children}
      </main>
    </div>
  );
};
