import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';

export const SettingsPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Settings</h1>
        <p className="text-slate-400">Configure system settings and preferences</p>
      </div>

      <div className="space-y-6">
        <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
          <h2 className="text-xl font-semibold mb-4">General Settings</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm mb-2">Company Name</label>
              <input
                type="text"
                defaultValue="Asset Management System"
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
              />
            </div>
            <div>
              <label className="block text-sm mb-2">Default Area</label>
              <input
                type="text"
                defaultValue="COLLECTION"
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
              />
            </div>
          </div>
        </div>

        <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
          <h2 className="text-xl font-semibold mb-4">Asset Types</h2>
          <p className="text-sm text-slate-400 mb-4">Configure available asset types</p>
          <div className="flex flex-wrap gap-2">
            {['PC', 'LAPTOP', 'MONITOR', 'KEYBOARD', 'MOUSE', 'HEADSET'].map((type) => (
              <span key={type} className="px-3 py-1 bg-blue-900 text-blue-300 rounded text-sm">
                {type}
              </span>
            ))}
          </div>
        </div>

        <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
          <h2 className="text-xl font-semibold mb-4">Notifications</h2>
          <div className="space-y-3">
            <label className="flex items-center gap-2">
              <input type="checkbox" defaultChecked />
              <span>Email notifications for new assets</span>
            </label>
            <label className="flex items-center gap-2">
              <input type="checkbox" defaultChecked />
              <span>Alert when assets are broken</span>
            </label>
            <label className="flex items-center gap-2">
              <input type="checkbox" />
              <span>Daily summary reports</span>
            </label>
          </div>
        </div>

        <button className="px-6 py-2 bg-blue-600 hover:bg-blue-500 rounded transition">
          Save Settings
        </button>
      </div>
    </div>
  );
};
