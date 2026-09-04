import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { useAuthStore } from '../../store/authStore';
import { Filter, RefreshCw } from 'lucide-react';
import { API_BASE_URL } from '../../services/apiClient';

interface AuditLog {
  id: number;
  timestamp: string;
  user: string;
  action: string;
  entity_type: string;
  entity_id?: string;
  details: string;
  source: string;
}

export const HistoryPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterAction, setFilterAction] = useState('');
  const [filterSource, setFilterSource] = useState('');

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  const fetchLogs = async () => {
    setLoading(true);
    try {
      let url = `${API_BASE_URL}/api/history?limit=100`;
      if (filterAction) url += `&action=${filterAction}`;
      if (filterSource) url += `&source=${filterSource}`;

      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch logs');
      const data = await response.json();
      setLogs(data);
    } catch (error) {
      console.error('Error fetching logs:', error);
      toast.error('Failed to load activity history');
      setLogs([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, [filterAction, filterSource]);

  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold mb-2">Activity History</h1>
          <p className="text-slate-400">View all system activity and audit logs</p>
        </div>
        <button
          onClick={fetchLogs}
          className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition flex items-center gap-2"
        >
          <RefreshCw size={18} />
          Refresh
        </button>
      </div>

      {/* Filters */}
      <div className="mb-4 flex gap-4">
        <div className="flex items-center gap-2">
          <Filter size={18} className="text-slate-400" />
          <select
            value={filterAction}
            onChange={(e) => setFilterAction(e.target.value)}
            className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg"
          >
            <option value="">All Actions</option>
            <option value="CREATE">Create</option>
            <option value="UPDATE">Update</option>
            <option value="DELETE">Delete</option>
            <option value="SCAN">Scan</option>
          </select>
        </div>
        <div>
          <select
            value={filterSource}
            onChange={(e) => setFilterSource(e.target.value)}
            className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg"
          >
            <option value="">All Sources</option>
            <option value="web">Web</option>
            <option value="mobile">Mobile</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-slate-800 rounded-lg border border-slate-700 overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-slate-400">Loading...</div>
        ) : logs.length === 0 ? (
          <div className="p-8 text-center text-slate-400">No activity logs found</div>
        ) : (
          <table className="w-full">
            <thead className="bg-slate-900">
              <tr>
                <th className="px-4 py-3 text-left text-sm font-semibold">Timestamp</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">User</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Action</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Source</th>
                <th className="px-4 py-3 text-left text-sm font-semibold">Details</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log) => (
                <tr key={log.id} className="border-t border-slate-700 hover:bg-slate-750">
                  <td className="px-4 py-3 text-sm text-slate-400">{formatTimestamp(log.timestamp)}</td>
                  <td className="px-4 py-3">{log.user}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded text-xs ${
                      log.action === 'CREATE' ? 'bg-green-900 text-green-300' :
                      log.action === 'UPDATE' ? 'bg-blue-900 text-blue-300' :
                      log.action === 'DELETE' ? 'bg-red-900 text-red-300' :
                      'bg-purple-900 text-purple-300'
                    }`}>
                      {log.action}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded text-xs ${
                      log.source === 'web' ? 'bg-indigo-900 text-indigo-300' : 'bg-orange-900 text-orange-300'
                    }`}>
                      {log.source === 'web' ? '🖥️ Web' : '📱 Mobile'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm">{log.details}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};
