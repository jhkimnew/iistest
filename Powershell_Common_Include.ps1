#////////////////////////////////////////////
#
#Module Name:
#    
#    Powershell_Common_Include.ps1
#
#Abstract:
#    
#    Include file for all Powershell based test scripts in IIS test team
#
#
#Author:
#
#    Jeong Hwan Kim (jhkim)  13-June-2008     Created
#    Mark Kuang (v-markua)   20-Jan-2015      Updated

#
#References:
#   
#    For a documented list of global functions and variables, use:
#        findstr /c:"function global:" Powershell_Common_Include.ps1
#        findstr /c:"$global:" IISProvider_Common_Include.ps1
#
#    Recommended usage:
#    1. Create a global include file for your test area
#    2. Excute IISProvider_common_include.ps1 from the file of #1
#    3. Excute #1 inside of all your test scripts
#
#    How to launch test suite
#    1. %windir%\system32\webtest\tools\run.js -f %windir%\system32\webtest\tools\suites\powershell.xml
#   
#    How to launch test case with test case id, 555
#    1. run.js "%windir%\system32\webtest\scripts\powershell\driver.js %windir%\system32\webtest\scripts\Powershell\IISProvider\walkthrough.ps1" -cl 74167
#         
#////////////////////////////////////////////


$global:g_serverManager = $false
$iisTestReg = get-item HKLM:Software\Microsoft\IISTest
$g_serverManager = ($iisTestReg.getvalue("ServerManagerMode") -eq 1)


#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Initialize() function in Test Suite
#
#////////////////////////////////////////////
function global:CallInitialize() 
{
    $result = $true
    LogDebug "Enter Child::Initialize()" 
    $result = Initialize $objContext
    LogDebug "Exit  Child::Initialize()"

    if ( $result -ne $true ) {
        throw "Child::Initialize() did not return true."
    }
    return $result
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Execute() function in Test Suite
#
#////////////////////////////////////////////
function global:CallExecute() 
{
    $result = $true
    LogDebug "Enter Child::Execute()" 
    $result = Execute $objContext
    LogDebug "Exit Child::Execute()" 
    return $result
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Terminate() function in Test Suite
#
#////////////////////////////////////////////
function global:CallTerminate() 
{
    $result = $true
    LogDebug "Enter Child::Terminate()" 
    Terminate $objContext
    LogDebug "Exit Child::Terminate()" 

    if ( $result -ne $true ) {
        throw "Child::Terminate() did not return true."
    }

    LogDebug "Enter Global::Terminate()" 

    ## Finish logging Transcript
    if($global:transScriptFile -ne "SKIP")
    {
        Stop-Transcript
    }
    LogDebug "Exit Global::Terminate()" 
    return $result
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Test Scenario. This should be invoked from Test Suite script
#
#////////////////////////////////////////////
function global:RunTest() 
{
    $continueRun = $true

    if ($continueRun)
    {
        CallInitialize
    }

    if ($continueRun)
    {
        CallExecute
    }

    # Always call terminate to cleanup
    CallTerminate

    #
    # Exception Error Handler
    #
    trap {
        LogError ("RunTest(): Error in " + $_)
        set-variable -name continueRun -value $false -scope 1
        continue
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Base Initialize() function
#
#////////////////////////////////////////////
function global:BaseInitialize ($objContext) 
{
    LogDebug( "Enter Base::Initialize()" );
    LogDebug( "Exit  Base::Initialize()" );
    return $true
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Base Execute() function
#
#////////////////////////////////////////////
function global:BaseExecute ($objContext) 
{
    LogDebug( "Enter Base::Execute()" );
    LogDebug( "Exit  Base::Execute()" );
    return $true
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Execute Base Terminate() function
#
#////////////////////////////////////////////
function global:BaseTerminate ($objContext) 
{
    LogDebug( "Enter Base::Terminate()" );
    LogDebug( "Exit  Base::Terminate()" );
    return $true
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log TestCase Error
#
#////////////////////////////////////////////
function global:LogTestCaseError ($errorObject, $exceptionExpected) 
{
    if ($exceptionExpected -eq $null -or $exceptionExpected -eq $false)
    {
        $errorObject 
        LogError (("Exception in test case - "+$errorObject))
    }
    continue
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Function Error
#
#////////////////////////////////////////////
function global:LogFunctionError ($errorObject) 
{
    $errorObject 
    LogError (("Exception in function - "+$errorObject))
    continue  
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Error
#
#////////////////////////////////////////////
function global:LogError ($strComment) 
{
    LogTrace $strComment $TRACE_LEVEL_FATAL
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Debug Information
#
#////////////////////////////////////////////
function global:LogDebug ($strComment) 
{
    LogTrace $strComment $TRACE_LEVEL_VERBOSE
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Warning information
#
#////////////////////////////////////////////
function global:LogWarning ($strComment) 
{
    LogTrace $strComment $TRACE_LEVEL_WARNINIG
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Comment
#
#////////////////////////////////////////////
function global:LogComment ($strComment) 
{
    LogTrace $strComment $TRACE_LEVEL_NORMAL
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Trace Information
#
#////////////////////////////////////////////
function global:LogTrace ($strComment, $enumLogType) 
{
    if ( $enumLogType -eq $TRACE_LEVEL_FATAL ) {
        $g_logObject.Fail( $strComment )
    }
    else {
        $g_logObject.Comment( $strComment )
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Import IIS Provider module
#
#////////////////////////////////////////////
function global:IISTest-ImportWebAdministration ()
{

    LogDebug( "Enter IISTest-ImportWebAdministration()" );

    get-item iis:\ 2> $null
    if ($? -ne $true) {
        LogDebug( "Try to add IIS Snapin first for IIS OOB..." );
        add-pssnapin WebAdministration 2> $null
    }

    get-item iis:\ 2> $null
    if ($? -ne $true) {
        LogDebug( "Try to import IIS Powershell provider module..." );
        import-module webadministration 2> $null
        import-module webadministration
    }

    ## Verify IIS imported successfully
    get-item iis:\ > $null
    if ($? -ne $true) {
        LogError ("Error!!! Failed to add IIS Powershell Provider Module...")
    }
    else
    {
        LogDebug( ("Current IIS root container count: " + (get-childitem iis:\).length));
    }
    LogDebug( "Exit  IISTest-ImportWebAdministration()" );

    trap 
    {
        LogComment ("Exception: " + $?)
        continue
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Import IIS Provider module
#
#////////////////////////////////////////////
function global:IISTest-ImportIISAdministration ()
{

    LogDebug( "Enter IISTest-ImportIISAdministration()" );

    Import-Module iisadministration

    ## Verify IIS imported successfully
    Get-IISSite -Name "Default Web Site"
    if ($? -ne $true) {
        LogError ("Error!!! Failed to add IIS Powershell Provider Module...")
    }

    LogDebug( "Exit  IISTest-ImportIISAdministration()" );

    trap 
    {
        LogComment ("Exception: " + $?)
        continue
    }
}

#////////////////////////////////////////////
#
# Global Variables
#
#////////////////////////////////////////////

$global:g_logObject = new-object -ComObject msutil.log
$global:g_iisConfig = new-object -ComObject msutil.iis7config
$global:g_scriptUtil = new-object -ComObject MSUtil.ScriptUtil
$global:g_myHttpClient = new-object -ComObject MSUtil.Client

$global:objContext = $null
$global:TRACE_LEVEL_FATAL = 0
$global:TRACE_LEVEL_NORMAL = 1
$global:TRACE_LEVEL_WARNINIG = 2
$global:TRACE_LEVEL_VERBOSE = 3
$global:TEXT_SCRIPT_SUMMARY = ""
$global:g_nIIsBitness = 0

if ($culture -eq $null)
{
    ### Use $Host.CurrentCulture if you are not using UI cutlure
    ### English UI language name is "en-US"
    $global:culture = (Get-UICulture).name
}
$global:g_testEnv = new-object psobject
add-member -in $global:g_testEnv noteproperty WebSite1 "Default Web Site"
add-member -in $global:g_testEnv noteproperty AppPool1 "DefaultAppPool"
add-member -in $global:g_testEnv noteproperty BaseURL "http://localhost:80"
  
#////////////////////////////////////////////
#
# Initialize TestFrameWork
#
#////////////////////////////////////////////

## Initialize IIS common objects
$g_logObject.Init > $null
if(!$g_serverManager)
{
    $g_iisConfig.Initialize($null)
}

LogDebug( "Enter Initialize TestFrameWork..." );
# Set g_testDir, which is supposed to be set by the driver.js when this ps1 file is executed
if ($g_testDir -eq $null)
{
    $global:g_testDir = join-path $env:windir "system32\webtest"
}

# Start Transcript to log output 
if ($global:transScriptFile -ne "SKIP") {
    $dateObject = Get-Date
    $global:transScriptFile = $g_testDir+"\scripts\powershell\testresult" + $dateObject.Month.ToString() + $dateObject.Day.ToString() + $dateObject.Year.ToString() +".log"
    &{
        Start-Transcript -path $transScriptFile 2> $null
        trap
        {
            stop-Transcript 2> $null
            Start-Transcript -path $transScriptFile 2> $null
            continue
        }
    }
}

## Set excution policy to allow running scripts
Set-ExecutionPolicy unrestricted

## Initialize g_nIIsBitness
$psProcess = get-process powershell | sort StartTime | select -last 1
if (($psProcess) -ne $null -and (($psProcess).path.tostring().tolower().indexof("syswow64") -ne -1))
{
    $global:g_nIIsBitness = 1
}

## Import IIS Powershell provider module if the current powershell is not in sysWow64 mode
if ($global:g_nIIsBitness -ne "1" -and !$g_serverManager)
{ 
    IISTest-ImportWebAdministration > $null
    IISTest-ImportIISAdministration > $null
}

LogDebug( "Exit Initialize TestFrameWork..." );

#
# Log exception error from Initialization of Test Framework
#
trap {
    $exceptionError = $error[0]
    Write-Host "Failed to complete test script. Terminating... Error in " + $_ -ForegroundColor Red
    LogDebug(("Error!!! Failed to complete test script. Terminating... Error in " + $_))
    LogDebug(("Stack Info: " + $exceptionError.exception.stacktrace))
    throw $_
}

#
# Load Utility cmdlets
#
&($g_testDir+'\scripts\Powershell\Utility\InstallAll.ps1')

