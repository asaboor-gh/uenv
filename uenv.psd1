@{
    RootModule = 'uenv.psm1'
    ModuleVersion = '0.1.0'
    GUID = '9c7f8722-d6b0-4e24-8ea7-62db8358f9bf'
    Author = 'uenv contributors'
    CompanyName = 'Community'
    Copyright = '(c) 2026 uenv contributors. All rights reserved.'
    Description = 'Named virtual environment manager for uv users.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @('uenv')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('uv', 'python', 'virtualenv', 'environment')
            ProjectUri = 'https://github.com/asaboor-gh/uenv'
            LicenseUri = 'https://github.com/asaboor-gh/uenv/blob/main/LICENSE'
            ReleaseNotes = 'Initial module release.'
        }
    }
}
