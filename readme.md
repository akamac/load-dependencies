#### Install and load PowerShell module dependencies

To use in your module, add as a submodule to your project into `load` directory and list dependencies in the module's manifest:

```
@{
    RequiredModules =
        @{ModuleName = 'VMware.VimAutomation.Storage'; ModuleVersion = '6.3.0.0'},
        @{ModuleName = 'VirtualMachineManager'; ModuleVersion = '1.0'}
        @{ModuleName = 'ActiveDirectory'; ModuleVersion = '1.0.0.0'}
    ScriptsToProcess = @('load\load-dependencies.ps1')
    PrivateData = @{
        RequiredPackages = @(
            @{CanonicalId = 'gitlab:CredentialManagement/1.2.1#CompanySource'},
            @{CanonicalId = 'powershellget:PSScriptAnalyzer/1.5.0#PSGallery'},
            @{
                CanonicalId = 'nuget:Microsoft.Exchange.WebServices/2.2#nuget.org'
                Destination = 'C:\ProgramData\NuGet\Packages'
                RequiredAssemblies = @('\lib\40\Microsoft.Exchange.WebServices.dll')
                EnvPath = $false # Machine
            },
            @{
                CanonicalId = 'chocolatey:OpenSSL.Light/1.1.0.20160926#'
                # only default install path is supported for chocolatey packages
                Destination = 'C:\Program Files\OpenSSL\bin'
                EnvPath = $true # Machine
            }
        )
    }
}
```
