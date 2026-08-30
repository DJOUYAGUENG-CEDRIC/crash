import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../context/AuthContext';
import { useToast, errorMessage } from '../context/ToastContext';
import { AccountStatusBadge, BetStatusBadge } from '../components/Badge';
import { Button } from '../components/Button';
import { Modal } from '../components/Modal';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { FieldWrapper, TextInput } from '../components/FormField';
import {
  listUsersWithWallets,
  blockUser,
  unblockUser,
  adjustBalance,
  getUserTransactions,
  getUserBets,
} from '../services/users';
import type { UserWithWallet } from '../services/users';
import type { BetRow, TransactionRow } from '../types/database';
import { formatAmount, formatDate, formatSignedAmount, formatMultiplier } from '../lib/format';

export function UsersPage() {
  const { hasPermission } = useAuth();
  const { showError, showSuccess } = useToast();

  const [users, setUsers] = useState<UserWithWallet[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedUser, setSelectedUser] = useState<UserWithWallet | null>(null);
  const [adjustTarget, setAdjustTarget] = useState<UserWithWallet | null>(null);
  const [blockTarget, setBlockTarget] = useState<{ user: UserWithWallet; block: boolean } | null>(null);
  const [actionBusy, setActionBusy] = useState(false);

  const canManage = hasPermission('MANAGE_USERS');
  const canBlock = hasPermission('BLOCK_USERS');

  async function load() {
    setLoading(true);
    try {
      const data = await listUsersWithWallets();
      setUsers(data);
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const filtered = users.filter((u) => {
    const q = search.toLowerCase();
    return (
      (u.display_name ?? '').toLowerCase().includes(q) || u.email.toLowerCase().includes(q)
    );
  });

  async function handleToggleBlock() {
    if (!blockTarget) return;
    setActionBusy(true);
    try {
      if (blockTarget.block) await blockUser(blockTarget.user.id);
      else await unblockUser(blockTarget.user.id);
      showSuccess(blockTarget.block ? 'Utilisateur bloqué.' : 'Utilisateur débloqué.');
      setBlockTarget(null);
      await load();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setActionBusy(false);
    }
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-zinc-50">Utilisateurs</h1>
          <p className="text-sm text-zinc-500">Comptes joueurs et soldes en FCFA.</p>
        </div>
        <TextInput
          placeholder="Rechercher un utilisateur…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-64"
        />
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-800">
        <table className="min-w-full divide-y divide-zinc-800 text-sm">
          <thead className="bg-zinc-900/60">
            <tr className="text-left text-xs font-medium uppercase tracking-wide text-zinc-500">
              <th className="px-4 py-3">Nom</th>
              <th className="px-4 py-3">Email</th>
              <th className="px-4 py-3">Statut</th>
              <th className="px-4 py-3">Solde</th>
              <th className="px-4 py-3">Dernière activité</th>
              <th className="px-4 py-3">Créé le</th>
              <th className="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {loading ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-zinc-500">
                  Chargement…
                </td>
              </tr>
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-zinc-500">
                  Aucun utilisateur trouvé.
                </td>
              </tr>
            ) : (
              filtered.map((u) => (
                <tr key={u.id} className="hover:bg-zinc-900/40">
                  <td className="px-4 py-3">
                    <button
                      className="font-medium text-zinc-100 hover:text-violet-400"
                      onClick={() => setSelectedUser(u)}
                    >
                      {u.display_name ?? '—'}
                    </button>
                  </td>
                  <td className="px-4 py-3 text-zinc-400">{u.email}</td>
                  <td className="px-4 py-3">
                    <AccountStatusBadge status={u.status} />
                  </td>
                  <td className="px-4 py-3 font-medium text-zinc-200">{formatAmount(u.balance)}</td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(u.last_device_activity)}</td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(u.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      {canManage && (
                        <Button variant="secondary" onClick={() => setAdjustTarget(u)}>
                          Ajuster le solde
                        </Button>
                      )}
                      {canBlock && (
                        <Button
                          variant={u.status === 'ACTIVE' ? 'danger' : 'primary'}
                          onClick={() => setBlockTarget({ user: u, block: u.status === 'ACTIVE' })}
                        >
                          {u.status === 'ACTIVE' ? 'Bloquer' : 'Débloquer'}
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {adjustTarget && (
        <AdjustBalanceModal
          user={adjustTarget}
          onClose={() => setAdjustTarget(null)}
          onSuccess={() => {
            setAdjustTarget(null);
            void load();
          }}
        />
      )}

      {selectedUser && <UserDetailModal user={selectedUser} onClose={() => setSelectedUser(null)} />}

      <ConfirmDialog
        open={!!blockTarget}
        title={blockTarget?.block ? "Bloquer l'utilisateur" : "Débloquer l'utilisateur"}
        message={
          blockTarget?.block
            ? `Confirmez-vous le blocage de ${blockTarget.user.display_name ?? blockTarget.user.email} ? Il ne pourra plus se connecter.`
            : `Confirmez-vous le déblocage de ${blockTarget?.user.display_name ?? blockTarget?.user.email} ?`
        }
        danger={blockTarget?.block}
        busy={actionBusy}
        onConfirm={() => void handleToggleBlock()}
        onCancel={() => setBlockTarget(null)}
      />
    </div>
  );
}

function AdjustBalanceModal({
  user,
  onClose,
  onSuccess,
}: {
  user: UserWithWallet;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const { showError, showSuccess } = useToast();
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const parsed = Number(amount);
    if (!parsed || Number.isNaN(parsed)) {
      showError('Montant invalide.');
      return;
    }
    if (!reason.trim()) {
      showError('Veuillez indiquer un motif.');
      return;
    }
    setSaving(true);
    try {
      await adjustBalance(user.id, parsed, reason.trim());
      showSuccess('Solde ajusté.');
      onSuccess();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open onClose={onClose} title={`Ajuster le solde — ${user.display_name ?? user.email}`}>
      <form onSubmit={handleSubmit}>
        <p className="mb-3 text-xs text-zinc-500">
          Solde actuel : <span className="font-medium text-zinc-300">{formatAmount(user.balance)}</span>. Le
          montant peut être positif (crédit) ou négatif (débit), en FCFA.
        </p>
        <FieldWrapper label="Montant (positif ou négatif)">
          <TextInput
            type="number"
            step="1"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="ex: 5000 ou -2000"
            required
          />
        </FieldWrapper>
        <FieldWrapper label="Motif">
          <TextInput
            type="text"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="ex: Correction manuelle"
            required
          />
        </FieldWrapper>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" onClick={onClose} type="button">
            Annuler
          </Button>
          <Button variant="primary" type="submit" disabled={saving}>
            {saving ? 'Enregistrement…' : 'Valider'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

function UserDetailModal({ user, onClose }: { user: UserWithWallet; onClose: () => void }) {
  const { hasPermission } = useAuth();
  const { showError } = useToast();
  const [transactions, setTransactions] = useState<TransactionRow[]>([]);
  const [bets, setBets] = useState<BetRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<'transactions' | 'bets'>('transactions');

  const canViewBets = hasPermission('VIEW_BETS');
  const canViewStats = hasPermission('VIEW_STATISTICS');

  useEffect(() => {
    let mounted = true;
    async function load() {
      try {
        const [tx, b] = await Promise.all([
          canViewStats ? getUserTransactions(user.id) : Promise.resolve([]),
          canViewBets ? getUserBets(user.id) : Promise.resolve([]),
        ]);
        if (!mounted) return;
        setTransactions(tx);
        setBets(b);
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
  }, [user.id]);

  return (
    <Modal open onClose={onClose} title={user.display_name ?? user.email} widthClass="max-w-2xl">
      <div className="mb-4 flex gap-2 text-sm">
        <button
          className={`rounded-md px-3 py-1.5 ${tab === 'transactions' ? 'bg-violet-600/20 text-violet-300' : 'text-zinc-500 hover:bg-zinc-800'}`}
          onClick={() => setTab('transactions')}
        >
          Transactions
        </button>
        <button
          className={`rounded-md px-3 py-1.5 ${tab === 'bets' ? 'bg-violet-600/20 text-violet-300' : 'text-zinc-500 hover:bg-zinc-800'}`}
          onClick={() => setTab('bets')}
        >
          Mises
        </button>
      </div>

      {loading ? (
        <p className="text-sm text-zinc-500">Chargement…</p>
      ) : tab === 'transactions' ? (
        canViewStats ? (
          <div className="max-h-96 overflow-y-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="text-left text-xs uppercase text-zinc-500">
                  <th className="py-1.5">Type</th>
                  <th className="py-1.5">Montant</th>
                  <th className="py-1.5">Solde après</th>
                  <th className="py-1.5">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800">
                {transactions.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="py-4 text-center text-zinc-500">
                      Aucune transaction.
                    </td>
                  </tr>
                ) : (
                  transactions.map((t) => (
                    <tr key={t.id}>
                      <td className="py-1.5 text-zinc-300">{t.type}</td>
                      <td className={`py-1.5 font-medium ${t.amount >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                        {formatSignedAmount(t.amount)}
                      </td>
                      <td className="py-1.5 text-zinc-400">{formatAmount(t.balance_after)}</td>
                      <td className="py-1.5 text-zinc-500">{formatDate(t.created_at)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-zinc-500">Permission VIEW_STATISTICS requise.</p>
        )
      ) : canViewBets ? (
        <div className="max-h-96 overflow-y-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase text-zinc-500">
                <th className="py-1.5">Emplacement</th>
                <th className="py-1.5">Mise</th>
                <th className="py-1.5">Statut</th>
                <th className="py-1.5">Cashout</th>
                <th className="py-1.5">Gain</th>
                <th className="py-1.5">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {bets.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-4 text-center text-zinc-500">
                    Aucune mise.
                  </td>
                </tr>
              ) : (
                bets.map((b) => (
                  <tr key={b.id}>
                    <td className="py-1.5 text-zinc-300">Slot {b.slot}</td>
                    <td className="py-1.5 text-zinc-300">{formatAmount(b.amount)}</td>
                    <td className="py-1.5">
                      <BetStatusBadge status={b.status} />
                    </td>
                    <td className="py-1.5 text-zinc-400">{formatMultiplier(b.cashout_multiplier)}</td>
                    <td className="py-1.5 text-zinc-400">{b.payout ? formatAmount(b.payout) : '—'}</td>
                    <td className="py-1.5 text-zinc-500">{formatDate(b.placed_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="text-sm text-zinc-500">Permission VIEW_BETS requise.</p>
      )}
    </Modal>
  );
}
