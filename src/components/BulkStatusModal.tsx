import { useState } from 'react';
import { X, AlertCircle, CheckCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { API_BASE_URL } from '../services/apiClient';

interface BulkStatusModalProps {
  show: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

interface BulkResult {
  success_count: number;
  failed_count: number;
  failed_ids?: string[];
  message: string;
}

export const BulkStatusModal = ({ show, onClose, onSuccess }: BulkStatusModalProps) => {

  const [assetIds, setAssetIds] = useState('');
  const [newStatus, setNewStatus] = useState('AVAILABLE');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<BulkResult | null>(null);

  if (!show) return null;

  const parseAssetIds = (): string[] => {
    return assetIds
      .split('\n')
      .map(id => id.trim())
      .filter(id => id.length > 0);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setResult(null);

    const ids = parseAssetIds();
    if (ids.length === 0) {
      toast.error('Please enter at least one Asset ID');
      setLoading(false);
      return;
    }

    try {
      const response = await fetch(`${API_BASE_URL}/api/assets/bulk-status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          asset_ids: ids,
          new_status: newStatus,
        }),
      });

      if (!response.ok) throw new Error('Bulk update failed');

      const data: BulkResult = await response.json();
      setResult(data);

      if (data.success_count > 0) {
        toast.success(`${data.success_count} asset(s) updated successfully`);
        onSuccess();
      }
      if (data.failed_count > 0) {
        toast(`${data.failed_count} asset(s) failed to update`, { icon: '⚠️' });
      }
    } catch (error) {
      console.error('Bulk status update error:', error);
      toast.error('Failed to update assets');
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setAssetIds('');
    setNewStatus('AVAILABLE');
    setResult(null);
    onClose();
  };

  const assetCount = parseAssetIds().length;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-800 rounded-lg p-6 max-w-2xl w-full border border-slate-700 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-xl font-semibold">Bulk Status Update</h3>
          <button onClick={handleClose} className="p-1 hover:bg-slate-700 rounded">
            <X size={20} />
          </button>
        </div>

        {!result ? (
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Asset IDs Input */}
            <div>
              <label className="block text-sm font-medium mb-2">
                Asset IDs (one per line)
              </label>
              <textarea
                value={assetIds}
                onChange={(e) => setAssetIds(e.target.value)}
                placeholder="CPU-001&#10;CPU-002&#10;CPU-003&#10;..."
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded h-40 font-mono text-sm"
                required
              />
              <p className="text-xs text-slate-400 mt-1">
                {assetCount} asset{assetCount !== 1 ? 's' : ''} will be updated
              </p>
            </div>

            {/* Status Selector */}
            <div>
              <label className="block text-sm font-medium mb-2">
                New Status
              </label>
              <select
                value={newStatus}
                onChange={(e) => setNewStatus(e.target.value)}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
              >
                <option value="AVAILABLE">AVAILABLE</option>
                <option value="IN_USE">IN USE</option>
                <option value="BROKEN">BROKEN</option>
                <option value="GHOST">GHOST</option>
              </select>
            </div>

            {/* Preview */}
            <div className="p-3 bg-blue-900/20 border border-blue-700 rounded">
              <p className="text-sm text-blue-300">
                ℹ️ {assetCount} asset{assetCount !== 1 ? 's' : ''} will be updated to <strong>{newStatus}</strong>
              </p>
            </div>

            {/* Actions */}
            <div className="flex gap-2">
              <button
                type="submit"
                disabled={loading || assetCount === 0}
                className="flex-1 px-4 py-2 bg-green-600 hover:bg-green-500 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Updating...' : 'Update Assets'}
              </button>
              <button
                type="button"
                onClick={handleClose}
                className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition"
              >
                Cancel
              </button>
            </div>
          </form>
        ) : (
          <div className="space-y-4">
            {/* Success Message */}
            {result.success_count > 0 && (
              <div className="flex items-center gap-3 p-4 bg-green-900/20 border border-green-700 rounded-lg">
                <CheckCircle size={24} className="text-green-400" />
                <div>
                  <p className="font-semibold text-green-400">
                    {result.success_count} asset{result.success_count !== 1 ? 's' : ''} updated successfully
                  </p>
                  <p className="text-sm text-slate-300">{result.message}</p>
                </div>
              </div>
            )}

            {/* Failed Assets */}
            {result.failed_count > 0 && result.failed_ids && (
              <div className="p-4 bg-red-900/20 border border-red-700 rounded-lg">
                <div className="flex items-center gap-3 mb-3">
                  <AlertCircle size={24} className="text-red-400" />
                  <p className="font-semibold text-red-400">
                    {result.failed_count} asset{result.failed_count !== 1 ? 's' : ''} failed to update
                  </p>
                </div>
                <div className="max-h-40 overflow-y-auto space-y-1">
                  {result.failed_ids.map((id, index) => (
                    <div key={index} className="text-sm bg-slate-900/50 p-2 rounded font-mono">
                      {id} - Not found or update failed
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Actions */}
            <div className="flex gap-2">
              <button
                onClick={handleClose}
                className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition"
              >
                Done
              </button>
              <button
                onClick={() => {
                  setAssetIds('');
                  setResult(null);
                }}
                className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition"
              >
                Update More
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
