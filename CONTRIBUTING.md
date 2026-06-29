# Contributing

Thanks for your interest in improving **secure-your-env-with-gpg**!

## Ground rules

- Keep the tool **zero-dependency** — POSIX-friendly Bash and GnuPG only.
- Run [`shellcheck`](https://www.shellcheck.net/) on `secure-env.sh` before opening a PR.
- Never commit a plaintext `.env`. The pre-commit hook should catch it, but double-check.

## Workflow

1. Fork and create a feature branch: `git checkout -b feature/my-change`.
2. Make your change and test `./secure-env.sh` manually (encrypt + decrypt round-trip).
3. Open a pull request describing what changed and why.

## Reporting security issues

Please see [SECURITY.md](SECURITY.md) — do not open public issues for vulnerabilities.
