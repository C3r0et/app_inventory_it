import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { API_BASE_URL } from '../../services/apiClient';
import { useAuthStore } from '../../store/authStore';
import { useStore } from '../../store/assetStore';
import { Plus, Edit, Trash2 } from 'lucide-react';
import type { Desk } from '../../types';

export const DesksPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { desks, fetchDesks, initDeskMaster } = useStore();
  const [showInitForm, setShowInitForm] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showEditForm, setShowEditForm] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [selectedDesk, setSelectedDesk] = useState<Desk | null>(null);

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchDesks();
  }, [isAuthenticated, navigate, fetchDesks]);

  const handleInit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    await initDeskMaster(
      Number(formData.get('start')),
      Number(formData.get('end')),
      formData.get('area') as string
    );
    setShowInitForm(false);
    fetchDesks();
  };

  const handleAdd = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    
    const newDesk = {
      number: Number(formData.get('number')),
      area: formData.get('area') as string,
      status: formData.get('status') as string,
    };

    try {
      const response = await fetch(`${API_BASE_URL}/api/desks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newDesk),
      });
      if (!response.ok) throw new Error('Failed to create desk');
      await fetchDesks();
      setShowAddForm(false);
      toast.success('Desk created successfully!');
    } catch (error) {
      console.error('Error creating desk:', error);
      toast.error('Failed to create desk');
    }
  };

  const handleEdit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!selectedDesk) return;
    const formData = new FormData(e.currentTarget);
    
    const updatedDesk = {
      number: Number(formData.get('number')),
      area: formData.get('area') as string,
      status: formData.get('status') as string,
    };

    try {
      const response = await fetch(`${API_BASE_URL}/api/desks/${selectedDesk.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updatedDesk),
      });
      if (!response.ok) throw new Error('Failed to update desk');
      await fetchDesks();
      setShowEditForm(false);
      setSelectedDesk(null);
      toast.success('Desk updated successfully!');
    } catch (error) {
      console.error('Error updating desk:', error);
      toast.error('Failed to update desk');
    }
  };

  const handleDelete = async () => {
    if (!selectedDesk) return;
    
    try {
      const response = await fetch(`${API_BASE_URL}/api/desks/${selectedDesk.id}`, {
        method: 'DELETE',
      });
      if (!response.ok) throw new Error('Failed to delete desk');
      await fetchDesks();
      setShowDeleteModal(false);
      setSelectedDesk(null);
      toast.success('Desk deleted successfully!');
    } catch (error) {
      console.error('Error deleting desk:', error);
      toast.error('Failed to delete desk');
    }
  };

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold mb-2">Desk Management</h1>
          <p className="text-slate-400">Manage all desks and assignments</p>
        </div>
        <div className="flex gap-2">
          <button 
            onClick={() => setShowAddForm(true)}
            className="px-4 py-2 bg-green-600 hover:bg-green-500 rounded-lg transition flex items-center gap-2"
          >
            <Plus size={20} />
            Add Desk
          </button>
          <button 
            onClick={() => setShowInitForm(true)}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition flex items-center gap-2"
          >
            <Plus size={20} />
            Bulk Initialize
          </button>
        </div>
      </div>

      {/* Desk Grid */}
      <div className="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h2 className="text-xl font-semibold mb-4">Desk Overview ({desks.length} desks)</h2>
        <div className="grid grid-cols-10 gap-2">
          {desks.map((desk) => (
            <div
              key={desk.id}
              className={`p-3 rounded text-center text-sm relative group cursor-pointer ${
                desk.status === 'OCCUPIED' ? 'bg-blue-600' :
                desk.status === 'BROKEN' ? 'bg-red-600' :
                'bg-slate-700'
              }`}
              title={`${desk.id} - ${desk.status}`}
            >
              {desk.number}
              <div className="absolute inset-0 bg-black/80 opacity-0 group-hover:opacity-100 transition flex items-center justify-center gap-1">
                <button
                  onClick={() => {
                    setSelectedDesk(desk);
                    setShowEditForm(true);
                  }}
                  className="p-1 bg-blue-600 hover:bg-blue-500 rounded"
                  title="Edit"
                >
                  <Edit size={14} />
                </button>
                <button
                  onClick={() => {
                    setSelectedDesk(desk);
                    setShowDeleteModal(true);
                  }}
                  className="p-1 bg-red-600 hover:bg-red-500 rounded"
                  title="Delete"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Bulk Init Modal */}
      {showInitForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Bulk Initialize Desks</h3>
            <form onSubmit={handleInit} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Start Number</label>
                <input
                  type="number"
                  name="start"
                  defaultValue={1}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">End Number</label>
                <input
                  type="number"
                  name="end"
                  defaultValue={120}
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
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-500 py-2 rounded transition"
                >
                  Create Desks
                </button>
                <button
                  type="button"
                  onClick={() => setShowInitForm(false)}
                  className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Desk Modal */}
      {showAddForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Add New Desk</h3>
            <form onSubmit={handleAdd} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Desk Number</label>
                <input
                  type="number"
                  name="number"
                  placeholder="e.g., 121"
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
                  placeholder="e.g., COLLECTION, SALES, ADMIN"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Status</label>
                <select
                  name="status"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  defaultValue="AVAILABLE"
                >
                  <option value="AVAILABLE">AVAILABLE</option>
                  <option value="OCCUPIED">OCCUPIED</option>
                  <option value="BROKEN">BROKEN</option>
                </select>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-green-600 hover:bg-green-500 py-2 rounded transition"
                >
                  Add Desk
                </button>
                <button
                  type="button"
                  onClick={() => setShowAddForm(false)}
                  className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Desk Modal */}
      {showEditForm && selectedDesk && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Edit Desk {selectedDesk.number}</h3>
            <form onSubmit={handleEdit} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Desk Number</label>
                <input
                  type="number"
                  name="number"
                  defaultValue={selectedDesk.number}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Area</label>
                <input
                  type="text"
                  name="area"
                  defaultValue={selectedDesk.area}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  required
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Status</label>
                <select
                  name="status"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                  defaultValue={selectedDesk.status}
                >
                  <option value="AVAILABLE">AVAILABLE</option>
                  <option value="OCCUPIED">OCCUPIED</option>
                  <option value="BROKEN">BROKEN</option>
                </select>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-500 py-2 rounded transition"
                >
                  Update Desk
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowEditForm(false);
                    setSelectedDesk(null);
                  }}
                  className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteModal && selectedDesk && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-md w-full border border-slate-700">
            <h3 className="text-xl font-semibold mb-4">Delete Desk</h3>
            <p className="text-slate-300 mb-6">
              Are you sure you want to delete Desk {selectedDesk.number}? This action cannot be undone.
            </p>
            <div className="flex gap-2">
              <button
                onClick={handleDelete}
                className="flex-1 bg-red-600 hover:bg-red-500 py-2 rounded transition"
              >
                Delete
              </button>
              <button
                onClick={() => {
                  setShowDeleteModal(false);
                  setSelectedDesk(null);
                }}
                className="flex-1 bg-slate-700 hover:bg-slate-600 py-2 rounded transition"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
