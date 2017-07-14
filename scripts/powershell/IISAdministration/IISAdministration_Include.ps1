#///////////////////////////////////////////////////////////////////////////////
#
# Module Name:
#    
#    IISProvider_Include.ps1
#
# Abstract:
#    
#    Include file for testing IIS Powershell Provider
#
#///////////////////////////////////////////////////////////////////////////////

# Set g_testDir, which is supposed to be set by the driver.js when this ps1 file is executed
if ($global:g_testDir -eq $null)
{  
    $tempPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    $tempPath = Split-Path -Parent -Path $tempPath
    $tempPath = Split-Path -Parent -Path $tempPath
    $tempPath = Split-Path -Parent -Path $tempPath
    $global:g_testDir = $tempPath
}

#
# Excute test framework to load libary functions and variables
#
&($global:g_testDir+'\scripts\Powershell\Powershell_Common_Include.ps1')

#
# Local variables
#
$rootWebconfigPath = Join-Path -path $runtimeDeirectory -childpath "config\web.config"
$rootWebconfigBackupPath = Join-Path -path $runtimeDeirectory -childpath "config\web_backup.config"

$IISVersionMaj = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\InetStp" -Name "MajorVersion").MajorVersion
if($IISVersionMaj -ge 10)
{
    #TBD
}

#////////////////////////////////////////////
#
#
#Routine Description:
#
#    Validates the context where the tests are running
#    Should make sure that MSFTPSVC is installed
#
#Arguments:
#
#    none
#
#Return Value:
#
#    0 - context is proper for running the tests
#    1 - context does not satify the area requirements
#    2 - exception during validation
#
#////////////////////////////////////////////
function global:ValidateContext()
{
    $result = 0

    #if (TBD -eq 1)
    #{
    #    $result = 1;
    #}
    return $result
}

#///////////////////////////////////////////////////////////////////////////////
#
#Routine Description:
#
#    Test wide initialization
#
#Arguments:
#
#    objContext  - Context object
#
#Return Value:
#
#    true        - Initialization successful
#    false       - Initialization unsuccessful
#///////////////////////////////////////////////////////////////////////////////

$initialize = {
    # Execute BaseInitalize function
    if ( (BaseInitialize($objContext) ) -ne $true ) {
       return $false;
    }

    # Initialize IIS Provider test environment
    #if (TBD -ne $true) 
    #{
    #    return $false
    #}

    #
    # Initialize some other commonly used test objects
    #
    $testarea.g_objContextValidation = 0;

    LogDebug "Validate context"
    $testarea.g_objContextValidation = ValidateContext

    start-sleep -m 500
    return $true 
    trap
    {
        LogFunctionError $_
    }
}

#///////////////////////////////////////////////////////////////////////////////
#Routine Description:
#
#    Test wide execute
#
#Arguments:
#
#    objContext  - Context object
#
#Return Value:
#
#    true        - Initialization successful
#    false       - Initialization unsuccessful
#///////////////////////////////////////////////////////////////////////////////

$execute = {

    # Execute BaseExecute function
    if ( (BaseExecute($objContext) ) -ne $true ) {
       return $false;
    }
    return $true
    trap
    {
        LogFunctionError $_
    }
}

#///////////////////////////////////////////////////////////////////////////////
#Routine Description:
#
#    Test wide termination
#
#Arguments:
#
#    objContext  - Context object
#
#Return Value:
#
#    true        - Initialization successful
#    false       - Initialization unsuccessful
#///////////////////////////////////////////////////////////////////////////////

$terminate = {

    # Execute BaseTerminate function
    if ( (BaseTerminate($objContext) ) -ne $true ) {
        return $false;
    }

    # Clean up IIS Provider test environment
    #if (TBD) -ne $true) 
    #{
    #    return $false
    #}
    return $true
    trap
    {
        LogFunctionError $_
    }
}

#////////////////////////////////////////////
#
# Initialize testarea object
#
#////////////////////////////////////////////

$global:testarea = new-object psobject
add-member -in $testarea noteproperty g_objContextValidation 0
add-member -in $testarea scriptmethod Initialize $initialize
add-member -in $testarea scriptmethod Execute $execute
add-member -in $testarea scriptmethod Terminate $terminate

$global:g_dwsDirPath = join-path $env:systemdrive "inetpub\wwwroot"
$global:g_dwsDirPathEnv = "%SystemDrive%\inetpub\wwwroot"

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Verify test is ready to start
#
#////////////////////////////////////////////
function global:IISTest-Ready()
{
    LogDebug ("Start IISTest-Ready...")
    if ( $testarea.g_objContextValidation -eq 1 )
    {
        return $false        
    }

    $webConfigFilePath = (Get-item 'IIS:\Sites\Default Web Site').physicalPath
    $webConfigFilePath = [System.Environment]::ExpandEnvironmentVariables($webConfigFilePath) + "\web.config"
    $config = get-item $webConfigFilePath 2> $null
    if ($config -ne $null)
    {
        $longline = ""
        cat $config | foreach { $longline += $_}
        $backup = $longline;
        $longline = $longline.replace("<configuration>", "")
        $longline = $longline.replace("</configuration>", "")
        $longline = $longline.replace('<?xml version="1.0" encoding="UTF-8"?>', "")
        $longline = $longline.trim()
        if ($longline -ne "")
        {
            LogDebug (("IISTest-Ready: Web.Config was not cleaned up: " + $backup))
            remove-item $webConfigFilePath -confirm:$false -recurse 2> $null
        }
    }

    if ($null -eq (get-item 'IIS:\Sites\Default Web Site'))
    {
        LogDebug ("IISTest-Ready: Default Web Site Not Found!!!")
    } 
    else
    {
        $binding = ((get-item 'IIS:\Sites\Default Web Site').bindings.collection | select bindingInformation).bindingInformation
        if ($binding -ne "*:80:")
        {
            LogDebug (("IISTest-Ready: Wrong binding was set for Default Web Site: " + $binding))
            Set-ItemProperty 'IIS:\Sites\Default Web Site' -name bindings @{protocol="http";bindingInformation="*:80:"} 2> $null 
        }

        $dirPath = (get-itemproperty 'IIS:\Sites\Default Web Site' -name physicalPath)
        if ($dirPath -ne $g_dwsDirPathEnv)
        {
            LogDebug (("IISTest-Ready: Wrong physicalPath for Default Web Site: " + $dirPath))
            Set-ItemProperty 'IIS:\Sites\Default Web Site' -name physicalPath $g_dwsDirPathEnv.tostring() 2> $null 
        }

        $result = get-childitem $g_dwsDirPath | foreach {if ($_.Mode -eq "d----") {$_} }
        if ($result -ne $null)
        {
            LogDebug (("IISTest-Ready: Physical Directories are remained"))
            ###get-childitem $g_dwsDirPath | foreach {if ($_.Mode -eq "d----") {remove-item $_ -recurse -confirm:$false} }
        }

    }

    $sites = get-childitem 'IIS:\Sites' 2> $null
    if ($sites.length -ne $null -and $sites.length -ne 1)
    {
        $longline = ""
        LogDebug (("IISTest-Ready: There were uncleared sites in IIS:\Sites folder!!! : " + $longline))
    } 

    $locations = Get-WebConfigurationlocation 'iis:\' 2> $null
    if ($locations -ne $null)
    {
        $longline = ""
        $locations | foreach { 
            $longline += ($_.name+",")
        }
        LogDebug (("IISTest-Ready: There were uncleared location sections in applicationhost.config: " + $longline))
    }    
    
    LogDebug ("End IISTest-Ready...")
    return $true

    trap
    {
        LogDebug ("IISTest-Ready causes an exception error...")
        LogFunctionError $_
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    SetEnvPath using pipleline
#
#////////////////////////////////////////////
function global:IISTest-SetEnvPath() 
{ 
    foreach ($item in $input)
    {	
        if ($item.indexof(".txt") -gt 0) 
        { 
            $global:TestLocation = $item.split("\")[$g_testEnv.Path.split("\").length - 1] 
            $global:TestPSPath = $item.subString(0, $g_testEnv.Path.indexof($global:TestLocation))
        } 
        else 
        {
            $global:TestLocation = "" 
            $global:TestPSPath = $g_testEnv.Path; 
        } 

        echo ("### Test case context (PSPath: " + $global:TestPSPath + ", Location: " + $global:TestLocation + ")")
        TestCase
    }
}

#////////////////////////////////////////////
#
# IIS Utilify functions 
#
#////////////////////////////////////////////


#////////////////////////////////////////////
#
#Routine Description: 
#
#    Repeat coping file until destination file is copied correctly
#
#////////////////////////////////////////////
function global:IISTest-SafeCopy($sourceFilePath, $destineFilePath) 
{
    LogDebug ("Start IISTest-SafeCopy...")
    $destineFileLegnth = -1
    $sourceFileLegnth = (get-item $sourceFilePath).length
    if ($sourceFileLegnth -eq 0)
    { 
        throw "Source file length is zero!!!"
    }
     
    $command = "copy /y " + $sourceFilePath + " " + $destineFilePath    
    cmd /c $command 
    start-sleep -m 1000                

    (1..30) | foreach {
        $destineFileLegnth = (get-item $destineFilePath).length
        if ($destineFileLegnth -ne $sourceFileLegnth)
        {
            cmd /c $command
            start-sleep -m 1000
        }
    }

    if ($destineFileLegnth -ne $sourceFileLegnth)
    {
        throw ("Failed copying file from " + $sourceFilePath + " to " + $destineFilePath)  
    }
    LogDebug ("End IISTest-SafeCopy...")
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Repeat removing file until target is removed correctly
#
#////////////////////////////////////////////
function global:IISTest-SafeDelete($targetFilePath) 
{
    LogDebug ("Start IISTest-SafeDelete...")

    $targetItem = get-item $targetFilePath 2> $null
    if ($targetItem -ne $null)
    {
        $command = "del /q " + $targetFilePath 
        cmd /c $command
        start-sleep -m 1000                

        (1..30) | foreach {
            $targetItem = get-item $targetFilePath 2> $null
            if ($targetItem -ne $null)
            {
                cmd /c $command
                start-sleep -m 1000
            }
        }

        if ($targetItem -ne $null)
        {
            throw ("Failed removing file " + $targetFilePath)  
        }
    }
    LogDebug ("End IISTest-SafeDelete...")
}

function global:IISTest-RestoreRootWebConfig()
{
    if((Test-Path $rootWebconfigBackupPath) -ne $true)
    {
        BackupRootWebConfig
        Start-Sleep 1
    }
    Copy-Item -Path $rootWebconfigBackupPath -Destination $rootWebconfigPath -Force
}

function global:IISTest-BackupRootWebConfig()
{
    if (-not (test-path $rootWebconfigBackupPath))
    {
        Copy-Item -Path $rootWebconfigPath -Destination $rootWebconfigBackupPath -Force    
    }
    global:IISTest-RestoreRootWebConfig
}

function global:IISTest-RestoreAppHostConfig()
{
    Stop-Service W3SVC
    Stop-Service WAS
    Copy-Item -Path $env:systemroot\system32\inetsrv\config\applicationHost_IISAdministration.config.bak -Destination $env:systemroot\system32\inetsrv\config\applicationHost.config -Force
    Start-Service W3SVC
}

function global:IISTest-BackupAppHostConfig()
{
    if (-not (test-path $env:systemroot\system32\inetsrv\config\applicationHost_IISAdministration.config.bak))
    {
        Copy-Item -Path $env:systemroot\system32\inetsrv\config\applicationHost.config -Destination $env:systemroot\system32\inetsrv\config\applicationHost_IISAdministration.config.bak -Force
    }
    global:IISTest-RestoreAppHostConfig
}
