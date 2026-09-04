import { useEffect, useState, useRef } from 'react';
import toast from 'react-hot-toast';

export interface ActivityEvent {
  timestamp: string;
  user: string;
  action: string;
  entity_type: string;
  entity_id: string;
  details: string;
  source: string;
}

const getApiBaseUrl = () => {
  if (import.meta.env.DEV) {
    return 'http://localhost:8080';
  }
  return '';
};

export const useSSE = () => {
  const [isConnected, setIsConnected] = useState(false);
  const [lastEvent, setLastEvent] = useState<ActivityEvent | null>(null);
  const eventSourceRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const sseUrl = `${getApiBaseUrl()}/api/sse`;
    const es = new EventSource(sseUrl);
    eventSourceRef.current = es;

    es.addEventListener('connected', () => {
      setIsConnected(true);
    });

    es.addEventListener('activity', (e) => {
      try {
        const data: ActivityEvent = JSON.parse(e.data);
        setLastEvent(data);

        // Dispatch window event so table pages (like AssetsPage) can auto-refresh
        window.dispatchEvent(new CustomEvent('asset-activity-updated', { detail: data }));

        // Format and show toast alert
        const isMobile = data.source === 'mobile';
        const sourceBadge = isMobile ? '📱 Mobile' : '💻 Web';

        let actionLabel = data.action;
        let actionColor = 'text-blue-400';
        if (data.action === 'CREATE') {
          actionLabel = 'ASET BARU';
          actionColor = 'text-emerald-400';
        } else if (data.action === 'UPDATE') {
          actionLabel = 'UPDATE ASET';
          actionColor = 'text-cyan-400';
        } else if (data.action === 'AUDIT_SUBMIT') {
          actionLabel = 'HASIL AUDIT';
          actionColor = 'text-amber-400';
        } else if (data.action === 'DELETE') {
          actionLabel = 'HAPUS ASET';
          actionColor = 'text-rose-400';
        }

        toast(
          () => (
            <div className="flex flex-col gap-1 text-sm max-w-sm">
              <div className="flex items-center justify-between gap-2 border-b border-slate-700/60 pb-1">
                <span className="text-[11px] font-bold px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 border border-slate-700">
                  {sourceBadge}
                </span>
                <span className={`text-[11px] font-bold ${actionColor}`}>
                  {actionLabel}
                </span>
                <span className="text-[10px] text-slate-400">{data.timestamp ? data.timestamp.substring(11, 19) : ''}</span>
              </div>
              <div className="font-semibold text-white mt-0.5">
                {data.entity_id ? `ID: ${data.entity_id}` : data.user}
              </div>
              <p className="text-xs text-slate-300 line-clamp-2">
                {data.details || 'Aktivitas berhasil dicatat.'}
              </p>
            </div>
          ),
          {
            duration: 5000,
            position: 'top-right',
            style: {
              background: '#0f172a',
              border: isMobile ? '1px solid #3b82f6' : '1px solid #334155',
              boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5)',
              borderRadius: '12px',
              padding: '12px 14px',
            },
          }
        );
      } catch (err) {
        console.error('Failed to parse SSE activity event:', err);
      }
    });

    es.onerror = () => {
      setIsConnected(false);
    };

    return () => {
      es.close();
    };
  }, []);

  return { isConnected, lastEvent };
};
