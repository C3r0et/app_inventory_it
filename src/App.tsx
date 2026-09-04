import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { Dashboard } from './pages/Dashboard';
import { MobileUI } from './pages/MobileUI';
import { LoginPage } from './pages/LoginPage';
import { AdminLayout } from './components/AdminLayout';
import { DashboardPage } from './pages/admin/DashboardPage';
import { AssetsPage } from './pages/admin/AssetsPage';
import { DesksPage } from './pages/admin/DesksPage';
import { UsersPage } from './pages/admin/UsersPage';
import { BatchOperationsPage } from './pages/admin/BatchOperationsPage';
import { HistoryPage } from './pages/admin/HistoryPage';
import { ReportsPage } from './pages/admin/ReportsPage';
import { SettingsPage } from './pages/admin/SettingsPage';
import { QRGeneratorPage } from './pages/admin/QRGeneratorPage';
import { CategoriesPage } from './pages/admin/CategoriesPage';
import { IntakePage } from './pages/admin/IntakePage';

function App() {
  return (
    <BrowserRouter>
      <Toaster 
        position="top-right"
        containerStyle={{
          zIndex: 99999,
        }}
        toastOptions={{
          duration: 3000,
          style: {
            background: '#1e293b',
            color: '#fff',
            border: '1px solid #334155',
          },
          success: {
            iconTheme: {
              primary: '#10b981',
              secondary: '#fff',
            },
          },
          error: {
            iconTheme: {
              primary: '#ef4444',
              secondary: '#fff',
            },
          },
        }}
      />
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />
        
        {/* Admin Routes with Sidebar */}
        <Route path="/admin" element={<AdminLayout><Navigate to="/admin/dashboard" replace /></AdminLayout>} />
        <Route path="/admin/dashboard" element={<AdminLayout><DashboardPage /></AdminLayout>} />
        <Route path="/admin/assets" element={<AdminLayout><AssetsPage /></AdminLayout>} />
        <Route path="/admin/desks" element={<AdminLayout><DesksPage /></AdminLayout>} />
        <Route path="/admin/users" element={<AdminLayout><UsersPage /></AdminLayout>} />
        <Route path="/admin/batch" element={<AdminLayout><BatchOperationsPage /></AdminLayout>} />
        <Route path="/admin/intake" element={<AdminLayout><IntakePage /></AdminLayout>} />
        <Route path="/admin/history" element={<AdminLayout><HistoryPage /></AdminLayout>} />
        <Route path="/admin/reports" element={<AdminLayout><ReportsPage /></AdminLayout>} />
        <Route path="/admin/settings" element={<AdminLayout><SettingsPage /></AdminLayout>} />
        <Route path="/admin/qr-generator" element={<AdminLayout><QRGeneratorPage /></AdminLayout>} />
        <Route path="/admin/categories" element={<AdminLayout><CategoriesPage /></AdminLayout>} />
        
        {/* Public Dashboard */}
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/mobile" element={<MobileUI />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
