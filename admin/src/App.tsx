import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ToastProvider } from './context/ToastContext';
import { ProtectedRoute } from './components/ProtectedRoute';
import { DashboardLayout } from './layouts/DashboardLayout';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { GamePage } from './pages/GamePage';
import { CrashSchedulePage } from './pages/CrashSchedulePage';
import { UsersPage } from './pages/UsersPage';
import { SubAdminsPage } from './pages/SubAdminsPage';
import { DevicesPage } from './pages/DevicesPage';
import { InvitationsPage } from './pages/InvitationsPage';
import { StatisticsPage } from './pages/StatisticsPage';
import { LogsPage } from './pages/LogsPage';
import { SettingsPage } from './pages/SettingsPage';
import { InvitePublicPage } from './pages/InvitePublicPage';
import { PredictorPage } from './pages/PredictorPage';
import { PlayerLoginPage } from './pages/PlayerLoginPage';
import { PlayerProtectedRoute } from './components/PlayerProtectedRoute';

function App() {
  return (
    <AuthProvider>
      <ToastProvider>
        <BrowserRouter>
          <Routes>
            {/* Public routes — no auth required */}
            <Route path="/login" element={<LoginPage />} />
            <Route path="/player-login" element={<PlayerLoginPage />} />
            <Route path="/invite/:token" element={<InvitePublicPage />} />
            <Route
              path="/predictor"
              element={
                <PlayerProtectedRoute>
                  <PredictorPage />
                </PlayerProtectedRoute>
              }
            />

            {/* Protected dashboard routes */}
            <Route
              element={
                <ProtectedRoute>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route
                path="/"
                element={
                  <ProtectedRoute permission="VIEW_DASHBOARD">
                    <DashboardPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/game"
                element={
                  <ProtectedRoute permission="VIEW_GAME">
                    <GamePage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/crash-schedule"
                element={
                  <ProtectedRoute permission="VIEW_GAME">
                    <CrashSchedulePage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/users"
                element={
                  <ProtectedRoute permission="VIEW_USERS">
                    <UsersPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/sub-admins"
                element={
                  <ProtectedRoute requireSuperAdmin>
                    <SubAdminsPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/devices"
                element={
                  <ProtectedRoute permission="VIEW_USERS">
                    <DevicesPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/invitations"
                element={
                  <ProtectedRoute permission="VIEW_USERS">
                    <InvitationsPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/statistics"
                element={
                  <ProtectedRoute permission="VIEW_STATISTICS">
                    <StatisticsPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/logs"
                element={
                  <ProtectedRoute permission="VIEW_LOGS">
                    <LogsPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/settings"
                element={
                  <ProtectedRoute permission="VIEW_SETTINGS">
                    <SettingsPage />
                  </ProtectedRoute>
                }
              />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Route>
          </Routes>
        </BrowserRouter>
      </ToastProvider>
    </AuthProvider>
  );
}

export default App;
