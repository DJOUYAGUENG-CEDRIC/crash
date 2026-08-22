import { supabase } from '../lib/supabase';
import type { AdminLogRow } from '../types/database';

export interface AdminLogWithAdmin extends AdminLogRow {
  admin_display_name: string | null;
}

const PAGE_SIZE = 25;

export async function listAdminLogsPage(page: number): Promise<{ rows: AdminLogWithAdmin[]; total: number }> {
  const from = page * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  const { data: logs, error: logsError, count } = await supabase
    .from('admin_logs')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, to);

  if (logsError) throw logsError;

  const adminIds = Array.from(new Set((logs ?? []).map((l) => l.admin_id)));
  let nameById = new Map<string, string | null>();
  if (adminIds.length > 0) {
    const { data: admins, error: adminsError } = await supabase
      .from('admin_users')
      .select('id, display_name')
      .in('id', adminIds);
    if (adminsError) throw adminsError;
    nameById = new Map((admins ?? []).map((a) => [a.id, a.display_name]));
  }

  return {
    rows: (logs ?? []).map((l) => ({ ...l, admin_display_name: nameById.get(l.admin_id) ?? null })),
    total: count ?? 0,
  };
}

export const ADMIN_LOGS_PAGE_SIZE = PAGE_SIZE;
