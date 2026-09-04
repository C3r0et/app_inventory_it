import { useState, useEffect } from 'react';
import { X, Clock } from 'lucide-react';

interface AuditLog {
  id: number;
  timestamp: string;
  user: string;
  action: string;
  entity_type: string;
  entity_id: string;
  details: string;
  source: string;
}

import { API_BASE_URL } from '../services/apiClient';

export const AssetHistoryModal = ({
  show,
  onClose,
  assetId
}: {
  show: boolean;
  onClose: () => void;
  assetId: string;
}) => {
  const [activeTab, setActiveTab] = useState<'AUDIT' | 'CLEANING' | 'PARTS' | 'LOCATION'>('AUDIT');
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [fullHistory, setFullHistory] = useState<any>({ maintenance: [], part_history: [], location_history: [] });
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (show && assetId) {
      fetchHistory();
    }
  }, [show, assetId]);

  const fetchHistory = async () => {
    setLoading(true);
    try {
      const [auditRes, fullRes] = await Promise.all([
        fetch(`${API_BASE_URL}/api/history?asset_id=${assetId}`),
        fetch(`${API_BASE_URL}/api/assets/${assetId}/history`)
      ]);
      
      if (auditRes.ok) {
        setLogs(await auditRes.json());
      }
      if (fullRes.ok) {
        setFullHistory(await fullRes.json());
      }
    } catch (error) {
      console.error('Failed to fetch asset history:', error);
    } finally {
      setLoading(false);
    }
  };

  if (!show) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-800 rounded-lg p-6 max-w-3xl w-full border border-slate-700 max-h-[85vh] flex flex-col">
        <div className="flex justify-between items-center mb-4 border-b border-slate-700 pb-4">
          <div>
            <h3 className="text-xl font-semibold flex items-center gap-2">
              <Clock className="text-blue-400" />
              Asset History: <span className="text-blue-400 font-mono">{assetId}</span>
            </h3>
            <p className="text-sm text-slate-400 mt-1">Timeline aktivitas, kebersihan debu, perbaikan part, & lokasi</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-slate-700 rounded-full transition">
            <X size={24} />
          </button>
        </div>

        {/* Tabs Header */}
        <div className="flex gap-2 mb-4 border-b border-slate-700 pb-2">
          <button
            onClick={() => setActiveTab('AUDIT')}
            className={`px-3 py-1.5 rounded text-sm font-medium transition ${
              activeTab === 'AUDIT' ? 'bg-blue-600 text-white' : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
            }`}
          >
            Audit Log ({logs.length})
          </button>
          <button
            onClick={() => setActiveTab('CLEANING')}
            className={`px-3 py-1.5 rounded text-sm font-medium transition ${
              activeTab === 'CLEANING' ? 'bg-blue-600 text-white' : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
            }`}
          >
            🧹 Pembersihan Debu ({fullHistory.maintenance?.length || 0})
          </button>
          <button
            onClick={() => setActiveTab('PARTS')}
            className={`px-3 py-1.5 rounded text-sm font-medium transition ${
              activeTab === 'PARTS' ? 'bg-blue-600 text-white' : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
            }`}
          >
            ⚙️ Riwayat Perbaikan Part ({fullHistory.part_history?.length || 0})
          </button>
          <button
            onClick={() => setActiveTab('LOCATION')}
            className={`px-3 py-1.5 rounded text-sm font-medium transition ${
              activeTab === 'LOCATION' ? 'bg-blue-600 text-white' : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
            }`}
          >
            📍 Mutasi Lokasi ({fullHistory.location_history?.length || 0})
          </button>
        </div>

        <div className="flex-1 overflow-y-auto pr-2 custom-scrollbar">
          {loading ? (
            <div className="flex justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-400"></div>
            </div>
          ) : activeTab === 'AUDIT' ? (
            logs.length === 0 ? (
              <div className="text-center py-12 text-slate-500">Belum ada log audit.</div>
            ) : (
              <div className="space-y-3">
                {logs.map((log) => (
                  <div key={log.id} className="bg-slate-900/50 p-3 rounded border border-slate-700">
                    <div className="flex justify-between text-xs text-slate-400 mb-1">
                      <span className="font-semibold text-blue-400">{log.action} ({log.user})</span>
                      <span>{new Date(log.timestamp).toLocaleString()}</span>
                    </div>
                    <p className="text-sm text-slate-200">{log.details}</p>
                  </div>
                ))}
              </div>
            )
          ) : activeTab === 'CLEANING' ? (
            fullHistory.maintenance.length === 0 ? (
              <div className="text-center py-12 text-slate-500">Belum ada catatan pembersihan debu bulanan.</div>
            ) : (
              <div className="space-y-3">
                {fullHistory.maintenance.map((m: any) => (
                  <div key={m.id} className="bg-slate-900/50 p-3 rounded border border-emerald-900/50 flex justify-between items-center">
                    <div>
                      <div className="font-semibold text-emerald-400 text-sm">🧹 {m.type}</div>
                      <div className="text-xs text-slate-300 mt-1">{m.notes}</div>
                      <div className="text-xs text-slate-500 mt-1">Teknisi: {m.performed_by}</div>
                    </div>
                    <div className="text-xs text-slate-400 font-mono">
                      {new Date(m.performed_at).toLocaleString()}
                    </div>
                  </div>
                ))}
              </div>
            )
          ) : activeTab === 'PARTS' ? (
            fullHistory.part_history.length === 0 ? (
              <div className="text-center py-12 text-slate-500">Belum ada riwayat perbaikan / pergantian part.</div>
            ) : (
              <div className="space-y-3">
                {fullHistory.part_history.map((p: any) => (
                  <div key={p.id} className="bg-slate-900/50 p-3 rounded border border-amber-900/50">
                    <div className="flex justify-between items-start mb-1">
                      <span className="font-bold text-amber-400 text-sm">
                        {p.part_name} <span className="text-xs font-normal text-slate-400">({p.action_type})</span>
                      </span>
                      <span className="text-xs text-slate-400">{new Date(p.replaced_at).toLocaleDateString()}</span>
                    </div>
                    {p.old_spec && <div className="text-xs text-red-400">Lama: {p.old_spec}</div>}
                    {p.new_spec && <div className="text-xs text-emerald-400">Baru: {p.new_spec}</div>}
                    {p.reason && <div className="text-xs text-slate-300 mt-1">Alasan: {p.reason}</div>}
                    <div className="text-xs text-slate-500 mt-1">Teknisi: {p.technician}</div>
                  </div>
                ))}
              </div>
            )
          ) : (
            fullHistory.location_history.length === 0 ? (
              <div className="text-center py-12 text-slate-500">Belum ada riwayat mutasi lokasi.</div>
            ) : (
              <div className="space-y-3">
                {fullHistory.location_history.map((l: any) => (
                  <div key={l.id} className="bg-slate-900/50 p-3 rounded border border-blue-900/50 flex justify-between items-center">
                    <div>
                      <div className="text-sm font-medium text-slate-200">
                        <span className="text-red-400">{l.from_location || 'Awal'}</span> $\rightarrow$ <span className="text-emerald-400">{l.to_location}</span>
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">{l.reason}</div>
                      <div className="text-xs text-slate-500">Oleh: {l.moved_by}</div>
                    </div>
                    <div className="text-xs text-slate-400 font-mono">
                      {new Date(l.moved_at).toLocaleString()}
                    </div>
                  </div>
                ))}
              </div>
            )
          )}
        </div>
      </div>
    </div>
  );
};
