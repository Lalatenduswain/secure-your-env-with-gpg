# Security Policy

## Supported versions

This is a single-file utility distributed from `main`. Always use the latest version.

## Reporting a vulnerability

If you discover a security issue (for example, a path where plaintext secrets could
leak past the pre-commit hook), please report it privately:

- Use GitHub's **Report a vulnerability** button under the Security tab, or
- Open a private security advisory.

Please do **not** open a public issue for security problems.

## Scope

`secure-env.sh` relies on GnuPG for all cryptographic operations. Report issues in the
script's handling of secrets (temp files, process arguments, hook bypass) here; report
cryptographic issues in GnuPG itself upstream.
