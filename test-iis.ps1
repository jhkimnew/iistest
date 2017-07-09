
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

 Whenever code is updated, make sure there is no error or warning from ScriptAnalyzer

 Install-Module PSScriptAnalyzer
 Import-Module psscriptanalyzer
 Invoke-ScriptAnalyzer -Path .\test-iis.ps1 
#> 
[CmdletBinding()]
[Alias("IISTEST")]
[OutputType([String[]], [String])]
Param
(
    [Parameter(Position=0)]
    [ValidateSet('CORS','IISAdministration')]
    [String] $Feature
 
)
function Test-IISServer
{
    [CmdletBinding()]
    [Alias("TEST-IIS")]
    [OutputType([String[]], [String])]
    Param
    (
        [Parameter(Position=0)]
        $Feature
    )

    $global:g_testDir = (get-item .).FullName
    $global:g_iistest = $true

    if ($Feature)
    {
       switch ($Feature)
       {
           "IISAdministration" { ("Test-IISAdministration") }
           "CORS"              { ("Test-CORS")              }
           default             { Write-Warning ("Unsupported feature name '" + $Feature + "'") }
       }
    }
    else
    {
        Write-Warning "Feature parameter is not set"
    }
}

function Test-IISAdministration
{
    ("Test-IISAdministration")
}

function Test-CORS
{
    ("Test-CORS")
}

# Call Test-IISServer function
Test-IISServer @PSBOundParameters
#EOF

