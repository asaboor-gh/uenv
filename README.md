# uenv

uenv is a small native-shell companion for [uv](https://github.com/astral-sh/uv).

It keeps things simple: no extra runtime dependencies and no complex tooling layer. You get named environments in one centralized location (`~/.uenvs`) with straightforward create, activate, list, freeze, and delete commands. Activation sets `UV_PROJECT_ENVIRONMENT=virtualenv` so uv commands target the active environment with less friction.

## Installation

### Linux and macOS (Bash/Zsh)

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/asaboor-gh/uenv/main/install.sh | bash
```

After installation, restart your terminal or source your shell profile.

### Windows (PowerShell module)

**Recommended:**

1. List module paths: `$env:PSModulePath -split [IO.Path]::PathSeparator`
2. `Set-Location` to one path from that list (typically ending in `Modules`).
3. Run: `Invoke-RestMethod "https://raw.githubusercontent.com/asaboor-gh/uenv/main/install.ps1" | Invoke-Expression`

**Manual fallback:**

Place `uenv.psm1` and `uenv.psd1` inside a `uenv` directory under any path in `PSModulePath`.

## Usage

### Create an environment

```bash
uenv create myenv
uenv create py312 --python 3.12
```

### Activate an environment

```bash
uenv activate myenv
```

### Deactivate

```bash
uenv deactivate
# or:
deactivate
```

### List environments

```bash
uenv list
```

### Inspect installed packages

```bash
uenv freeze
uenv freeze > requirements.txt
```

### Delete an environment

```bash
uenv delete myenv
uenv delete myenv --yes
```

## Notes

- Environment names are restricted to: letters, numbers, dot, underscore, and dash.
- `install.sh` stores the shell loader at `~/.local/share/uenv/uenv.sh`.
- Managed environments are stored separately at `~/.uenvs`.
- The PowerShell manifest (`uenv.psd1`) is included to support metadata and reliable module behavior.
- On Windows, install the module into a writable directory from `$env:PSModulePath`.

## License

This project is licensed under the [MIT License](LICENSE).
