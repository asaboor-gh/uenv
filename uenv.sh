#!/usr/bin/env bash

_uenv_dir() {
    printf '%s\n' "${UENV_HOME:-$HOME/.uenvs}"
}

_uenv_print_help() {
    cat <<'EOF'
Usage: uenv <command> [options]

Commands:
  create <name> [--python X.XX]    Create a new virtual environment
  activate <name>                  Activate a managed environment
  deactivate                       Deactivate the current environment
  list                             List all managed environments
  freeze                           Print installed packages from active environment
  delete <name> [-y|--yes]         Delete a managed environment
  help                             Show this help message

Notes:
  - Environment names can only contain letters, numbers, dot, underscore, and dash.
  - By default, environments are stored in ~/.uenvs (override with UENV_HOME).
EOF
}

_uenv_require_uv() {
    if ! command -v uv >/dev/null 2>&1; then
        echo "Error: uv is not installed or not available on PATH." >&2
        return 1
    fi
}

_uenv_validate_name() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        return 1
    fi

    case "$name" in
        *[!A-Za-z0-9._-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

_uenv_function_exists() {
    typeset -f "$1" >/dev/null 2>&1
}

_uenv_capture_original_deactivate() {
    local deactivate_def

    deactivate_def="$(typeset -f deactivate 2>/dev/null || true)"
    if [ -z "$deactivate_def" ]; then
        return 1
    fi

    deactivate_def="${deactivate_def//deactivate/_uenv_original_deactivate}"
    eval "$deactivate_def"
}

_uenv_list_envs() {
    local uenv_dir dir
    uenv_dir="$(_uenv_dir)"

    [ -d "$uenv_dir" ] || return 0

    for dir in "$uenv_dir"/*; do
        [ -d "$dir" ] || continue
        basename "$dir"
    done
}

uenv() {
    local command="${1:-help}"
    if [ "$#" -gt 0 ]; then
        shift
    fi

    local uenv_dir name env_path activate_script confirm found dir
    uenv_dir="$(_uenv_dir)"
    mkdir -p "$uenv_dir"

    case "$command" in
        create)
            name="${1:-}"
            if [ "$#" -gt 0 ]; then
                shift
            fi

            if ! _uenv_validate_name "$name"; then
                echo "Error: Please provide a valid environment name." >&2
                return 1
            fi

            if ! _uenv_require_uv; then
                return 1
            fi

            env_path="$uenv_dir/$name"
            if [ -d "$env_path" ]; then
                echo "Warning: Environment '$name' already exists." >&2
                return 1
            fi

            echo "Creating environment '$name' using uv..." >&2
            if ! uv venv "$env_path" "$@"; then
                echo "Error: Failed to create environment '$name'." >&2
                return 1
            fi
            ;;

        activate)
            name="${1:-}"
            if ! _uenv_validate_name "$name"; then
                echo "Error: Please provide a valid environment name to activate." >&2
                return 1
            fi

            env_path="$uenv_dir/$name"
            if [ ! -d "$env_path" ]; then
                echo "Error: Environment '$name' does not exist." >&2
                return 1
            fi

            if [ "${VIRTUAL_ENV:-}" = "$env_path" ] && [ "${_UENV_ACTIVE_NAME:-}" = "$name" ]; then
                echo "Environment '$name' is already active." >&2
                return 0
            fi

            activate_script="$env_path/bin/activate"
            if [ ! -f "$activate_script" ]; then
                echo "Error: Activation script not found at $activate_script." >&2
                return 1
            fi

            # shellcheck disable=SC1090
            if ! source "$activate_script"; then
                echo "Error: Failed to source activation script for '$name'." >&2
                return 1
            fi

            if ! _uenv_function_exists deactivate; then
                echo "Error: Activation completed but deactivate function was not defined." >&2
                return 1
            fi

            if ! _uenv_capture_original_deactivate; then
                echo "Error: Failed to capture original deactivate function." >&2
                return 1
            fi

            export UV_PROJECT_ENVIRONMENT="virtualenv"
            export _UENV_ACTIVE_NAME="$name"

            deactivate() {
                unset UV_PROJECT_ENVIRONMENT
                unset _UENV_ACTIVE_NAME

                if _uenv_function_exists _uenv_original_deactivate; then
                    _uenv_original_deactivate "$@"
                fi

                unset -f _uenv_original_deactivate >/dev/null 2>&1 || true
                unset -f deactivate >/dev/null 2>&1 || true
                echo "Deactivated environment cleanly." >&2
            }

            echo "Activated environment: $name" >&2
            ;;

        deactivate)
            if [ -n "${VIRTUAL_ENV:-}" ] && _uenv_function_exists deactivate; then
                deactivate "$@"
            else
                echo "Warning: No uenv virtual environment is currently active." >&2
            fi
            ;;

        list)
            echo "Managed environments in $uenv_dir:"
            echo "----------------------------------------"

            found=0
            for dir in "$uenv_dir"/*; do
                [ -d "$dir" ] || continue

                if [ "${VIRTUAL_ENV:-}" = "$dir" ]; then
                    echo "  * $(basename "$dir") (active)"
                else
                    echo "    $(basename "$dir")"
                fi

                found=1
            done

            if [ "$found" -eq 0 ]; then
                echo "  (No environments found. Create one with 'uenv create <name>')"
            fi
            ;;

        freeze)
            if [ -z "${VIRTUAL_ENV:-}" ]; then
                echo "Error: No active environment found. Activate one before freezing." >&2
                return 1
            fi

            if ! _uenv_require_uv; then
                return 1
            fi

            uv pip freeze "$@"
            ;;

        delete)
            name="${1:-}"
            if [ "$#" -gt 0 ]; then
                shift
            fi

            if ! _uenv_validate_name "$name"; then
                echo "Error: Please provide a valid environment name to delete." >&2
                return 1
            fi

            env_path="$uenv_dir/$name"
            if [ ! -d "$env_path" ]; then
                echo "Error: Environment '$name' does not exist." >&2
                return 1
            fi

            if [ "${VIRTUAL_ENV:-}" = "$env_path" ]; then
                if _uenv_function_exists deactivate; then
                    echo "Deactivating active environment before deletion..." >&2
                    deactivate
                else
                    echo "Error: '$name' appears active, but deactivate is unavailable." >&2
                    return 1
                fi
            fi

            confirm="${1:-}"
            if [ "$confirm" != "--yes" ] && [ "$confirm" != "-y" ]; then
                if [ ! -t 0 ]; then
                    echo "Error: Non-interactive shell detected. Use 'uenv delete $name --yes'." >&2
                    return 1
                fi

                read -r -p "Are you sure you want to delete '$name'? [y/N]: " confirm
            fi

            case "$confirm" in
                y|Y|--yes|-y)
                    rm -rf -- "$env_path"
                    echo "Environment '$name' successfully deleted." >&2
                    ;;
                *)
                    echo "Deletion canceled." >&2
                    ;;
            esac
            ;;

        help|-h|--help|"")
            _uenv_print_help
            ;;

        *)
            echo "Error: Unknown command '$command'." >&2
            _uenv_print_help
            return 1
            ;;
    esac
}

_uenv_completions() {
    local commands cur prev subcommand envs
    commands="create activate deactivate list freeze delete help"

    if [ -n "${ZSH_VERSION:-}" ]; then
        if (( CURRENT == 2 )); then
            local -a zsh_commands
            zsh_commands=(create activate deactivate list freeze delete help)
            _describe -t commands 'uenv commands' zsh_commands
            return
        fi

        if (( CURRENT >= 3 )); then
            case "${words[2]}" in
                activate|delete)
                    local -a zsh_envs
                    zsh_envs=("${(@f)$(_uenv_list_envs)}")
                    _describe -t envs 'managed environments' zsh_envs
                    ;;
                create)
                    local -a create_opts
                    create_opts=(--python --python=)
                    _describe -t options 'create options' create_opts
                    ;;
            esac
        fi
        return
    fi

    if [ -n "${BASH_VERSION:-}" ]; then
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        subcommand="${COMP_WORDS[1]}"

        if [ "$COMP_CWORD" -eq 1 ]; then
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            return
        fi

        case "$subcommand" in
            activate|delete)
                if [ "$COMP_CWORD" -eq 2 ]; then
                    envs="$(_uenv_list_envs)"
                    COMPREPLY=( $(compgen -W "$envs" -- "$cur") )
                fi
                ;;
            create)
                COMPREPLY=( $(compgen -W "--python --python=" -- "$cur") )
                ;;
        esac
    fi
}

if [ -n "${ZSH_VERSION:-}" ] && command -v compdef >/dev/null 2>&1; then
    compdef _uenv_completions uenv
elif [ -n "${BASH_VERSION:-}" ]; then
    complete -F _uenv_completions uenv
fi
