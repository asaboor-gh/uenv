# uenv

uenv is a lightweight shell wrapper and centralized environment manager for [uv](https://github.com/astral-sh/uv).

It stores named virtual environments in a single location (`~/.uenvs`) and sets `UV_PROJECT_ENVIRONMENT=virtualenv` when you activate a uenv-managed environment.

## Project layout

- `uenv.sh`: Bash/Zsh implementation
- `uenv.psm1`: PowerShell implementation
- `uenv.psd1`: PowerShell module manifest (recommended for reliable auto-loading and metadata)
- `install.sh`: Unix-like installer

## Installation

### Linux and macOS (Bash/Zsh)

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/asaboor-gh/uenv/main/install.sh | bash
```

After installation, restart your terminal or source your shell profile.

### Windows (PowerShell module)

Download both module files into your user module path:

```powershell
$modulePath = Join-Path $HOME "Documents/PowerShell/Modules/uenv"
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
Invoke-RestMethod "https://raw.githubusercontent.com/asaboor-gh/uenv/main/uenv.psm1" | Out-File (Join-Path $modulePath "uenv.psm1") -Encoding utf8
Invoke-RestMethod "https://raw.githubusercontent.com/asaboor-gh/uenv/main/uenv.psd1" | Out-File (Join-Path $modulePath "uenv.psd1") -Encoding utf8
Import-Module uenv -Force
```

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

## License

This project is licensed under the [MIT License](LICENSE).
