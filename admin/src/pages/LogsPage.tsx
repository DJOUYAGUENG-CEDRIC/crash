import { useEffect, useState } from 'react';
import { useToast, errorMessage } from '../context/ToastContext';
import { Button } from '../components/Button';
import { listAdminLogsPage, ADMIN_LOGS_PAGE_SIZE } from '../services/logs';
import type { AdminLogWithAdmin } from '../services/logs';
import { formatDate } from '../lib/format';

export function LogsPage() {
  const { showError } = useToast();
  const [rows, setRows] = useState<AdminLogWithAdmin[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  useEffect(() => {
    let mounted = true;
    async function load() {
      setLoading(true);
      try {
        const { rows: r, total: t } = await listAdminLogsPage(page);
        if (!mounted) return;
        setRows(r);
        setTotal(t);
      } catch (err) {
        showError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    }
    void load();
    return () => {
      mounted = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  function toggle(id: string) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const totalPages = Math.max(1, Math.ceil(total / ADMIN_LOGS_PAGE_SIZE));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-zinc-50">Journaux d'activité</h1>
        <p className="text-sm text-zinc-500">Historique en lecture seule des actions administratives.</p>
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-800">
        <table className="min-w-full divide-y divide-zinc-800 text-sm">
          <thead className="bg-zinc-900/60">
            <tr className="text-left text-xs font-medium uppercase tracking-wide text-zinc-500">
              <th className="px-4 py-3">Admin</th>
              <th className="px-4 py-3">Action</th>
              <th className="px-4 py-3">Cible</th>
              <th className="px-4 py-3">Détails</th>
              <th className="px-4 py-3">Date</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {loading ? (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-zinc-500">Chargement…</td>
              </tr>
            ) : rows.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-zinc-500">Aucun journal.</td>
              </tr>
            ) : (
              rows.map((log) => (
                <tr key={log.id} className="align-top hover:bg-zinc-900/40">
                  <td className="px-4 py-3 text-zinc-300">{log.admin_display_name ?? log.admin_id.slice(0, 8)}</td>
                  <td className="px-4 py-3 font-mono text-xs text-violet-300">{log.action}</td>
                  <td className="px-4 py-3 text-zinc-400">
                    {log.target_type ? `${log.target_type}${log.target_id ? ` · ${log.target_id.slice(0, 8)}` : ''}` : '—'}
                  </td>
                  <td className="px-4 py-3">
                    {log.metadata && Object.keys(log.metadata).length > 0 ? (
                      <>
                        <button
                          onClick={() => toggle(log.id)}
                          className="text-xs text-zinc-500 underline hover:text-zinc-300"
                        >
                          {expanded.has(log.id) ? 'Masquer' : 'Voir le JSON'}
                        </button>
                        {expanded.has(log.id) && (
                          <pre className="mt-1 max-w-md overflow-x-auto rounded bg-zinc-950 p-2 text-[11px] text-zinc-400">
                            {JSON.stringify(log.metadata, null, 2)}
                          </pre>
                        )}
                      </>
                    ) : (
                      <span className="text-xs text-zinc-600">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(log.created_at)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="mt-4 flex items-center justify-between text-sm text-zinc-500">
        <span>
          Page {page + 1} / {totalPages} ({total} entrées)
        </span>
        <div className="flex gap-2">
          <Button variant="secondary" disabled={page === 0} onClick={() => setPage((p) => Math.max(0, p - 1))}>
            Précédent
          </Button>
          <Button
            variant="secondary"
            disabled={page + 1 >= totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Suivant
          </Button>
        </div>
      </div>
    </div>
  );
}
