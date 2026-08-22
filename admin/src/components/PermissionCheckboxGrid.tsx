import { ALL_PERMISSIONS, PERMISSION_LABELS } from '../types/database';
import type { AdminPermission } from '../types/database';

interface PermissionCheckboxGridProps {
  value: Set<AdminPermission>;
  onChange: (next: Set<AdminPermission>) => void;
  disabled?: boolean;
}

export function PermissionCheckboxGrid({ value, onChange, disabled }: PermissionCheckboxGridProps) {
  function toggle(permission: AdminPermission) {
    const next = new Set(value);
    if (next.has(permission)) next.delete(permission);
    else next.add(permission);
    onChange(next);
  }

  return (
    <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
      {ALL_PERMISSIONS.map((permission) => (
        <label
          key={permission}
          className={`flex cursor-pointer items-start gap-2 rounded-md border border-zinc-800 bg-zinc-950/50 px-3 py-2 text-sm hover:border-zinc-700 ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
        >
          <input
            type="checkbox"
            className="mt-0.5 h-4 w-4 rounded border-zinc-600 bg-zinc-800 text-violet-600 focus:ring-violet-500"
            checked={value.has(permission)}
            disabled={disabled}
            onChange={() => toggle(permission)}
          />
          <span className="text-zinc-300">{PERMISSION_LABELS[permission]}</span>
        </label>
      ))}
    </div>
  );
}
