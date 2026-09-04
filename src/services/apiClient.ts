import toast from 'react-hot-toast';

// Dynamic API base URL (supports dev mode and production reverse proxy)
export const getApiBaseUrl = () => {
  if (typeof window !== 'undefined' && window.location && window.location.hostname) {
    // If running in development Vite server (ports 5173, 5174, 3000), point to local backend
    if (window.location.port === '5173' || window.location.port === '5174' || window.location.port === '3000') {
      return `http://${window.location.hostname}:8080`;
    }
    // In production (served from same domain / reverse proxy), use relative path
    return '';
  }
  return '';
};

export const API_BASE_URL = getApiBaseUrl();

// Custom fetch wrapper with automatic toast notifications
export const apiClient = {
  async get(endpoint: string, showToast = false) {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`);
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      if (showToast) toast.success('Data loaded successfully');
      return data;
    } catch (error) {
      toast.error(`Failed to fetch data: ${error instanceof Error ? error.message : 'Unknown error'}`);
      throw error;
    }
  },

  async post(endpoint: string, body: any, successMessage?: string) {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      toast.success(successMessage || 'Operation completed successfully');
      return data;
    } catch (error) {
      toast.error(`Operation failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
      throw error;
    }
  },

  async put(endpoint: string, body: any, successMessage?: string) {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      toast.success(successMessage || 'Updated successfully');
      return data;
    } catch (error) {
      toast.error(`Update failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
      throw error;
    }
  },

  async delete(endpoint: string, successMessage?: string) {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        method: 'DELETE',
      });
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      toast.success(successMessage || 'Deleted successfully');
      return true;
    } catch (error) {
      toast.error(`Delete failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
      throw error;
    }
  },
};

// Specific API methods with custom messages
export const assetAPI = {
  create: (asset: any) => apiClient.post('/api/assets', asset, `Asset ${asset.id} created successfully`),
  update: (id: string, asset: any) => apiClient.put(`/api/assets/${id}`, asset, `Asset ${id} updated successfully`),
  delete: (id: string) => apiClient.delete(`/api/assets/${id}`, `Asset ${id} deleted successfully`),
  getAll: () => apiClient.get('/api/assets'),
};

export const deskAPI = {
  create: (desk: any) => apiClient.post('/api/desks', desk, `Desk ${desk.number} created successfully`),
  update: (id: string, desk: any) => apiClient.put(`/api/desks/${id}`, desk, `Desk updated successfully`),
  delete: (id: string) => apiClient.delete(`/api/desks/${id}`, `Desk deleted successfully`),
  getAll: () => apiClient.get('/api/desks'),
};

export const categoryAPI = {
  create: (category: any) => apiClient.post('/api/categories', category, `Category "${category.name}" created successfully`),
  update: (id: number, category: any) => apiClient.put(`/api/categories/${id}`, category, `Category "${category.name}" updated successfully`),
  delete: (id: number) => apiClient.delete(`/api/categories/${id}`, `Category deleted successfully`),
  getAll: () => apiClient.get('/api/categories'),
};

export const bulkAPI = {
  updateStatus: (assetIds: string[], newStatus: string) => 
    apiClient.post('/api/assets/bulk-status', { asset_ids: assetIds, new_status: newStatus }, 
      `${assetIds.length} asset(s) status updated to ${newStatus}`),
  updateLocation: (assetIds: string[], newLocation: string) => 
    apiClient.post('/api/assets/bulk-location', { asset_ids: assetIds, new_location: newLocation }, 
      `${assetIds.length} asset(s) transferred to ${newLocation}`),
};
