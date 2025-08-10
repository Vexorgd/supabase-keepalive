---
name: Bug report
about: Create a report to help us improve
title: "[BUG] Action issue with v1.x.x"
labels: bug
assignees: Vexorgd

---

**Describe the bug**
A clear description of what the action should do vs. what happened.

**Workflow setup**
Please share the relevant parts of your workflow file:
```yaml
# Paste your workflow YAML here, for example:
name: Maintain Supabase Responsiveness
on:
  schedule:
    - cron: "0 */6 * * *"
  workflow_dispatch:

jobs:
  ping:
    uses: Vexorgd/supabase-keepalive/.github/workflows/reusable-supabase-keepalive.yml@v1.0.3
    with:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
      SUPABASE_ANON: ${{ secrets.SUPABASE_ANON }}

Expected behavior
What you expected the action to do.
Actual behavior
What actually happened. Include any error messages from the workflow run.
Action logs
Please include relevant logs from the GitHub Actions run. You can find these in your repository's Actions tab.
(Remove any sensitive information before sharing)
Environment

Action version: [e.g. @v1.0.3, @main]
Supabase project tier: [e.g. free, pro]
Workflow trigger: [e.g. scheduled, manual]

Additional context
Any other relevant information about the issue.
