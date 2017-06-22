<#PSScriptInfo

.VERSION 1.0.0

.GUID 2f16e59f-b261-41ce-bccc-ac64fa47330a
      
.AUTHOR Jeong Hwan Kim

.TAGS
    IIS, Test, Script, Productivity

.LICENSEURI
    https://github.com/jhkimnew/iistest/blob/master/LICENSE

.PROJECTURI
    https://github.com/jhkimnew/iistest

.DESCRIPTION
    Test IIS.
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