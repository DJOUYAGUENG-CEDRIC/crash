export function CrashxLogo({ className = '' }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2 font-bold tracking-tight ${className}`}>
      <span className="flex h-7 w-7 items-center justify-center rounded-md bg-gradient-to-br from-violet-500 to-fuchsia-600 text-sm text-white shadow-lg shadow-violet-500/20">
        ⚡
      </span>
      <span className="bg-gradient-to-r from-violet-300 to-fuchsia-300 bg-clip-text text-transparent">
        CRASH
      </span>
    </span>
  );
}
