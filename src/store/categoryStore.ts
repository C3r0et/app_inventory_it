import { create } from 'zustand';
import type { Category } from '../types';
import { categoryAPI } from '../services/apiClient';

interface CategoryState {
  categories: Category[];
  isLoading: boolean;
  error: string | null;
  fetchCategories: () => Promise<void>;
  createCategory: (category: Omit<Category, 'id' | 'children'>) => Promise<void>;
  updateCategory: (id: number, category: Partial<Category>) => Promise<void>;
  deleteCategory: (id: number) => Promise<void>;
  getSubcategories: (parentId: number) => Category[];
}

export const useCategoryStore = create<CategoryState>((set, get) => ({
  categories: [],
  isLoading: false,
  error: null,

  fetchCategories: async () => {
    set({ isLoading: true, error: null });
    try {
      const data = await categoryAPI.getAll();
      set({ categories: data, isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      throw error;
    }
  },

  createCategory: async (category) => {
    try {
      await categoryAPI.create(category);
      await get().fetchCategories();
    } catch (error) {
      set({ error: (error as Error).message });
      throw error;
    }
  },

  updateCategory: async (id, category) => {
    try {
      await categoryAPI.update(id, category);
      await get().fetchCategories();
    } catch (error) {
      set({ error: (error as Error).message });
      throw error;
    }
  },

  deleteCategory: async (id) => {
    try {
      await categoryAPI.delete(id);
      await get().fetchCategories();
    } catch (error) {
      set({ error: (error as Error).message });
      throw error;
    }
  },

  getSubcategories: (parentId) => {
    const categories = get().categories;
    const parent = categories.find(c => c.id === parentId);
    return parent?.children || [];
  },
}));
