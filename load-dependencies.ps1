try {
	$ModuleManifest = Test-ModuleManifest $PSScriptRoot\*.psd1
	Get-Module $ModuleManifest.Name | % {
		$_.ExportedTypeFiles | % {
			Remove-TypeData -Path $_
		}
	}
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
					Write-Verbose "Installing package $PackageName version $Version from source $Source"
					Install-Package -ProviderName $ProviderName -Name $PackageName -RequiredVersion $Version -Source $Source -Destination $_.Destination
				}
				Write-Verbose 'Loading assemblies'
				$RequiredPackage.RequiredAssemblies | % {
					Add-Type -Path (Join-Path $Destination $_)
				}
				#$Package.PackageFilename -replace '\.nupkg$'
			}
			'powershellget|gitlab' {
				#powershellget:PSScriptAnalyzer/1.5.0#PSGallery
				#gitlab:Networking/1.2.0#Intermedia
				$Module = Get-Module -Name $PackageName -ListAvailable | ? Version -eq $Version
				if (-not $Module) {
					Write-Verbose "Installing module $PackageName version $Version from source $Source"
					Import-PackageProvider $ProviderName
					switch ($ProviderName) {
						powershellget {
							Install-Module -Name $PackageName -RequiredVersion $Version -Repository $Source
						}
						gitlab {
							$Credential = Get-Credential -Message "Provider $ProviderName source $Source"
							Install-Package -ProviderName $ProviderName -Credential $Credential -Name $PackageName -RequiredVersion $Version -Source $Source
						}
					}
					Import-Module -Name $PackageName -RequiredVersion $Version -WarningAction SilentlyContinue -ea Stop
				}
			}
			'chocolatey' {
				#chocolatey:OpenSSL.Light/1.1.0.20160926#
				# until Chocolatey provider did not go GA
				$Package = choco list $PackageName --local-only
				if (-not $Package -match [regex]::Escape($PackageName)) {
					Write-Verbose "Installing package $PackageName version $Version from source $Source"
					choco install -y $PackageName
				}
				$Destination = $RequiredPackage.Destination
				#$Package = Get-Package -Name $PackageName -RequiredVersion $Version -ProviderName $ProviderName
				#if (-not $Package) {
				#	Install-Package -Name $PackageName -RequiredVersion $Version -ProviderName $ProviderName
				#}
			}
			'.*' {
				if ($env:Path -notlike "*$Destination*" -and $RequiredPackage.EnvPath) {
					Write-Verbose 'Updating $Path'
					$MachinePath = [System.Environment]::GetEnvironmentVariable('Path','Machine')
					[System.Environment]::SetEnvironmentVariable('Path',$MachinePath + ";$Destination",'Machine')
					$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine')
				}
			}
		}
	}
} catch {
	Write-Error $_.Exception
	throw 'Failed to load required dependency'
}