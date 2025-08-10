# Contributing to Supabase Keepalive

Thanks for your interest in improving this GitHub Action! This is a simple project that helps keep Supabase instances responsive during development.

## Quick Start

1. **Fork** this repository
2. **Clone** your fork: `git clone https://github.com/your-username/supabase-keepalive.git`
3. **Create a branch**: `git checkout -b your-improvement`
4. **Make your changes**
5. **Test** your changes (see [Testing](#testing) below)
6. **Submit** a pull request

## Ways to Contribute

### Bug Reports
- Action fails to ping Supabase correctly
- Workflow syntax errors or compatibility issues
- Documentation inaccuracies

### Enhancements
- Better error handling and logging
- Support for additional Supabase endpoints
- Improved scheduling options or flexibility
- Documentation improvements and examples

### Documentation
- Clearer setup instructions
- More usage examples
- Troubleshooting guides
- README improvements

## Development

### Project Structure
```
.github/workflows/
  └── reusable-supabase-keepalive.yml  # Main action workflow
README.md                              # Project documentation
LICENSE                               # MIT license
```

### Making Changes

**For workflow changes:**
- Edit `.github/workflows/reusable-supabase-keepalive.yml`
- Follow [GitHub Actions syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- Keep it simple and focused on the core purpose

**For documentation changes:**
- Update README.md for user-facing changes
- Ensure examples are accurate and up-to-date

## Testing

Since this is a GitHub Action, testing requires:

1. **Test in a separate repository** with a real Supabase project:
   ```yaml
   # Create .github/workflows/test-keepalive.yml in a test repo
   name: Test Keepalive
   on: workflow_dispatch
   
   jobs:
     test:
       uses: your-username/supabase-keepalive/.github/workflows/reusable-supabase-keepalive.yml@your-branch
       with:
         SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
         SUPABASE_ANON: ${{ secrets.SUPABASE_ANON }}
   ```

2. **Verify the action succeeds** and check logs for proper behavior

3. **Test edge cases** like invalid URLs or network timeouts

## Commit Messages

Use clear, descriptive commit messages:

```
feat: add retry logic for failed requests
fix: handle invalid Supabase URL format
docs: add troubleshooting section to README
```

**Types:**
- `feat` - New features or improvements
- `fix` - Bug fixes
- `docs` - Documentation updates
- `refactor` - Code improvements without changing behavior

## Pull Request Guidelines

**Before submitting:**
- [ ] Tested the action in a real environment
- [ ] Updated documentation if needed
- [ ] Commit messages are clear
- [ ] Branch is up to date with main

**In your PR description:**
- Explain what changed and why
- Include testing details (which Supabase project, results)
- Link any related issues
- Note any breaking changes

## Reporting Issues

**For bugs:**
- Describe what the action should do vs. what happened
- Include relevant workflow logs (remove sensitive data)
- Share your workflow YAML setup
- Mention your Supabase project tier (free, pro, etc.)

**For feature requests:**
- Explain the use case or problem
- Describe your proposed solution
- Consider if it fits the project's simple scope

## Project Philosophy

This action is intentionally **simple and focused**:
- Lightweight health checks only
- No database operations
- Development/staging use case
- Minimal configuration required

When contributing, please keep this simplicity in mind. Complex features that deviate from the core purpose might be better as separate actions.

## Getting Help

- Check existing [Issues](https://github.com/Vexorgd/supabase-keepalive/issues)
- Email: [projects@mitloop.com](mailto:projects@mitloop.com)
- For Supabase-specific questions, see [Supabase Documentation](https://supabase.com/docs)          

## Versioning

- We use [Semantic Versioning](https://semver.org/)
- Tag releases with `v1.0.0` format
- Update version references in README examples

---

**First contribution?** Look for issues labeled `good first issue` or start by improving documentation!
