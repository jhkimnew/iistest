<#PSScriptInfo

.VERSION 1.0.0

.GUID 1b4ee806-349d-3108-9126-c7692d602ebc

.AUTHOR Jeong Hwan Kim

.COMPANYNAME Microsoft Corporation

.COPYRIGHT (C) Microsoft Corporation. All rights reserved.

.TAGS IIS

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>

<# 
.Synopsis
   Show an ASCII text representation of a namespace tree
.DESCRIPTION 
 Script to test IIS web sites
.EXAMPLE
PS> test-iis -Feature CORS

#>
[CmdletBinding()]
[Alias("IIS")]
[OutputType([string[]])]
Param
(
    [Parameter(Position=0)]
    $Feature = "CORS"
 
)
function Test-Iis
{
    [CmdletBinding()]
    [Alias("iis-test")]
    [OutputType([string[]])]
    Param
    (
        [Parameter(Position=0)]
        $Feature = "CORS"
    )

    Invoke-WebRequest http://localhost    
}
Test-Iis @PSBOundParameters
#EOF