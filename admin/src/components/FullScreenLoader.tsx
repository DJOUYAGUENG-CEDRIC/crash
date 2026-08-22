export function FullScreenLoader() {
  return (
    <div className="flex h-screen w-full items-center justify-center bg-zinc-950">
      <div className="flex flex-col items-center gap-3">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-zinc-700 border-t-violet-500" />
        <span className="text-sm text-zinc-500">Chargement…</span>
      </div>
    </div>
  );
}
