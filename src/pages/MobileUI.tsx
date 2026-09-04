import { useState } from 'react';
import { Scan, Search, Box, CheckCircle, AlertTriangle } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useStore } from '../store/assetStore';
import type { Asset } from '../types';
import { clsx } from 'clsx';

export const MobileUI = () => {
    const [scannedId, setScannedId] = useState('');
    const [activeAsset, setActiveAsset] = useState<Asset | null>(null);
    const { assets } = useStore();

    const handleScan = (id: string) => {
        setScannedId(id);
        const found = assets.find(a => a.id === id);
        if (found) {
            setActiveAsset(found);
        } else {
            setActiveAsset(null);
        }
    };

    return (
        <div className="min-h-screen bg-black text-white p-4 flex flex-col font-sans">
            {/* Header */}
            <div className="flex justify-between items-center mb-6">
                <div className="font-bold text-lg bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500">
                    AssetScanner
                </div>
                <Link to="/dashboard" className="text-xs text-slate-500">Dashboard</Link>
            </div>

            {!activeAsset ? (
                <>
                    {/* Scan Mode */}
                    <div className="flex-1 flex flex-col justify-center items-center space-y-8">
                        <div className="relative group cursor-pointer" onClick={() => handleScan('CPU-031')}>
                            <div className="absolute -inset-1 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full blur opacity-50 group-hover:opacity-100 transition duration-1000"></div>
                            <div className="relative w-32 h-32 bg-slate-900 rounded-full flex items-center justify-center border border-slate-700">
                                <Scan size={48} className="text-white" />
                            </div>
                        </div>
                        <div className="text-center">
                            <h2 className="text-xl font-bold mb-2">Tap to Scan</h2>
                            <p className="text-slate-500 text-sm">Point camera at QR Code</p>
                        </div>

                        {/* Manual Input Simulation */}
                        <div className="w-full max-w-xs relative mt-8">
                            <input
                                type="text"
                                placeholder="Enter Asset ID manually..."
                                className="w-full bg-slate-900 border border-slate-700 rounded-xl py-3 px-4 pl-10 text-white focus:outline-none focus:border-blue-500 transition-colors"
                                value={scannedId}
                                onChange={(e) => handleScan(e.target.value)}
                            />
                            <Search size={18} className="absolute left-3 top-3.5 text-slate-500" />
                        </div>
                    </div>
                </>
            ) : (
                <>
                    {/* Asset Detail View */}
                    <div className="flex-1 animate-in fade-in slide-in-from-bottom-4 duration-300">
                        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-2xl relative overflow-hidden">
                             <div className={`absolute top-0 left-0 w-1 h-full ${
                                 activeAsset.status === 'AVAILABLE' ? 'bg-green-500' : 
                                 activeAsset.status === 'BROKEN' ? 'bg-red-500' : 'bg-blue-500'
                             }`} />

                            <div className="flex justify-between items-start mb-4">
                                <div>
                                    <div className="text-xs text-slate-400 uppercase tracking-wider mb-1">Asset ID</div>
                                    <div className="text-3xl font-mono font-bold text-white">{activeAsset.id}</div>
                                </div>
                                <div className={clsx(
                                    "px-3 py-1 rounded-full text-xs font-bold border",
                                    activeAsset.status === 'AVAILABLE' ? "bg-green-900/30 border-green-500/50 text-green-400" :
                                    activeAsset.status === 'BROKEN' ? "bg-red-900/30 border-red-500/50 text-red-400" :
                                    "bg-blue-900/30 border-blue-500/50 text-blue-400"
                                )}>
                                    {activeAsset.status}
                                </div>
                            </div>

                            <div className="space-y-4">
                                <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 flex items-center gap-4">
                                    <Box className="text-slate-400" />
                                    <div>
                                        <div className="text-xs text-slate-500">Type</div>
                                        <div className="font-semibold">{activeAsset.type}</div>
                                    </div>
                                </div>
                                 <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 flex items-center gap-4">
                                    <div className="text-xs text-slate-500">Location</div>
                                    <div className="font-semibold">{activeAsset.location}</div>
                                </div>
                                {activeAsset.specs && (
                                    <div className="text-sm text-slate-400 mt-2">
                                        Specs: {activeAsset.specs}
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* Context Actions */}
                        <div className="mt-6 grid grid-cols-2 gap-4">
                            <button className="bg-blue-600 hover:bg-blue-500 text-white p-4 rounded-xl font-bold flex flex-col items-center gap-2 transition-all">
                                <CheckCircle size={24} />
                                <span>Check In/Out</span>
                            </button>
                             <button className="bg-slate-800 hover:bg-slate-700 text-white p-4 rounded-xl font-bold flex flex-col items-center gap-2 transition-all border border-slate-700">
                                <AlertTriangle size={24} className="text-yellow-500" />
                                <span>Report Issue</span>
                            </button>
                        </div>

                         <button 
                            onClick={() => { setActiveAsset(null); setScannedId(''); }}
                            className="mt-8 w-full py-4 text-slate-500 hover:text-white transition-colors flex items-center justify-center gap-2"
                        >
                            <Scan size={16} /> Scan Next
                        </button>
                    </div>
                </>
            )}
        </div>
    );
};
