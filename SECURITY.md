# Security Policy

## Supported Versions

We provide security updates for the following versions of Supabase Keepalive:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

We recommend always using the latest release and pinning to specific tags (e.g., `@v1.0.3`) rather than `@main` for stability and security.

## Reporting a Vulnerability

If you discover a security vulnerability in this GitHub Action, please report it responsibly:

**Contact:** [projects@mitloop.com](mailto:projects@mitloop.com)

**Please include "SECURITY" in your email subject line** to ensure prompt attention.

**What to include in your report:**
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact (e.g., secrets exposure, workflow compromise)
- Any suggested fixes or mitigations

**Response timeline:**
- **Initial response:** Within 48 hours
- **Status updates:** Weekly until resolved
- **Resolution:** We aim to address critical vulnerabilities within 7 days

**What happens next:**
- **Accepted vulnerabilities:** We'll work on a fix, coordinate disclosure timing, and credit you in the release notes (if desired)
- **Declined reports:** We'll explain why the issue doesn't qualify as a security vulnerability

**Common security concerns for this action:**
- Secrets being exposed in workflow logs
- Unauthorized access to Supabase instances
- Workflow permission escalation
- Dependency vulnerabilities

Please do not open public GitHub issues for security vulnerabilities. Use the email contact above for responsible disclosure.

Thank you for helping keep Supabase Keepalive secure!
