import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { errorMessage } from '../context/ToastContext';
import { supabase } from '../lib/supabase';
import { hasActivePlayerProfile } from '../services/playerAccess';

export function PlayerLoginPage() {
  const { session, loading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [checking, setChecking] = useState(false);
  const [error, setError] = useState<string | null>(
    (location.state as { denied?: boolean } | null)?.denied
      ? 'Ce compte ne possède pas de profil joueur actif.'
      : null,
  );

  useEffect(() => {
    let active = true;

    async function redirectActivePlayer() {
      if (loading || !session) return;
      setChecking(true);
      try {
        if (await hasActivePlayerProfile(session.user.id)) {
          navigate('/predictor', { replace: true });
        } else {
          if (active) {
            setError('Ce compte ne possède pas de profil joueur actif.');
            setChecking(false);
          }
          await supabase.auth.signOut();
        }
      } catch (checkError) {
        if (active) {
          setError(errorMessage(checkError));
          setChecking(false);
        }
        await supabase.auth.signOut();
      } finally {
        if (active) setChecking(false);
      }
    }

    void redirectActivePlayer();
    return () => {
      active = false;
    };
  }, [loading, navigate, session]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);

    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });

      if (signInError) {
        setError('Email ou mot de passe incorrect.');
      }
    } catch (signInError) {
      setError(errorMessage(signInError));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#078a43] px-5 py-10 text-white">
      <section className="w-full max-w-sm rounded-3xl border border-white/20 bg-black/10 p-6 shadow-2xl backdrop-blur-sm sm:p-8">
        <div className="mb-8 text-center">
          <p className="text-sm font-black tracking-[0.24em]">
            CRASH<span className="text-[#b9ffcf]">X</span>
          </p>
          <h1 className="mt-5 text-2xl font-bold">Connexion joueur</h1>
          <p className="mt-2 text-sm text-white/75">
            Utilisez les mêmes identifiants que dans l’application CRASHX.
          </p>
        </div>

        <form className="space-y-4" onSubmit={(event) => void handleSubmit(event)}>
          <label className="block text-sm font-medium">
            Adresse email
            <input
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="mt-1.5 w-full rounded-xl border border-white/25 bg-black/15 px-4 py-3 text-white outline-none placeholder:text-white/50 focus:border-white/70"
              placeholder="joueur@exemple.com"
            />
          </label>

          <label className="block text-sm font-medium">
            Mot de passe
            <input
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="mt-1.5 w-full rounded-xl border border-white/25 bg-black/15 px-4 py-3 text-white outline-none placeholder:text-white/50 focus:border-white/70"
              placeholder="Votre mot de passe"
            />
          </label>

          {error && (
            <p role="alert" className="rounded-xl border border-red-100/30 bg-red-950/20 px-3 py-2 text-sm">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={submitting || checking || loading}
            className="w-full rounded-xl bg-white px-4 py-3 font-bold text-[#087a3e] transition hover:bg-white/90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submitting || checking ? 'Connexion…' : 'Se connecter'}
          </button>
        </form>

        <p className="mt-6 text-center text-xs leading-5 text-white/65">
          Démonstration CRASHX · Argent virtuel uniquement
        </p>
      </section>
    </main>
  );
}
