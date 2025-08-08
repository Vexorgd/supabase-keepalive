# Supabase Keepalive

Reusable GitHub Action that sends a lightweight GET request to Supabase’s public `/auth/v1/health` endpoint — helping maintain responsiveness during development, staging, or demo phases.

## Why This Exists

Supabase free-tier projects may pause after several days without API traffic, leading to a cold-start delay the next time you need to test, demo, or review.
This action allows you to schedule minimal, non-invasive pings to the public health endpoint so the instance stays responsive for legitimate development and demonstration purposes.

**Key points:**

- Uses only the **public `/auth/v1/health` endpoint**
- Does **not** create, modify, or delete data
- Intended for **development/staging continuity** — not to avoid usage-based billing

---

## How to Use

1. **Add two repository secrets** (safe public values):

   - `SUPABASE_URL` → e.g. `https://abccompany.supabase.co`
   - `SUPABASE_ANON` → your **public anon key** (not service role)

2. **Create a caller workflow** in your consuming repo at `.github/workflows/keepalive.yml`:

```yaml
name: Maintain Supabase Responsiveness
on:
  schedule:
    - cron: "0 */6 * * *" # every 6 hours UTC; adjust as needed (8–12 hours is common)
  workflow_dispatch: # manual trigger option

jobs:
  ping:
    uses: Vexorgd/supabase-keepalive/.github/workflows/reusable-supabase-keepalive.yml@main
    with:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
      SUPABASE_ANON: ${{ secrets.SUPABASE_ANON }}
```

---

## Best Practices

- Keep the schedule conservative (e.g., every 8–12 hours) to avoid unnecessary traffic.
- Disable the workflow if you no longer need it.
- For production workloads, rely on actual application traffic rather than synthetic pings.
