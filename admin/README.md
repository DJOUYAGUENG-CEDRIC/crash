# React + TypeScript + Vite

This React + Vite app contains the CRASHX admin dashboard and the public demo predictor.

## Public demo predictor

The `/predictor` route displays the exact server-programmed multiplier and recent results for the CRASHX virtual-money demo. It is intentionally public and must only be deployed against the demo Supabase project.

### Deploy to Vercel

1. Commit and push the repository to GitHub, then import that repository into Vercel.
2. Set **Root Directory** to `admin`.
3. Select **Vite** if Vercel does not detect it automatically. Set `npm run build` as the build command and `dist` as the output directory. Vercel installs dependencies from `admin/package.json`.
4. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in **Project Settings → Environment Variables**. Use the URL and public anon/publishable key from the demo Supabase project. Never add a `service_role` key to Vercel.
5. Redeploy after setting the variables. Open `/predictor` on the generated Vercel domain.

`vercel.json` rewrites direct requests such as `/predictor` to the React app entry point. Before testing the page, apply `supabase/migrations/0025_demo_round_predictions.sql` to the writable demo Supabase database; the project shown in read-only mode must be unlocked first. The migration exposes exact round targets publicly: never apply it to a real-money environment.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend enabling type-aware lint rules by installing `oxlint-tsgolint` and editing `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc"],
  "options": {
    "typeAware": true
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }]
  }
}
```

See the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules) for the full list of rules and categories.
