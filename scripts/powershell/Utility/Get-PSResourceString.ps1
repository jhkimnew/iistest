########################################################################################################################
# NAME
#     Get-PSResourceString
#
# SYNOPSIS
#     Returns a resource string that is looked up in the System.Management.Automation namespace or the
#     Microsoft.PowerShell.ConsoleHost namespace, or a list of resource root names or resource identifiers that are
#     available.
#
# SYNTAX
#     Get-PSResourceString [-baseName] <string> [-resourceId] <string> [[-defaultValue] <string>]
#     [[-culture] <System.Globalization.CultureInfo>]
#     Get-PSResourceString [[-baseName] <string>] -list
#
# DETAILED DESCRIPTION
#     The Get-PSResourceString function returns a resource string that is looked up in the System.Management.Automation
#     namespace or the Microsoft.PowerShell.ConsoleHost namespace, or a list of resource root names or resource
#     identifiers that are available. If a resource string was requested and it is not found, the default value (if
#     present) will be returned.
#
# PARAMETERS
#     -baseName <string>
#         Specifies the root name of the resources.
#
#         Required?                    true
#         Position?                    1
#         Default value
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
#     -resourceId <string>
#         Specifies the identifier of the resource that is being retrieved.
#
#         Required?                    true
#         Position?                    2
#         Default value
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
#     -defaultValue <string>
#         Specifies the default value for the resource string. If the string is not found, the default value will be
#         returned.
#
#         Required?                    false
#         Position?                    3
#         Default value                null
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
#     -culture <System.Globalization.CultureInfo>
#         Specifies the culture to use when looking up the resource string.
#
#         Required?                    false
#         Position?                    4
#         Default value                $host.CurrentCulture
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
#     -list <Switch>
#         When this parameter is used by itself, this function outputs the root names that are available. When this
#         parameter is used in conjunction with the baseName parameter, this function outputs the resource identifiers
#         that are availab.e
#
#         Required?                    false
#         Position?                    named
#         Default value                false
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
# INPUT TYPE
#     String,System.Globalization.CultureInfo,Switch
#
# RETURN TYPE
#     String,String[]
#
# NOTES
#     For more information the System.Globalization.CultureInfo type consult the relevant MSDN documentation.
#
#     -------------------------- EXAMPLE 1 --------------------------
#
#     C:\PS>get-psresourcestring -list
#
#
#     This command retrieves the list of resource root names that are available.
#
#
#     -------------------------- EXAMPLE 2 --------------------------
#
#     C:\PS>get-psresourcestring -basename helpdisplaystrings -list 
#
#
#     This command retrieves the list of resource strings in the resource root called 'helpdisplaystrings' using the
#     current culture.
#
#
#     -------------------------- EXAMPLE 3 --------------------------
#
#     C:\PS>get-psresourcestring -list | foreach-object { get-psresourcestring -basename $_ -list }
#
#
#     This command retrieves all resource strings that are available using the current culture.
#
#
#     -------------------------- EXAMPLE 4 --------------------------
#
#     C:\PS>get-psresourcestring -basename helpdisplaystrings -resourceid falseshort
#
#
#     This command retrieves the string associated with the 'falseshort' resource id using the current culture.
#
#

function global:Get-PSResourceString {
	param(
		[string]$baseName = $null,
		[string]$resourceId = $null,
		[string]$defaultValue = $null,
		[System.Globalization.CultureInfo]$culture = $host.CurrentCulture,
		[Switch]$list
	)
	
	if ($list -and ($resourceId -or $defaultValue)) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	}

	if ($list) {
		$engineAssembly = [psobject].Assembly
		$hostAssembly = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.PowerShell.ConsoleHost')
		if ($baseName) {
			$engineAssembly.GetManifestResourceNames() | Where-Object { $_ -eq "$baseName.resources" } | ForEach-Object {
				$resourceManager = New-Object -TypeName System.Resources.ResourceManager($baseName, $engineAssembly)
				$resourceManager.GetResourceSet($host.CurrentCulture,$true,$true) | Add-Member -Name BaseName -MemberType NoteProperty -Value $baseName -Force -PassThru | ForEach-Object {
					$_.PSObject.TypeNames.Clear()
					$_.PSObject.TypeNames.Add('ResourceString')
					$_ | Write-Output
				}
			}
			$hostAssembly.GetManifestResourceNames() | Where-Object { $_ -eq "$baseName.resources" } | ForEach-Object {
				$resourceManager = New-Object -TypeName System.Resources.ResourceManager($baseName, $hostAssembly)
				$resourceManager.GetResourceSet($host.CurrentCulture,$true,$true) | Add-Member -Name BaseName -MemberType NoteProperty -Value $baseName -Force -PassThru | ForEach-Object {
					$_.PSObject.TypeNames.Clear()
					$_.PSObject.TypeNames.Add('ResourceString')
					$_ | Write-Output
				}
			}
		} else {
			$engineAssembly.GetManifestResourceNames() | Where-Object { $_ -match '\.resources$' } | ForEach-Object { $_.Replace('.resources','') }
			$hostAssembly.GetManifestResourceNames() | Where-Object { $_ -match '\.resources$' } | ForEach-Object { $_.Replace('.resources','') }
		}
	} else {
		if (-not $baseName) {
			throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'BaseName')
		}
		if (-not $resourceId) {
			throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'ResourceId')
		}
		if (-not $global:PSResourceStringTable) {
			$engineAssembly = [psobject].Assembly
			$hostAssembly = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.PowerShell.ConsoleHost')
			if ($engineAssembly.GetManifestResourceNames() -contains "$baseName.resources") {
				New-Variable -Scope Global -Name PSResourceStringTable -Value @{} -Description 'A cache of PowerShell resource strings. To access data in this table, use Get-ResourceString.'
				$global:PSResourceStringTable['EngineAssembly'] = @{'Assembly'=$engineAssembly;'Cultures'=@{}}
				$global:PSResourceStringTable['HostAssembly'] = @{'Assembly'=$hostAssembly;'Cultures'=@{}}
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($baseName, $global:PSResourceStringTable.EngineAssembly.Assembly));
				$global:PSResourceStringTable.EngineAssembly.Cultures[$culture.Name] = @{($baseName)=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($culture,$true,$true)}};
			} elseif ($hostAssembly.GetManifestResourceNames() -contains "$baseName.resources") {
				New-Variable -Scope Global -Name PSResourceStringTable -Value @{} -Description 'A cache of PowerShell resource strings. To access data in this table, use Get-ResourceString.'
				$global:PSResourceStringTable['EngineAssembly'] = @{'Assembly'=$engineAssembly;'Cultures'=@{}}
				$global:PSResourceStringTable['HostAssembly'] = @{'Assembly'=$hostAssembly;'Cultures'=@{}}
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($baseName, $global:PSResourceStringTable.HostAssembly.Assembly));
				$global:PSResourceStringTable.HostAssembly.Cultures[$culture.Name] = @{($baseName)=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($culture,$true,$true)}};
			}
		} elseif ($global:PSResourceStringTable.EngineAssembly.Assembly.GetManifestResourceNames() -contains "$baseName.resources") {
			if (-not $global:PSResourceStringTable.EngineAssembly.Cultures.ContainsKey($culture.Name)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($baseName, $global:PSResourceStringTable.EngineAssembly.Assembly));
				$global:PSResourceStringTable.EngineAssembly.Cultures[$culture.Name] = @{($baseName)=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($culture,$true,$true)}};
			} elseif (-not $global:PSResourceStringTable.EngineAssembly.Cultures[$culture.Name].ContainsKey($baseName)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($baseName, $global:PSResourceStringTable.EngineAssembly.Assembly));
				$global:PSResourceStringTable.EngineAssembly.Cultures[$culture.Name][$baseName] = @{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($culture,$true,$true)};
			}
		} elseif ($global:PSResourceStringTable.HostAssembly.Assembly.GetManifestResourceNames() -contains "$baseName.resources") {
			if (-not $global:PSResourceStringTable.HostAssembly.Cultures.ContainsKey($culture.Name)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($baseName, $global:PSResourceStringTable.HostAssembly.Assembly));
				$global:PSResourceStringTable.HostAssembly.Cultures[$culture.Name] = @{($baseName)=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($culture,$true,$true)}};
			} elseif (-not $global:PSResourceStringTable.HostAssembly.Cultures[$culture.Name].ContainsKey($baseName)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($baseName, $global:PSResourceStringTable.HostAssembly.Assembly));
				$global:PSResourceStringTable.HostAssembly.Cultures[$culture.Name][$baseName] = @{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($culture,$true,$true)};
			}
		}

		$resourceString = $null
		if ($global:PSResourceStringTable) {
			if ($global:PSResourceStringTable.EngineAssembly.Cultures -and $global:PSResourceStringTable.EngineAssembly.Cultures.ContainsKey($culture.Name) -and $global:PSResourceStringTable.EngineAssembly.Cultures[$culture.Name].ContainsKey($baseName)) {
				$resourceString = ($global:PSResourceStringTable.EngineAssembly.Cultures[$culture.Name][$baseName].Strings | Where-Object { $_.Name -eq $resourceId }).Value
			} elseif ($global:PSResourceStringTable.HostAssembly.Cultures -and $global:PSResourceStringTable.HostAssembly.Cultures.ContainsKey($culture.Name) -and $global:PSResourceStringTable.HostAssembly.Cultures[$culture.Name].ContainsKey($baseName)) {
				$resourceString = ($global:PSResourceStringTable.HostAssembly.Cultures[$culture.Name][$baseName].Strings | Where-Object { $_.Name -eq $resourceId }).Value
			}
		}
		if (-not $resourceString) {
			$resourceString = $defaultValue
		}
		
		return $resourceString
	}
}
