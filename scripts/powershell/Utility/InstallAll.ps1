# Set g_testDir, which is supposed to be set by the driver.js when this ps1 file is executed
if ($g_testDir -eq $null)
{
    $global:g_testDir = join-path $env:windir "system32\webtest"
}

#
# Load utility scripts
#
&($g_testDir+'\scripts\Powershell\Utility\Get-PSResourceString.ps1')
&($g_testDir+'\scripts\Powershell\Utility\Get-WebSchema.ps1')
&($g_testDir+'\scripts\Powershell\Utility\Get-WebWmiObject.ps1')
