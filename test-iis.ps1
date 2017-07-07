
<#PSScriptInfo

.VERSION 1.2

.GUID 2f16e59f-b261-41ce-bccc-ac64fa47330a

.AUTHOR TBD

.COMPANYNAME TBD

.COPYRIGHT TBD

.TAGS IIS

.LICENSEURI TBD 

.PROJECTURI https://github.com/jhkimnew/iistest

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
[Alias("IISTEST")]
[OutputType([string[]])]
Param
(
    [Parameter(Position=0)]
    $Feature
 
)
function Test-Iis
{
    [CmdletBinding()]
    [Alias("iis-test")]
    [OutputType([string[]])]
    Param
    (
        [Parameter(Position=0)]
        $Feature
    )

    if ($Feature)
    {
       Invoke-WebRequest http://localhost    
    }
}
Test-Iis @PSBOundParameters
#EOF

