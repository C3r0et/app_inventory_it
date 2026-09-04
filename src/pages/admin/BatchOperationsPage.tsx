import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { useStore } from '../../store/assetStore';
import { BulkStatusModal } from '../../components/BulkStatusModal';
import { BulkLocationModal } from '../../components/BulkLocationModal';
import type { Asset } from '../../types';

export const BatchOperationsPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { fetchAssets, fetchDesks, baselineAudit } = useStore();
  const [showAuditForm, setShowAuditForm] = useState(false);
  const [showBulkStatusModal, setShowBulkStatusModal] = useState(false);
  const [showBulkLocationModal, setShowBulkLocationModal] = useState(false);

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  const handleAudit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const assetTypes: Asset['type'][] = [];
    if (formData.get('pc')) assetTypes.push('PC');
    if (formData.get('monitor')) assetTypes.push('MONITOR');
    if (formData.get('keyboard')) assetTypes.push('KEYBOARD');
    if (formData.get('mouse')) assetTypes.push('MOUSE');
    if (formData.get('headset')) assetTypes.push('HEADSET');

    await baselineAudit(
      Number(formData.get('deskNumber')),
      formData.get('area') as string,
      assetTypes
    );
    setShowAuditForm(false);
    fetchAssets();
    fetchDesks();
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Batch Operations</h1>
        <p className="text-slate-400">Perform bulk operations on assets and desks</p>
      </div>

      <div className="grid grid-cols-2 gap-6">
        <button
          onClick={() => setShowAuditForm(true)}
          className="bg-slate-800 hover:bg-slate-700 p-8 rounded-lg border border-slate-700 transition text-left"
        >
          <h3 className="text-xl font-semibold mb-2">Baseline Audit</h3>
          <p className="text-slate-400">Batch create assets for a specific desk</p>
        </button>

        <div className="bg-slate-800 p-8 rounded-lg border border-slate-700 opacity-50">
          <h3 className="text-xl font-semibold mb-2">CSV Import</h3>
          <p className="text-slate-400">Import assets from CSV file (Coming Soon)</p>
        </div>

        <button
          onClick={() => setShowBulkStatusModal(true)}
          className="bg-slate-800 hover:bg-slate-700 p-8 rounded-lg border border-slate-700 transition text-left"
        >
          <h3 className="text-xl font-semibold mb-2">Bulk Status Update</h3>
          <p className="text-slate-400">Update status for multiple assets at once</p>
        </button>

        <button
          onClick={() => setShowBulkLocationModal(true)}
          className="bg-slate-800 hover:bg-slate-700 p-8 rounded-lg border border-slate-700 transition text-left"
        >
          <h3 className="text-xl font-semibold mb-2">Bulk Location Transfer</h3>
          <p className="text-slate-400">Transfer multiple assets to new location</p>
        </button>
      </div>

      {/* Audit Modal */}
      {showAuditForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Baseline Audit</h3>
            <form onSubmit={handleAudit} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Desk Number</label>
                <input
                  type="number"
                  name="deskNumber"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Area</label>
                <input
                  type="text"
                  name="area"
                  defaultValue="COLLECTION"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Asset Types</label>
                <div className="space-y-2">
                  {['pc', 'monitor', 'keyboard', 'mouse', 'headset'].map((type) => (
                    <label key={type} className="flex items-center gap-2">
                      <input type="checkbox" name={type} defaultChecked={type !== 'headset'} />
                      <span className="capitalize">{type}</span>
                    </label>
                  ))}
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-green-600 hover:bg-green-500 py-2 rounded transition"
                >
                  Create Assets
                </button>
                <button
                  type="button"
                  onClick={() => setShowAuditForm(false)}
                  className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Bulk Status Modal */}
      <BulkStatusModal
        show={showBulkStatusModal}
        onClose={() => setShowBulkStatusModal(false)}
        onSuccess={() => fetchAssets()}
      />

      {/* Bulk Location Modal */}
      <BulkLocationModal
        show={showBulkLocationModal}
        onClose={() => setShowBulkLocationModal(false)}
        onSuccess={() => fetchAssets()}
      />
    </div>
  );
};
