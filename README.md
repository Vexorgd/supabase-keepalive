# Supabase Keepalive

[![GitHub release](https://img.shields.io/github/v/release/Vexorgd/supabase-keepalive?sort=semver)](https://github.com/Vexorgd/supabase-keepalive/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Reusable GitHub Action that sends a lightweight GET request to Supabase’s public `/auth/v1/health` endpoint — helping maintain responsiveness during development, staging, or demo phases.

---

## Why This Exists

Supabase free-tier projects may pause after several days without API traffic, causing cold-start delays the next time you test or demo.
This action schedules minimal, non-invasive pings to the **public** health endpoint so the instance stays responsive for legitimate development and demonstration purposes.

**Key points**

- Uses only the **public `/auth/v1/health` endpoint**
- Does **not** create, modify, or delete data
- Intended for **dev/staging continuity**, not to bypass usage-based billing

---

## How to Use

This is a **reusable workflow** — it won’t run by itself in this repo.
You call it **from another repository** (your site/API) by adding a small workflow there.

1. **Add two repository secrets** (safe public values) to the **consuming repo**:

   - `SUPABASE_URL` → e.g. `https://abccompany.supabase.co`
   - `SUPABASE_ANON` → your **public anon key** (not service role)

2. **Create a caller workflow** in the consuming repo at `.github/workflows/keepalive.yml`:

```yaml
name: Maintain Supabase Responsiveness
on:
  schedule:
    - cron: "0 */6 * * *" # every 6 hours UTC; adjust as needed (8–12 hours is common)
  workflow_dispatch: # manual trigger option

jobs:
  ping:
    uses: Vexorgd/supabase-keepalive/.github/workflows/reusable-supabase-keepalive.yml@v1.0.3
    with:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
      SUPABASE_ANON: ${{ secrets.SUPABASE_ANON }}
```

> **Why runs appear in your repo:** the caller workflow lives in _your_ repo, so all runs/logs show up there. This repo only hosts the reusable workflow.

---

## Best Practices

- Use a conservative schedule (e.g., **every 8–12 hours**) to avoid unnecessary traffic.
- Disable the workflow when you don’t need it.
- For production workloads, rely on real application traffic rather than synthetic pings.

---

## Versioning

Pin to a **tagged version** instead of `main` for stability (e.g., `@v1.0.2` as shown above).
New releases are published on the [Releases](https://github.com/Vexorgd/supabase-keepalive/releases) page.

---

## License

MIT — see [LICENSE](LICENSE).
