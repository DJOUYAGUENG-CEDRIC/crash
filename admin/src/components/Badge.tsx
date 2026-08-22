import type { ReactNode } from 'react';

type Tone = 'neutral' | 'green' | 'red' | 'amber' | 'blue' | 'violet';

const TONE_CLASSES: Record<Tone, string> = {
  neutral: 'bg-zinc-800 text-zinc-300 ring-zinc-700',
  green: 'bg-emerald-500/10 text-emerald-400 ring-emerald-500/30',
  red: 'bg-red-500/10 text-red-400 ring-red-500/30',
  amber: 'bg-amber-500/10 text-amber-400 ring-amber-500/30',
  blue: 'bg-blue-500/10 text-blue-400 ring-blue-500/30',
  violet: 'bg-violet-500/10 text-violet-400 ring-violet-500/30',
};

export function Badge({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset ${TONE_CLASSES[tone]}`}
    >
      {children}
    </span>
  );
}

const ACCOUNT_STATUS_TONE: Record<string, Tone> = {
  ACTIVE: 'green',
  BLOCKED: 'red',
};

export function AccountStatusBadge({ status }: { status: string }) {
  return (
    <Badge tone={ACCOUNT_STATUS_TONE[status] ?? 'neutral'}>
      {status === 'ACTIVE' ? 'Actif' : status === 'BLOCKED' ? 'Bloqué' : status}
    </Badge>
  );
}

const ROUND_STATUS_TONE: Record<string, Tone> = {
  WAITING: 'neutral',
  BETTING: 'blue',
  RUNNING: 'green',
  CRASHED: 'red',
  RESULT: 'amber',
};

const ROUND_STATUS_LABEL: Record<string, string> = {
  WAITING: 'En attente',
  BETTING: 'Paris ouverts',
  RUNNING: 'En cours',
  CRASHED: 'Crashé',
  RESULT: 'Résultat',
};

export function RoundStatusBadge({ status }: { status: string }) {
  return (
    <Badge tone={ROUND_STATUS_TONE[status] ?? 'neutral'}>
      {ROUND_STATUS_LABEL[status] ?? status}
    </Badge>
  );
}

const DEVICE_STATUS_TONE: Record<string, Tone> = {
  ACTIVE: 'green',
  BLOCKED: 'amber',
  REVOKED: 'red',
};

const DEVICE_STATUS_LABEL: Record<string, string> = {
  ACTIVE: 'Actif',
  BLOCKED: 'Bloqué',
  REVOKED: 'Révoqué',
};

export function DeviceStatusBadge({ status }: { status: string }) {
  return (
    <Badge tone={DEVICE_STATUS_TONE[status] ?? 'neutral'}>
      {DEVICE_STATUS_LABEL[status] ?? status}
    </Badge>
  );
}

const INVITATION_STATUS_TONE: Record<string, Tone> = {
  PENDING: 'blue',
  USED: 'green',
  EXPIRED: 'neutral',
  REVOKED: 'red',
};

const INVITATION_STATUS_LABEL: Record<string, string> = {
  PENDING: 'En attente',
  USED: 'Utilisée',
  EXPIRED: 'Expirée',
  REVOKED: 'Révoquée',
};

export function InvitationStatusBadge({ status }: { status: string }) {
  return (
    <Badge tone={INVITATION_STATUS_TONE[status] ?? 'neutral'}>
      {INVITATION_STATUS_LABEL[status] ?? status}
    </Badge>
  );
}

const BET_STATUS_TONE: Record<string, Tone> = {
  PENDING: 'neutral',
  ACTIVE: 'blue',
  CASHED_OUT: 'green',
  LOST: 'red',
  CANCELLED: 'amber',
};

const BET_STATUS_LABEL: Record<string, string> = {
  PENDING: 'En attente',
  ACTIVE: 'Active',
  CASHED_OUT: 'Encaissée',
  LOST: 'Perdue',
  CANCELLED: 'Annulée',
};

export function BetStatusBadge({ status }: { status: string }) {
  return (
    <Badge tone={BET_STATUS_TONE[status] ?? 'neutral'}>{BET_STATUS_LABEL[status] ?? status}</Badge>
  );
}

export function RoleBadge({ role }: { role: string }) {
  return (
    <Badge tone={role === 'SUPER_ADMIN' ? 'violet' : 'blue'}>
      {role === 'SUPER_ADMIN' ? 'Super admin' : 'Sous-admin'}
    </Badge>
  );
}

export function ActiveInactiveBadge({ active }: { active: boolean }) {
  return <Badge tone={active ? 'green' : 'neutral'}>{active ? 'Actif' : 'Désactivé'}</Badge>;
}
