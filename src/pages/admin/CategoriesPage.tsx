import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { useCategoryStore } from '../../store/categoryStore';
import { Plus, Edit2, Trash2, ChevronRight, ChevronDown } from 'lucide-react';
import type { Category } from '../../types';

export const CategoriesPage = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const { categories, fetchCategories, createCategory, updateCategory, deleteCategory } = useCategoryStore();

  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<Category | null>(null);
  const [expandedCategories, setExpandedCategories] = useState<Set<number>>(new Set());

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
      return;
    }
    fetchCategories();
  }, [isAuthenticated, navigate, fetchCategories]);

  const handleCreate = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    try {
      await createCategory({
        name: formData.get('name') as string,
        parent_id: formData.get('parent_id') ? Number(formData.get('parent_id')) : null,
        type: formData.get('type') as Category['type'],
        icon: formData.get('icon') as string || null,
      });
      setShowCreateModal(false);
    } catch (error) {
      console.error('Failed to create category:', error);
    }
  };

  const handleEdit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!selectedCategory) return;
    const formData = new FormData(e.currentTarget);
    try {
      await updateCategory(selectedCategory.id, {
        name: formData.get('name') as string,
        parent_id: formData.get('parent_id') ? Number(formData.get('parent_id')) : null,
        type: formData.get('type') as Category['type'],
        icon: formData.get('icon') as string || null,
      });
      setShowEditModal(false);
      setSelectedCategory(null);
    } catch (error) {
      console.error('Failed to update category:', error);
    }
  };

  const handleDelete = async () => {
    if (!selectedCategory) return;
    try {
      await deleteCategory(selectedCategory.id);
      setShowDeleteModal(false);
      setSelectedCategory(null);
    } catch (error) {
      console.error('Failed to delete category:', error);
    }
  };

  const toggleExpand = (categoryId: number) => {
    const newExpanded = new Set(expandedCategories);
    if (newExpanded.has(categoryId)) {
      newExpanded.delete(categoryId);
    } else {
      newExpanded.add(categoryId);
    }
    setExpandedCategories(newExpanded);
  };

  const renderCategoryTree = (cats: Category[], level = 0) => {
    return cats.map((category) => (
      <div key={category.id} style={{ marginLeft: `${level * 24}px` }}>
        <div className="flex items-center justify-between p-3 bg-slate-800 rounded-lg mb-2 hover:bg-slate-700 transition">
          <div className="flex items-center gap-3 flex-1">
            {category.children && category.children.length > 0 && (
              <button
                onClick={() => toggleExpand(category.id)}
                className="text-slate-400 hover:text-white"
              >
                {expandedCategories.has(category.id) ? (
                  <ChevronDown size={20} />
                ) : (
                  <ChevronRight size={20} />
                )}
              </button>
            )}
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="font-semibold">{category.name}</span>
                <span className="text-xs px-2 py-1 bg-slate-700 rounded">{category.type}</span>
              </div>
              {category.icon && (
                <span className="text-xs text-slate-400">Icon: {category.icon}</span>
              )}
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => {
                setSelectedCategory(category);
                setShowEditModal(true);
              }}
              className="p-2 text-blue-400 hover:bg-slate-600 rounded transition"
            >
              <Edit2 size={18} />
            </button>
            <button
              onClick={() => {
                setSelectedCategory(category);
                setShowDeleteModal(true);
              }}
              className="p-2 text-red-400 hover:bg-slate-600 rounded transition"
            >
              <Trash2 size={18} />
            </button>
          </div>
        </div>
        {category.children && expandedCategories.has(category.id) && (
          <div className="ml-6">
            {renderCategoryTree(category.children, level + 1)}
          </div>
        )}
      </div>
    ));
  };

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold mb-2">Category Management</h1>
          <p className="text-slate-400">Manage asset categories and subcategories</p>
        </div>
        <button
          onClick={() => setShowCreateModal(true)}
          className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg transition flex items-center gap-2"
        >
          <Plus size={20} />
          Add Category
        </button>
      </div>

      <div className="bg-slate-900 rounded-lg border border-slate-700 p-6">
        {categories.length === 0 ? (
          <div className="text-center text-slate-400 py-12">
            No categories found. Create your first category!
          </div>
        ) : (
          <div className="space-y-2">
            {renderCategoryTree(categories)}
          </div>
        )}
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-slate-800 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Create New Category</h2>
            <form onSubmit={handleCreate} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Category Name</label>
                <input
                  type="text"
                  name="name"
                  required
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Type</label>
                <select
                  name="type"
                  required
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                >
                  <option value="HARDWARE">Hardware</option>
                  <option value="SOFTWARE">Software</option>
                  <option value="CABLES">Cables</option>
                  <option value="CONSUMABLES">Consumables</option>
                  <option value="NETWORK">Network Equipment</option>
                </select>
              </div>
              <div>
                <label className="block text-sm mb-2">Parent Category (Optional)</label>
                <select
                  name="parent_id"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                >
                  <option value="">None (Root Category)</option>
                  {categories
                    .filter((cat) => !cat.parent_id)
                    .map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name} ({cat.type})
                      </option>
                    ))}
                </select>
              </div>
              <div>
                <label className="block text-sm mb-2">Icon (Optional)</label>
                <input
                  type="text"
                  name="icon"
                  placeholder="e.g., monitor, laptop, cable"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                />
              </div>
              <div className="flex gap-2 justify-end">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded transition"
                >
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {showEditModal && selectedCategory && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-slate-800 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Edit Category</h2>
            <form onSubmit={handleEdit} className="space-y-4">
              <div>
                <label className="block text-sm mb-2">Category Name</label>
                <input
                  type="text"
                  name="name"
                  defaultValue={selectedCategory.name}
                  required
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                />
              </div>
              <div>
                <label className="block text-sm mb-2">Type</label>
                <select
                  name="type"
                  defaultValue={selectedCategory.type}
                  required
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                >
                  <option value="HARDWARE">Hardware</option>
                  <option value="SOFTWARE">Software</option>
                  <option value="CABLES">Cables</option>
                  <option value="CONSUMABLES">Consumables</option>
                  <option value="NETWORK">Network Equipment</option>
                </select>
              </div>
              <div>
                <label className="block text-sm mb-2">Parent Category (Optional)</label>
                <select
                  name="parent_id"
                  defaultValue={selectedCategory.parent_id || ''}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                >
                  <option value="">None (Root Category)</option>
                  {categories
                    .filter((cat) => !cat.parent_id && cat.id !== selectedCategory.id)
                    .map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name} ({cat.type})
                      </option>
                    ))}
                </select>
              </div>
              <div>
                <label className="block text-sm mb-2">Icon (Optional)</label>
                <input
                  type="text"
                  name="icon"
                  defaultValue={selectedCategory.icon || ''}
                  placeholder="e.g., monitor, laptop, cable"
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-600 rounded"
                />
              </div>
              <div className="flex gap-2 justify-end">
                <button
                  type="button"
                  onClick={() => {
                    setShowEditModal(false);
                    setSelectedCategory(null);
                  }}
                  className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded transition"
                >
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Modal */}
      {showDeleteModal && selectedCategory && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-slate-800 rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-4 text-red-400">Delete Category</h2>
            <p className="mb-4">
              Are you sure you want to delete <strong>{selectedCategory.name}</strong>?
            </p>
            <p className="text-sm text-slate-400 mb-6">
              This will also delete all subcategories. This action cannot be undone.
            </p>
            <div className="flex gap-2 justify-end">
              <button
                onClick={() => {
                  setShowDeleteModal(false);
                  setSelectedCategory(null);
                }}
                className="px-4 py-2 bg-slate-700 hover:bg-slate-600 rounded transition"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                className="px-4 py-2 bg-red-600 hover:bg-red-500 rounded transition"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
