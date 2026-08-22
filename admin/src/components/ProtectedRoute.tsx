import type { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import type { AdminPermission } from '../types/database';
import { FullScreenLoader } from './FullScreenLoader';

interface ProtectedRouteProps {
  children: ReactNode;
  /** Require this permission (SUPER_ADMIN always passes). Omit for "any authenticated admin". */
  permission?: AdminPermission;
  /** Require SUPER_ADMIN role specifically. */
  requireSuperAdmin?: boolean;
}

export function ProtectedRoute({ children, permission, requireSuperAdmin }: ProtectedRouteProps) {
  const { session, loading, accessDenied, hasPermission, isSuperAdmin } = useAuth();

  if (loading) return <FullScreenLoader />;

  if (accessDenied) return <Navigate to="/login" replace />;

  if (!session) return <Navigate to="/login" replace />;

  if (requireSuperAdmin && !isSuperAdmin) {
    return <AccessDeniedInline />;
  }

  if (permission && !hasPermission(permission)) {
    return <AccessDeniedInline />;
  }

  return <>{children}</>;
}

function AccessDeniedInline() {
  return (
    <div className="flex h-full min-h-[60vh] flex-col items-center justify-center gap-2 text-center">
      <div className="text-4xl">🚫</div>
      <h2 className="text-lg font-semibold text-zinc-100">Accès refusé</h2>
      <p className="max-w-sm text-sm text-zinc-500">
        Vous n'avez pas la permission requise pour accéder à cette section du tableau de bord.
      </p>
    </div>
  );
}
