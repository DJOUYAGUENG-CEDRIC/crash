import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../context/AuthContext';
import { useToast, errorMessage } from '../context/ToastContext';
import { InvitationStatusBadge } from '../components/Badge';
import { Button } from '../components/Button';
import { Modal } from '../components/Modal';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { FieldWrapper, TextInput } from '../components/FormField';
import { listInvitations, createInvitation, revokeInvitation } from '../services/invitations';
import type { InvitationRow } from '../types/database';
import { formatDate } from '../lib/format';
import { buildInvitationLink } from '../constants';

export function InvitationsPage() {
  const { hasPermission } = useAuth();
  const { showError, showSuccess } = useToast();
  const [invitations, setInvitations] = useState<InvitationRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);
  const [revokeTarget, setRevokeTarget] = useState<InvitationRow | null>(null);
  const [busy, setBusy] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const canCreate = hasPermission('CREATE_INVITATIONS');
  const canManage = hasPermission('MANAGE_INVITATIONS');

  async function load() {
    setLoading(true);
    try {
      setInvitations(await listInvitations());
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

  async function handleCopy(inv: InvitationRow) {
    const link = buildInvitationLink(inv.token);
    try {
      await navigator.clipboard.writeText(link);
      setCopiedId(inv.id);
      setTimeout(() => setCopiedId(null), 2000);
    } catch {
      showError('Impossible de copier le lien.');
    }
  }

  async function handleRevoke() {
    if (!revokeTarget) return;
    setBusy(true);
    try {
      await revokeInvitation(revokeTarget.id);
      showSuccess('Invitation révoquée.');
      setRevokeTarget(null);
      await load();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-zinc-50">Invitations</h1>
          <p className="text-sm text-zinc-500">Invitations personnelles pour rejoindre CRASH.</p>
        </div>
        {canCreate && (
          <Button variant="primary" onClick={() => setCreateOpen(true)}>
            + Créer une invitation
          </Button>
        )}
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-800">
        <table className="min-w-full divide-y divide-zinc-800 text-sm">
          <thead className="bg-zinc-900/60">
            <tr className="text-left text-xs font-medium uppercase tracking-wide text-zinc-500">
              <th className="px-4 py-3">Nom invité</th>
              <th className="px-4 py-3">Lien</th>
              <th className="px-4 py-3">Statut</th>
              <th className="px-4 py-3">Appareils max</th>
              <th className="px-4 py-3">Expire le</th>
              <th className="px-4 py-3">Créée le</th>
              {canManage && <th className="px-4 py-3 text-right">Actions</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {loading ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-zinc-500">Chargement…</td>
              </tr>
            ) : invitations.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-6 text-center text-zinc-500">Aucune invitation.</td>
              </tr>
            ) : (
              invitations.map((inv) => (
                <tr key={inv.id} className="hover:bg-zinc-900/40">
                  <td className="px-4 py-3">
                    <div className="font-medium text-zinc-100">{inv.invited_name}</div>
                    {inv.invited_email && <div className="text-xs text-zinc-500">{inv.invited_email}</div>}
                  </td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => void handleCopy(inv)}
                      className="rounded-md bg-zinc-800 px-2 py-1 text-xs font-mono text-zinc-300 hover:bg-zinc-700"
                      title={buildInvitationLink(inv.token)}
                    >
                      {copiedId === inv.id ? 'Copié !' : `${inv.token.slice(0, 10)}… 📋`}
                    </button>
                  </td>
                  <td className="px-4 py-3"><InvitationStatusBadge status={inv.status} /></td>
                  <td className="px-4 py-3 text-zinc-400">{inv.max_devices}</td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(inv.expires_at)}</td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(inv.created_at)}</td>
                  {canManage && (
                    <td className="px-4 py-3 text-right">
                      {inv.status === 'PENDING' && (
                        <Button variant="danger" onClick={() => setRevokeTarget(inv)}>
                          Révoquer
                        </Button>
                      )}
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {createOpen && (
        <CreateInvitationModal
          onClose={() => setCreateOpen(false)}
          onSuccess={() => {
            setCreateOpen(false);
            void load();
          }}
        />
      )}

      <ConfirmDialog
        open={!!revokeTarget}
        title="Révoquer l'invitation"
        message={`Confirmez-vous la révocation de l'invitation destinée à ${revokeTarget?.invited_name} ?`}
        confirmLabel="Révoquer"
        danger
        busy={busy}
        onConfirm={() => void handleRevoke()}
        onCancel={() => setRevokeTarget(null)}
      />
    </div>
  );
}

function CreateInvitationModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const { showError, showSuccess } = useToast();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [expiresHours, setExpiresHours] = useState('24');
  const [maxDevices, setMaxDevices] = useState('1');
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      await createInvitation({
        invited_name: name,
        invited_email: email || null,
        expires_hours: Number(expiresHours),
        max_devices: Number(maxDevices),
      });
      showSuccess('Invitation créée.');
      onSuccess();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open onClose={onClose} title="Créer une invitation">
      <form onSubmit={handleSubmit}>
        <FieldWrapper label="Nom de l'invité">
          <TextInput value={name} onChange={(e) => setName(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Email (optionnel)">
          <TextInput type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </FieldWrapper>
        <FieldWrapper label="Expiration (heures)">
          <TextInput type="number" min="1" value={expiresHours} onChange={(e) => setExpiresHours(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Nombre d'appareils max">
          <TextInput type="number" min="1" value={maxDevices} onChange={(e) => setMaxDevices(e.target.value)} required />
        </FieldWrapper>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" type="button" onClick={onClose}>Annuler</Button>
          <Button variant="primary" type="submit" disabled={saving}>
            {saving ? 'Création…' : "Créer l'invitation"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
