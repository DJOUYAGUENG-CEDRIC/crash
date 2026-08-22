import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { CrashxLogo } from '../components/CrashxLogo';
import type { AdminPermission } from '../types/database';

interface NavItem {
  to: string;
  label: string;
  icon: string;
  permission?: AdminPermission;
  superAdminOnly?: boolean;
}

const NAV_ITEMS: NavItem[] = [
  { to: '/', label: 'Tableau de bord', icon: '📊', permission: 'VIEW_DASHBOARD' },
  { to: '/game', label: 'Jeu', icon: '🚀', permission: 'VIEW_GAME' },
  { to: '/users', label: 'Utilisateurs', icon: '👥', permission: 'VIEW_USERS' },
  { to: '/sub-admins', label: 'Sous-comptes', icon: '🛡️', superAdminOnly: true },
  { to: '/devices', label: 'Appareils', icon: '📱', permission: 'VIEW_USERS' },
  { to: '/invitations', label: 'Invitations', icon: '✉️', permission: 'VIEW_USERS' },
  { to: '/statistics', label: 'Statistiques', icon: '📈', permission: 'VIEW_STATISTICS' },
  { to: '/logs', label: 'Journaux', icon: '🧾', permission: 'VIEW_LOGS' },
  { to: '/settings', label: 'Paramètres', icon: '⚙️', permission: 'VIEW_SETTINGS' },
];

export function DashboardLayout() {
  const { adminDisplayName, adminRole, isSuperAdmin, hasPermission, signOut } = useAuth();

  const visibleItems = NAV_ITEMS.filter((item) => {
    if (item.superAdminOnly) return isSuperAdmin;
    if (item.permission) return hasPermission(item.permission);
    return true;
  });

  return (
    <div className="flex min-h-screen bg-zinc-950 text-zinc-100">
      <aside className="flex w-60 flex-shrink-0 flex-col border-r border-zinc-800 bg-zinc-950/80">
        <div className="flex h-16 items-center border-b border-zinc-800 px-5">
          <CrashxLogo />
        </div>
        <nav className="flex-1 space-y-0.5 overflow-y-auto px-3 py-4">
          {visibleItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-violet-600/15 text-violet-300 ring-1 ring-inset ring-violet-500/30'
                    : 'text-zinc-400 hover:bg-zinc-900 hover:text-zinc-100'
                }`
              }
            >
              <span className="text-base leading-none">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-zinc-800 px-3 py-3">
          <div className="rounded-md bg-amber-500/10 px-3 py-2 text-[11px] font-medium leading-snug text-amber-400 ring-1 ring-inset ring-amber-500/20">
            MODE DÉMONSTRATION
            <br />
            Argent virtuel uniquement
          </div>
        </div>
      </aside>

      <div className="flex flex-1 flex-col">
        <header className="flex h-16 flex-shrink-0 items-center justify-between border-b border-zinc-800 bg-zinc-950/60 px-6">
          <div />
          <div className="flex items-center gap-3">
            <div className="text-right">
              <p className="text-sm font-medium text-zinc-100">{adminDisplayName ?? 'Administrateur'}</p>
              <p className="text-xs text-zinc-500">
                {adminRole === 'SUPER_ADMIN' ? 'Super administrateur' : 'Sous-administrateur'}
              </p>
            </div>
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-zinc-800 text-sm font-semibold text-zinc-300">
              {(adminDisplayName ?? 'A').charAt(0).toUpperCase()}
            </div>
            <button
              type="button"
              onClick={() => void signOut()}
              className="rounded-md px-3 py-1.5 text-sm font-medium text-zinc-400 hover:bg-zinc-900 hover:text-red-400"
            >
              Déconnexion
            </button>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto px-6 py-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
