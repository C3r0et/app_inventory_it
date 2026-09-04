import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { API_BASE_URL } from '../../services/apiClient';
import { useAuthStore } from '../../store/authStore';
import { useStore } from '../../store/assetStore';
import { Printer, Save, Check } from 'lucide-react';

interface PreviewAsset {
  id: string;
  type: string;
  status: string;
  location: string;
  specs: string;
}

export const QRGeneratorPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { assets, fetchAssets } = useStore();
  const printRef = useRef<HTMLDivElement>(null);

  const [formData, setFormData] = useState({
    assetType: 'PC',
    quantity: 12,
  });

  const [qrCodes, setQrCodes] = useState<string[]>([]);
  const [previewAssets, setPreviewAssets] = useState<PreviewAsset[]>([]);
  const [isSaved, setIsSaved] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [nextNumber, setNextNumber] = useState(1);

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchAssets();
  }, [isAuthenticated, navigate, fetchAssets]);

  // Calculate next number based on existing assets
  useEffect(() => {
    if (assets.length === 0) {
      setNextNumber(1);
      return;
    }

    // Filter assets by selected type and find the highest number
    const typeAssets = assets.filter(asset => 
      asset.id.startsWith(formData.assetType + '-')
    );

    if (typeAssets.length === 0) {
      setNextNumber(1);
      return;
    }

    const numbers = typeAssets.map(asset => {
      const match = asset.id.match(/-(\d+)$/);
      return match ? parseInt(match[1], 10) : 0;
    });

    const maxNumber = Math.max(...numbers);
    setNextNumber(maxNumber + 1);
  }, [assets, formData.assetType]);

  const generateAssetIds = () => {
    const ids: string[] = [];
    for (let i = 0; i < formData.quantity; i++) {
      const assetNumber = nextNumber + i;
      const paddedNumber = String(assetNumber).padStart(3, '0');
      ids.push(`${formData.assetType}-${paddedNumber}`);
    }
    return ids;
  };

  const handlePreview = () => {
    const ids = generateAssetIds();
    const assets: PreviewAsset[] = ids.map(id => ({
      id,
      type: formData.assetType,
      status: 'AVAILABLE',
      location: '',
      specs: '',
    }));
    setPreviewAssets(assets);
    setQrCodes(ids);
    setIsSaved(false);
  };

  const handleSaveToDatabase = async () => {
    if (isSaved || isSaving) return;
    
    setIsSaving(true);
    try {
      const response = await fetch(`${API_BASE_URL}/api/assets/bulk-create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ assets: previewAssets }),
      });
      
      if (!response.ok) throw new Error('Failed to save assets');
      
      const result = await response.json();
      setIsSaved(true);
      toast.success(`✅ ${result.success_count} assets saved to database!`);
      fetchAssets(); // Refresh asset list
    } catch (error) {
      toast.error('❌ Failed to save assets to database');
    } finally {
      setIsSaving(false);
    }
  };

  const handlePrint = () => {
    window.print();
  };

  const getQRCodeUrl = (assetId: string) => {
    // Using QR Server API with high error correction and optimal size
    return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&ecc=H&data=${encodeURIComponent(assetId)}`;
  };

  const endNumber = nextNumber + formData.quantity - 1;

  return (
    <>
      {/* Screen View */}
      <div className="p-6 print:hidden">
        <div className="mb-6">
          <h1 className="text-3xl font-bold mb-2">QR Code Generator</h1>
          <p className="text-slate-400">Generate printable QR code stickers for assets</p>
        </div>

        <div className="grid grid-cols-2 gap-6">
          {/* Form */}
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
            <h2 className="text-xl font-semibold mb-4">Generator Settings</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Asset Type</label>
                <select
                  value={formData.assetType}
                  onChange={(e) => setFormData({ ...formData, assetType: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                >
                  <option value="PC">PC</option>
                  <option value="LAPTOP">Laptop</option>
                  <option value="MONITOR">Monitor</option>
                  <option value="KEYBOARD">Keyboard</option>
                  <option value="MOUSE">Mouse</option>
                  <option value="HEADSET">Headset</option>
                </select>
              </div>

              <div>
                <label className="block text-sm mb-2">Quantity (How many QR codes?)</label>
                <input
                  type="number"
                  value={formData.quantity}
                  onChange={(e) => setFormData({ ...formData, quantity: Number(e.target.value) })}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  min={1}
                  max={100}
                />
              </div>

              <div className="pt-2">
                <div className="bg-slate-900 p-3 rounded mb-4">
                  <div className="text-sm text-slate-400 mb-1">Next available number:</div>
                  <div className="text-lg font-bold text-green-400">{nextNumber}</div>
                </div>
                <div className="text-sm text-slate-400 mb-4">
                  Will generate: <span className="font-bold text-white">{formData.quantity}</span> QR codes
                  <br />
                  Range: <span className="font-mono text-blue-400">{formData.assetType}-{String(nextNumber).padStart(3, '0')}</span> to <span className="font-mono text-blue-400">{formData.assetType}-{String(endNumber).padStart(3, '0')}</span>
                </div>
                <button
                  onClick={handlePreview}
                  className="w-full px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded transition"
                >
                  Preview QR Codes
                </button>
              </div>
            </div>
          </div>

          {/* Preview */}
          <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold">Preview</h2>
              {qrCodes.length > 0 && (
                <div className="flex gap-2">
                  <button
                    onClick={handlePrint}
                    className="px-4 py-2 bg-green-600 hover:bg-green-500 rounded transition flex items-center gap-2"
                  >
                    <Printer size={18} />
                    Print Stickers
                  </button>
                  <button
                    onClick={handleSaveToDatabase}
                    disabled={isSaved || isSaving}
                    className={`px-4 py-2 rounded transition flex items-center gap-2 ${
                      isSaved
                        ? 'bg-gray-600 cursor-not-allowed'
                        : isSaving
                        ? 'bg-blue-400 cursor-wait'
                        : 'bg-blue-600 hover:bg-blue-500'
                    }`}
                  >
                    {isSaved ? (
                      <>
                        <Check size={18} />
                        Saved to Database
                      </>
                    ) : (
                      <>
                        <Save size={18} />
                        {isSaving ? 'Saving...' : 'Save to Database'}
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>

            {qrCodes.length === 0 ? (
              <div className="text-center py-12 text-slate-400">
                <p>No QR codes generated yet</p>
                <p className="text-sm mt-2">Configure settings and click "Preview QR Codes" to start</p>
              </div>
            ) : (
              <>
                {/* Preview Table */}
                <div className="mb-6 max-h-96 overflow-y-auto">
                  <table className="w-full">
                    <thead className="bg-slate-900 sticky top-0">
                      <tr>
                        <th className="px-4 py-2 text-left">#</th>
                        <th className="px-4 py-2 text-left">Asset ID</th>
                        <th className="px-4 py-2 text-left">Type</th>
                        <th className="px-4 py-2 text-left">QR Code</th>
                        <th className="px-4 py-2 text-left">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {previewAssets.map((asset, index) => (
                        <tr key={asset.id} className="border-t border-slate-700 hover:bg-slate-750">
                          <td className="px-4 py-2">{index + 1}</td>
                          <td className="px-4 py-2 font-mono text-blue-400">{asset.id}</td>
                          <td className="px-4 py-2">{asset.type}</td>
                          <td className="px-4 py-2">
                            <img 
                              src={getQRCodeUrl(asset.id)} 
                              alt={asset.id}
                              className="w-12 h-12"
                            />
                          </td>
                          <td className="px-4 py-2">
                            <span className={`px-2 py-1 rounded text-xs ${
                              isSaved 
                                ? 'bg-green-900 text-green-300' 
                                : 'bg-yellow-900 text-yellow-300'
                            }`}>
                              {isSaved ? 'Saved' : 'Pending'}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* QR Grid for Printing */}
                <div className="grid grid-cols-3 gap-4">
                  {qrCodes.map((assetId) => (
                    <div key={assetId} className="border border-slate-600 rounded p-3 text-center">
                      <img 
                        src={getQRCodeUrl(assetId)} 
                        alt={assetId}
                        className="w-full h-auto mb-2"
                      />
                      <div className="text-xs font-mono">{assetId}</div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Print View */}
      <div ref={printRef} className="hidden print:block">
        <style>{`
          @media print {
            @page {
              size: A4;
              margin: 1cm;
            }
            html, body {
              width: 210mm;
              height: 297mm;
              margin: 0 !important;
              padding: 0 !important;
              background: white !important;
            }
            body * {
              visibility: hidden;
            }
            #print-area, #print-area * {
              visibility: visible;
            }
            #print-area {
              position: absolute;
              left: 0;
              top: 0;
              width: 100%;
            }
            .sticker-page {
              width: 210mm;
              height: 297mm; /* A4 height */
              page-break-after: always;
              display: grid;
              grid-template-columns: repeat(3, 1fr);
              grid-template-rows: repeat(4, 1fr);
              gap: 10mm;
              padding: 15mm;
              box-sizing: border-box;
            }
            .sticker-page:last-child {
              page-break-after: auto;
            }
            .sticker-item {
              border: 2px dashed #000 !important;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              padding: 10px;
              height: 100%;
              width: 100%;
              box-sizing: border-box;
              background: white !important;
            }
            img {
              width: 100% !important;
              height: auto !important;
              max-width: 120px !important;
              display: block !important;
            }
          }
        `}</style>

        {qrCodes.length > 0 && (
          <div id="print-area">
            {Array.from({ length: Math.ceil(qrCodes.length / 12) }, (_, pageIndex) => (
              <div key={pageIndex} className="sticker-page">
                {qrCodes.slice(pageIndex * 12, (pageIndex + 1) * 12).map((id) => (
                  <div key={id} className="sticker-item">
                    <img 
                      src={getQRCodeUrl(id)} 
                      alt={id}
                    />
                    <div style={{ 
                      fontSize: '16pt', 
                      fontFamily: 'monospace', 
                      fontWeight: 'bold',
                      marginTop: '10px',
                      color: 'black' 
                    }}>
                      {id}
                    </div>
                  </div>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
};
