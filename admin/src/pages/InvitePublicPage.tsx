import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { CrashxLogo } from '../components/CrashxLogo';
import { formatRelativeTime, isPast } from '../lib/format';

interface InvitationInfo {
  invited_name: string;
  expires_at: string;
  status: string;
  valid: boolean;
}

export function InvitePublicPage() {
  const { token } = useParams<{ token: string }>();
  const [info, setInfo] = useState<InvitationInfo | null>(null);
  const [downloadUrl, setDownloadUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    let mounted = true;
    async function load() {
      if (!token) {
        setNotFound(true);
        setLoading(false);
        return;
      }
      try {
        // `get-invitation` is a public GET endpoint with the token as a query
        // param, so we call it via a plain fetch rather than functions.invoke
        // (which is designed around POST + JSON body).
        const functionsUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/get-invitation?token=${encodeURIComponent(token)}`;
        const res = await fetch(functionsUrl, {
          headers: {
            apikey: import.meta.env.VITE_SUPABASE_ANON_KEY as string,
          },
        });
        if (!mounted) return;
        if (res.status === 404) {
          setNotFound(true);
        } else {
          const json = (await res.json()) as InvitationInfo;
          setInfo(json);
        }
      } catch {
        if (mounted) setNotFound(true);
      } finally {
        if (mounted) setLoading(false);
      }

      try {
        const { data: app } = await supabase.from('app_settings').select('download_url').eq('id', 1).maybeSingle();
        if (mounted && app) setDownloadUrl(app.download_url);
      } catch {
        // non-fatal — download button will be hidden if this fails
      }
    }
    void load();
    return () => {
      mounted = false;
    };
  }, [token]);

  const expired = info ? info.status === 'EXPIRED' || isPast(info.expires_at) : false;
  const usable = info?.valid && info.status === 'PENDING' && !expired;

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-950 px-4">
      <div className="w-full max-w-sm text-center">
        <div className="mb-8 flex flex-col items-center gap-2">
          <CrashxLogo className="text-2xl" />
        </div>

        <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-6 shadow-xl">
          {loading ? (
            <p className="text-sm text-zinc-500">Chargement de l'invitation…</p>
          ) : notFound || !info ? (
            <>
              <p className="mb-1 text-lg font-semibold text-red-400">Invitation introuvable</p>
              <p className="text-sm text-zinc-500">Ce lien d'invitation n'existe pas ou n'est plus valide.</p>
            </>
          ) : (
            <>
              <p className="text-xs uppercase tracking-wide text-zinc-500">Invitation personnelle</p>
              <p className="mt-1 text-xl font-semibold text-zinc-50">Utilisateur : {info.invited_name}</p>

              {usable ? (
                <>
                  <p className="mt-2 text-sm text-zinc-400">
                    Expiration : {formatRelativeTime(info.expires_at)}
                  </p>
                  <div className="mt-5 rounded-md border border-amber-500/20 bg-amber-500/10 px-3 py-2 text-xs text-amber-400">
                    MODE DÉMONSTRATION — argent virtuel uniquement, aucune valeur réelle.
                  </div>
                  {downloadUrl ? (
                    <a
                      href={downloadUrl}
                      className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-md bg-violet-600 px-4 py-3 text-sm font-semibold text-white hover:bg-violet-500"
                    >
                      TÉLÉCHARGER L'APK
                    </a>
                  ) : (
                    <p className="mt-5 text-xs text-zinc-600">Lien de téléchargement indisponible pour le moment.</p>
                  )}
                </>
              ) : (
                <p className="mt-3 text-sm text-red-400">
                  {info.status === 'USED'
                    ? 'Cette invitation a déjà été utilisée.'
                    : info.status === 'REVOKED'
                      ? 'Cette invitation a été révoquée.'
                      : 'Cette invitation a expiré.'}
                </p>
              )}
            </>
          )}
        </div>

        <p className="mt-6 text-xs text-zinc-600">CRASHX — Environnement de démonstration, argent virtuel uniquement.</p>
      </div>
    </div>
  );
}
