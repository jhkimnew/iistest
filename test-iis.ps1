
<#PSScriptInfo

.VERSION 1.1

.GUID 2f16e59f-b261-41ce-bccc-ac64fa47330a

.AUTHOR jhkim@microsoft.com

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 test tool for verifying IIS features 

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

