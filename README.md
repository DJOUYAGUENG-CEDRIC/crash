# CRASHX DEMO

Prototype pédagogique de Crash Game **100% argent virtuel** (`FCFA VIRTUELS`).
Aucun dépôt, retrait, paiement ou portefeuille réel. Toujours affiché comme
**MODE DÉMO — ARGENT VIRTUEL**.

Identité propre CRASHX — aucune marque, logo ou asset 1xBet/Aviator n'est
utilisé ; seule l'ergonomie générale d'une application de betting moderne
est reprise (header compact, navigation inférieure, cartes, historique).

## Architecture

```
crashx/
├── mobile/     Flutter (Android) — l'application joueur
├── admin/      React + Vite + TypeScript + Tailwind — dashboard staff
└── supabase/   PostgreSQL, RLS, RPC, Edge Functions — source de vérité
```

Le serveur (Supabase/PostgreSQL) est la seule source de vérité pour les
soldes, mises, cashouts, résultats, permissions et rôles. Ni le client
Flutter ni le dashboard admin ne calculent quoi que ce soit de sensible —
ils appellent des fonctions RPC `SECURITY DEFINER` qui re-vérifient tout
côté serveur.

## 1. Prérequis

| Outil | Version conseillée | Vérifier avec |
|---|---|---|
| Flutter | stable (≥ 3.35) | `flutter --version` |
| Node.js | ≥ 20 | `node --version` |
| npm | ≥ 10 | `npm --version` |
| Git | toute version récente | `git --version` |
| JDK | 17 ou 21 | `java -version` |
| Android SDK (cmdline-tools + platform-tools + build-tools 34) | — | `flutter doctor` |
| Compte Supabase | — | https://supabase.com |

Lancer `flutter doctor -v` et corriger tout ce qui est marqué `[✗]` avant de
continuer (licences Android non acceptées : `flutter doctor --android-licenses`).

## 2. Configuration Supabase

1. Créer un nouveau projet sur https://supabase.com.
2. Dans **Authentication → Providers → Email**, désactiver **"Allow new
   users to sign up"**. C'est obligatoire : la création de compte ne doit
   se faire que via l'Edge Function `activate-invitation` (invitation
   obligatoire), jamais via l'inscription publique standard.
3. Appliquer les migrations dans l'ordre, depuis le **SQL Editor** du
   dashboard Supabase (copier-coller chaque fichier) ou via la CLI :

   ```bash
   npx supabase login
   npx supabase link --project-ref <votre-project-ref>
   npx supabase db push
   ```

   Fichiers, dans l'ordre : `supabase/migrations/0001_initial_schema.sql`
   → `0002_functions_and_triggers.sql` → `0003_rls_policies.sql` →
   `0004_game_engine_functions.sql` → `0005_admin_functions.sql`.

4. Déployer les Edge Functions :

   ```bash
   npx supabase functions deploy get-invitation --no-verify-jwt
   npx supabase functions deploy activate-invitation --no-verify-jwt
   npx supabase functions deploy create-sub-admin
   npx supabase functions deploy game-tick
   ```

5. Activer l'extension **pg_cron** (Database → Extensions), puis exécuter
   `supabase/seed.sql` **une seule fois**, à la main, depuis le SQL
   Editor (voir §3 ci-dessous — ce fichier n'est volontairement pas dans
   la chaîne de migrations automatique).

## 3. Création des deux Super Admin

Aucun bouton de l'application ne peut créer un `SUPER_ADMIN` — c'est
volontaire (spec §9). La procédure est manuelle et unique :

1. **Authentication → Users → Add user** dans le dashboard Supabase.
   Créer les deux comptes (email + mot de passe fort, "Auto Confirm
   User" activé). Partager les mots de passe hors de cette conversation
   / hors dépôt Git.
2. Ouvrir `supabase/seed.sql`, remplacer les deux emails placeholder par
   les emails réels, puis exécuter le script dans le SQL Editor. Il lie
   les deux comptes comme `SUPER_ADMIN` et programme le moteur de jeu
   (`pg_cron`).
3. Vérifier : `select * from admin_users;` doit montrer les deux lignes
   `role = 'SUPER_ADMIN'`.

## 4. Création des sous-comptes et configuration des permissions

Une fois connecté au dashboard admin (`admin/`) avec un des deux comptes
`SUPER_ADMIN` :

1. **Sous-comptes → Créer un sous-compte** (email, mot de passe,
   affichage) → crée le compte via l'Edge Function `create-sub-admin`
   (jamais de SQL manuel).
2. Cocher les permissions à accorder parmi les 14 disponibles
   (`VIEW_DASHBOARD`, `VIEW_USERS`, `VIEW_STATISTICS`, `VIEW_GAME`,
   `CONTROL_GAME`, `CONTROL_DEMO_MULTIPLIER`, `VIEW_BETS`,
   `MANAGE_USERS`, `BLOCK_USERS`, `MANAGE_DEVICES`,
   `CREATE_INVITATIONS`, `MANAGE_INVITATIONS`, `VIEW_LOGS`,
   `VIEW_SETTINGS`). Il n'existe **aucune** permission de type "créer un
   compte" — un sous-compte ne peut jamais créer ou modifier un autre
   compte administratif, ceci est appliqué par les RLS Postgres, pas
   seulement par l'interface.

## 5. Variables d'environnement

### Admin (`admin/.env`, voir `admin/.env.example`)

```
VITE_SUPABASE_URL=https://xxxxxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

### Mobile (passées au build, jamais commitées en dur)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

**Ne jamais** placer `SUPABASE_SERVICE_ROLE_KEY` dans `mobile/` ou
`admin/` — cette clé ne doit exister que côté Edge Functions (secrets
Supabase, injectés automatiquement à l'exécution).

## 6. Lancement local

### Admin

```bash
cd admin
npm install
npm run dev
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## 7. Tests

```bash
cd mobile
flutter analyze
flutter test

cd ../admin
npm run build
```

### Backend (RLS + RPC)

```bash
npx supabase test db
```

Runs `supabase/tests/database/access_control.test.sql` (pgTAP): RLS
isolation between players, the sub-admin-cannot-create-an-admin
invariant (both via RLS and the SUPER_ADMIN-cap trigger), `place_bet`/
`cashout_bet` validation, permission checks on admin RPCs, and the
`check_activation()` device-quota/version/account-status gate. Requires
a local Postgres (`supabase start`, Docker — dev/test only, not part of
the production architecture) or can be pointed at any Postgres with
this schema applied via `psql "$DATABASE_URL" -f supabase/tests/database/access_control.test.sql`.

## 8. Build APK Release

```bash
cd mobile
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

APK généré dans `mobile/build/app/outputs/flutter-apk/app-release.apk`.

> **Note Windows multi-disques** : si le projet et le SDK Flutter/le pub
> cache (`C:\Users\<vous>\AppData\Local\Pub\Cache`) sont sur des lettres
> de lecteur différentes (ex. projet sur `D:`), le compilateur Kotlin
> incrémental peut planter avec `IllegalArgumentException: this and
> base files have different roots`. C'est un bug connu de Kotlin/Gradle
> sur Windows (impossible de relativiser un chemin entre deux disques).
> Déjà corrigé dans ce dépôt via `kotlin.incremental=false` dans
> `mobile/android/gradle.properties` — à garder si vous êtes dans la
> même configuration.

## 9. Distribution contrôlée de l'APK

L'APK seul n'autorise jamais l'accès (spec §33). Chaque utilisateur a
besoin de : `APK + Compte + Autorisation + Appareil autorisé`. Flux :

1. Un admin avec la permission `CREATE_INVITATIONS` crée une invitation
   depuis le dashboard → génère un lien `https://crashx.app/invite/<token>`.
2. Ce lien ouvre la page publique (`admin/src/pages/InvitePublic.tsx`,
   route `/invite/:token`, sans authentification) qui affiche le nom
   invité, l'expiration, et un bouton "TÉLÉCHARGER L'APK".
3. Au premier lancement, l'utilisateur active son compte dans l'app
   avec le token d'invitation (Edge Function `activate-invitation`),
   ce qui crée son compte ET consomme l'invitation.
4. À chaque lancement/reprise, l'app appelle `check_activation()` côté
   serveur : compte actif ? appareil autorisé ? version à jour ? Un
   APK copié et partagé ne suffit donc jamais à lui seul.

## 10. Révocation

Dashboard → **Utilisateurs** (bloquer un compte) ou **Appareils**
(révoquer un appareil précis). Effectif à la prochaine vérification
serveur (`check_activation`), pas besoin de mise à jour de l'app.

## Sécurité — points clés

- RLS activé sur toutes les tables ; toute écriture sensible passe par
  des fonctions `SECURITY DEFINER` qui revérifient les permissions dans
  le code, jamais seulement dans l'UI (spec §12).
- Le multiplicateur cible (`game_rounds.target_multiplier`,
  `game_settings.next_manual_target_multiplier`) n'est jamais exposé aux
  clients joueurs — seule la vue `game_rounds_public` (colonnes
  filtrées) et les fonctions `place_bet`/`cashout_bet` leur sont
  accessibles.
- Le contrôle manuel du multiplicateur (`CONTROL_DEMO_MULTIPLIER`) est
  strictement réservé à l'environnement de démonstration et étiqueté
  "MODE DÉMONSTRATION" partout dans l'UI (spec §19).
