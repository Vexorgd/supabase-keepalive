# supabase-keepalive

Reusable GitHub Action that sends a lightweight ping to a Supabase project’s
`/auth/v1/health` endpoint on a schedule so the free-tier instance never auto-pauses.

## Why this exists

Supabase pauses free-tier projects after **7 days** of no API traffic.
During low-traffic stages (e.g., pre-launch, staging, demos) a single GET request
every few hours is enough to reset the timer.
Keeping the logic in one dedicated repo means every website or microservice can
**reference** the same workflow instead of duplicating code.

## How to consume this workflow in _any_ repo

1. **Add two repository secrets**
   | Name | Example value |
   |------|---------------|
   | `SUPABASE_URL` | `https://abccompany.supabase.co` |
   | `SUPABASE_ANON` | `eyJhbGciOiJIUzI1...` (public anon key) |

2. **Create a tiny caller workflow** in the consuming repo
   `.github/workflows/keepalive.yml`:

   ```yaml
   name: Keep Supabase Awake
   on:
     schedule:
       - cron: "0 */6 * * *" # every 6 hours, UTC
     workflow_dispatch: # manual trigger option

   jobs:
     use-reusable:
       uses: Vexorgd/supabase-keepalive/.github/workflows/reusable-supabase-keepalive.yml@main
       with:
         SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
         SUPABASE_ANON: ${{ secrets.SUPABASE_ANON }}
   ```
