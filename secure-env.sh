#!/usr/bin/env bash
# ==============================================================================
# secure-env.sh — GPG-based environment variable encryption and safety utility.
# ==============================================================================
#
# Usage:
#   ./secure-env.sh encrypt [symmetric|asymmetric]
#   ./secure-env.sh decrypt [symmetric|asymmetric]
#   ./secure-env.sh init-hooks
#
# Requirements:
#   - gpg (GNU Privacy Guard) installed
#   - git (Git Version Control System) installed
#   - git repository
#
# ==============================================================================

set -euo pipefail

# Configurations
ENV_FILE=".env"
ENC_FILE=".env.gpg"
HOOKS_DIR=".git/hooks"
PRE_COMMIT_HOOK="${HOOKS_DIR}/pre-commit"

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $*"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
    exit 1
}

check_gpg() {
    if ! command -v gpg &> /dev/null; then
        log_error "gpg command could not be found. Please install GNU Privacy Guard."
    fi
}

check_git_repo() {
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "This utility must be run inside a Git repository."
    fi
}

ensure_git_ignored() {
    if [ ! -f .gitignore ]; then
        touch .gitignore
    fi
    if ! grep -q "^${ENV_FILE}$" .gitignore; then
        echo -e "\n# Plaintext secrets\n${ENV_FILE}" >> .gitignore
        log_info "Added '${ENV_FILE}' to .gitignore to prevent accidental commits."
    fi
}

encrypt_symmetric() {
    log_info "Encrypting ${ENV_FILE} symmetrically..."
    if [ ! -f "${ENV_FILE}" ]; then
        log_error "Source file '${ENV_FILE}' not found. Cannot encrypt."
    fi

    # Prompt for passphrase securely
    echo -n "Enter symmetric passphrase: "
    read -rs passphrase
    echo
    echo -n "Confirm passphrase: "
    read -rs passphrase_confirm
    echo

    if [ "${passphrase}" != "${passphrase_confirm}" ]; then
        log_error "Passphrases do not match!"
    fi

    if [ -z "${passphrase}" ]; then
        log_error "Passphrase cannot be empty."
    fi

    # Encrypt
    gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase "${passphrase}" -o "${ENC_FILE}" "${ENV_FILE}"
    log_info "Success! Symmetrically encrypted secrets saved to '${ENC_FILE}'."
    log_info "You can commit '${ENC_FILE}' safely."
}

decrypt_symmetric() {
    log_info "Decrypting ${ENC_FILE} symmetrically..."
    if [ ! -f "${ENC_FILE}" ]; then
        log_error "Encrypted file '${ENC_FILE}' not found."
    fi

    # Prompt for passphrase or check env
    if [ -n "${GPG_PASSPHRASE:-}" ]; then
        passphrase="${GPG_PASSPHRASE}"
    else
        echo -n "Enter symmetric passphrase: "
        read -rs passphrase
        echo
    fi

    if [ -z "${passphrase}" ]; then
        log_error "Passphrase cannot be empty."
    fi

    gpg --decrypt --batch --yes --passphrase "${passphrase}" -o "${ENV_FILE}" "${ENC_FILE}"
    log_info "Success! Plaintext secrets restored to '${ENV_FILE}'."
}

encrypt_asymmetric() {
    log_info "Encrypting ${ENV_FILE} asymmetrically..."
    if [ ! -f "${ENV_FILE}" ]; then
        log_error "Source file '${ENV_FILE}' not found."
    fi

    # List keys and prompt for recipient
    log_info "Available GPG Keys:"
    gpg --list-public-keys --keyid-format LONG || true
    echo
    echo -n "Enter the recipient's GPG Key ID or Email address: "
    read -r recipient

    if [ -z "${recipient}" ]; then
        log_error "Recipient cannot be empty."
    fi

    gpg --encrypt --recipient "${recipient}" --trust-model always -o "${ENC_FILE}" "${ENV_FILE}"
    log_info "Success! Asymmetrically encrypted secrets saved to '${ENC_FILE}'."
}

decrypt_asymmetric() {
    log_info "Decrypting ${ENC_FILE} asymmetrically..."
    if [ ! -f "${ENC_FILE}" ]; then
        log_error "Encrypted file '${ENC_FILE}' not found."
    fi

    # Try standard private key decryption
    gpg --decrypt --batch --yes -o "${ENV_FILE}" "${ENC_FILE}"
    log_info "Success! Plaintext secrets restored to '${ENV_FILE}'."
}

init_hooks() {
    log_info "Installing Git pre-commit security hook..."
    ensure_git_ignored

    # Create the pre-commit script
    cat << 'EOF' > "${PRE_COMMIT_HOOK}"
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
ENC_FILE=".env.gpg"

# Check if .env is staged
if git diff --cached --name-only | grep -q "^${ENV_FILE}$"; then
    echo -e "\033[0;31m[CRITICAL SECURITY WARNING] Staged changes include '${ENV_FILE}'!\033[0m"
    echo -e "You should NEVER commit your plaintext '${ENV_FILE}' file."
    echo -e "Please run './secure-env.sh encrypt' to update '${ENC_FILE}', then commit '${ENC_FILE}' instead."
    echo -e "Use 'git reset HEAD ${ENV_FILE}' to unstage it."
    exit 1
fi

# Check if .env has been modified since .env.gpg was last updated
if [ -f "${ENV_FILE}" ] && [ -f "${ENC_FILE}" ]; then
    if [ "${ENV_FILE}" -nt "${ENC_FILE}" ]; then
        echo -e "\033[0;33m[WARNING] '${ENV_FILE}' is newer than your encrypted '${ENC_FILE}'!\033[0m"
        echo -e "Did you forget to run './secure-env.sh encrypt' after making changes?"
        echo -e "Press Enter to proceed anyway, or Ctrl+C to abort and update your encryption."
        read -r _
    fi
fi
EOF

    chmod +x "${PRE_COMMIT_HOOK}"
    log_info "Git pre-commit hook installed at '${PRE_COMMIT_HOOK}'."
}

show_help() {
    cat << EOF
secure-env.sh — GPG-based environment variable encryption and safety utility.

Usage:
  $0 encrypt [symmetric|asymmetric]  Encrypt your local .env to .env.gpg
  $0 decrypt [symmetric|asymmetric]  Decrypt your .env.gpg back to .env
  $0 init-hooks                       Install Git safety hooks to prevent plaintext leaks

Options:
  Symmetric encryption uses a passphrase (great for single-developer and CI keys).
  Asymmetric encryption uses GPG keys (great for team developer collaboration).
EOF
}

# Main routing
main() {
    check_gpg
    check_git_repo

    local action="${1:-help}"
    local mode="${2:-symmetric}"

    case "${action}" in
        encrypt)
            ensure_git_ignored
            if [ "${mode}" = "asymmetric" ]; then
                encrypt_asymmetric
            else
                encrypt_symmetric
            fi
            ;;
        decrypt)
            if [ "${mode}" = "asymmetric" ]; then
                decrypt_asymmetric
            else
                decrypt_symmetric
            fi
            ;;
        init-hooks)
            init_hooks
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
