import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface AuthState {
  isAuthenticated: boolean;
  username: string | null;
  login: (username: string, password: string) => boolean;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      isAuthenticated: false,
      username: null,
      login: (username, password) => {
        // Simple hardcoded authentication
        if (username === 'admin' && password === 'admin123') {
          set({ isAuthenticated: true, username });
          return true;
        }
        return false;
      },
      logout: () => set({ isAuthenticated: false, username: null }),
    }),
    {
      name: 'auth-storage',
    }
  )
);
