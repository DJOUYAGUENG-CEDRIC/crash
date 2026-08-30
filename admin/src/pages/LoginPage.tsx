import { useState } from 'react';
import type { FormEvent } from 'react';
import { Navigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { CrashxLogo } from '../components/CrashxLogo';
import { TextInput, FieldWrapper } from '../components/FormField';
import { Button } from '../components/Button';
import { errorMessage } from '../context/ToastContext';

export function LoginPage() {
  const { session, adminRole, loading, accessDenied } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!loading && session && adminRole) {
    return <Navigate to="/" replace />;
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
      if (signInError) {
        setError("Identifiants invalides. Vérifiez votre email et votre mot de passe.");
        return;
      }
      // AuthContext will pick up the new session and verify admin_users membership.
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-950 px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center gap-2">
          <CrashxLogo className="text-2xl" />
          <p className="text-sm text-zinc-500">Console d'administration</p>
        </div>

        <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-6 shadow-xl">
          {accessDenied && (
            <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/10 px-3 py-3 text-center">
              <p className="text-sm font-semibold text-red-400">ACCÈS REFUSÉ</p>
              <p className="mt-1 text-xs text-red-300/80">
                Ce compte n'est pas autorisé à accéder au tableau de bord d'administration.
              </p>
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <FieldWrapper label="Adresse email">
              <TextInput
                type="email"
                required
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@crash.app"
              />
            </FieldWrapper>
            <FieldWrapper label="Mot de passe">
              <TextInput
                type="password"
                required
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </FieldWrapper>

            {error && (
              <p className="mb-3 rounded-md bg-red-500/10 px-3 py-2 text-xs text-red-400">{error}</p>
            )}

            <Button
              type="submit"
              variant="primary"
              disabled={submitting}
              className="w-full justify-center py-2"
            >
              {submitting ? 'Connexion…' : 'Se connecter'}
            </Button>
          </form>
        </div>

        <p className="mt-6 text-center text-xs text-zinc-600">
          Accès réservé aux administrateurs.
        </p>
      </div>
    </div>
  );
}
