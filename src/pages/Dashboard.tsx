import { useEffect } from 'react';
import { useStore } from '../store/assetStore';
import { clsx } from 'clsx';
import { Monitor, AlertCircle } from 'lucide-react';

export const Dashboard = () => {
  const { desks, assets, isLoading, error, fetchDesks, fetchAssets } = useStore();

  useEffect(() => {
    fetchDesks();
    fetchAssets();
  }, [fetchDesks, fetchAssets]);

  const collectionDesks = desks.filter(d => d.area === 'COLLECTION');

  if (isLoading) {
    return (
      <div className="p-8 bg-slate-900 min-h-screen text-white flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p className="text-slate-400">Loading data...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8 bg-slate-900 min-h-screen text-white flex items-center justify-center">
        <div className="text-center">
          <AlertCircle className="text-red-500 mx-auto mb-4" size={48} />
          <p className="text-red-400">Error: {error}</p>
          <button 
            onClick={() => { fetchDesks(); fetchAssets(); }}
            className="mt-4 px-4 py-2 bg-blue-600 rounded hover:bg-blue-500"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 bg-slate-900 min-h-screen text-white">
      <header className="mb-8 flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500">
            IT Asset Dashboard
          </h1>
          <p className="text-slate-400">Real-time Overview</p>
        </div>
        <div className="flex gap-4">
             <div className="bg-slate-800 p-3 rounded-lg flex items-center gap-3 border border-slate-700">
                <Monitor className="text-blue-400" />
                <div>
                    <div className="text-xs text-slate-400">Total Desks</div>
                    <div className="font-bold">{desks.length}</div>
                </div>
             </div>
             <div className="bg-slate-800 p-3 rounded-lg flex items-center gap-3 border border-slate-700">
                <AlertCircle className="text-green-400" />
                <div>
                    <div className="text-xs text-slate-400">Total Assets</div>
                    <div className="font-bold">{assets.length}</div>
                </div>
             </div>
        </div>
      </header>

      <main>
        <div className="mb-6">
            <h2 className="text-xl font-semibold mb-4 text-slate-300">Collection Area Map</h2>
            {collectionDesks.length === 0 ? (
              <div className="text-center py-12 text-slate-500">
                No desks found. Initialize desk master from mobile app.
              </div>
            ) : (
              <div className="grid grid-cols-10 gap-2">
                  {collectionDesks.map(desk => (
                      <div 
                          key={desk.id}
                          className={clsx(
                              "aspect-square rounded-md border flex flex-col items-center justify-center transition-all cursor-pointer hover:scale-105",
                              desk.status === 'EMPTY' ? "bg-slate-800/50 border-slate-700 text-slate-500" :
                              desk.status === 'OCCUPIED' ? "bg-blue-900/30 border-blue-500 text-blue-300" :
                              "bg-red-900/30 border-red-500 text-red-300"
                          )}
                          title={`Desk: ${desk.id}`}
                      >
                          <span className="text-xs font-mono">{desk.number}</span>
                          {desk.status === 'OCCUPIED' && <Monitor size={12} />}
                      </div>
                  ))}
              </div>
            )}
        </div>
      </main>
    </div>
  );
};
