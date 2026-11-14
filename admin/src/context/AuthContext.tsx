import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { AdminPermission, AdminRole } from '../types/database';

interface AuthContextValue {
  session: Session | null;
  adminRole: AdminRole | null;
  adminDisplayName: string | null;
  permissions: Set<AdminPermission>;
  hasPermission: (permission: AdminPermission) => boolean;
  isSuperAdmin: boolean;
  /** true while the initial session + admin lookup is in flight */
  loading: boolean;
  /** true once we've established the signed-in user is NOT a valid active admin */
  accessDenied: boolean;
  signOut: () => Promise<void>;
  refreshAdmin: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [adminRole, setAdminRole] = useState<AdminRole | null>(null);
  const [adminDisplayName, setAdminDisplayName] = useState<string | null>(null);
  const [permissions, setPermissions] = useState<Set<AdminPermission>>(new Set());
  const [loading, setLoading] = useState(true);
  const [accessDenied, setAccessDenied] = useState(false);

  async function loadAdmin(userId: string) {
    const { data: adminRow, error: adminError } = await supabase
      .from('admin_users')
      .select('role, display_name, is_active')
      .eq('id', userId)
      .maybeSingle();

    if (adminError || !adminRow || !adminRow.is_active) {
      setAdminRole(null);
      setAdminDisplayName(null);
      setPermissions(new Set());
      setAccessDenied(true);
      return;
    }

    setAdminRole(adminRow.role);
    setAdminDisplayName(adminRow.display_name);
    setAccessDenied(false);

    if (adminRow.role === 'SUPER_ADMIN') {
      setPermissions(new Set());
    } else {
      const { data: permRows } = await supabase
        .from('admin_permissions')
        .select('permission')
        .eq('admin_id', userId);
      setPermissions(new Set((permRows ?? []).map((p) => p.permission)));
    }
  }

  async function refreshAdmin() {
    if (session?.user.id) {
      await loadAdmin(session.user.id);
    }
  }

  useEffect(() => {
    let mounted = true;

    supabase.auth.getSession().then(async ({ data }) => {
      if (!mounted) return;
      setSession(data.session);
      if (data.session?.user.id) {
        await loadAdmin(data.session.user.id);
      }
      if (mounted) setLoading(false);
    });

    const { data: listener } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      if (!mounted) return;
      setSession(newSession);
      if (newSession?.user.id) {
        setLoading(true);
        await loadAdmin(newSession.user.id);
        if (mounted) setLoading(false);
      } else {
        setAdminRole(null);
        setAdminDisplayName(null);
        setPermissions(new Set());
        setLoading(false);
      }
    });

    return () => {
      mounted = false;
      listener.subscription.unsubscribe();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isSuperAdmin = adminRole === 'SUPER_ADMIN';

  function hasPermission(permission: AdminPermission): boolean {
    if (isSuperAdmin) return true;
    return permissions.has(permission);
  }

  async function signOut() {
    await supabase.auth.signOut();
    setSession(null);
    setAdminRole(null);
    setAdminDisplayName(null);
    setPermissions(new Set());
    setAccessDenied(false);
  }

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      adminRole,
      adminDisplayName,
      permissions,
      hasPermission,
      isSuperAdmin,
      loading,
      accessDenied,
      signOut,
      refreshAdmin,
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [session, adminRole, adminDisplayName, permissions, loading, accessDenied],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}
