Set-StrictMode -Version Latest

$script:UenvDir = Join-Path $HOME ".uenvs"
$script:UenvCommands = @("create", "activate", "deactivate", "list", "freeze", "delete", "help")

function Test-UenvUv {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Error "uv is not installed or not available on PATH."
        return $false
    }

    return $true
}

function Test-UenvName {
    param(
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    return ($Name -match '^[A-Za-z0-9._-]+$')
}

function Get-UenvPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return (Join-Path $script:UenvDir $Name)
}

function Resolve-UenvComparablePath {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    } catch {
        return $Path
    }
}

function Show-UenvHelp {
    Write-Host "Usage: uenv <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  create <name> [--python X.XX]    Create a new virtual environment"
    Write-Host "  activate <name>                  Activate a managed environment"
    Write-Host "  deactivate                       Deactivate the current environment"
    Write-Host "  list                             List all managed environments"
    Write-Host "  freeze                           Print installed packages"
    Write-Host "  delete <name> [-y|--yes]         Delete a managed environment"
    Write-Host "  help                             Show this help message"
    Write-Host ""
    Write-Host "Notes:"
    Write-Host "  - Environment names may only contain letters, numbers, dot, underscore, and dash."
    Write-Host "  - Managed environments are stored in ${script:UenvDir}."
}

function Set-UenvDeactivateWrapper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $deactivateCmd = Get-Command deactivate -CommandType Function -ErrorAction SilentlyContinue
    if (-not $deactivateCmd) {
        Write-Error "Activation completed but no deactivate function was found."
        return $false
    }

    Set-Item -Path function:global:_uenv_original_deactivate -Value $deactivateCmd.ScriptBlock -Force

    $env:UV_PROJECT_ENVIRONMENT = "virtualenv"
    $env:UENV_ACTIVE_NAME = $Name

    function global:deactivate {
        param(
            [Parameter(ValueFromRemainingArguments = $true)]
            [object[]]$ForwardArgs
        )

        Remove-Item env:UV_PROJECT_ENVIRONMENT -ErrorAction SilentlyContinue
        Remove-Item env:UENV_ACTIVE_NAME -ErrorAction SilentlyContinue

        if (Get-Command _uenv_original_deactivate -CommandType Function -ErrorAction SilentlyContinue) {
            & _uenv_original_deactivate @ForwardArgs
        }

        Remove-Item function:global:_uenv_original_deactivate -ErrorAction SilentlyContinue
        Remove-Item function:global:deactivate -ErrorAction SilentlyContinue
        Write-Host "Deactivated environment cleanly." -ForegroundColor Yellow
    }

    return $true
}

function uenv {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Command = "help",

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Name,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ExtraArgs
    )

    if (-not (Test-Path -LiteralPath $script:UenvDir)) {
        New-Item -ItemType Directory -Path $script:UenvDir -Force | Out-Null
    }

    $normalizedCommand = $Command.ToLowerInvariant()

    switch ($normalizedCommand) {
        "create" {
            if (-not (Test-UenvName -Name $Name)) {
                Write-Error "Please specify a valid environment name."
                return
            }

            if (-not (Test-UenvUv)) {
                return
            }

            $envPath = Get-UenvPath -Name $Name
            if (Test-Path -LiteralPath $envPath) {
                Write-Warning "Environment '$Name' already exists."
                return
            }

            Write-Host "Creating environment '$Name' using uv..." -ForegroundColor Cyan
            $uvArgs = @("venv", $envPath) + $ExtraArgs
            & uv @uvArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create environment '$Name'."
                return
            }
        }

        "activate" {
            if (-not (Test-UenvName -Name $Name)) {
                Write-Error "Please specify a valid environment name to activate."
                return
            }

            $envPath = Get-UenvPath -Name $Name
            if (-not (Test-Path -LiteralPath $envPath)) {
                Write-Error "Environment '$Name' does not exist."
                return
            }

            $activateScript = Join-Path $envPath "Scripts/Activate.ps1"
            if (-not (Test-Path -LiteralPath $activateScript -PathType Leaf)) {
                Write-Error "Activation script not found at $activateScript."
                return
            }

            if (($env:UENV_ACTIVE_NAME -eq $Name) -and ($env:VIRTUAL_ENV -eq $envPath)) {
                Write-Host "Environment '$Name' is already active." -ForegroundColor Yellow
                return
            }

            . $activateScript

            if (-not (Set-UenvDeactivateWrapper -Name $Name)) {
                return
            }

            Write-Host "Activated environment: $Name" -ForegroundColor Green
        }

        "deactivate" {
            $deactivateCmd = Get-Command deactivate -CommandType Function -ErrorAction SilentlyContinue
            if ($env:VIRTUAL_ENV -and $deactivateCmd) {
                deactivate @ExtraArgs
            } else {
                Write-Warning "No uenv virtual environment is currently active."
            }
        }

        "list" {
            Write-Host "Managed environments in ${script:UenvDir}:" -ForegroundColor Cyan
            Write-Host "----------------------------------------"

            $dirs = @(Get-ChildItem -LiteralPath $script:UenvDir -Directory -ErrorAction SilentlyContinue)
            if ($dirs.Count -eq 0) {
                Write-Host "  (No environments found. Create one with 'uenv create <name>')"
                return
            }

            foreach ($dir in $dirs) {
                if ($env:VIRTUAL_ENV -eq $dir.FullName) {
                    Write-Host "  * $($dir.Name) (active)" -ForegroundColor Green
                } else {
                    Write-Host "    $($dir.Name)"
                }
            }
        }

        "freeze" {
            if (-not $env:VIRTUAL_ENV) {
                Write-Error "No active environment found. Activate one before freezing."
                return
            }

            if (-not (Test-UenvUv)) {
                return
            }

            $uvArgs = @("pip", "freeze") + $ExtraArgs
            & uv @uvArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Error "uv pip freeze failed."
                return
            }
        }

        "delete" {
            if (-not (Test-UenvName -Name $Name)) {
                Write-Error "Please specify a valid environment name to delete."
                return
            }

            $envPath = Get-UenvPath -Name $Name
            if (-not (Test-Path -LiteralPath $envPath)) {
                Write-Error "Environment '$Name' does not exist."
                return
            }

            $activePath = Resolve-UenvComparablePath -Path $env:VIRTUAL_ENV
            $targetPath = Resolve-UenvComparablePath -Path $envPath

            if ($activePath -and ($activePath -eq $targetPath)) {
                $deactivateCmd = Get-Command deactivate -CommandType Function -ErrorAction SilentlyContinue
                if (-not $deactivateCmd) {
                    Write-Error "'$Name' appears active, but deactivate is unavailable."
                    return
                }

                Write-Host "Deactivating active environment before deletion..." -ForegroundColor Yellow
                deactivate
            }

            $assumeYes = ($ExtraArgs -contains "-y") -or ($ExtraArgs -contains "--yes")
            if (-not $assumeYes) {
                $confirm = Read-Host "Are you sure you want to delete '$Name'? [y/N]"
                if ($confirm -notmatch '^[Yy]$') {
                    Write-Host "Deletion canceled."
                    return
                }
            }

            Remove-Item -LiteralPath $envPath -Recurse -Force
            Write-Host "Environment '$Name' successfully deleted." -ForegroundColor Red
        }

        "help" {
            Show-UenvHelp
        }

        default {
            Write-Error "Unknown command '$Command'."
            Show-UenvHelp
        }
    }
}

Register-ArgumentCompleter -CommandName uenv -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $script:UenvCommands |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
        }
}

Register-ArgumentCompleter -CommandName uenv -ParameterName Name -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $elements = @($commandAst.CommandElements | ForEach-Object { $_.Value })
    $subCommand = ""

    if ($elements.Count -ge 2) {
        $subCommand = [string]$elements[1]
    }

    if ($subCommand -in @("activate", "delete")) {
        if (Test-Path -LiteralPath $script:UenvDir) {
            Get-ChildItem -LiteralPath $script:UenvDir -Directory |
                Select-Object -ExpandProperty Name |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
                }
        }
    }
}

Export-ModuleMember -Function uenv
