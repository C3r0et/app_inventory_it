import { useState } from 'react';
import { X, Upload, Download, CheckCircle, AlertCircle } from 'lucide-react';
import { API_BASE_URL } from '../services/apiClient';

interface BulkImportModalProps {
  show: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

interface ImportResult {
  success_count: number;
  error_count: number;
  errors: Array<{
    row: number;
    asset_id: string;
    error: string;
  }>;
}

export const BulkImportModal = ({ show, onClose, onSuccess }: BulkImportModalProps) => {
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [dragActive, setDragActive] = useState(false);

  if (!show) return null;

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      const droppedFile = e.dataTransfer.files[0];
      if (droppedFile.name.endsWith('.xlsx') || droppedFile.name.endsWith('.xls')) {
        setFile(droppedFile);
      } else {
        alert('Please upload an Excel file (.xlsx or .xls)');
      }
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0]);
    }
  };

  const handleDownloadTemplate = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/assets/bulk-import/template`);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'asset_import_template.xlsx';
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Failed to download template:', error);
      alert('Failed to download template');
    }
  };

  const handleUpload = async () => {
    if (!file) return;

    setUploading(true);
    setResult(null);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await fetch(`${API_BASE_URL}/api/assets/bulk-import`, {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        throw new Error('Upload failed');
      }

      const data: ImportResult = await response.json();
      setResult(data);

      if (data.success_count > 0) {
        onSuccess();
      }
    } catch (error) {
      console.error('Upload error:', error);
      alert('Failed to upload file');
    } finally {
      setUploading(false);
    }
  };

  const handleClose = () => {
    setFile(null);
    setResult(null);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-800 rounded-lg p-6 max-w-2xl w-full border border-slate-700">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-xl font-semibold">Bulk Import Assets</h3>
          <button onClick={handleClose} className="p-1 hover:bg-slate-700 rounded">
            <X size={20} />
          </button>
        </div>

        {!result ? (
          <>
            {/* Download Template Button */}
            <div className="mb-6">
              <button
                onClick={handleDownloadTemplate}
                className="w-full px-4 py-3 bg-blue-600 hover:bg-blue-500 rounded-lg transition flex items-center justify-center gap-2"
              >
                <Download size={20} />
                Download Excel Template
              </button>
              <p className="text-sm text-slate-400 mt-2 text-center">
                Download the template, fill it with your asset data, then upload it below
              </p>
            </div>

            {/* File Upload Area */}
            <div
              className={`border-2 border-dashed rounded-lg p-8 text-center transition ${
                dragActive
                  ? 'border-blue-500 bg-blue-500/10'
                  : 'border-slate-600 hover:border-slate-500'
              }`}
              onDragEnter={handleDrag}
              onDragLeave={handleDrag}
              onDragOver={handleDrag}
              onDrop={handleDrop}
            >
              <Upload size={48} className="mx-auto mb-4 text-slate-400" />
              <p className="text-lg mb-2">
                {file ? file.name : 'Drag and drop your Excel file here'}
              </p>
              <p className="text-sm text-slate-400 mb-4">or</p>
              <label className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded-lg cursor-pointer inline-block transition">
                Browse Files
                <input
                  type="file"
                  accept=".xlsx,.xls"
                  onChange={handleFileChange}
                  className="hidden"
                />
              </label>
            </div>

            {/* Upload Button */}
            {file && (
              <div className="mt-6 flex gap-2">
                <button
                  onClick={handleUpload}
                  disabled={uploading}
                  className="flex-1 px-4 py-2 bg-green-600 hover:bg-green-500 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {uploading ? 'Uploading...' : 'Upload and Import'}
                </button>
                <button
                  onClick={() => setFile(null)}
                  className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition"
                >
                  Clear
                </button>
              </div>
            )}
          </>
        ) : (
          <>
            {/* Import Results */}
            <div className="space-y-4">
              <div className="flex items-center gap-3 p-4 bg-green-900/20 border border-green-700 rounded-lg">
                <CheckCircle size={24} className="text-green-400" />
                <div>
                  <p className="font-semibold text-green-400">
                    {result.success_count} assets imported successfully
                  </p>
                </div>
              </div>

              {result.error_count > 0 && (
                <div className="p-4 bg-red-900/20 border border-red-700 rounded-lg">
                  <div className="flex items-center gap-3 mb-3">
                    <AlertCircle size={24} className="text-red-400" />
                    <p className="font-semibold text-red-400">
                      {result.error_count} rows failed validation
                    </p>
                  </div>
                  <div className="max-h-60 overflow-y-auto space-y-2">
                    {result.errors.map((error, index) => (
                      <div key={index} className="text-sm bg-slate-900/50 p-2 rounded">
                        <span className="font-mono text-red-300">Row {error.row}</span>
                        {error.asset_id && (
                          <span className="text-slate-400"> ({error.asset_id})</span>
                        )}
                        : {error.error}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="flex gap-2">
                <button
                  onClick={handleClose}
                  className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition"
                >
                  Done
                </button>
                <button
                  onClick={() => {
                    setFile(null);
                    setResult(null);
                  }}
                  className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded-lg transition"
                >
                  Import More
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};
