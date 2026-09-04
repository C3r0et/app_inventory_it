import { create } from 'zustand';
import type { Desk, Asset } from '../types';
import { apiClient, assetAPI } from '../services/apiClient';

interface AppState {
  desks: Desk[];
  assets: Asset[];
  isLoading: boolean;
  error: string | null;
  fetchDesks: () => Promise<void>;
  fetchAssets: () => Promise<void>;
  initDeskMaster: (start: number, end: number, area: string) => Promise<void>;
  baselineAudit: (deskNumber: number, area: string, assetTypes: Asset['type'][]) => Promise<void>;
  createAsset: (asset: Omit<Asset, 'id'>) => Promise<void>;
  updateAsset: (id: string, asset: Partial<Asset>) => Promise<void>;
  deleteAsset: (id: string) => Promise<void>;
}

export const useStore = create<AppState>((set, get) => ({
  desks: [],
  assets: [],
  isLoading: false,
  error: null,

  fetchDesks: async () => {
    set({ isLoading: true, error: null });
    try {
      const data = await apiClient.get('/api/desks');
      set({ desks: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchAssets: async () => {
    set({ isLoading: true, error: null });
    try {
      const data = await assetAPI.getAll();
      set({ assets: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  initDeskMaster: async (start, end, area) => {
    set({ isLoading: true, error: null });
    try {
      await apiClient.post('/api/desks/init', { start, end, area }, `Initialized ${end - start + 1} desks in ${area}`);
      await get().fetchDesks();
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  baselineAudit: async (deskNumber, area, assetTypes) => {
    set({ isLoading: true, error: null });
    try {
      await apiClient.post('/api/baseline-audit', { desk_number: deskNumber, area, asset_types: assetTypes }, 
        `Baseline audit completed for desk ${deskNumber}`);
      await get().fetchAssets();
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createAsset: async (asset) => {
    set({ isLoading: true, error: null });
    try {
      await assetAPI.create(asset);
      await get().fetchAssets();
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  updateAsset: async (id, asset) => {
    set({ isLoading: true, error: null });
    try {
      await assetAPI.update(id, asset);
      await get().fetchAssets();
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  deleteAsset: async (id) => {
    set({ isLoading: true, error: null });
    try {
      await assetAPI.delete(id);
      await get().fetchAssets();
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },
}));
