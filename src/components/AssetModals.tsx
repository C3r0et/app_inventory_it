import { useState, useEffect, useRef } from 'react';
import { X, Upload, Image, ChevronDown, ChevronUp, Check, ExternalLink } from 'lucide-react';
import { useCategoryStore } from '../store/categoryStore';
import type { Asset } from '../types';
import { API_BASE_URL } from '../services/apiClient';
import toast from 'react-hot-toast';

const BRANDS = ['Logitech', 'Votre', 'HP', 'Lenovo', 'Dell', 'Asus', 'LG', 'Simbadda', 'Lainnya'];

const ASSET_TYPES = [
  { id: 'PC', label: 'PC / CPU' },
  { id: 'LAPTOP', label: 'Laptop' },
  { id: 'MONITOR', label: 'Monitor' },
  { id: 'KEYBOARD', label: 'Keyboard' },
  { id: 'MOUSE', label: 'Mouse' },
  { id: 'HEADSET', label: 'Headset' },
  { id: 'LAINNYA', label: 'Lainnya' },
];

const REPAIR_PRESETS = [
  'RAM Tidak Terdeteksi',
  'No Display',
  'Mati Nyala',
  'Socket Rusak',
  'Kabel Putus',
  'Tombol Macet/Rusak',
  'Layar Rusak',
  'Baterai Drop',
  'OS Corrupt/Install Ulang',
];

// Modern, layman-friendly Asset Form Modal
const AssetFormModal = ({ 
  show, 
  onClose, 
  onSubmit, 
  title, 
  asset 
}: { 
  show: boolean; 
  onClose: () => void; 
  onSubmit: (e: React.FormEvent<HTMLFormElement>) => void; 
  title: string; 
  asset?: Asset | null;
}) => {
  const { categories, fetchCategories } = useCategoryStore();

  // Primary fields
  const [assetType, setAssetType] = useState<string>('PC');
  const [brand, setBrand] = useState<string>('Logitech');
  const [customBrand, setCustomBrand] = useState<string>('');
  const [status, setStatus] = useState<string>('AVAILABLE');
  const [locationType, setLocationType] = useState<string>('Ruang IT');
  const [deskNumber, setDeskNumber] = useState<string>('');
  const [note, setNote] = useState<string>('');
  const [additionalSpecs, setAdditionalSpecs] = useState<string>('');
  const [imagePaths, setImagePaths] = useState<string[]>([]);
  const [isUploadingImage, setIsUploadingImage] = useState<boolean>(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Advanced / Optional technical fields
  const [showAdvanced, setShowAdvanced] = useState<boolean>(false);
  const [selectedCategory, setSelectedCategory] = useState<number | null>(null);
  const [serialNumber, setSerialNumber] = useState<string>('');
  const [warrantyDate, setWarrantyDate] = useState<string>('');
  const [legacyInvCode, setLegacyInvCode] = useState<string>('');

  useEffect(() => {
    if (show) {
      fetchCategories();
    }
  }, [show, fetchCategories]);

  useEffect(() => {
    if (asset) {
      setAssetType(asset.type || 'PC');
      setStatus(asset.status || 'AVAILABLE');
      setNote(asset.note || '');
      setSerialNumber(asset.serial_number || '');
      setWarrantyDate(asset.warranty_date ? asset.warranty_date.substring(0, 10) : '');
      setLegacyInvCode(asset.legacy_inv_code || '');
      setSelectedCategory(asset.category_id || null);

      // Parse Location
      if (asset.location) {
        if (asset.location.startsWith('Floor')) {
          const parts = asset.location.split(' - Meja ');
          setLocationType(parts[0]);
          setDeskNumber(parts.length > 1 ? parts[1] : '');
        } else {
          setLocationType(asset.location);
          setDeskNumber('');
        }
      } else {
        setLocationType('Ruang IT');
        setDeskNumber('');
      }

      // Parse Brand & Specs
      const dbSpecs = asset.specs || '';
      if (dbSpecs.startsWith('Merk: ')) {
        const parts = dbSpecs.split('|');
        const possibleBrand = parts[0].replace('Merk: ', '').trim();
        if (BRANDS.includes(possibleBrand)) {
          setBrand(possibleBrand);
          setCustomBrand('');
        } else {
          setBrand('Lainnya');
          setCustomBrand(possibleBrand);
        }
        setAdditionalSpecs(parts.length > 1 ? parts.slice(1).join('|').trim() : '');
      } else {
        setBrand('Logitech');
        setCustomBrand('');
        setAdditionalSpecs(dbSpecs);
      }

      // Parse Images
      if (asset.image_path) {
        setImagePaths(asset.image_path.split(',').map((p) => p.trim()).filter(Boolean));
      } else {
        setImagePaths([]);
      }
    } else {
      // Defaults for Create Mode
      setAssetType('PC');
      setBrand('Logitech');
      setCustomBrand('');
      setStatus('AVAILABLE');
      setLocationType('Ruang IT');
      setDeskNumber('');
      setNote('');
      setAdditionalSpecs('');
      setImagePaths([]);
      setSerialNumber('');
      setWarrantyDate('');
      setLegacyInvCode('');
      setSelectedCategory(null);
    }
  }, [asset, show]);

  // Handle uploading photo from PC to /api/upload
  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    setIsUploadingImage(true);
    try {
      const res = await fetch(`${API_BASE_URL}/api/upload`, {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) throw new Error('Gagal mengunggah foto');
      const data = await res.json();
      const uploadedPath = data.path || data.url || data.filePath;

      if (uploadedPath) {
        setImagePaths((prev) => [...prev, uploadedPath]);
        toast.success('Foto berhasil diunggah!');
      }
    } catch (err) {
      console.error('Image upload failed:', err);
      toast.error('Gagal mengunggah gambar ke server');
    } finally {
      setIsUploadingImage(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const removeImage = (indexToRemove: number) => {
    setImagePaths((prev) => prev.filter((_, idx) => idx !== indexToRemove));
  };

  if (!show) return null;

  // Compute merged location & specs
  const computedLocation = locationType === 'Ruang IT'
    ? locationType
    : deskNumber.trim()
    ? `${locationType} - Meja ${deskNumber.trim()}`
    : locationType;

  const finalBrand = brand === 'Lainnya' && customBrand.trim() ? customBrand.trim() : brand;
  const computedSpecs = additionalSpecs.trim()
    ? `Merk: ${finalBrand} | ${additionalSpecs.trim()}`
    : `Merk: ${finalBrand}`;

  const computedImagePath = imagePaths.join(',');

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
      <div className="bg-slate-800 rounded-3xl p-6 md:p-7 max-w-2xl w-full border border-slate-700 shadow-2xl max-h-[90vh] overflow-y-auto space-y-5">
        {/* Header */}
        <div className="flex justify-between items-center border-b border-slate-700 pb-4">
          <div>
            <div className="flex items-center gap-2.5">
              <h3 className="text-xl font-extrabold text-white tracking-tight">{title}</h3>
              {asset?.id && (
                <span className="font-mono text-xs font-bold px-2 py-0.5 rounded bg-blue-950 text-blue-300 border border-blue-800">
                  {asset.id}
                </span>
              )}
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              Kelola data aset, status, lokasi, merk, dan dokumentasi foto fisik.
            </p>
          </div>
          <button 
            onClick={onClose} 
            className="p-1.5 hover:bg-slate-700 rounded-xl text-slate-400 hover:text-white transition"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={onSubmit} className="space-y-5">
          {/* Hidden inputs to pass data seamlessly to existing onSubmit handler */}
          <input type="hidden" name="type" value={assetType} />
          <input type="hidden" name="status" value={status} />
          <input type="hidden" name="location" value={computedLocation} />
          <input type="hidden" name="specs" value={computedSpecs} />
          <input type="hidden" name="note" value={note} />
          <input type="hidden" name="image_path" value={computedImagePath} />
          <input type="hidden" name="serial_number" value={serialNumber} />
          <input type="hidden" name="warranty_date" value={warrantyDate} />
          <input type="hidden" name="legacy_inv_code" value={legacyInvCode} />
          <input type="hidden" name="category_id" value={selectedCategory || ''} />

          {/* Asset ID Field (Only if Creating New) */}
          {!asset && (
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Nomor ID Aset *
              </label>
              <input
                type="text"
                name="id"
                required
                placeholder="Contoh: MS-1126, KB-0700, PC-1303"
                className="w-full px-4 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sm font-mono text-white focus:outline-none focus:border-blue-500 transition"
              />
            </div>
          )}

          {/* 1. Tipe Perangkat (Chip selector) */}
          <div>
            <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-2">
              Jenis Perangkat Aset
            </label>
            <div className="grid grid-cols-4 sm:grid-cols-7 gap-2">
              {ASSET_TYPES.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setAssetType(t.id)}
                  className={`py-2 px-1 rounded-xl text-xs font-semibold border transition text-center ${
                    assetType === t.id
                      ? 'bg-blue-600 text-white border-blue-500 shadow-md shadow-blue-600/30'
                      : 'bg-slate-900 text-slate-400 border-slate-700 hover:text-white hover:border-slate-600'
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          {/* 2. Brand / Merk Selector (Aligned with Android) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Merk / Brand Populer
              </label>
              <select
                value={brand}
                onChange={(e) => setBrand(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-blue-500 transition"
              >
                {BRANDS.map((b) => (
                  <option key={b} value={b}>{b}</option>
                ))}
              </select>
            </div>

            {brand === 'Lainnya' ? (
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Tulis Merk Khusus
                </label>
                <input
                  type="text"
                  value={customBrand}
                  onChange={(e) => setCustomBrand(e.target.value)}
                  placeholder="Contoh: Armaggeddon, Fantech, Rexus"
                  className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-blue-500 transition"
                />
              </div>
            ) : (
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Spesifikasi Singkat (Opsional)
                </label>
                <input
                  type="text"
                  value={additionalSpecs}
                  onChange={(e) => setAdditionalSpecs(e.target.value)}
                  placeholder="Contoh: Wireless / USB / Core i5 / 24 inch"
                  className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-blue-500 transition"
                />
              </div>
            )}
          </div>

          {/* 3. Status Aset (Segmented Buttons) */}
          <div>
            <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-2">
              Status Operasional Aset
            </label>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {[
                { id: 'AVAILABLE', label: 'Siap Pakai (Available)', color: 'bg-emerald-600 border-emerald-500 text-white' },
                { id: 'IN_USE', label: 'Sedang Dipakai (In Use)', color: 'bg-cyan-600 border-cyan-500 text-white' },
                { id: 'REPAIRING', label: 'Perlu Servis (Repairing)', color: 'bg-amber-600 border-amber-500 text-white' },
                { id: 'BROKEN', label: 'Rusak Berat (Broken)', color: 'bg-rose-600 border-rose-500 text-white' },
              ].map((st) => (
                <button
                  key={st.id}
                  type="button"
                  onClick={() => setStatus(st.id)}
                  className={`py-2 px-2 rounded-xl text-xs font-semibold border transition text-center ${
                    status === st.id
                      ? `${st.color} shadow-md`
                      : 'bg-slate-900 text-slate-400 border-slate-700 hover:text-white hover:border-slate-600'
                  }`}
                >
                  {st.label}
                </button>
              ))}
            </div>
          </div>

          {/* 4. Lokasi & Meja Kerja */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Lokasi Penempatan
              </label>
              <select
                value={locationType}
                onChange={(e) => setLocationType(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-blue-500 transition"
              >
                <option value="Ruang IT">Ruang IT</option>
                <option value="Floor Lt2">Floor Lt2 (Lantai 2)</option>
                <option value="Floor Lt3">Floor Lt3 (Lantai 3)</option>
              </select>
            </div>

            {(locationType === 'Floor Lt2' || locationType === 'Floor Lt3') && (
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Nomor Meja Karyawan *
                </label>
                <input
                  type="text"
                  value={deskNumber}
                  onChange={(e) => setDeskNumber(e.target.value)}
                  placeholder="Contoh: 12 atau 05A"
                  required
                  className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sm text-white focus:outline-none focus:border-blue-500 transition"
                />
              </div>
            )}
          </div>

          {/* 5. Catatan Kerusakan & Quick Presets */}
          <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-700/80 space-y-2.5">
            <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider">
              Catatan Kondisi / Keterangan Perbaikan
            </label>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Jelaskan kondisi fisik, alasan servis, atau keterangan lokasi..."
              rows={2}
              className="w-full px-3.5 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 transition"
            />
            <div className="flex flex-wrap gap-1.5 items-center pt-1">
              <span className="text-[11px] text-slate-400 mr-1">Pilih Cepat:</span>
              {REPAIR_PRESETS.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => setNote((prev) => (prev ? `${prev}, ${preset}` : preset))}
                  className="px-2 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 text-[11px] transition"
                >
                  + {preset}
                </button>
              ))}
            </div>
          </div>

          {/* 6. Foto Fisik Aset & Upload dari PC */}
          <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-700/80 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
                <Image size={15} className="text-blue-400" />
                Dokumentasi Foto Fisik Aset
              </span>
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={isUploadingImage}
                className="px-3 py-1.5 rounded-xl bg-blue-600/30 hover:bg-blue-600/50 text-blue-300 border border-blue-500/40 text-xs font-semibold flex items-center gap-1.5 transition"
              >
                <Upload size={14} />
                {isUploadingImage ? 'Mengunggah...' : 'Unggah Foto dari PC'}
              </button>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleFileUpload}
                className="hidden"
              />
            </div>

            {imagePaths.length === 0 ? (
              <p className="text-xs text-slate-500 italic py-2">
                Belum ada foto yang dilampirkan. Anda bisa mengunggah dari komputer atau memotret langsung dari aplikasi HP teknisi.
              </p>
            ) : (
              <div className="flex flex-wrap gap-3 pt-1">
                {imagePaths.map((path, idx) => {
                  const fullUrl = path.startsWith('http')
                    ? path
                    : `${API_BASE_URL}${path.startsWith('/') ? path : '/' + path}`;

                  return (
                    <div key={idx} className="relative group rounded-xl overflow-hidden border border-slate-700 w-24 h-24 bg-slate-950">
                      <img
                        src={fullUrl}
                        alt={`Asset photo ${idx + 1}`}
                        className="w-full h-full object-cover group-hover:scale-105 transition"
                      />
                      <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 flex items-center justify-center gap-2 transition">
                        <a
                          href={fullUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="p-1 rounded bg-slate-800 text-white hover:bg-blue-600"
                          title="Lihat Foto Ukuran Penuh"
                        >
                          <ExternalLink size={14} />
                        </a>
                        <button
                          type="button"
                          onClick={() => removeImage(idx)}
                          className="p-1 rounded bg-rose-900 text-rose-200 hover:bg-rose-700"
                          title="Hapus Foto"
                        >
                          <X size={14} />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* 7. Advanced Technical Details (Collapsible) */}
          <div className="border border-slate-700/80 rounded-2xl overflow-hidden bg-slate-900/40">
            <button
              type="button"
              onClick={() => setShowAdvanced(!showAdvanced)}
              className="w-full p-3.5 flex items-center justify-between text-xs font-bold text-slate-400 hover:text-white transition"
            >
              <span>⚙️ Pengaturan Teknis Lanjutan (Nomor Seri, Garansi, Kode GA Lama)</span>
              {showAdvanced ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
            </button>

            {showAdvanced && (
              <div className="p-4 pt-0 grid grid-cols-1 sm:grid-cols-2 gap-3 border-t border-slate-700/60 mt-1">
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    Nomor Seri Pabrik (Serial Number)
                  </label>
                  <input
                    type="text"
                    value={serialNumber}
                    onChange={(e) => setSerialNumber(e.target.value)}
                    placeholder="Contoh: SN12345678"
                    className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    Batas Masa Garansi
                  </label>
                  <input
                    type="date"
                    value={warrantyDate}
                    onChange={(e) => setWarrantyDate(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    Kode Inventaris GA / Stiker Lama
                  </label>
                  <input
                    type="text"
                    value={legacyInvCode}
                    onChange={(e) => setLegacyInvCode(e.target.value)}
                    placeholder="Contoh: MS/1126/2024"
                    className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white font-mono"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    Kategori Database
                  </label>
                  <select
                    value={selectedCategory || ''}
                    onChange={(e) => setSelectedCategory(Number(e.target.value) || null)}
                    className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white"
                  >
                    <option value="">Default Kategori</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name} ({cat.type})
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            )}
          </div>

          {/* Form Actions */}
          <div className="pt-2 flex gap-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-3 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded-2xl text-xs font-semibold transition"
            >
              Batalkan
            </button>
            <button
              type="submit"
              className="flex-1 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white rounded-2xl text-xs font-bold shadow-lg shadow-blue-600/30 transition flex items-center justify-center gap-2"
            >
              <Check size={16} />
              {asset ? 'Simpan Perubahan Aset' : 'Buat Aset Baru'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Delete Confirmation Modal Component
const DeleteConfirmModal = ({ 
  show, 
  onClose, 
  onConfirm, 
  assetId 
}: { 
  show: boolean; 
  onClose: () => void; 
  onConfirm: () => void; 
  assetId?: string;
}) => {
  if (!show) return null;

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
      <div className="bg-slate-800 rounded-3xl p-6 max-w-md w-full border border-rose-500/50 shadow-2xl space-y-4">
        <div className="flex justify-between items-center border-b border-slate-700 pb-3">
          <h3 className="text-lg font-bold text-rose-400">Hapus Data Aset</h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-700 rounded-xl text-slate-400 hover:text-white transition">
            <X size={20} />
          </button>
        </div>
        <p className="text-xs text-slate-300 leading-relaxed">
          Apakah Anda yakin ingin menghapus aset dengan ID <strong className="font-mono text-white bg-slate-900 px-1.5 py-0.5 rounded">{assetId}</strong>? Tindakan ini tidak dapat dibatalkan.
        </p>
        <div className="flex gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-2.5 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded-xl text-xs font-semibold transition"
          >
            Batal
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className="flex-1 py-2.5 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold shadow-lg shadow-rose-600/30 transition"
          >
            Ya, Hapus Aset
          </button>
        </div>
      </div>
    </div>
  );
};

export { AssetFormModal, DeleteConfirmModal };
