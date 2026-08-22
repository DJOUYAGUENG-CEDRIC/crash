import type { ReactNode } from 'react';

interface StatCardProps {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  icon?: ReactNode;
  accent?: 'violet' | 'green' | 'blue' | 'amber' | 'red';
}

const ACCENT_CLASSES: Record<string, string> = {
  violet: 'text-violet-400 bg-violet-500/10',
  green: 'text-emerald-400 bg-emerald-500/10',
  blue: 'text-blue-400 bg-blue-500/10',
  amber: 'text-amber-400 bg-amber-500/10',
  red: 'text-red-400 bg-red-500/10',
};

export function StatCard({ label, value, hint, icon, accent = 'violet' }: StatCardProps) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-4 shadow-sm">
      <div className="flex items-start justify-between">
        <p className="text-xs font-medium uppercase tracking-wide text-zinc-500">{label}</p>
        {icon && (
          <span className={`rounded-md p-1.5 text-sm ${ACCENT_CLASSES[accent]}`}>{icon}</span>
        )}
      </div>
      <p className="mt-2 text-2xl font-semibold text-zinc-50">{value}</p>
      {hint && <p className="mt-1 text-xs text-zinc-500">{hint}</p>}
    </div>
  );
}
