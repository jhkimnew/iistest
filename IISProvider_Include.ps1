#///////////////////////////////////////////////////////////////////////////////
#
#Module Name:
#    
#    IISProvider_Include.ps1
#
#Abstract:
#    
#    Include file for testing IIS Powershell Provider
#
#
#Author:
#
#    Jeong Hwan Kim (jhkim)      11-July-2008     Created
#    Simon Xu (v-sixu)           27-Jan-2015      Updated
#
#///////////////////////////////////////////////////////////////////////////////

# Set g_testDir, which is supposed to be set by the driver.js when this ps1 file is executed
if ($g_testDir -eq $null)
{
    $global:g_testDir = join-path $env:windir "system32\webtest"
}

#
# Excute test framework to load libary functions and variables
#
&($g_testDir+'\scripts\Powershell\Powershell_Common_Include.ps1')

# Update help
update-help webadministration -Force

$IISVersionMaj = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\InetStp" -Name "MajorVersion").MajorVersion
if($IISVersionMaj -ge 10)
{
    update-help IISAdministration -Force
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

    if ($g_nIIsBitness -eq 1)
    {
        $result = 1;
    }
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
    if ((IISTest-DoTestEnvironement) -ne $true) 
    {
        return $false
    }

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
    if ((IISTest-DoTestEnvironement -Clear) -ne $true) 
    {
        return $false
    }
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

$global:g_iisIntlObject = new-object -ComObject msutil.iisintl
$global:g_dwsDirPath = join-path $env:systemdrive "inetpub\wwwroot"
$global:g_dwsDirPathEnv = "%SystemDrive%\inetpub\wwwroot"

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Clean up Defalut Web Site home directory path
#
#////////////////////////////////////////////
function global:IISTest-CleanUpDefaultWebSite()
{
    ### Reset IIS config files and initialize global variables
    start-sleep -m 1000    

    $g_iisConfig.RestoreConfig("default",$null,$null,$null)

    start-sleep -m 3000    
    $temp = Get-WebFilePath "iis:\sites\default web site"
    $global:g_dwsDirPath = Join-Path $temp.FullName "iis powershell"
    $global:g_dwsDirPath = $global:g_dwsDirPath.tostring()

    ### Prepare a new physical directory of Default Web Site
    $result = $null = get-item $global:g_dwsDirPath 2> $null
    remove-item $global:g_dwsDirPath -recurse -confirm:$false 2> $null
    new-item $global:g_dwsDirPath -type directory 2> $null > $null

    $filePath = Join-Path $global:g_dwsDirPath "iisstart.htm" 
    Set-Content $filePath "iisstart.htm"

    ### Update applicationhost.config with a new physical directory for Default Web Site
    $global:g_dwsDirPathEnv = Join-Path (get-itemproperty 'IIS:\Sites\Default Web Site' -name physicalPath) "iis powershell"
    $global:g_dwsDirPathEnv = $global:g_dwsDirPathEnv.tostring()
    set-itemProperty 'IIS:\Sites\Default Web Site' -name physicalPath -value $global:g_dwsDirPathEnv.tostring()
    $result = $null = (get-item $global:g_dwsDirPath).name

    if ("iis powershell" -ne $result.tostring())
    {
       throw "New Default Web Site's physical path Not Exist"
    }

    $result = $null = (get-itemproperty 'IIS:\Sites\Default Web Site' -name physicalPath)
    if ($global:g_dwsDirPathEnv.tostring() -ne $result.tostring())
    {
       throw "New Default Web Site's physical path Not Exist"
    }

    trap
    {
        LogDebug "Exception error on IISTest-CleanUpDefaultWebSite()"
        #LogFunctionError $_
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Get IIS Powershell Provider resource strings
#
#////////////////////////////////////////////
function global:IISTest-GetResourceString {
    param(
        [string]$ResourceId = $null,
        [string]$BaseName = $null,
        [Switch]$List
    )
    if ($list -and $resourceId)
    {
        throw $("IISTest-IISProviderResourceString -List -ResourceId 'AmbiguousParameterSet'")
    }

    $uiculture = get-uiculture
    $twoLetterLangName = $uiculture.name
    $twoLetterLangName = $twoLetterLangName.split("-")[0] 

    $assemplyPath = ("Microsoft.IIS.PowerShell.Provider.Resources, Version=7.5.0.0, Culture="+$twoLetterLangName+", PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL"),
                    ("Microsoft.IIS.PowerShell.Framework.Resources, Version=7.5.0.0, Culture="+$twoLetterLangName+", PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL"),
                    ("Microsoft.BestPractices.Resources, Version=6.1.0.0, Culture="+$twoLetterLangName+", PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL")

    $assemplyPath | ForEach-Object {
        $path = $_
        $hostAssembly = [System.Reflection.Assembly]::Load($path)
        $baseNameInPath = ($path.split(",")[0]+"."+$twoLetterLangName)
        $hostAssembly.GetManifestResourceNames() | Where-Object { $_ -eq "$baseNameInPath.resources" } | ForEach-Object {
            $result = $null
            $resourceManager = New-Object -TypeName System.Resources.ResourceManager($baseNameInPath, $hostAssembly)
            if ($list)
            {
                $resourceManager.GetResourceSet($uiculture,$true,$true) | Add-Member -Name BaseName -MemberType NoteProperty -Value $baseNameInPath -Force -PassThru | ForEach-Object {
                    $_.PSObject.TypeNames.Clear()
                    $_.PSObject.TypeNames.Add('ResourceString')
                    $_ | Write-Output
                }
            }
            else
            {
                if (($baseName -eq $null) -or ($baseNameInPath.tolower().indexof(($baseName.tolower())) -ne -1)) {
                    $resourceManager.GetString($resourceId, $uiculture)      
                }
            } 
        }
    }
}


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
#    Restart IIS Services
#
#////////////////////////////////////////////
function global:IISTest-RestartIISService ()
{
    LogDebug "Restarting IIS Services..."
    $g_scriptUtil.StopService("WAS",$null) > $null

    ## Start W3SVC service
    $g_scriptUtil.StartService("W3SVC",$null) > $null
    $g_scriptUtil.StartService("HTTP",$null) > $null
    start-website "Default Web Site" > $null
    Start-WebAppPool DefaultAppPool > $null

    trap
    {
        LogDebug ("IISTest-RestartIISService causes an exception error...")
        LogFunctionError $_
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Prepare IIS Provider test environment
#
#////////////////////////////////////////////
function global:IISTest-DoTestEnvironement ([switch]$Clear)
{
    # Do nothing if IIS Bitness is 32 bit mode
    if ($g_nIIsBitness -eq 1) {
        return $true
    }
    
    if ($Clear) {
        LogDebug "Enter IISTest-DoTestEnvironement -Clear for BVT"
        if ($global:__metadata_BvtMode -eq $true) 
        {
            LogDebug "Exit IISTest-DoTestEnvironement -Clear for BVT"
            return $true
        }

        LogDebug "Exit IISTest-DoTestEnvironement -Clear for BVT"
        LogDebug "Enter IISTest-DoTestEnvironement -Clear for Non BVT"

        LogDebug "Exit IISTest-DoTestEnvironement -Clear for Non BVT"
        return $true
    }

    LogDebug "Enter IISTest-DoTestEnvironement for BVT"

    ## Restart IIS Services with the default applicationhost.config
    LogDebug "Cleanup Default Web Test..."
    IISTest-CleanUpDefaultWebSite
    
    LogDebug "Restarting IIS Services..."
    IISTest-RestartIISService

    if ($global:__metadata_BvtMode -eq $true) 
    {
        LogDebug "Exit IISTest-DoTestEnvironement for BVT"
        return $true
    }
    LogDebug "Exit IISTest-DoTestEnvironement for BVT"
    LogDebug "Enter IISTest-DoTestEnvironement for Non BVT"
    
    LogDebug "Exit IISTest-DoTestEnvironement for Non BVT"
    return $true
}


#////////////////////////////////////////////
#
#Routine Description: 
#
#    Create Sample Content
#
#////////////////////////////////////////////
function global:CreateWebContent($path, $type, $content)
{
    if ($type.ToString() -eq "file") {
        # remove existing file first and create the file
        remove-item $path -confirm:$false 2> $null  
        $fileContent = $content
        if ($fileContent -ne $null) {
            Set-Content $path $fileContent
        } else {
            new-item $path -type $type 2> $null
        }
    } else {
        # create a directory if the directory does not exist
        get-item $path  2> $null
        if ($? -ne $true) {
            new-item $path -type $type 2> $null   
        }
    }   
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Create Sample Nodes
#
#////////////////////////////////////////////
function global:IISTest-CreateSampleNodes ([switch]$Clear)
{  
    # Cleanup contents - web contents
    get-item ("iis:\sites\" + $g_testEnv.Node_Site) 2> $null
    if ($?) {
        remove-item ("iis:\sites\" + $g_testEnv.Node_Site) -confirm:$false -recurse 2> $null
    }
    get-item ("iis:\apppools\" + $g_testEnv.Node_Pool) 2> $null
    if ($?) {  
        remove-item ("iis:\apppools\" + $g_testEnv.Node_Pool) -confirm:$false -recurse 2> $null
    }

    # remove web.config files recursively 
    $configFiles = get-childitem $g_testEnv.Path_TestRoot -Recurse -filter web.config 2> $null
    if ($configFiles -ne $null) {
        $configFiles | remove-item 
    }

    if ($Clear) {
        return
    }

    # Create contents - physical directories and files
    CreateWebContent $g_testEnv.Path_TestRoot directory $null
    CreateWebContent $g_testEnv.Path_Site directory $null
    CreateWebContent $g_testEnv.Path_Site_Vdir directory $null
    CreateWebContent $g_testEnv.Path_Site_PDir directory $null
    CreateWebContent $g_testEnv.Path_Site_PFile file "Site_PFile" 
    CreateWebContent $g_testEnv.Path_App directory $null
    CreateWebContent $g_testEnv.Path_App_App directory $null
    CreateWebContent $g_testEnv.Path_Vdir directory $null
    CreateWebContent $g_testEnv.Path_PDir directory $null
    CreateWebContent $g_testEnv.Path_Pdir_App directory $null
    CreateWebContent $g_testEnv.Path_Pdir_VDir directory $null
    CreateWebContent $g_testEnv.Path_Pfile file "Pfile" 
      
    # Create Sample Files under the test site
    CreateWebContent ($g_testEnv.Path_Site+'\long.aspx') file "<%@ Page language=`"C#`"%><%System.Threading.Thread.Sleep(30000);Response.Write(`"slept for 30 seconds`");%>"
    CreateWebContent ($g_testEnv.Path_Site+'\index.htm') file "index.htm"
  
    # Create a new apppool
    new-item ("iis:\apppools\" + $g_testEnv.Node_Pool) -itemType apppool

    # change directory to pool
    cd ('iis:\apppools\' + $g_testEnv.Node_Pool)

    # change directory to workerProcesses
    cd ('iis:\apppools\' + $g_testEnv.Node_Pool + '\' + 'workerProcesses')

    # Create a new web site
    new-item ("iis:\sites\" + $g_testEnv.Node_Site) -bindings @{protocol="http";bindingInformation="*:8082:"} -physicalPath $g_testEnv.Path_Site -itemType site

    # change directory to web site
    cd ('iis:\sites\' + $g_testEnv.Node_Site)

    # Create contents for site
    new-item $g_testEnv.Node_Site_VDir -itemType VirtualDirectory -physicalPath $g_testEnv.Path_Site_Vdir

    # Create a new application
    new-item $g_testEnv.Node_App -physicalPath $g_testEnv.Path_App -itemType application

    # change directory to app
    cd ('iis:\sites\' + $g_testEnv.Node_Site + '\' + $g_testEnv.Node_App)

    # Create contents for app
    new-item $g_testEnv.Node_App_App -physicalPath $g_testEnv.Path_App_App -itemType application
    new-item $g_testEnv.Path_App_PDir -type directory 2> $null
    new-item $g_testEnv.Path_App_PFile -type file 2> $null

    # Create vdir
    new-item $g_testEnv.Node_Vdir -physicalPath $g_testEnv.Path_Vdir -itemType virtualdirectory

    # change directory to vdir
    cd ('iis:\sites\' + $g_testEnv.Node_Site + '\' + $g_testEnv.Node_App + '\' + $g_testEnv.Node_Vdir)

    # Create contents for vdir
    cd ('iis:\sites\' + $g_testEnv.Node_Site)
    new-item $g_testEnv.Path_Vdir_App -type directory 2> $null
    new-item ($g_testEnv.Node_App+"\"+$g_testEnv.Node_Vdir+"\"+$g_testEnv.Node_Vdir_App) -physicalPath $g_testEnv.Path_Vdir_App -itemType application
    new-item $g_testEnv.Path_Vdir_PFile -type file 2> $null
    cd ('iis:\sites\' + $g_testEnv.Node_Site + '\' + $g_testEnv.Node_App + '\' + $g_testEnv.Node_Vdir)

    # change directory to Pdir
    cd ('iis:\sites\' + $g_testEnv.Node_Site + '\' + $g_testEnv.Node_App + '\' + $g_testEnv.Node_Vdir + '\' + $g_testEnv.Node_Pdir)

    # Create contents for Pdir
    cd ('iis:\sites\' + $g_testEnv.Node_Site)
    new-item ($g_testEnv.Node_App+"\"+$g_testEnv.Node_Vdir+"\"+$g_testEnv.Node_Pdir+"\"+$g_testEnv.Node_Pdir_App) -type application -physicalPath $g_testEnv.Path_Pdir_App
    cd ('iis:\sites\' + $g_testEnv.Node_Site + '\' + $g_testEnv.Node_App)
    new-item ($g_testEnv.Node_Vdir+"\"+$g_testEnv.Node_Pdir+"\"+$g_testEnv.Node_Pdir_VDir) -type virtualdirectory -physicalPath $g_testEnv.Path_Pdir_VDir
    cd ('iis:\sites\' + $g_testEnv.Node_Site + '\' + $g_testEnv.Node_App + '\' + $g_testEnv.Node_Vdir + '\' + $g_testEnv.Node_Pdir)
    cd \
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


#////////////////////////////////////////////
#
#Routine Description: 
#
#    Initialize TestEnv
#
#////////////////////////////////////////////
function global:IISTest-InitializeTestEnvVariable() 
{
    # Initialize Sample Node Variables
    add-member -in $g_testEnv noteproperty Node_Pool "newPool"
    add-member -in $g_testEnv noteproperty Node_Site "newSite"
    add-member -in $g_testEnv noteproperty Node_App "newApp"
    add-member -in $g_testEnv noteproperty Node_Vdir "newVdir"
    add-member -in $g_testEnv noteproperty Node_Pdir "newPdir"
    add-member -in $g_testEnv noteproperty Node_Pfile "newFile.txt"
    add-member -in $g_testEnv noteproperty Node_Site_VDir "newSite_vdir"
    add-member -in $g_testEnv noteproperty Node_Site_PDir "newSite_pdir"
    add-member -in $g_testEnv noteproperty Node_Site_PFile "newSite_pfile.txt"
    add-member -in $g_testEnv noteproperty Node_App_App "newApp_App"
    add-member -in $g_testEnv noteproperty Node_App_PDir "newApp_pdir"
    add-member -in $g_testEnv noteproperty Node_App_PFile "newApp_pfile.txt"
    add-member -in $g_testEnv noteproperty Node_Vdir_App "newVdir_App"
    add-member -in $g_testEnv noteproperty Node_Vdir_PFile "newVdir_pfile.txt"
    add-member -in $g_testEnv noteproperty Node_Pdir_App "newPdir_App"
    add-member -in $g_testEnv noteproperty Node_Pdir_Vdir "newPdir_vdir"

    # Initialize Sample Node Paths
    add-member -in $g_testEnv noteproperty Path_DefaultWebSite "$env:Systemdrive\inetpub\wwwroot"
    add-member -in $g_testEnv noteproperty Path_TestRoot "$env:Systemdrive\IisPowershell"
    add-member -in $g_testEnv noteproperty Path_Site "$env:Systemdrive\IisPowershell\siteRoot"
    add-member -in $g_testEnv noteproperty Path_App "$env:Systemdrive\IisPowershell\appRoot"
    add-member -in $g_testEnv noteproperty Path_Vdir "$env:Systemdrive\IisPowershell\vdirRoot"
    add-member -in $g_testEnv noteproperty Path_PDir ("$env:Systemdrive\IisPowershell\vdirRoot\" + $g_testEnv.Node_Pdir)    
    add-member -in $g_testEnv noteproperty Path_Pfile ("$env:Systemdrive\IisPowershell\vdirRoot\" + $g_testEnv.Node_Pdir + '\' + $g_testEnv.Node_Pfile)
    add-member -in $g_testEnv noteproperty Path_Site_Vdir "$env:Systemdrive\IisPowershell\site_VdirRoot"
    add-member -in $g_testEnv noteproperty Path_Site_PDir ("$env:Systemdrive\IisPowershell\siteRoot\" + $g_testEnv.Node_Site_PDir)
    add-member -in $g_testEnv noteproperty Path_Site_PFile ("$env:Systemdrive\IisPowershell\siteRoot\" + $g_testEnv.Node_Site_PFile)
    add-member -in $g_testEnv noteproperty Path_App_App "$env:Systemdrive\IisPowershell\app_AppRoot"
    add-member -in $g_testEnv noteproperty Path_App_PDir ("$env:Systemdrive\IisPowershell\appRoot\" + $g_testEnv.Node_App_PDir)
    add-member -in $g_testEnv noteproperty Path_App_PFile ("$env:Systemdrive\IisPowershell\appRoot\" + $g_testEnv.Node_App_PFile)
    add-member -in $g_testEnv noteproperty Path_Vdir_App "$env:Systemdrive\IisPowershell\vdir_AppRoot"
    add-member -in $g_testEnv noteproperty Path_Vdir_PFile ("$env:Systemdrive\IisPowershell\vdirRoot\" + $g_testEnv.Node_Vdir_PFile)
    add-member -in $g_testEnv noteproperty Path_Pdir_App "$env:Systemdrive\IisPowershell\pdir_AppRoot"
    add-member -in $g_testEnv noteproperty Path_Pdir_VDir "$env:Systemdrive\IisPowershell\pdir_VdirRoot"

    # Initialize Common Path Variables
    add-member -in $g_testEnv noteproperty Path_MachineConfigFile "$env:Systemdrive\windows\Microsoft.NET\Framework\v2.0.50727\config\machine.config"
    add-member -in $g_testEnv noteproperty Path_WebRootConfigFile "$env:Systemdrive\windows\Microsoft.NET\Framework\v2.0.50727\config\web.config"
    add-member -in $g_testEnv noteproperty Path_ApplicationHostConfigFile "$env:Systemdrive\windows\system32\inetsrv\config\applicationHost.config"

    # Initialize PSPath
    add-member -in $g_testEnv noteproperty PSPath_Root "iis:\"
    add-member -in $g_testEnv noteproperty PSPath_SslBindings "iis:\sslbindings"
    add-member -in $g_testEnv noteproperty PSPath_IPPort "iis:\sslbindings\0.0.0.0!8172"
    add-member -in $g_testEnv noteproperty PSPath_Sites "iis:\sites"
    add-member -in $g_testEnv noteproperty PSPath_Pools "iis:\apppools"
    add-member -in $g_testEnv noteproperty PSPath_Site ("iis:\sites\" + $g_testEnv.Node_Site)
    add-member -in $g_testEnv noteproperty PSPath_Pool ("iis:\apppools\" + $g_testEnv.Node_Pool)
    add-member -in $g_testEnv noteproperty PSPath_App ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App)
    add-member -in $g_testEnv noteproperty PSPath_VDir ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir)
    add-member -in $g_testEnv noteproperty PSPath_PDir ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir + "\" + $g_testEnv.Node_Pdir)
    add-member -in $g_testEnv noteproperty PSPath_PFile ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir + "\" + $g_testEnv.Node_Pdir + "\" + $g_testEnv.Node_Pfile)
    add-member -in $g_testEnv noteproperty PSPath_Site_VDir ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_Site_Vdir)
    add-member -in $g_testEnv noteproperty PSPath_Site_PDir ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_Site_PDir)
    add-member -in $g_testEnv noteproperty PSPath_Site_PFile ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_Site_Pfile)
    add-member -in $g_testEnv noteproperty PSPath_App_App ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_App_App)
    add-member -in $g_testEnv noteproperty PSPath_App_PDir ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_App_Pdir)
    add-member -in $g_testEnv noteproperty PSPath_App_PFile ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_App_Pfile)
    add-member -in $g_testEnv noteproperty PSPath_Vdir_App ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir + "\" + $g_testEnv.Node_Vdir_App)
    add-member -in $g_testEnv noteproperty PSPath_Vdir_PFile ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir + "\" + $g_testEnv.Node_Vdir_PFile)
    add-member -in $g_testEnv noteproperty PSPath_Pdir_App ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir + "\" + $g_testEnv.Node_Pdir + "\" + $g_testEnv.Node_Pdir_App)
    add-member -in $g_testEnv noteproperty PSPath_Pdir_Vdir ("iis:\sites\" + $g_testEnv.Node_Site + "\" + $g_testEnv.Node_App + "\" + $g_testEnv.Node_Vdir + "\" + $g_testEnv.Node_Pdir + "\" + $g_testEnv.Node_Pdir_Vdir)

    # Initialize Collection_PSPaths
    $Collection_PSPaths = (
        $g_testEnv.PSPath_Root,
        $g_testEnv.PSPath_SslBindings, 
        $g_testEnv.PSPath_Sites, 
        $g_testEnv.PSPath_Pools,
        $g_testEnv.PSPath_Site,
        $g_testEnv.PSPath_Pool,
        $g_testEnv.PSPath_App,
        $g_testEnv.PSPath_VDir,
        $g_testEnv.PSPath_PDir,
        $g_testEnv.PSPath_PFile,
        $g_testEnv.PSPath_Site_VDir,
        $g_testEnv.PSPath_Site_PDir,
        $g_testEnv.PSPath_Site_PFile,
        $g_testEnv.PSPath_App_App,
        $g_testEnv.PSPath_App_PDir,
        $g_testEnv.PSPath_App_PFile,
        $g_testEnv.PSPath_Vdir_App,
        $g_testEnv.PSPath_Vdir_PFile,
        $g_testEnv.PSPath_Pdir_App,
        $g_testEnv.PSPath_Pdir_Vdir)
    add-member -in $g_testEnv noteproperty Collection_PSPaths $Collection_PSPaths

    # Initialize NamedParam variables
    add-member -in $g_testEnv noteproperty NamedParam_Path "-Path"
    add-member -in $g_testEnv noteproperty NamedParam_Filter "-Filter"
    add-member -in $g_testEnv noteproperty NamedParam_PSPath "-PSPath"
    add-member -in $g_testEnv noteproperty NamedParam_Name "-Name"
    add-member -in $g_testEnv noteproperty NamedParam_At "-At"
    add-member -in $g_testEnv noteproperty NamedParam_Value "-Value"
    add-member -in $g_testEnv noteproperty NamedParam_Commit "-Commit"
    add-member -in $g_testEnv noteproperty NamedParam_Destination "-Destination"
    add-member -in $g_testEnv noteproperty NamedParam_Metadata "-Metadata"
    add-member -in $g_testEnv noteproperty NamedParam_Verb "-Verb"
    add-member -in $g_testEnv noteproperty NamedParam_Protocol "-Protocol"
    add-member -in $g_testEnv noteproperty NamedParam_Site "-Site"
    add-member -in $g_testEnv noteproperty NamedParam_AppPool "-AppPool"
    add-member -in $g_testEnv noteproperty NamedParam_IPAddress "-IPAddress"
    add-member -in $g_testEnv noteproperty NamedParam_Application "-Application"
    add-member -in $g_testEnv noteproperty NamedParam_Process "-Process"
    add-member -in $g_testEnv noteproperty NamedParam_Port "-Port"
    add-member -in $g_testEnv noteproperty NamedParam_ID "-ID"
    add-member -in $g_testEnv noteproperty NamedParam_Type "-Type"
    add-member -in $g_testEnv noteproperty NamedParam_Module "-Module"
    add-member -in $g_testEnv noteproperty NamedParam_PreCondition "-PreCondition"
    add-member -in $g_testEnv noteproperty NamedParam_ResourceType "-ResourceType"
    add-member -in $g_testEnv noteproperty NamedParam_HostHeader "-HostHeader"
    add-member -in $g_testEnv noteproperty NamedParam_PhysicalPath "-PhysicalPath"
    add-member -in $g_testEnv noteproperty NamedParam_ScriptProcessor "-ScriptProcessor"
    add-member -in $g_testEnv noteproperty NamedParam_SSL "-SSL"
    add-member -in $g_testEnv noteproperty NamedParam_RequiredAccess "-RequiredAccess"
    add-member -in $g_testEnv noteproperty NamedParam_BindingInformation "-BindingInformation"
    add-member -in $g_testEnv noteproperty NamedParam_Enabled "-Enabled"
    add-member -in $g_testEnv noteproperty NamedParam_Location "-Location"
    add-member -in $g_testEnv noteproperty NamedParam_Recurse "-Recurse"
    add-member -in $g_testEnv noteproperty NamedParam_ItemType "-ItemType"
    add-member -in $g_testEnv noteproperty NamedParam_Metata "-Metata"
    add-member -in $g_testEnv noteproperty NamedParam_InputObject "-InputObject"
    add-member -in $g_testEnv noteproperty NamedParam_NewName "-NewName"

    # Initialize Params
    add-member -in $g_testEnv noteproperty Param_PathArrayString "Param_PathArrayString"
    add-member -in $g_testEnv noteproperty Param_PathSingleString "Param_PathSingleString"
    add-member -in $g_testEnv noteproperty Param_FilterArrayString "Param_FilterArrayString"
    add-member -in $g_testEnv noteproperty Param_FilterSingleString "Param_FilterSingleString"
    add-member -in $g_testEnv noteproperty Param_PSPathArrayString "Param_PSPathArrayString"
    add-member -in $g_testEnv noteproperty Param_NameSingleString "Param_NameSingleString"
    add-member -in $g_testEnv noteproperty Param_NameArrayString "Param_NameArrayString"
    add-member -in $g_testEnv noteproperty Param_RecurseOption "Param_RecurseOption"
    add-member -in $g_testEnv noteproperty Param_ValueSingleObject "Param_ValueSingleObject"
    add-member -in $g_testEnv noteproperty Param_AtSingleObject "Param_AtSingleObject"
    add-member -in $g_testEnv noteproperty Param_LocationArrayString "Param_LocationArrayString"
    add-member -in $g_testEnv noteproperty Param_MetataSingleString "Param_MetataSingleString"
    add-member -in $g_testEnv noteproperty Param_InputObjectSingleObject "Param_InputObjectSingleObject"
    add-member -in $g_testEnv noteproperty Param_DestinationSingleString "Param_DestinationSingleString"
    add-member -in $g_testEnv noteproperty Param_ItemTypeSingleString "Param_ItemTypeSingleString"
    add-member -in $g_testEnv noteproperty Param_NewNameSingleString "Param_NewNameSingleString"
    add-member -in $g_testEnv noteproperty Param_CommitOption "Param_CommitOption"
    add-member -in $g_testEnv noteproperty Param_ProtocolSingleString "Param_ProtocolSingleString"
    add-member -in $g_testEnv noteproperty Param_MetadataOption "Param_MetadataOption"
    add-member -in $g_testEnv noteproperty Param_AppPoolSingleString "Param_AppPoolSingleString"
    add-member -in $g_testEnv noteproperty Param_SiteSingleString "Param_SiteSingleString"
    add-member -in $g_testEnv noteproperty Param_ApplicationSingleString "Param_ApplicationSingleString"
    add-member -in $g_testEnv noteproperty Param_ProcessSingleInt32 "Param_ProcessSingleInt32"
    add-member -in $g_testEnv noteproperty Param_IPAddressSingleString "Param_IPAddressSingleString"
    add-member -in $g_testEnv noteproperty Param_IDSingleUInt32 "Param_IDSingleUInt32"
    add-member -in $g_testEnv noteproperty Param_PortSingleUInt32 "Param_PortSingleUInt32"
    add-member -in $g_testEnv noteproperty Param_PreConditionSingleString "Param_PreConditionSingleString"
    add-member -in $g_testEnv noteproperty Param_VerbSingleString "Param_VerbSingleString"
    add-member -in $g_testEnv noteproperty Param_HostHeaderSingleString "Param_HostHeaderSingleString"
    add-member -in $g_testEnv noteproperty Param_TypeSingleString "Param_TypeSingleString"
    add-member -in $g_testEnv noteproperty Param_ModuleSingleString "Param_ModuleSingleString"
    add-member -in $g_testEnv noteproperty Param_ScriptProcessorSingleString "Param_ScriptProcessorSingleString"
    add-member -in $g_testEnv noteproperty Param_ResourceTypeSingleString "Param_ResourceTypeSingleString"
    add-member -in $g_testEnv noteproperty Param_PhysicalPathSingleString "Param_PhysicalPathSingleString"
    add-member -in $g_testEnv noteproperty Param_BindingInformationSingleString "Param_BindingInformationSingleString"
    add-member -in $g_testEnv noteproperty Param_SSLOption "Param_SSLOption"
    add-member -in $g_testEnv noteproperty Param_ValueSingleString "Param_ValueSingleString"
    add-member -in $g_testEnv noteproperty Param_RequiredAccessSingleString "Param_RequiredAccessSingleString"
    add-member -in $g_testEnv noteproperty Param_EnabledOption "Param_EnabledOption"

    # Initialize Datatype tokens
    add-member -in $g_testEnv noteproperty DataType_ArrayString "ArrayString"
    add-member -in $g_testEnv noteproperty DataType_SingleString "SingleString"
    add-member -in $g_testEnv noteproperty DataType_Option "Option"
    add-member -in $g_testEnv noteproperty DataType_SingleObject "SingleObject"
    add-member -in $g_testEnv noteproperty DataType_SingleUInt32 "SingleUInt32"
    add-member -in $g_testEnv noteproperty DataType_SingleInt32 "SingleInt32"

    # Initialize Cmdlets
    add-member -in $g_testEnv noteproperty Cmdlet_GetChildItem "Get-ChildItem"
    add-member -in $g_testEnv noteproperty Cmdlet_SetItem "Set-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_NewItem "New-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_RenameItem "Rename-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_CopyItem "Copy-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_MoveItem "Move-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_ClearItem "Clear-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_GetItem "Get-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveItem "Remove-Item"
    add-member -in $g_testEnv noteproperty Cmdlet_NewItemProperty "New-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_GetItemProperty "Get-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_SetItemProperty "Set-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_ClearItemProperty "Clear-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveItemProperty "Remove-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_CopyItemProperty "Copy-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_MoveItemProperty "Move-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_RenameItemProperty "Rename-ItemProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_AddWebConfiguration "Add-WebConfiguration"
    add-member -in $g_testEnv noteproperty Cmdlet_SetWebConfiguration "Set-WebConfiguration"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebConfiguration "Get-WebConfiguration"
    add-member -in $g_testEnv noteproperty Cmdlet_ClearWebConfiguration "Clear-WebConfiguration"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebConfigurationProperty "Get-WebConfigurationProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_AddWebConfigurationProperty "Add-WebConfigurationProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveWebConfigurationProperty "Remove-WebConfigurationProperty"
    add-member -in $g_testEnv noteproperty Cmdlet_BeginCommitDelay "Begin-CommitDelay"
    add-member -in $g_testEnv noteproperty Cmdlet_EndCommitDelay "End-CommitDelay"
    add-member -in $g_testEnv noteproperty Cmdlet_StartWebItem "Start-WebItem"
    add-member -in $g_testEnv noteproperty Cmdlet_RestartWebItem "Restart-WebItem"
    add-member -in $g_testEnv noteproperty Cmdlet_StopWebItem "Stop-WebItem"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebItemState "Get-WebItemState"
    add-member -in $g_testEnv noteproperty Cmdlet_ConvertToWebApplication "ConvertTo-WebApplication"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebHandler "Get-WebHandler"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebModule "Get-WebModule"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebRequest "Get-WebRequest"
    add-member -in $g_testEnv noteproperty Cmdlet_GetWebSiteState "Get-WebSiteState"
    add-member -in $g_testEnv noteproperty Cmdlet_NewWebApplication "New-WebApplication"
    add-member -in $g_testEnv noteproperty Cmdlet_NewVirtualDirectory "New-VirtualDirectory"
    add-member -in $g_testEnv noteproperty Cmdlet_NewWebBinding "New-WebBinding"
    add-member -in $g_testEnv noteproperty Cmdlet_NewWebHandler "New-WebHandler"
    add-member -in $g_testEnv noteproperty Cmdlet_NewWebModule "New-WebModule"
    add-member -in $g_testEnv noteproperty Cmdlet_NewWebSite "New-WebSite"
    add-member -in $g_testEnv noteproperty Cmdlet_NewFtpSite "New-FtpSite"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveWebApplication "Remove-WebApplication"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveWebBinding "Remove-WebBinding"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveWebHandler "Remove-WebHandler"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveWebModule "Remove-WebModule"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveWebSite "Remove-WebSite"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveVirtualDirectory "Remove-VirtualDirectory"
    add-member -in $g_testEnv noteproperty Cmdlet_SetWebBinding "Set-WebBinding"
    add-member -in $g_testEnv noteproperty Cmdlet_SetWebHandler "Set-WebHandler"
    add-member -in $g_testEnv noteproperty Cmdlet_SetWebModule "Set-WebModule"
    add-member -in $g_testEnv noteproperty Cmdlet_EnableWebModule "Enable-WebModule"
    add-member -in $g_testEnv noteproperty Cmdlet_DisableWebModule "Disable-WebModule"
    add-member -in $g_testEnv noteproperty Cmdlet_StartWebSite "Start-WebSite"
    add-member -in $g_testEnv noteproperty Cmdlet_StopWebSite "Stop-WebSite"
    add-member -in $g_testEnv noteproperty Cmdlet_GetAppPoolState "Get-AppPoolState"
    add-member -in $g_testEnv noteproperty Cmdlet_NewAppPool "New-AppPool"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveAppPool "Remove-AppPool"
    add-member -in $g_testEnv noteproperty Cmdlet_RestartAppPool "Restart-AppPool"
    add-member -in $g_testEnv noteproperty Cmdlet_StartAppPool "Start-AppPool"
    add-member -in $g_testEnv noteproperty Cmdlet_StopAppPool "Stop-AppPool"
    add-member -in $g_testEnv noteproperty Cmdlet_GetAppDomain "Get-AppDomain"
    add-member -in $g_testEnv noteproperty Cmdlet_GetConfigurationBackup "Get-ConfigurationBackup"
    add-member -in $g_testEnv noteproperty Cmdlet_RemoveConfigurationBackup "Remove-ConfigurationBackup"
    add-member -in $g_testEnv noteproperty Cmdlet_RestoreWebConfiguration "Restore-WebConfiguration"
    add-member -in $g_testEnv noteproperty Cmdlet_BackupWebConfiguration "Backup-WebConfiguration"

    # Initialize Collection_Cmdlets
    $Collection_Cmdlets = (
        ($g_testEnv.Cmdlet_GetChildItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_FilterSingleString+" "+$g_testEnv.Param_RecurseOption+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_SetItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_ValueSingleObject),
        ($g_testEnv.Cmdlet_NewItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ItemTypeSingleString+" "+$g_testEnv.Param_ValueSingleObject),
        ($g_testEnv.Cmdlet_RenameItem+" "+$g_testEnv.Param_PathSingleString+" "+$g_testEnv.Param_NewNameSingleString),
        ($g_testEnv.Cmdlet_CopyItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_DestinationSingleString+" "+$g_testEnv.Param_FilterSingleString+" "+$g_testEnv.Param_RecurseOption),
        ($g_testEnv.Cmdlet_MoveItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_DestinationSingleString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_ClearItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_GetItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_RemoveItem+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_FilterSingleString+" "+$g_testEnv.Param_RecurseOption),
        ($g_testEnv.Cmdlet_NewItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ValueSingleObject+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_GetItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_NameArrayString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_SetItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ValueSingleObject+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_SetItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_InputObjectSingleObject+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_ClearItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_RemoveItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_NameArrayString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_CopyItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_DestinationSingleString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_MoveItemProperty+" "+$g_testEnv.Param_PathArrayString+" "+$g_testEnv.Param_DestinationSingleString+" "+$g_testEnv.Param_NameArrayString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_RenameItemProperty+" "+$g_testEnv.Param_PathSingleString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_NewNameSingleString+" "+$g_testEnv.Param_FilterSingleString),
        ($g_testEnv.Cmdlet_AddWebConfiguration+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_ValueSingleObject+" "+$g_testEnv.Param_AtSingleObject+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_SetWebConfiguration+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_ValueSingleObject+" "+$g_testEnv.Param_MetataSingleString+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_SetWebConfiguration+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_InputObjectSingleObject+" "+$g_testEnv.Param_MetataSingleString+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_GetWebConfiguration+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_RecurseOption+" "+$g_testEnv.Param_MetadataOption+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_ClearWebConfiguration+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_GetWebConfigurationProperty+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameArrayString+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_SetWebConfigurationProperty+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ValueSingleObject+" "+$g_testEnv.Param_AtSingleObject+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_SetWebConfigurationProperty+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_InputObjectSingleObject+" "+$g_testEnv.Param_AtSingleObject+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_AddWebConfigurationProperty+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ValueSingleObject+" "+$g_testEnv.Param_AtSingleObject+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_RemoveWebConfigurationProperty+" "+$g_testEnv.Param_FilterArrayString+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_AtSingleObject+" "+$g_testEnv.Param_LocationArrayString),
        ($g_testEnv.Cmdlet_BeginCommitDelay+" "+$g_testEnv.Param_PSPathArrayString),
        ($g_testEnv.Cmdlet_EndCommitDelay+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_CommitOption),
        ($g_testEnv.Cmdlet_StartWebItem+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_ProtocolSingleString),
        ($g_testEnv.Cmdlet_RestartWebItem+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_ProtocolSingleString),
        ($g_testEnv.Cmdlet_StopWebItem+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_ProtocolSingleString),
        ($g_testEnv.Cmdlet_GetWebItemState+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_ProtocolSingleString),
        ($g_testEnv.Cmdlet_ConvertToWebApplication+" "+$g_testEnv.Param_PSPathArrayString),
        ($g_testEnv.Cmdlet_GetWebHandler+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_GetWebModule+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_EnabledOption),
        ($g_testEnv.Cmdlet_GetWebRequest+" "+$g_testEnv.Param_AppPoolSingleString+" "+$g_testEnv.Param_ProcessSingleInt32),
        ($g_testEnv.Cmdlet_GetWebSiteState+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_NewWebApplication+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_PhysicalPathSingleString),
        ($g_testEnv.Cmdlet_NewWebBinding+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_PortSingleUInt32+" "+$g_testEnv.Param_IPAddressSingleString+" "+$g_testEnv.Param_HostHeaderSingleString+" "+$g_testEnv.Param_SSLOption),
        ($g_testEnv.Cmdlet_NewWebHandler+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_PathSingleString+" "+$g_testEnv.Param_VerbSingleString+" "+$g_testEnv.Param_TypeSingleString+" "+$g_testEnv.Param_ModuleSingleString+" "+$g_testEnv.Param_ScriptProcessorSingleString+" "+$g_testEnv.Param_ResourceTypeSingleString+" "+$g_testEnv.Param_RequiredAccessSingleString),
        ($g_testEnv.Cmdlet_NewWebModule+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_TypeSingleString+" "+$g_testEnv.Param_PreConditionSingleString+" "+$g_testEnv.Param_EnabledOption),
        ($g_testEnv.Cmdlet_NewWebSite+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_IDSingleUInt32+" "+$g_testEnv.Param_PortSingleUInt32+" "+$g_testEnv.Param_IPAddressSingleString+" "+$g_testEnv.Param_HostHeaderSingleString+" "+$g_testEnv.Param_PhysicalPathSingleString),
        ($g_testEnv.Cmdlet_NewFtpSite+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_IDSingleUInt32+" "+$g_testEnv.Param_PortSingleUInt32+" "+$g_testEnv.Param_IPAddressSingleString+" "+$g_testEnv.Param_HostHeaderSingleString+" "+$g_testEnv.Param_PhysicalPathSingleString),
        ($g_testEnv.Cmdlet_RemoveWebApplication+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_RemoveWebBinding+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_IPAddressSingleString+" "+$g_testEnv.Param_PortSingleUInt32+" "+$g_testEnv.Param_HostHeaderSingleString),
        ($g_testEnv.Cmdlet_RemoveWebBinding+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_BindingInformationSingleString),
        ($g_testEnv.Cmdlet_RemoveWebHandler+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_RemoveWebModule+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_RemoveWebSite+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_SetWebBinding+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_IPAddressSingleString+" "+$g_testEnv.Param_PortSingleUInt32+" "+$g_testEnv.Param_HostHeaderSingleString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ValueSingleString),
        ($g_testEnv.Cmdlet_SetWebBinding+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_BindingInformationSingleString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_ValueSingleString),
        ($g_testEnv.Cmdlet_SetWebHandler+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_PathSingleString+" "+$g_testEnv.Param_VerbSingleString+" "+$g_testEnv.Param_TypeSingleString+" "+$g_testEnv.Param_ModuleSingleString+" "+$g_testEnv.Param_ScriptProcessorSingleString+" "+$g_testEnv.Param_ResourceTypeSingleString+" "+$g_testEnv.Param_RequiredAccessSingleString),
        ($g_testEnv.Cmdlet_SetWebModule+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_TypeSingleString+" "+$g_testEnv.Param_PreConditionSingleString+" "+$g_testEnv.Param_EnabledOption),
        ($g_testEnv.Cmdlet_StartWebSite+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_StopWebSite+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_GetAppPoolState+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_NewAppPool+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_RemoveAppPool+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_RestartAppPool+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_StartAppPool+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_StopAppPool+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_GetAppDomain+" "+$g_testEnv.Param_AppPoolSingleString+" "+$g_testEnv.Param_ProcessSingleInt32),
        ($g_testEnv.Cmdlet_NewVirtualDirectory+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_ApplicationSingleString+" "+$g_testEnv.Param_NameSingleString+" "+$g_testEnv.Param_PhysicalPathSingleString),
        ($g_testEnv.Cmdlet_RemoveVirtualDirectory+" "+$g_testEnv.Param_SiteSingleString+" "+$g_testEnv.Param_ApplicationSingleString+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_GetConfigurationBackup),
        ($g_testEnv.Cmdlet_RemoveConfigurationBackup+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_RestoreWebConfiguration+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_BackupWebConfiguration+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_EnableWebModule+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString),
        ($g_testEnv.Cmdlet_DisableWebModule+" "+$g_testEnv.Param_PSPathArrayString+" "+$g_testEnv.Param_NameSingleString))
    add-member -in $g_testEnv noteproperty Collection_Cmdlets $Collection_Cmdlets
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Replace parameter name with actual data
#
#////////////////////////////////////////////
function global:IISTest-MakeParameter ($strCmd, $paramName)
{
    $result = "Error in IISTest-MakeParameter()!!!"
    switch ($paramName)
    {
        { $_ -eq  $g_testEnv.Param_PathArrayString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Path $g_testEnv.DataType_ArrayString ); break }
        { $_ -eq  $g_testEnv.Param_PathSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Path $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_FilterArrayString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Filter $g_testEnv.DataType_ArrayString ); break }
        { $_ -eq  $g_testEnv.Param_FilterSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Filter $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_PSPathArrayString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_PSPath $g_testEnv.DataType_ArrayString ); break }
        { $_ -eq  $g_testEnv.Param_NameSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Name $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_NameArrayString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Name $g_testEnv.DataType_ArrayString ); break }
        { $_ -eq  $g_testEnv.Param_RecurseOption } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Recurse $g_testEnv.DataType_Option ); break }
        { $_ -eq  $g_testEnv.Param_ValueSingleObject } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Value $g_testEnv.DataType_SingleObject ); break }
        { $_ -eq  $g_testEnv.Param_AtSingleObject } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_At $g_testEnv.DataType_SingleObject ); break }
        { $_ -eq  $g_testEnv.Param_LocationArrayString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Location $g_testEnv.DataType_ArrayString ); break }
        { $_ -eq  $g_testEnv.Param_MetataSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Metata $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_InputObjectSingleObject } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_InputObject $g_testEnv.DataType_SingleObject ); break }
        { $_ -eq  $g_testEnv.Param_DestinationSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Destination $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_ItemTypeSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_ItemType $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_NewNameSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_NewName $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_CommitOption } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Commit $g_testEnv.DataType_Option ); break }
        { $_ -eq  $g_testEnv.Param_ProtocolSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Protocol $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_MetadataOption } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Metadata $g_testEnv.DataType_Option ); break }
        { $_ -eq  $g_testEnv.Param_AppPoolSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_AppPool $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_SiteSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Site $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_ApplicationSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Application $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_ProcessSingleInt32 } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Process $g_testEnv.DataType_SingleInt32 ); break }
        { $_ -eq  $g_testEnv.Param_IPAddressSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_IPAddress $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_IDSingleUInt32 } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_ID $g_testEnv.DataType_SingleUInt32 ); break }
        { $_ -eq  $g_testEnv.Param_PortSingleUInt32 } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Port $g_testEnv.DataType_SingleUInt32 ); break }
        { $_ -eq  $g_testEnv.Param_PreConditionSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_PreCondition $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_VerbSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Verb $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_HostHeaderSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_HostHeader $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_TypeSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Type $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_ModuleSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Module $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_ScriptProcessorSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_ScriptProcessor $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_ResourceTypeSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_ResourceType $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_PhysicalPathSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_PhysicalPath $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_BindingInformationSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_BindingInformation $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_SSLOption } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_SSL $g_testEnv.DataType_Option ); break }
        { $_ -eq  $g_testEnv.Param_ValueSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Value $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_RequiredAccessSingleString } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_RequiredAccess $g_testEnv.DataType_SingleString ); break }
        { $_ -eq  $g_testEnv.Param_EnabledOption } { $result = ( MakeData $strCmd $g_testEnv.NamedParam_Enabled $g_testEnv.DataType_Option ); break }
    }
    return $result
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Make sample data for a parameter
#
#////////////////////////////////////////////
function global:MakeData ($strCmd, $strParam, $dataType)
{
    $result = "Error in MakeData()!!!"
    switch ($strParam)
    {
        { $_ -eq  $g_testEnv.NamedParam_Path } { $result = ( GetSampleData $strCmd $_ $dataType -PSPath ); break }
        { $_ -eq  $g_testEnv.NamedParam_Filter } { $result = ( GetSampleData $strCmd $_ $dataType -Filter ); break }
        { $_ -eq  $g_testEnv.NamedParam_PSPath } { $result = ( GetSampleData $strCmd $_ $dataType -PSPath ); break }
        { $_ -eq  $g_testEnv.NamedParam_Name } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_At } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Value } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Commit } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Destination } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Metadata } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Verb } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Protocol } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Site } { $result = ( GetSampleData $strCmd $_ $dataType -Site ); break }
        { $_ -eq  $g_testEnv.NamedParam_AppPool } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_IPAddress } { $result = ( GetSampleData $strCmd $_ $dataType -IPAddress ); break }
        { $_ -eq  $g_testEnv.NamedParam_Application } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Process } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Port } { $result = ( GetSampleData $strCmd $_ $dataType -Port ); break }
        { $_ -eq  $g_testEnv.NamedParam_ID } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Type } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Module } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_PreCondition } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_ResourceType } { $result = ( GetSampleData $strCmd $_ $dataType -ResourceType ); break }
        { $_ -eq  $g_testEnv.NamedParam_HostHeader } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_PhysicalPath } { $result = ( GetSampleData $strCmd $_ $dataType -PhysicalPath ); break }
        { $_ -eq  $g_testEnv.NamedParam_ScriptProcessor } { $result = ( GetSampleData $strCmd $_ $dataType -ScriptProcessor); break }
        { $_ -eq  $g_testEnv.NamedParam_SSL } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_RequiredAccess } { $result = ( GetSampleData $strCmd $_ $dataType -RequireAccess); break }
        { $_ -eq  $g_testEnv.NamedParam_BindingInformation } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Enabled } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Location } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Recurse } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_ItemType } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_Metata } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_InputObject } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
        { $_ -eq  $g_testEnv.NamedParam_NewName } { $result = ( GetSampleData $strCmd $_ $dataType ); break }
    }
    return $result
}


#////////////////////////////////////////////
#
#Routine Description: 
#
#    Make sample data for a parameter
#
#////////////////////////////////////////////
function global:GetSampleData (
    $strCmd,
    $strParam, 
    $dataType, 
    [switch]$PSPath, 
    [switch]$PhysicalPath, 
    [switch]$IPAddress, 
    [switch]$Filter, 
    [switch]$Site, 
    [switch]$Port,
    [switch]$ScriptProcessor,
    [switch]$RequireAccess,
    [switch]$ResourceType)
{
    $result = "Error in GetSampleData()!!!"
    switch ($dataType)
    {
        { $_ -eq  $g_testEnv.DataType_ArrayString } 
            {                  
                $result = 'randomAS1,randomAS2'
                if ($PSPath) 
                {
                    $result = '"IIS:\Sites\newSite\newSite_vdir","IIS:\Sites\newSite\newApp\newVdir"'
                } 
                if ($PhysicalPath) 
                {
                    $result = '"c:\","c:\"'
                } 
                if ($IPAddress) 
                {
                    $result = '"127.0.0.1","127.0.0.1"'
                } 
                if ($Filter) 
                {
                    $result = '//appSettings,//appSettings'
                } 
                if ($Site) 
                {
                    $result = '"Default Web Site",newSite'
                } 
                if ($Port) 
                {
                    $result = '1234,1235'
                } 
                break                 
            }
        { $_ -eq  $g_testEnv.DataType_SingleString } 
            {
                $result = 'randomSS'
                if ($PSPath) 
                {
                    $result = '"IIS:\Sites\newSite\newApp\newVdir"'
                } 
                if ($PhysicalPath) 
                {
                    $result = '"c:\"'
                } 
                if ($IPAddress) 
                {
                    $result = '127.0.0.1'
                } 
                if ($Filter) 
                {
                    $result = '//appSettings'
                } 
                if ($Site) 
                {
                    $result = 'newSite'
                } 
                if ($Port) 
                {
                    $result = '1236'
                } 
                if ($ScriptProcessor) 
                {
                    $result = '%windir%\system32\notepad.exe'
                } 
                if ($ResourceType) 
                {
                    $result = 'File'  ## "File, Directory, Either, Unspecified"
                } 
                if ($RequireAccess) 
                {
                    $result = 'None'  ## "None, Read, Write, Script, Execute"
                } 
                break                 
            }        
        { $_ -eq  $g_testEnv.DataType_Option } 
            { 
                $result = ""
                break 
            }
        { $_ -eq  $g_testEnv.DataType_SingleObject } 
            { 
                $result = "object" 
                break 
            }
        { $_ -eq  $g_testEnv.DataType_SingleUInt32 } 
            { 
                $result = "1234"
                break 
            }
        { $_ -eq  $g_testEnv.DataType_SingleInt32 } 
            { 
                $result = "4567"
                break 
            }
    }
    return ($strParam + " " + $result)
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Make cmdline with actual data
#
#////////////////////////////////////////////
function global:IISTest-MakeCmdlet ($strCmd)
{
    $tokenArray = $strCmd.Trim().Split(" ")
    $cmdName = ""
    $counter = 0
    $result = "Error in IISTest-MakeCmdlet()!!!"
    foreach ($item in $tokenArray) { 
        if ($counter -eq 0) {
            $cmdName = $item
            $result = $cmdName
        }
        else {
            $result += " " + (IISTest-MakeParameter $cmdName $item)
        }
        $counter++ 
    }
    return $result
}

function global:IISTest-VerifyOutput ($expectedString, $lines)
{
    if ($expectedString -eq $null -or $expectedString -eq "") 
    {
        throw "$expectedString cannot be null or empty string"
    }

    $lineToRead = 5
    if ($lines -ne $null)
    {
        $lineToRead = $lines
    }
    
    $content = get-content $transScriptFile  | select-object -last $lineToRead
    $tempString = ""
    $content | foreach {$tempString += $_}    

    LogDebug $tempString
    return ($tempString.IndexOf($expectedString))
}

function global:Createsite($name)
{
     $physicaldir="$env:systemdrive\testdir"
     md $physicaldir -confirm:$false 2> $null

     $g_iisConfig = new-object -ComObject msutil.iis7config
     $g_iisConfig.Initialize($null)

     if($g_iisConfig.ExistsWebSite($name,$null) -eq $false)
     {
         new-item ("iis:\sites\"+$name) -physicalPath $physicaldir -itemType site -bindings @{protocol="http";bindingInformation="*:1234:"}

         $g_iisConfig = new-object -ComObject msutil.iis7config
         $g_iisConfig.Initialize($null)
     }
}

function global:ExistsWebSite($name)
{

     $g_iisConfig = new-object -ComObject msutil.iis7config
     $g_iisConfig.Initialize($null)

     $g_iisConfig.ExistsWebSite($name,$null)
}

function global:Deletewebsite($name)
{
    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    if($g_iisConfig.ExistsWebSite($name,$null) -eq $true)
    {
        remove-item ("iis:\sites\"+$name) -recurse -confirm:$false
        if($g_iisConfig.ExistsWebSite($name,$null) -eq $true)
        {
           throw "Failed to remove a site!!!"
        }         
    }
    del "$env:systemdrive\testdir" -recurse -confirm:$false 2> $null
}

#
# order of array application,site,physical path name
#
function global:CreateApplication($inputData)
{
    $Appname=$inputData[0];
    $siteName=$inputData[1];
    $Physicalpath=$inputData[2];
    if($Physicalpath -eq $null)
    {
        $physicaldir="$env:systemdrive\"
    } 
    else
    {
        $physicaldir=$Physicalpath
    }

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)
    if($g_iisConfig.ExistsApplication($siteName,"/"+$Appname,$null) -eq $false) 
    {
        new-item ("iis:\sites\"+$sitename+"\"+$Appname) -itemType application -physicalPath $physicaldir

        $g_iisConfig = new-object -ComObject msutil.iis7config
        $g_iisConfig.Initialize($null)
    }
}

function global:ExistsApplication($inputData)
{

    $Appname=$inputData[0];
    $siteName=$inputData[1];

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    $g_iisConfig.ExistsApplication($siteName,"/"+$Appname,$null)
}

#
#order site,application,vdir name
#
function global:ExistsVirtualDirectory($inputData)
{

    $sitename=$inputData[0];
    $apppath=$inputData[1];
    $vdirname=$inputData[2];

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    $g_iisConfig.ExistsVirtualDirectory($sitename,"/"+$apppath,"/"+$vdirname,$null)
}

#
#order of array application,site,physicalpath name
#
function global:DeleteApplication($inputData)
{
    $Appname=$inputData[0];
    $siteName=$inputData[1];
    $Physicalpath=$inputData[2];

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)
    if($g_iisConfig.ExistsApplication($siteName,"/"+$Appname,$null) -eq $true)
    {
        remove-item ("iis:\sites\"+$siteName+"\"+$Appname) -recurse -confirm:$false

        $g_iisConfig = new-object -ComObject msutil.iis7config
        $g_iisConfig.Initialize($null)

        if($g_iisConfig.ExistsApplication($siteName,"/"+$Appname,$null) -eq $true)
        {
           throw "Failed to remove an application!!!"
        }         
    }

    if($Physicalpath -ne $null)
    {
        del $Physicalpath -recurse -confirm:$false 2> $null
    }         
}

function global:CreateAppPool($name)
{
    new-item ("iis:\appPools\"+$name) -itemType apppool

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)
}

function global:DeleteAppPool($name)
{    
    remove-item ("iis:\appPools\"+$name) -recurse -confirm:$false
    if ((get-item $name 2> $null) -ne $null)
    {
        throw "Failed to remove an apppool!!!"
    }         

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)
}

#
# order site,application,vdir name
#
function global:CreateVirtualdirectory($inputData)
{
    $sitename=$inputData[0];
    $apppath=$inputData[1];
    $vdirname=$inputData[2];
    $physicaldir="$env:systemdrive\testdir"
    md $physicaldir -confirm:$false 2> $null
    if (($apppath -eq "") -or ($apppath -eq $null))
    {
        $targetvdirPath = $sitename+"\"+$vdirname
    }
    else 
    {
        $targetvdirPath = $sitename+"\"+$apppath+"\"+$vdirname
    }

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)
    if($g_iisConfig.ExistsVirtualDirectory($sitename,"/"+$apppath,"/"+$vdirname,$null) -eq $false)
    {
        new-item ("iis:\sites\"+$targetvdirPath) -itemType virtualdirectory -physicalPath $physicaldir

        $g_iisConfig = new-object -ComObject msutil.iis7config
        $g_iisConfig.Initialize($null)
    }
}

#order site,application,vdir name
function global:ExistsVirtualDirectory($inputData)
{

    $sitename=$inputData[0];
    $apppath=$inputData[1];
    $vdirname=$inputData[2];
    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    $g_iisConfig.ExistsVirtualDirectory($sitename,"/"+$apppath,"/"+$vdirname,$null)
}

#site,app,vdir
function global:DeleteVirtualDirectory($inputData)
{
    $sitename=$inputData[0];
    $apppath=$inputData[1];
    $vdirPath=$inputData[2];
    if (($apppath -eq "") -or ($apppath -eq $null))
    {
        $targetvdirPath = $sitename+"\"+$vdirPath
    }
    else 
    {
        $targetvdirPath = $sitename+"\"+$apppath+"\"+$vdirPath
    }

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    if($g_iisConfig.ExistsVirtualDirectory($sitename,"/"+$apppath,"/"+$vdirPath,$null) -eq $true)
    {
        remove-item ("iis:\sites\"+$targetvdirPath) -recurse -confirm:$false

        $g_iisConfig = new-object -ComObject msutil.iis7config
        $g_iisConfig.Initialize($null)

        if($g_iisConfig.ExistsVirtualDirectory($sitename,"/"+$apppath,"/"+$vdirPath,$null) -eq $true)
        {
           throw "Failed to remove a virtual directory!!!"
        }         
    }
    del "$env:systemdrive\testdir" -recurse -confirm:$false 2> $null
}


#order site,protocol
function  global:GetBindings($inputData)
{
    $sitename=$inputData[0];
    $protocol=$inputData[1];

    #returns an array
    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    return $g_iisConfig.GetBindings($sitname,$protocol,$null)
}

function global:AssignInitialBoolean($section)
{

    $booleanValue=$true

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    $InitialState=$g_iisConfig.GetBooleanProperty($section,$null,"enabled","/",$null,$null)
    if($InitialState -eq $true)
    {
         $booleanValue=$false
    }
    return $booleanValue

}

function global:GetEnabledProperty($section)
{

    $g_iisConfig = new-object -ComObject msutil.iis7config
    $g_iisConfig.Initialize($null)

    return $g_iisConfig.GetBooleanProperty($section,$null,"enabled","/",$null,$null)
}

function global:ForRtw()
{

    $rtw = (get-date -year 2009 -month 1 -day 1)
    return ($rtw -lt (get-date))
}

