# Déménagement vers un nouveau projet Supabase

Copie complète de CRASHX (comptes et mots de passe, soldes, mises,
historique, administrateurs) depuis l'ancien projet, même s'il est en
lecture seule, vers un nouveau projet. L'historique pg_cron, qui a rempli
l'ancien disque, n'est pas copié.

Les joueurs gardent leur identifiant et leur mot de passe, mais doivent
installer le **nouvel APK** (l'ancien pointe vers l'ancien projet) et se
reconnecter une fois.

## 1. Créer le nouveau projet

1. https://supabase.com → **New project** (noter le mot de passe de la base).
2. **Authentication → Providers → Email** : désactiver
   **Allow new users to sign up**.
3. **Database → Extensions** : activer **pg_cron**.

## 2. Installer le schéma

Depuis la racine du dépôt :

```bash
npx supabase login
npx supabase link --project-ref <ref-du-NOUVEAU-projet>
npx supabase db push
```

Toutes les migrations (0001 → 0022) s'appliquent et le moteur de jeu
démarre. **Ne pas exécuter `seed.sql`** : les super admins arrivent avec
les données à l'étape 3.

## 3. Copier les données

Outils nécessaires : les outils clients PostgreSQL, en version **au
moins égale** à celle des deux serveurs (le script vérifie et prévient).
Version des serveurs : **Settings → Infrastructure** de chaque projet. Si
c'est 17, installer PostgreSQL 17 (outils en ligne de commande suffisent).

Chaînes de connexion : **Connect → Session pooler** dans chaque projet
(fonctionne sans IPv6), en remplaçant `[YOUR-PASSWORD]`.

Dans Git Bash, depuis la racine du dépôt :

```bash
OLD_DB_URL='postgresql://postgres.<ancien-ref>:<mdp>@aws-0-<region>.pooler.supabase.com:5432/postgres' \
NEW_DB_URL='postgresql://postgres.<nouveau-ref>:<mdp>@aws-0-<region>.pooler.supabase.com:5432/postgres' \
PG_BIN='/c/Program Files/PostgreSQL/17/bin' \
bash supabase/scripts/migrate-to-new-project.sh
```

Le script :
1. exporte `auth.users`, `auth.identities` et tout le schéma `public` de
   l'ancien projet (lecture seule) ;
2. met le moteur en pause et vide les tables du nouveau projet (il refuse
   de continuer si le nouveau projet a déjà des comptes) ;
3. importe tout dans une seule transaction ;
4. rejoue sur les données importées les corrections des migrations
   0020 et 0022, redémarre le moteur ;
5. affiche les comptages des deux projets pour comparaison.

En cas d'erreur, rien n'est importé à moitié : corriger et relancer.

## 4. Déployer les Edge Functions

```bash
npx supabase functions deploy create-player
npx supabase functions deploy create-sub-admin
npx supabase functions deploy game-tick
```

## 5. Rebrancher les applications

Clés : **Settings → API** du nouveau projet (URL et clé `anon`).

- Admin web : mettre à jour `admin/.env`, puis `npm run build` et
  redéployer.
- Mobile :
  ```bash
  cd mobile
  flutter build apk --release \
    --dart-define=SUPABASE_URL=https://<nouveau-ref>.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=<nouvelle-clé-anon>
  ```
  Distribuer ce nouvel APK à tous les joueurs.

## 6. Vérifier, puis fermer l'ancien projet

- Se connecter avec un compte admin et un compte joueur existants.
- Vérifier qu'une manche tourne (Admin → Jeu) et qu'un solde est correct.
- Garder l'ancien projet quelques jours en secours, puis le mettre en
  pause ou le supprimer depuis son dashboard.
