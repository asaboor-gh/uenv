# uenv

uenv is a lightweight native-shell companion for [uv](https://github.com/astral-sh/uv).

Use named virtual environments stored in one place, with fast commands you can remember.

- No extra runtime dependencies
- Centralized environment directory: `~/.uenvs`
- Simple flow: create, activate, list, freeze, delete
- Active environment sets `UV_PROJECT_ENVIRONMENT=virtualenv`

## Install

### Linux and macOS (Bash/Zsh)

```bash
curl -fsSL https://raw.githubusercontent.com/asaboor-gh/uenv/main/install.sh | bash
```

### PowerShell (cross-platform)

```powershell
irm "https://raw.githubusercontent.com/asaboor-gh/uenv/main/install.ps1" | iex
```

The installer auto-detects OS and installs to the first writable module path in `$env:PSModulePath` (preferring your Documents-based user Modules path on Windows).

Manual fallback: if auto-install fails, place `uenv.psm1` and `uenv.psd1` in a `uenv` folder under any path in `$env:PSModulePath`.

## Commands

```powershell
uenv create <name> [--python X.Y]
uenv activate <name>
uenv deactivate (or deactivate)
uenv list
uenv freeze
uenv delete <name> [--yes]
```


## Notes

- Environments are created with `uv venv`.
- Environment names allow letters, numbers, dot, underscore, and dash.
- `install.sh` stores the shell loader at `~/.local/share/uenv/uenv.sh`.

## License

This project is licensed under the [MIT License](LICENSE).
