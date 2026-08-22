import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useToast, errorMessage } from '../context/ToastContext';
import { ActiveInactiveBadge, RoleBadge } from '../components/Badge';
import { Button } from '../components/Button';
import { Modal } from '../components/Modal';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { FieldWrapper, TextInput } from '../components/FormField';
import { PermissionCheckboxGrid } from '../components/PermissionCheckboxGrid';
import {
  listSubAdmins,
  createSubAdmin,
  setSubAdminPermissions,
  updateSubAdmin,
  deactivateSubAdmin,
  reactivateSubAdmin,
  deleteSubAdmin,
} from '../services/subAdmins';
import type { SubAdminWithPermissions } from '../services/subAdmins';
import { PERMISSION_LABELS } from '../types/database';
import type { AdminPermission } from '../types/database';
import { formatDate } from '../lib/format';

export function SubAdminsPage() {
  const { showError, showSuccess } = useToast();
  const [admins, setAdmins] = useState<SubAdminWithPermissions[]>([]);
  const [loading, setLoading] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<SubAdminWithPermissions | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<SubAdminWithPermissions | null>(null);
  const [toggleTarget, setToggleTarget] = useState<{ admin: SubAdminWithPermissions; activate: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    setLoading(true);
    try {
      setAdmins(await listSubAdmins());
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

  async function handleToggle() {
    if (!toggleTarget) return;
    setBusy(true);
    try {
      if (toggleTarget.activate) await reactivateSubAdmin(toggleTarget.admin.id);
      else await deactivateSubAdmin(toggleTarget.admin.id);
      showSuccess(toggleTarget.activate ? 'Sous-compte réactivé.' : 'Sous-compte désactivé.');
      setToggleTarget(null);
      await load();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setBusy(true);
    try {
      await deleteSubAdmin(deleteTarget.id);
      showSuccess('Sous-compte supprimé.');
      setDeleteTarget(null);
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
          <h1 className="text-xl font-semibold text-zinc-50">Sous-comptes</h1>
          <p className="text-sm text-zinc-500">Administrateurs délégués et leurs permissions.</p>
        </div>
        <Button variant="primary" onClick={() => setCreateOpen(true)}>
          + Créer un sous-compte
        </Button>
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-800">
        <table className="min-w-full divide-y divide-zinc-800 text-sm">
          <thead className="bg-zinc-900/60">
            <tr className="text-left text-xs font-medium uppercase tracking-wide text-zinc-500">
              <th className="px-4 py-3">Nom</th>
              <th className="px-4 py-3">Rôle</th>
              <th className="px-4 py-3">Permissions</th>
              <th className="px-4 py-3">Statut</th>
              <th className="px-4 py-3">Créé le</th>
              <th className="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {loading ? (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-zinc-500">Chargement…</td>
              </tr>
            ) : admins.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-zinc-500">Aucun sous-compte.</td>
              </tr>
            ) : (
              admins.map((a) => (
                <tr key={a.id} className="hover:bg-zinc-900/40">
                  <td className="px-4 py-3 font-medium text-zinc-100">{a.display_name ?? '—'}</td>
                  <td className="px-4 py-3"><RoleBadge role={a.role} /></td>
                  <td className="px-4 py-3">
                    <div className="flex max-w-xs flex-wrap gap-1">
                      {a.granted_permissions.length === 0 ? (
                        <span className="text-xs text-zinc-600">Aucune</span>
                      ) : (
                        a.granted_permissions.slice(0, 3).map((p) => (
                          <span key={p} className="rounded bg-zinc-800 px-1.5 py-0.5 text-[11px] text-zinc-400">
                            {PERMISSION_LABELS[p].split(' ')[0]}
                          </span>
                        ))
                      )}
                      {a.granted_permissions.length > 3 && (
                        <span className="rounded bg-zinc-800 px-1.5 py-0.5 text-[11px] text-zinc-500">
                          +{a.granted_permissions.length - 3}
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3"><ActiveInactiveBadge active={a.is_active} /></td>
                  <td className="px-4 py-3 text-zinc-500">{formatDate(a.created_at)}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2">
                      <Button variant="secondary" onClick={() => setEditTarget(a)}>Modifier</Button>
                      <Button
                        variant={a.is_active ? 'secondary' : 'primary'}
                        onClick={() => setToggleTarget({ admin: a, activate: !a.is_active })}
                      >
                        {a.is_active ? 'Désactiver' : 'Réactiver'}
                      </Button>
                      <Button variant="danger" onClick={() => setDeleteTarget(a)}>Supprimer</Button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {createOpen && (
        <CreateSubAdminModal
          onClose={() => setCreateOpen(false)}
          onSuccess={() => {
            setCreateOpen(false);
            void load();
          }}
        />
      )}

      {editTarget && (
        <EditSubAdminModal
          admin={editTarget}
          onClose={() => setEditTarget(null)}
          onSuccess={() => {
            setEditTarget(null);
            void load();
          }}
        />
      )}

      <ConfirmDialog
        open={!!toggleTarget}
        title={toggleTarget?.activate ? 'Réactiver le sous-compte' : 'Désactiver le sous-compte'}
        message={`Confirmez-vous cette action pour ${toggleTarget?.admin.display_name ?? 'ce sous-compte'} ?`}
        danger={!toggleTarget?.activate}
        busy={busy}
        onConfirm={() => void handleToggle()}
        onCancel={() => setToggleTarget(null)}
      />

      <ConfirmDialog
        open={!!deleteTarget}
        title="Supprimer le sous-compte"
        message={`Cette action est irréversible. Confirmez-vous la suppression de ${deleteTarget?.display_name ?? 'ce sous-compte'} ?`}
        confirmLabel="Supprimer"
        danger
        busy={busy}
        onConfirm={() => void handleDelete()}
        onCancel={() => setDeleteTarget(null)}
      />
    </div>
  );
}

function CreateSubAdminModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const { showError, showSuccess } = useToast();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [permissions, setPermissions] = useState<Set<AdminPermission>>(new Set());
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const { admin_id } = await createSubAdmin({ email, password, display_name: displayName });
      if (permissions.size > 0) {
        await setSubAdminPermissions(admin_id, Array.from(permissions));
      }
      showSuccess('Sous-compte créé.');
      onSuccess();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open onClose={onClose} title="Créer un sous-compte" widthClass="max-w-lg">
      <form onSubmit={handleSubmit}>
        <FieldWrapper label="Nom affiché">
          <TextInput value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Email">
          <TextInput type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Mot de passe initial">
          <TextInput
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            minLength={8}
            required
          />
        </FieldWrapper>
        <FieldWrapper label="Permissions accordées">
          <PermissionCheckboxGrid value={permissions} onChange={setPermissions} />
        </FieldWrapper>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" type="button" onClick={onClose}>Annuler</Button>
          <Button variant="primary" type="submit" disabled={saving}>
            {saving ? 'Création…' : 'Créer le sous-compte'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

function EditSubAdminModal({
  admin,
  onClose,
  onSuccess,
}: {
  admin: SubAdminWithPermissions;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const { showError, showSuccess } = useToast();
  const [displayName, setDisplayName] = useState(admin.display_name ?? '');
  const [permissions, setPermissions] = useState<Set<AdminPermission>>(new Set(admin.granted_permissions));
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      await updateSubAdmin(admin.id, displayName);
      await setSubAdminPermissions(admin.id, Array.from(permissions));
      showSuccess('Sous-compte mis à jour.');
      onSuccess();
    } catch (err) {
      showError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open onClose={onClose} title={`Modifier — ${admin.display_name ?? ''}`} widthClass="max-w-lg">
      <form onSubmit={handleSubmit}>
        <FieldWrapper label="Nom affiché">
          <TextInput value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
        </FieldWrapper>
        <FieldWrapper label="Permissions accordées">
          <PermissionCheckboxGrid value={permissions} onChange={setPermissions} />
        </FieldWrapper>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="ghost" type="button" onClick={onClose}>Annuler</Button>
          <Button variant="primary" type="submit" disabled={saving}>
            {saving ? 'Enregistrement…' : 'Enregistrer'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
