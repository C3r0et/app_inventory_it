import { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { API_BASE_URL } from '../../services/apiClient';
import type { Asset, AssetStatus } from '../../types';
import toast from 'react-hot-toast';
import { 
  ScanLine, 
  AlertTriangle, 
  Package, 
  Laptop, 
  Monitor, 
  Keyboard as KeyboardIcon, 
  Mouse, 
  Headphones, 
  Cpu, 
  ArrowRight, 
  Volume2, 
  VolumeX, 
  RotateCcw, 
  PlusCircle, 
  X,
  History,
  Boxes,
  HelpCircle,
  Camera,
  Image as ImageIcon,
  Loader2,
  Sparkles,
  CheckCircle2,
  RefreshCw,
  FlipHorizontal,
  Maximize2,
  Minimize2,
  Zap,
  Video
} from 'lucide-react';
import { scanStickerWithMistral } from '../../services/mistralVisionService';

interface ScannedSessionItem {
  asset: Asset;
  prevLocation: string;
  prevStatus: string;
  timestamp: string;
}

export const IntakePage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();

  // Intake configuration state
  const [targetLocation, setTargetLocation] = useState<string>('Ruang IT');
  const [targetStatus, setTargetStatus] = useState<AssetStatus>('AVAILABLE');
  const [batchNote, setBatchNote] = useState<string>('Penerimaan unit ke Ruang IT');
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);

  // Scan input & session state
  const [scanInput, setScanInput] = useState<string>('');
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [scannedItems, setScannedItems] = useState<ScannedSessionItem[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);

  // Camera & AI OCR Vision state
  const [isCameraOpen, setIsCameraOpen] = useState<boolean>(false);
  const [isOcrProcessing, setIsOcrProcessing] = useState<boolean>(false);
  const [ocrStatusText, setOcrStatusText] = useState<string | null>(null);
  const [ocrCandidates, setOcrCandidates] = useState<string[]>([]);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [videoDevices, setVideoDevices] = useState<MediaDeviceInfo[]>([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>('');
  const [isMirrored, setIsMirrored] = useState<boolean>(false);
  const [isDocked, setIsDocked] = useState<boolean>(false);

  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileUploadRef = useRef<HTMLInputElement>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);

  // Multi-match dialog state
  const [ambiguousMatches, setAmbiguousMatches] = useState<Asset[] | null>(null);
  const [ambiguousQuery, setAmbiguousQuery] = useState<string>('');

  // Unregistered Quick-Add dialog state
  const [unregisteredCode, setUnregisteredCode] = useState<string | null>(null);
  const [quickAddType, setQuickAddType] = useState<string>('MOUSE');
  const [quickAddBrand, setQuickAddBrand] = useState<string>('Logitech');

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  // Keep scanner input auto-focused at all times
  useEffect(() => {
    const timer = setTimeout(() => {
      if (!ambiguousMatches && !unregisteredCode) {
        inputRef.current?.focus();
      }
    }, 100);
    return () => clearTimeout(timer);
  }, [ambiguousMatches, unregisteredCode, scannedItems]);

  // Web Audio synth sound generator
  const playSound = (type: 'success' | 'warning' | 'error') => {
    if (!soundEnabled) return;
    try {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      const ctx = new AudioCtx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);

      if (type === 'success') {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(659.25, ctx.currentTime); // E5
        osc.frequency.setValueAtTime(880, ctx.currentTime + 0.08); // A5
        gain.gain.setValueAtTime(0.2, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.2);
        osc.start();
        osc.stop(ctx.currentTime + 0.2);
      } else if (type === 'warning') {
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(440, ctx.currentTime);
        osc.frequency.setValueAtTime(554.37, ctx.currentTime + 0.1);
        gain.gain.setValueAtTime(0.25, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.25);
        osc.start();
        osc.stop(ctx.currentTime + 0.25);
      } else {
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(220, ctx.currentTime);
        gain.gain.setValueAtTime(0.3, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.35);
        osc.start();
        osc.stop(ctx.currentTime + 0.35);
      }
    } catch (_) {
      // AudioContext not allowed or disabled
    }
  };

  // Keyboard shortcut listener for multi-match selection (1..9)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (ambiguousMatches && ambiguousMatches.length > 0) {
        const num = parseInt(e.key, 10);
        if (!isNaN(num) && num >= 1 && num <= ambiguousMatches.length) {
          e.preventDefault();
          checkInAsset(ambiguousMatches[num - 1]);
          setAmbiguousMatches(null);
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [ambiguousMatches]);

  const cleanQuery = (raw: string) => {
    return raw.trim().replace(/^[\s/]+|[\s/]+$/g, '');
  };

  const processQuery = async (rawQuery: string): Promise<boolean> => {
    const query = cleanQuery(rawQuery);
    if (!query || isProcessing) return false;

    setIsProcessing(true);
    try {
      // Search remote server with smart pattern
      const response = await fetch(`${API_BASE_URL}/api/assets/search?q=${encodeURIComponent(query)}`);
      if (!response.ok) {
        if (response.status === 404) {
          playSound('error');
          setUnregisteredCode(query);
          return false;
        }
        throw new Error('Gagal mencari aset di server');
      }

      const results = await response.json();
      const assetList: Asset[] = Array.isArray(results) ? results : results ? [results] : [];

      if (assetList.length === 1) {
        // Single match found - directly check in!
        await checkInAsset(assetList[0]);
        setScanInput('');
        return true;
      } else if (assetList.length > 1) {
        // Multiple matches found (e.g. MS-1126 and KB-1126)
        playSound('warning');
        setAmbiguousQuery(query);
        setAmbiguousMatches(assetList);
        return false;
      } else {
        // No match found
        playSound('error');
        setUnregisteredCode(query);
        return false;
      }
    } catch (err) {
      console.error('Scan check error:', err);
      toast.error('Gagal memproses scan. Periksa koneksi jaringan.');
      playSound('error');
      return false;
    } finally {
      setIsProcessing(false);
    }
  };

  const handleScanSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await processQuery(scanInput);
  };

  // Camera OCR Vision & USB Webcam methods
  const loadVideoDevices = async () => {
    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) {
        return [];
      }
      const devices = await navigator.mediaDevices.enumerateDevices();
      const videoInputs = devices.filter((d) => d.kind === 'videoinput');
      setVideoDevices(videoInputs);
      return videoInputs;
    } catch (err) {
      console.warn('Could not enumerate video devices:', err);
      return [];
    }
  };

  const startCamera = async (overrideDeviceId?: string) => {
    setCameraError(null);
    setOcrStatusText(null);
    setOcrCandidates([]);
    setIsCameraOpen(true);

    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach((track) => track.stop());
      mediaStreamRef.current = null;
    }

    try {
      // 1. Refresh devices list
      let devices = await loadVideoDevices();
      const hasLabels = devices.some((d) => Boolean(d.label));

      // If devices don't have labels yet, request temporary permission to populate labels
      if (!hasLabels) {
        try {
          const initStream = await navigator.mediaDevices.getUserMedia({ video: true });
          initStream.getTracks().forEach((track) => track.stop());
          devices = await loadVideoDevices();
        } catch (permErr) {
          console.warn('Webcam permission probe:', permErr);
        }
      }

      // 2. Select target device:
      // a. overrideDeviceId (explicit choice from user)
      // b. selectedDeviceId (current state)
      // c. localStorage 'preferred_camera_device_id'
      // d. auto-detect device with 'usb' or 'external' in its label
      // e. first available device
      const savedId = localStorage.getItem('preferred_camera_device_id');
      let targetId = overrideDeviceId || selectedDeviceId;

      if (!targetId && savedId && devices.some((d) => d.deviceId === savedId)) {
        targetId = savedId;
      }

      if (!targetId) {
        const usbDevice = devices.find((d) => {
          const label = (d.label || '').toLowerCase();
          return label.includes('usb') || label.includes('external') || label.includes('uvc') || label.includes('cam');
        });
        targetId = usbDevice?.deviceId || devices[0]?.deviceId || '';
      }

      if (targetId) {
        setSelectedDeviceId(targetId);
        localStorage.setItem('preferred_camera_device_id', targetId);
      }

      const constraints: MediaStreamConstraints = {
        video: targetId
          ? {
              deviceId: { exact: targetId },
              width: { ideal: 1920 },
              height: { ideal: 1080 },
            }
          : {
              facingMode: { ideal: 'environment' },
              width: { ideal: 1920 },
              height: { ideal: 1080 },
            },
      };

      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      mediaStreamRef.current = stream;

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play().catch(() => {});
      }
    } catch (err) {
      console.error('Webcam access error:', err);
      try {
        const fallbackStream = await navigator.mediaDevices.getUserMedia({ video: true });
        mediaStreamRef.current = fallbackStream;
        if (videoRef.current) {
          videoRef.current.srcObject = fallbackStream;
          videoRef.current.play().catch(() => {});
        }
      } catch (fallbackErr) {
        setCameraError(
          'Gagal mengakses kamera USB. Pastikan kabel USB kamera sudah dicolok dengan benar dan browser diberikan izin akses kamera di address bar.'
        );
      }
    }
  };

  const stopCamera = () => {
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach((track) => track.stop());
      mediaStreamRef.current = null;
    }
    setIsCameraOpen(false);
    setOcrStatusText(null);
    setOcrCandidates([]);
  };

  const handleDeviceChange = async (newDeviceId: string) => {
    setSelectedDeviceId(newDeviceId);
    localStorage.setItem('preferred_camera_device_id', newDeviceId);
    await startCamera(newDeviceId);
  };

  useEffect(() => {
    if (isCameraOpen && videoRef.current && mediaStreamRef.current) {
      if (videoRef.current.srcObject !== mediaStreamRef.current) {
        videoRef.current.srcObject = mediaStreamRef.current;
        videoRef.current.play().catch(() => {});
      }
    }
  }, [isCameraOpen]);

  useEffect(() => {
    return () => {
      if (mediaStreamRef.current) {
        mediaStreamRef.current.getTracks().forEach((track) => track.stop());
      }
    };
  }, []);

  // Keyboard shortcut listener: Space / Enter to capture & scan, Escape to close
  useEffect(() => {
    const handleCameraKeyDown = (e: KeyboardEvent) => {
      if (isCameraOpen && !isOcrProcessing) {
        if (e.code === 'Space' || e.code === 'Enter') {
          const tagName = document.activeElement?.tagName?.toLowerCase();
          if (tagName === 'input' || tagName === 'select' || tagName === 'textarea') return;
          e.preventDefault();
          captureAndScan();
        } else if (e.code === 'Escape') {
          e.preventDefault();
          stopCamera();
        }
      }
    };
    window.addEventListener('keydown', handleCameraKeyDown);
    return () => window.removeEventListener('keydown', handleCameraKeyDown);
  }, [isCameraOpen, isOcrProcessing, isMirrored]);

  // Continuous auto Barcode Scanner loop using BarcodeDetector API
  useEffect(() => {
    if (!isCameraOpen || !mediaStreamRef.current) return;

    let isScanning = true;
    interface DetectedBarcode {
      rawValue: string;
    }
    let barcodeDetector: { detect: (el: HTMLVideoElement) => Promise<DetectedBarcode[]> } | null = null;

    if ('BarcodeDetector' in window) {
      try {
        const BarcodeDetectorClass = (window as unknown as {
          BarcodeDetector: new (opts?: unknown) => { detect: (el: HTMLVideoElement) => Promise<DetectedBarcode[]> };
        }).BarcodeDetector;
        barcodeDetector = new BarcodeDetectorClass({
          formats: ['code_128', 'code_39', 'qr_code', 'ean_13', 'ean_8', 'itf'],
        });
      } catch (e) {
        console.warn('BarcodeDetector init error:', e);
      }
    }

    if (!barcodeDetector) return;

    const interval = setInterval(async () => {
      if (!isScanning || isOcrProcessing || isProcessing || !videoRef.current) return;
      const video = videoRef.current;
      if (video.readyState < 2) return;

      try {
        const barcodes = await barcodeDetector!.detect(video);
        if (barcodes && barcodes.length > 0) {
          const rawVal = barcodes[0].rawValue;
          if (rawVal && rawVal.trim()) {
            isScanning = false;
            toast.success(`Barcode Terdeteksi: ${rawVal}`, { id: 'barcode-detect' });
            playSound('success');
            setScanInput(rawVal);
            await processQuery(rawVal);
            setTimeout(() => {
              isScanning = true;
            }, 1800);
          }
        }
      } catch (_) {
        // Frame skipped
      }
    }, 450);

    return () => {
      isScanning = false;
      clearInterval(interval);
    };
  }, [isCameraOpen, isOcrProcessing, isProcessing]);

  const captureAndScan = async () => {
    if (!videoRef.current || isOcrProcessing) return;

    const video = videoRef.current;
    const canvas = canvasRef.current || document.createElement('canvas');
    canvas.width = video.videoWidth || 1280;
    canvas.height = video.videoHeight || 720;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    if (isMirrored) {
      ctx.translate(canvas.width, 0);
      ctx.scale(-1, 1);
    }
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    const dataUrl = canvas.toDataURL('image/jpeg', 0.85);

    playSound('success');
    setIsOcrProcessing(true);
    setOcrStatusText('AI sedang membaca tulisan tangan spidol...');
    setOcrCandidates([]);

    try {
      const res = await scanStickerWithMistral(dataUrl);
      if (res.isSuccess && res.assetId) {
        setOcrStatusText(`Terdeteksi: ${res.assetId}`);
        setOcrCandidates(res.candidates || []);
        setScanInput(res.assetId);

        const success = await processQuery(res.assetId);
        if (success) {
          toast.success(`OCR berhasil membaca: ${res.assetId}`);
          if (!isDocked) {
            stopCamera();
          }
        }
      } else if (res.candidates && res.candidates.length > 0) {
        setOcrStatusText('Pilih salah satu kandidat nomor yang terdeteksi:');
        setOcrCandidates(res.candidates);
      } else {
        setOcrStatusText(null);
        toast.error('Tulisan spidol tidak terdeteksi jelas. Coba dekatkan kamera atau atur pencahayaan.');
        playSound('warning');
      }
    } catch (err) {
      console.error('OCR Error:', err);
      toast.error('Gagal memproses OCR.');
    } finally {
      setIsOcrProcessing(false);
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async () => {
      const dataUrl = reader.result as string;
      setIsOcrProcessing(true);
      const toastId = toast.loading('AI sedang membaca foto stiker spidol...');

      try {
        const res = await scanStickerWithMistral(dataUrl);
        toast.dismiss(toastId);

        if (res.isSuccess && res.assetId) {
          setScanInput(res.assetId);
          toast.success(`OCR berhasil membaca: ${res.assetId}`);
          await processQuery(res.assetId);
        } else if (res.candidates && res.candidates.length > 0) {
          setAmbiguousQuery(res.candidates[0]);
          await processQuery(res.candidates[0]);
        } else {
          toast.error('Tulisan spidol tidak terdeteksi dari foto yang diunggah.');
        }
      } catch (err) {
        toast.dismiss(toastId);
        console.error('OCR Upload Error:', err);
        toast.error('Gagal memproses OCR foto.');
      } finally {
        setIsOcrProcessing(false);
        if (fileUploadRef.current) fileUploadRef.current.value = '';
      }
    };
    reader.readAsDataURL(file);
  };

  const checkInAsset = async (asset: Asset) => {
    try {
      const prevLoc = asset.location || 'Lokasi Tidak Diketahui';
      const prevStat = asset.status || 'AVAILABLE';

      const updatePayload = {
        ...asset,
        location: targetLocation,
        status: targetStatus,
        note: batchNote ? `${asset.note ? asset.note + ' | ' : ''}${batchNote}` : asset.note,
      };

      const res = await fetch(`${API_BASE_URL}/api/assets/${encodeURIComponent(asset.id)}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'X-Source': 'web',
        },
        body: JSON.stringify(updatePayload),
      });

      if (!res.ok) throw new Error('Gagal memperbarui status dan lokasi aset');

      playSound('success');
      toast.success(`Aset ${asset.id} (${asset.type}) berhasil dicatat masuk!`, {
        duration: 2000,
        position: 'top-center',
      });

      // Add to session list
      const timeStr = new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
      setScannedItems((prev) => [
        {
          asset: { ...asset, location: targetLocation, status: targetStatus },
          prevLocation: prevLoc,
          prevStatus: prevStat,
          timestamp: timeStr,
        },
        ...prev,
      ]);

      setAmbiguousMatches(null);
      setScanInput('');
    } catch (err) {
      console.error('Check-in failed:', err);
      toast.error(`Gagal memindahkan aset ${asset.id}`);
      playSound('error');
    }
  };

  // Quick Add new asset right from the intake scanner
  const handleQuickAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!unregisteredCode) return;

    try {
      let prefix = 'PC-';
      if (quickAddType === 'KEYBOARD') prefix = 'KB-';
      else if (quickAddType === 'MOUSE') prefix = 'MS-';
      else if (quickAddType === 'MONITOR') prefix = 'MN-';
      else if (quickAddType === 'HEADSET') prefix = 'HD-';
      else if (quickAddType === 'LAPTOP') prefix = 'LAP-';

      // If unregistered code already has prefix, use it, otherwise prepend
      const fullId = unregisteredCode.includes('-') || unregisteredCode.includes('/')
        ? unregisteredCode
        : `${prefix}${unregisteredCode}`;

      const newAssetPayload: Asset = {
        id: fullId,
        type: quickAddType,
        status: targetStatus,
        location: targetLocation,
        specs: `Merk: ${quickAddBrand}`,
        note: batchNote || 'Pendaftaran baru via Intake Ruang IT',
        legacy_inv_code: fullId,
        sticker_status: 'STICKERED',
      };

      const res = await fetch(`${API_BASE_URL}/api/assets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Source': 'web',
        },
        body: JSON.stringify(newAssetPayload),
      });

      if (!res.ok) throw new Error('Gagal mendaftarkan aset baru');

      playSound('success');
      toast.success(`Aset baru ${fullId} berhasil didaftarkan & masuk Ruang IT!`);

      const timeStr = new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
      setScannedItems((prev) => [
        {
          asset: newAssetPayload as unknown as Asset,
          prevLocation: '(Aset Baru)',
          prevStatus: '(Baru)',
          timestamp: timeStr,
        },
        ...prev,
      ]);

      setUnregisteredCode(null);
      setScanInput('');
    } catch (err) {
      console.error('Quick add error:', err);
      toast.error('Gagal membuat aset baru');
      playSound('error');
    }
  };

  const getAssetIcon = (type: string) => {
    const t = (type || '').toUpperCase();
    if (t.includes('PC') || t.includes('CPU')) return <Cpu className="text-blue-400" size={20} />;
    if (t.includes('MON')) return <Monitor className="text-cyan-400" size={20} />;
    if (t.includes('KB') || t.includes('KEY')) return <KeyboardIcon className="text-emerald-400" size={20} />;
    if (t.includes('MS') || t.includes('MOU')) return <Mouse className="text-orange-400" size={20} />;
    if (t.includes('HD') || t.includes('HS') || t.includes('HEAD')) return <Headphones className="text-purple-400" size={20} />;
    if (t.includes('LAP')) return <Laptop className="text-indigo-400" size={20} />;
    return <Package className="text-amber-400" size={20} />;
  };

  // Breakdown statistics for current session
  const sessionStats = scannedItems.reduce((acc, item) => {
    const t = (item.asset.type || 'LAINNYA').toUpperCase();
    acc[t] = (acc[t] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const renderCameraView = (isModal: boolean) => (
    <div className={`bg-slate-800 rounded-3xl p-5 sm:p-6 border border-emerald-500/50 shadow-2xl space-y-4 ${isModal ? 'max-w-2xl w-full' : 'w-full'}`}>
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-3 border-b border-slate-700 pb-3">
        <div className="flex items-center gap-2.5">
          <div className="p-2 rounded-xl bg-emerald-600/20 text-emerald-400 border border-emerald-500/30">
            <Camera size={20} />
          </div>
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              Kamera Live &amp; OCR AI (Tulisan Spidol / Barcode)
              <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                LIVE
              </span>
            </h3>
            <p className="text-xs text-slate-400">
              Sorot stiker spidol ke kotak target. Kamera USB menampilkan live feed langsung.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Toggle Dock / Modal */}
          <button
            type="button"
            onClick={() => setIsDocked(!isDocked)}
            className="p-1.5 hover:bg-slate-700 rounded-xl text-slate-300 hover:text-white transition border border-slate-700 text-xs flex items-center gap-1.5 px-2.5"
            title={isModal ? 'Sematkan ke Halaman' : 'Perbesar ke Modal'}
          >
            {isModal ? <Minimize2 size={14} /> : <Maximize2 size={14} />}
            <span className="text-xs font-semibold">{isModal ? 'Sematkan di Halaman' : 'Layar Penuh'}</span>
          </button>

          {/* Close Camera */}
          <button
            type="button"
            onClick={stopCamera}
            className="p-1.5 hover:bg-slate-700 rounded-xl text-slate-400 hover:text-white transition border border-slate-700"
            title="Tutup Kamera"
          >
            <X size={18} />
          </button>
        </div>
      </div>

      {/* Camera Selection & Controls Bar */}
      <div className="flex flex-wrap items-center justify-between gap-2 p-3 bg-slate-900/90 rounded-2xl border border-slate-700/80">
        <div className="flex items-center gap-2 flex-1 min-w-[260px]">
          <Video size={16} className="text-emerald-400 shrink-0" />
          <label className="text-xs text-slate-300 font-bold shrink-0">
            Pilih Kamera:
          </label>
          <select
            value={selectedDeviceId}
            onChange={(e) => handleDeviceChange(e.target.value)}
            className="w-full text-xs font-medium bg-slate-800 border border-slate-700 rounded-lg px-2.5 py-1.5 text-white focus:outline-none focus:border-emerald-500 cursor-pointer"
          >
            {videoDevices.length === 0 ? (
              <option value="">Kamera Default / Memuat...</option>
            ) : (
              videoDevices.map((dev, i) => {
                const label = dev.label || `Kamera ${i + 1}`;
                const isUsb = label.toLowerCase().includes('usb') || label.toLowerCase().includes('external') || label.toLowerCase().includes('cam');
                return (
                  <option key={dev.deviceId || i} value={dev.deviceId}>
                    {isUsb ? `🔌 ${label} (USB Eksternal)` : label}
                  </option>
                );
              })
            )}
          </select>
          <button
            type="button"
            onClick={() => {
              loadVideoDevices().then((devs) => {
                toast.success(`Ditemukan ${devs.length} kamera`);
              });
            }}
            title="Muat ulang daftar kamera jika baru mencolokkan kabel USB"
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 text-xs transition shrink-0"
          >
            <RefreshCw size={14} />
          </button>
        </div>

        <div className="flex items-center gap-2">
          {/* Flip / Mirror Toggle */}
          <button
            type="button"
            onClick={() => setIsMirrored(!isMirrored)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 border transition ${
              isMirrored
                ? 'bg-blue-600/30 border-blue-500 text-blue-300'
                : 'bg-slate-800 border-slate-700 text-slate-300 hover:text-white'
            }`}
            title="Balikkan horizontal (mirror) jika angka spidol terlihat terbalik"
          >
            <FlipHorizontal size={14} />
            <span>Cermin: {isMirrored ? 'ON' : 'OFF'}</span>
          </button>
        </div>
      </div>

      {/* Viewfinder Video */}
      <div className="relative rounded-2xl overflow-hidden bg-black aspect-video flex items-center justify-center border border-slate-700 shadow-inner">
        <video
          ref={(el) => {
            videoRef.current = el;
            if (el && mediaStreamRef.current && el.srcObject !== mediaStreamRef.current) {
              el.srcObject = mediaStreamRef.current;
              el.play().catch(() => {});
            }
          }}
          autoPlay
          playsInline
          muted
          className={`w-full h-full object-contain ${isMirrored ? 'scale-x-[-1]' : ''}`}
        />
        <canvas ref={canvasRef} className="hidden" />

        {/* Viewfinder Target Reticle */}
        <div className="absolute inset-8 sm:inset-14 border-2 border-dashed border-emerald-400/80 rounded-2xl pointer-events-none flex items-center justify-center">
          <div className="absolute top-2 left-3 px-2 py-0.5 rounded bg-black/75 text-[11px] font-mono text-emerald-300 border border-emerald-500/40 flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
            Arahkan Tulisan Spidol / Barcode ke Kotak Ini
          </div>
          <div className="absolute bottom-2 right-3 px-2 py-0.5 rounded bg-black/75 text-[10px] text-slate-300 border border-slate-700">
            Tekan <kbd className="font-mono text-emerald-300 font-bold">SPASI</kbd> untuk scan
          </div>
        </div>

        {/* Live Indicator overlay top-right */}
        <div className="absolute top-3 right-3 px-2.5 py-1 rounded-full bg-black/70 backdrop-blur-xs border border-emerald-500/40 text-[10px] font-mono font-bold text-emerald-300 flex items-center gap-1.5 pointer-events-none">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
          LIVE FEED
        </div>

        {/* Status Overlay */}
        {isOcrProcessing && (
          <div className="absolute inset-0 bg-black/80 backdrop-blur-xs flex flex-col items-center justify-center gap-3 text-white p-4 text-center z-10">
            <Loader2 size={36} className="animate-spin text-emerald-400" />
            <p className="text-sm font-semibold text-emerald-300">
              {ocrStatusText || 'AI sedang menganalisis tulisan tangan spidol...'}
            </p>
            <p className="text-[11px] text-slate-400">
              Mengekstraksi nomor stiker dengan model AI Vision...
            </p>
          </div>
        )}

        {cameraError && (
          <div className="absolute inset-0 bg-slate-900/95 p-6 flex flex-col items-center justify-center text-center gap-2 text-rose-300 z-10">
            <AlertTriangle size={36} className="text-rose-400" />
            <p className="text-xs font-semibold">{cameraError}</p>
            <div className="flex gap-2 mt-2">
              <button
                type="button"
                onClick={() => startCamera()}
                className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 rounded-xl text-xs text-white border border-slate-600 flex items-center gap-1.5"
              >
                <RefreshCw size={14} /> Coba Lagi
              </button>
            </div>
          </div>
        )}
      </div>

      {/* OCR Candidates (if any) */}
      {ocrCandidates.length > 0 && (
        <div className="p-3 bg-slate-900/90 rounded-xl border border-slate-700 space-y-1.5">
          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            Kandidat Terbaca (Klik untuk proses):
          </span>
          <div className="flex flex-wrap gap-2">
            {ocrCandidates.map((cand, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => {
                  setScanInput(cand);
                  processQuery(cand);
                  if (!isDocked) stopCamera();
                }}
                className="px-3 py-1.5 rounded-lg bg-emerald-950/80 hover:bg-emerald-900 text-emerald-300 border border-emerald-700 text-xs font-mono font-bold transition flex items-center gap-1"
              >
                <CheckCircle2 size={13} /> {cand}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="flex flex-col sm:flex-row gap-2.5 pt-1">
        <button
          type="button"
          onClick={stopCamera}
          className="py-3 px-4 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded-xl text-xs font-semibold transition text-center"
        >
          Tutup Kamera
        </button>

        <button
          type="button"
          onClick={captureAndScan}
          disabled={isOcrProcessing || Boolean(cameraError)}
          className="flex-1 py-3 px-5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 disabled:opacity-50 text-white rounded-xl text-xs font-bold shadow-lg shadow-emerald-600/30 flex items-center justify-center gap-2 transition hover:scale-[1.01]"
        >
          {isOcrProcessing ? (
            <>
              <Loader2 size={16} className="animate-spin" />
              AI Sedang Membaca Spidol...
            </>
          ) : (
            <>
              <Sparkles size={16} />
              📸 Ambil Foto &amp; Baca Tulisan Spidol
              <kbd className="ml-2 px-1.5 py-0.5 rounded bg-emerald-900/80 text-[10px] font-mono border border-emerald-700 text-emerald-200">
                Spasi / Enter
              </kbd>
            </>
          )}
        </button>
      </div>

      <div className="text-center text-[11px] text-slate-400 flex items-center justify-center gap-1.5">
        <Zap size={13} className="text-amber-400" />
        <span>Jika stiker memiliki barcode biasa, kamera juga akan <strong>otomatis men-scan barcode</strong> saat disorot.</span>
      </div>
    </div>
  );

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between md:items-center gap-4 bg-slate-800/80 p-6 rounded-2xl border border-slate-700 backdrop-blur-sm shadow-xl">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div className="p-2.5 rounded-xl bg-gradient-to-br from-blue-600 to-indigo-600 text-white shadow-lg shadow-blue-500/30">
              <ScanLine size={26} />
            </div>
            <div>
              <h1 className="text-2xl font-black text-white tracking-tight flex items-center gap-2">
                Penerimaan Aset Ruang IT
                <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  Fast Check-In
                </span>
              </h1>
              <p className="text-xs text-slate-400">
                Mode scan cepat ketika teknisi membawa kumpulan CPU, Mouse, Keyboard, dll. masuk ke Ruang IT.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => setSoundEnabled(!soundEnabled)}
            className={`px-3 py-2 rounded-xl text-xs font-semibold flex items-center gap-2 border transition ${
              soundEnabled
                ? 'bg-blue-900/40 border-blue-600 text-blue-300'
                : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
            }`}
            title="Aktifkan/nonaktifkan suara beep scan"
          >
            {soundEnabled ? <Volume2 size={16} /> : <VolumeX size={16} />}
            {soundEnabled ? 'Suara Beep: ON' : 'Suara Beep: OFF'}
          </button>

          {scannedItems.length > 0 && (
            <button
              type="button"
              onClick={() => {
                if (window.confirm('Selesaikan sesi penerimaan ini dan bersihkan daftar scan?')) {
                  setScannedItems([]);
                  toast.success('Sesi penerimaan berhasil diselesaikan.');
                }
              }}
              className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded-xl text-xs font-semibold flex items-center gap-2 transition"
            >
              <RotateCcw size={15} />
              Selesai &amp; Reset Sesi
            </button>
          )}
        </div>
      </div>

      {/* Target Configuration Card */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 bg-slate-800/60 p-5 rounded-2xl border border-slate-700/80 shadow-md">
        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
            📍 Lokasi Tujuan Masuk
          </label>
          <div className="flex flex-wrap gap-2">
            {['Ruang IT', 'Ruang IT - Meja Servis', 'Ruang IT - Rak Cadangan'].map((loc) => (
              <button
                key={loc}
                type="button"
                onClick={() => setTargetLocation(loc)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition ${
                  targetLocation === loc
                    ? 'bg-blue-600 text-white border-blue-500 shadow-md shadow-blue-600/30'
                    : 'bg-slate-900/80 text-slate-300 border-slate-700 hover:border-slate-600'
                }`}
              >
                {loc}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
            🏷️ Status Barang Diterima
          </label>
          <div className="flex flex-wrap gap-2">
            {[
              { id: 'AVAILABLE', label: 'Siap Pakai (Available)', color: 'border-emerald-500 bg-emerald-600 text-white' },
              { id: 'REPAIRING', label: 'Perlu Servis (Repairing)', color: 'border-amber-500 bg-amber-600 text-white' },
              { id: 'BROKEN', label: 'Rusak Berat (Broken)', color: 'border-rose-500 bg-rose-600 text-white' },
            ].map((st) => (
              <button
                key={st.id}
                type="button"
                onClick={() => setTargetStatus(st.id as AssetStatus)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition ${
                  targetStatus === st.id
                    ? `${st.color} shadow-md`
                    : 'bg-slate-900/80 text-slate-300 border-slate-700 hover:border-slate-600'
                }`}
              >
                {st.label}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
            📝 Keterangan Penerimaan (Opsional)
          </label>
          <input
            type="text"
            value={batchNote}
            onChange={(e) => setBatchNote(e.target.value)}
            placeholder="Contoh: Tarikan dari user lantai 2 / rotasi"
            className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 transition"
          />
        </div>
      </div>

      {/* Hero Scanner Input */}
      <div className="bg-gradient-to-r from-blue-900/40 via-indigo-900/30 to-purple-900/40 p-6 md:p-8 rounded-3xl border border-blue-500/40 shadow-2xl relative overflow-hidden">
        <div className="absolute -right-10 -bottom-10 opacity-10 pointer-events-none">
          <ScanLine size={240} className="text-blue-400" />
        </div>

        <form onSubmit={handleScanSubmit} className="relative z-10 max-w-3xl mx-auto text-center space-y-4">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-blue-500/20 border border-blue-400/30 text-blue-300 text-xs font-semibold">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
            Mendukung Tulisan Spidol (Ketik &amp; Kamera OCR) + Scanner Barcode USB
          </div>

          <h2 className="text-xl md:text-2xl font-extrabold text-white">
            Scan Stiker Tulisan Spidol, Barcode, atau Ketik Nomor Aset
          </h2>
          <p className="text-xs md:text-sm text-slate-300 max-w-xl mx-auto leading-relaxed">
            Jika stiker masih bertuliskan spidol, Anda bisa <strong className="text-white">Ketik Langsung Angkanya</strong> (misal <span className="font-mono text-cyan-300 bg-slate-800/80 px-1.5 py-0.5 rounded font-bold">1126</span> lalu tekan <kbd className="px-1.5 py-0.5 rounded bg-slate-800 border border-slate-700 text-xs text-slate-200 font-mono">Enter</kbd>), gunakan <strong className="text-emerald-300">Kamera OCR AI</strong> di bawah, atau tembak dengan barcode scanner USB.
          </p>

          <div className="flex flex-col sm:flex-row gap-2">
            <div className="relative flex-1">
              <input
                ref={inputRef}
                type="text"
                value={scanInput}
                onChange={(e) => setScanInput(e.target.value)}
                disabled={isProcessing}
                placeholder="Ketik angka spidol (misal: 1126) atau scan barcode di sini..."
                className="w-full pl-5 pr-12 py-4 bg-slate-900/90 border-2 border-blue-500/60 rounded-2xl text-lg font-mono text-white placeholder-slate-500 shadow-inner focus:outline-none focus:border-blue-400 focus:ring-4 focus:ring-blue-500/20 transition"
                autoFocus
              />
              {scanInput && (
                <button
                  type="button"
                  onClick={() => setScanInput('')}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white p-1"
                >
                  <X size={18} />
                </button>
              )}
            </div>
            <button
              type="submit"
              disabled={isProcessing || !scanInput.trim()}
              className="px-6 py-4 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 disabled:opacity-50 text-white font-bold rounded-2xl shadow-lg shadow-blue-600/30 flex items-center justify-center gap-2 transition"
            >
              {isProcessing ? 'Memproses...' : 'Catat Masuk'}
              <ArrowRight size={18} />
            </button>
          </div>

          {/* Quick Action Badges & OCR Scanner Controls */}
          <div className="flex flex-wrap items-center justify-center gap-3 pt-2">
            <button
              type="button"
              onClick={() => (isCameraOpen ? stopCamera() : startCamera())}
              className={`px-4 py-2.5 rounded-xl text-white text-xs font-bold shadow-md flex items-center gap-2 transition hover:scale-[1.02] ${
                isCameraOpen
                  ? 'bg-rose-600 hover:bg-rose-500 shadow-rose-900/40'
                  : 'bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 shadow-emerald-900/40'
              }`}
            >
              <Camera size={16} />
              {isCameraOpen ? '🔴 Tutup Live Kamera' : '📷 Buka Kamera OCR (Live Webcam USB)'}
            </button>

            <button
              type="button"
              onClick={() => fileUploadRef.current?.click()}
              disabled={isOcrProcessing}
              className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-600 text-xs font-semibold flex items-center gap-2 transition hover:border-slate-500"
            >
              <ImageIcon size={16} className="text-cyan-400" />
              📁 Upload Foto Stiker Spidol
            </button>
            <input
              ref={fileUploadRef}
              type="file"
              accept="image/*"
              onChange={handleFileUpload}
              className="hidden"
            />
          </div>
        </form>
      </div>

      {/* Docked Live USB Camera View */}
      {isDocked && isCameraOpen && (
        <div className="animate-in fade-in zoom-in-95 duration-200">
          {renderCameraView(false)}
        </div>
      )}

      {/* Session Summary & Scanned Feed */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Left: Summary Breakdown */}
        <div className="space-y-4">
          <div className="bg-slate-800/80 p-5 rounded-2xl border border-slate-700 shadow-md">
            <h3 className="text-sm font-bold text-slate-300 mb-3 flex items-center gap-2">
              <Boxes size={18} className="text-blue-400" />
              Total Diterima Sesi Ini
            </h3>
            <div className="text-4xl font-black text-white mb-2">
              {scannedItems.length}{' '}
              <span className="text-sm font-medium text-slate-400">unit</span>
            </div>
            <p className="text-xs text-slate-400 mb-4">
              Aset otomatis tercatat berada di <strong className="text-slate-200">{targetLocation}</strong> dengan status <strong className="text-slate-200">{targetStatus}</strong>.
            </p>

            {Object.keys(sessionStats).length > 0 ? (
              <div className="space-y-2 pt-3 border-t border-slate-700/60">
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                  Rincian Perangkat:
                </span>
                {Object.entries(sessionStats).map(([type, count]) => (
                  <div key={type} className="flex items-center justify-between text-xs py-1 px-2 rounded-lg bg-slate-900/60">
                    <span className="font-semibold text-slate-300">{type}</span>
                    <span className="font-bold text-blue-400 bg-blue-950/60 px-2 py-0.5 rounded border border-blue-900">
                      {count} unit
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-xs text-slate-500 italic text-center py-4 border-t border-slate-700/60">
                Belum ada aset yang di-scan pada sesi ini.
              </div>
            )}
          </div>

          <div className="bg-slate-800/60 p-4 rounded-2xl border border-slate-700/60 text-xs text-slate-400 space-y-2">
            <div className="font-bold text-slate-300 flex items-center gap-1.5">
              <HelpCircle size={15} className="text-cyan-400" />
              Tips Penggunaan Cepat:
            </div>
            <ul className="list-disc pl-4 space-y-1">
              <li>Colokkan barcode scanner USB Anda. Kursor akan selalu otomatis fokus ke kotak input.</li>
              <li>Jika teknisi membawa 10 mouse, Anda cukup tembak satu per satu tanpa menyentuh mouse atau keyboard.</li>
              <li>Jika ada nomor kembar (misal 1126), pop-up akan muncul otomatis untuk memilih Mouse atau Keyboard.</li>
            </ul>
          </div>
        </div>

        {/* Right: Live Feed of Scanned Assets */}
        <div className="lg:col-span-3 bg-slate-800/80 rounded-2xl border border-slate-700 shadow-md overflow-hidden flex flex-col">
          <div className="p-4 border-b border-slate-700 flex justify-between items-center bg-slate-900/40">
            <h3 className="font-bold text-white text-sm flex items-center gap-2">
              <History size={17} className="text-indigo-400" />
              Daftar Barang Masuk (Sesi Berjalan)
            </h3>
            <span className="text-xs text-slate-400">
              Menampilkan {scannedItems.length} item
            </span>
          </div>

          <div className="flex-1 overflow-y-auto max-h-[500px] p-4 space-y-2">
            {scannedItems.length === 0 ? (
              <div className="text-center py-16 text-slate-500">
                <ScanLine size={48} className="mx-auto mb-3 opacity-30 text-slate-400" />
                <p className="font-semibold text-sm">Menunggu Scan Pertama...</p>
                <p className="text-xs text-slate-400 mt-1">
                  Aset yang Anda scan akan langsung muncul di sini secara berurutan.
                </p>
              </div>
            ) : (
              scannedItems.map((item, idx) => (
                <div
                  key={`${item.asset.id}-${idx}`}
                  className="flex items-center justify-between p-3.5 rounded-xl bg-slate-900/90 border border-slate-700/80 hover:border-blue-500/50 transition group animate-in fade-in slide-in-from-top-2 duration-200"
                >
                  <div className="flex items-center gap-3">
                    <div className="p-2.5 rounded-xl bg-slate-800 border border-slate-700">
                      {getAssetIcon(item.asset.type)}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-bold text-white text-sm">
                          {item.asset.id}
                        </span>
                        <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-blue-900/60 text-blue-300 border border-blue-800">
                          {item.asset.type}
                        </span>
                        {item.asset.legacy_inv_code && (
                          <span className="text-[11px] font-mono text-slate-400">
                            ({item.asset.legacy_inv_code})
                          </span>
                        )}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5 flex items-center gap-2">
                        <span className="line-through text-slate-500">{item.prevLocation}</span>
                        <ArrowRight size={12} className="text-emerald-400" />
                        <span className="text-emerald-400 font-semibold">{item.asset.location}</span>
                        {item.asset.specs && (
                          <span className="text-slate-400 border-l border-slate-700 pl-2">
                            {item.asset.specs}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    <div className="text-right">
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/40">
                        {item.asset.status}
                      </span>
                      <div className="text-[10px] text-slate-500 mt-1 font-mono">
                        {item.timestamp}
                      </div>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Multi-Match Resolver Modal */}
      {ambiguousMatches && ambiguousMatches.length > 0 && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
          <div className="bg-slate-800 rounded-2xl p-6 max-w-lg w-full border border-blue-500/60 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-700 pb-3">
              <div className="flex items-center gap-2 text-amber-400">
                <AlertTriangle size={22} />
                <h3 className="text-lg font-bold text-white">
                  Nomor Kembar Terdeteksi ({ambiguousQuery})
                </h3>
              </div>
              <button
                onClick={() => setAmbiguousMatches(null)}
                className="text-slate-400 hover:text-white p-1 rounded-lg"
              >
                <X size={20} />
              </button>
            </div>

            <p className="text-xs text-slate-300">
              Nomor <strong className="text-white font-mono bg-slate-900 px-1.5 py-0.5 rounded">"{ambiguousQuery}"</strong> digunakan oleh beberapa perangkat sekaligus. Silakan pilih aset mana yang sedang Anda terima (bisa tekan angka keyboard):
            </p>

            <div className="space-y-2">
              {ambiguousMatches.map((match, i) => (
                <button
                  key={match.id}
                  onClick={() => checkInAsset(match)}
                  className="w-full flex items-center justify-between p-3.5 rounded-xl bg-slate-900 hover:bg-blue-900/40 border border-slate-700 hover:border-blue-500 transition text-left group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-blue-600/30 text-blue-300 font-bold text-sm flex items-center justify-center border border-blue-500/30 group-hover:bg-blue-600 group-hover:text-white transition">
                      {i + 1}
                    </div>
                    <div>
                      <div className="flex items-center gap-2 font-mono font-bold text-white text-sm">
                        {match.id}
                        <span className="text-[11px] font-sans font-semibold px-2 py-0.5 rounded bg-slate-800 text-blue-400 border border-slate-700">
                          {match.type}
                        </span>
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {match.location} • {match.specs || 'Tidak ada spek'}
                      </div>
                    </div>
                  </div>
                  <div className="text-xs font-semibold text-blue-400 group-hover:translate-x-1 transition">
                    Pilih &amp; Masuk →
                  </div>
                </button>
              ))}
            </div>

            <div className="text-center pt-2">
              <button
                type="button"
                onClick={() => setAmbiguousMatches(null)}
                className="text-xs text-slate-400 hover:text-white"
              >
                Batalkan Scan
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Unregistered Asset Quick-Add Modal */}
      {unregisteredCode && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
          <div className="bg-slate-800 rounded-2xl p-6 max-w-md w-full border border-amber-500/50 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-700 pb-3">
              <div className="flex items-center gap-2 text-amber-400">
                <PlusCircle size={22} />
                <h3 className="text-lg font-bold text-white">
                  Aset Belum Terdaftar
                </h3>
              </div>
              <button
                onClick={() => setUnregisteredCode(null)}
                className="text-slate-400 hover:text-white p-1 rounded-lg"
              >
                <X size={20} />
              </button>
            </div>

            <p className="text-xs text-slate-300">
              Kode stiker <strong className="text-amber-300 font-mono bg-slate-900 px-1.5 py-0.5 rounded">{unregisteredCode}</strong> belum ada di database. Daftarkan kilat langsung ke Ruang IT?
            </p>

            <form onSubmit={handleQuickAdd} className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Jenis Perangkat:
                </label>
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { id: 'MOUSE', label: 'Mouse' },
                    { id: 'KEYBOARD', label: 'Keyboard' },
                    { id: 'PC', label: 'CPU/PC' },
                    { id: 'MONITOR', label: 'Monitor' },
                    { id: 'HEADSET', label: 'Headset' },
                    { id: 'LAPTOP', label: 'Laptop' },
                  ].map((t) => (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setQuickAddType(t.id)}
                      className={`py-2 px-2 rounded-xl text-xs font-semibold border transition ${
                        quickAddType === t.id
                          ? 'bg-blue-600 text-white border-blue-500 shadow-md'
                          : 'bg-slate-900 text-slate-300 border-slate-700 hover:border-slate-600'
                      }`}
                    >
                      {t.label}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Merk / Brand:
                </label>
                <select
                  value={quickAddBrand}
                  onChange={(e) => setQuickAddBrand(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white"
                >
                  {['Logitech', 'Votre', 'HP', 'Lenovo', 'Dell', 'LG', 'Simbadda', 'Lainnya'].map((b) => (
                    <option key={b} value={b}>{b}</option>
                  ))}
                </select>
              </div>

              <div className="pt-2 flex gap-2">
                <button
                  type="button"
                  onClick={() => setUnregisteredCode(null)}
                  className="flex-1 py-2.5 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded-xl text-xs font-semibold"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white rounded-xl text-xs font-bold shadow-lg shadow-emerald-600/30"
                >
                  Simpan &amp; Masuk Ruang IT
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Floating Camera Modal */}
      {!isDocked && isCameraOpen && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center p-4 z-50 animate-in fade-in duration-200">
          {renderCameraView(true)}
        </div>
      )}
    </div>
  );
};
