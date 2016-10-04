[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param()

$PSDefaultParameterValues = $Global:PSDefaultParameterValues

try {
	$ModuleManifest = Test-ModuleManifest $PSScriptRoot\*.psd1
	Get-Module $ModuleManifest.Name | Remove-TypeData
	# for msi modules like VMware
	$ModuleManifest.RequiredModules | % {
		Import-Module -Name $_.Name -RequiredVersion $_.Version -ea Stop
	}
	@($ModuleManifest.PrivateData.RequiredPackages) -ne $null | % {
		$ProviderName,$PackageName,$Version,$Source = $_.CanonicalId.Split(':/#')
		$RequiredPackage = $_
		switch -Regex ($ProviderName) {
			'nuget' {
				#nuget:Microsoft.Exchange.WebServices/2.2#nuget.org
				$Destination = Join-Path $RequiredPackage.Destination "$PackageName.$Version"
				if (-not (Test-Path $Destination)) {
					Write-Verbose "Package $PackageName version $Version cannot be found"
					if ($PSCmdlet.ShouldProcess("$PackageName $Version","Install from $Source")) {
						Find-Package -ProviderName $ProviderName -Name $PackageName -RequiredVersion $Version -Source $Source |
						Install-Package -Destination $_.Destination
					} else {
						throw "Package $PackageName version $Version is not installed"
					}
				}
				Write-Verbose 'Loading assemblies'
				$RequiredPackage.RequiredAssemblies | % {
					Add-Type -Path (Join-Path $Destination $_)
				}
				#$Package.PackageFilename -replace '\.nupkg$'
				if ($env:Path -notlike "*$Destination*" -and $RequiredPackage.EnvPath) {
					Write-Verbose 'Updating $Path'
					$MachinePath = [System.Environment]::GetEnvironmentVariable('Path','Machine')
					[System.Environment]::SetEnvironmentVariable('Path',$MachinePath + ";$Destination",'Machine')
					$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine')
				}
			}
			'powershellget|gitlab' {
				#powershellget:PSScriptAnalyzer/1.5.0#PSGallery
				#gitlab:Networking/1.2.0#Intermedia
				$Module = Get-Module -FullyQualifiedName @{ModuleName = $PackageName; ModuleVersion = $Version} -ListAvailable
				if (-not $Module) {
					Write-Verbose "Module $PackageName version $Version cannot be found"
					if ($PSCmdlet.ShouldProcess("$PackageName $Version","Install from $Source")) {
						Import-PackageProvider $ProviderName
						switch ($ProviderName) {
							powershellget {
								Install-Module -Name $PackageName -RequiredVersion $Version -Repository $Source
							}
							gitlab {
								$Credential = Get-Credential -Message "Provider $ProviderName Source $Source"
								Find-Package -ProviderName $ProviderName -Credential $Credential -Name $PackageName -RequiredVersion $Version | Install-Package
							}
						}
					} else {
						throw "Package $PackageName version $Version is not installed"
					}
					Import-Module -Name $PackageName -RequiredVersion $Version -ea Stop
				}
			}
		}
	}
} catch {
	Write-Error $_.Exception
	throw 'Failed to load required dependency'
}