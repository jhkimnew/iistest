#////////////////////////////////////////////
#
# Module Name:
#    
#    Powershell_Common_Include.ps1
#
# Abstract:
#    
#    Include file for all Powershell based test
#
#////////////////////////////////////////////
$global:g_serverManager = $false

if ($global:g_iistest -eq $false)
{
    $iisTestReg = get-item HKLM:Software\Microsoft\IISTest
    $g_serverManager = ($iisTestReg.getvalue("ServerManagerMode") -eq 1)
}

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

    # Display summary
    LogTestSummary   
     
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
        LogError ("RunTest(): Error!!! in " + $_)
        $Error
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
#    Log StartTest
#
#////////////////////////////////////////////
function global:LogStartTest($param)
{
    $g_testenv.foundFailure = $false
    if ($g_testenv.testStarted)
    {
        throw ("Test is already started")
    }
    $g_testenv.testStarted = $true
    $strComment = $param[0]
    $testcaseID = $param[1]
    $g_testenv.testcase = $testcaseID.ToString() + ": " + $strComment
    
    $foundTargetTestcase = $null
    $result = $true
    if ($global:TargetTestcases -ne $null -and $global:TargetTestcases.GetType().Name.ToLower() -ne "string")
    {
       throw ("Unsupported type for TargetTestcases, which should be comma seperated string")
    }
    $targets = $null
    if ($global:TargetTestcases -ne $null)
    {
        $targets = $global:TargetTestcases.Split(",",[System.StringSplitOptions]::RemoveEmptyEntries)
    }
    if ($targets -ne $null -and $targets.length -gt 0)
    {
        foreach ($item in $targets)
        {
            if ($testcaseID.ToString() -eq $item.ToString())
            {
                $foundTargetTestcase = $item
            }
        }
        if ($foundTargetTestcase -ne $null)
        {
            $result = $true
        }
        else
        {
            $g_testenv.testStarted = $false
            $result = $false
        }
    }
    else
    {
        $result = $true
    }

    return $result
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log EndTest
#
#////////////////////////////////////////////
function global:LogEndTest()
{
    if (-not $g_testenv.testStarted)
    {
        throw ("Failed to end test")
    }
    $g_testenv.testStarted = $false

    $ForegroundColor = "Green"
    if ($g_testenv.foundFailure)
    {
        $ForegroundColor = "Red"
    }

    Write-Host ("##############################################") -ForegroundColor $ForegroundColor
    if ($g_testenv.foundFailure)
    {
        $message = ("Test Failure " + $g_testenv.testcase)
        $g_testenv.totalFailedTestCase += 1
        $g_testenv.FailedTestCases += "::comma::" + $g_testenv.testcase
    }
    else
    {
        $message = ("Test Success " + $g_testenv.testcase)
        $g_testenv.totalPassedTestCase += 1
    }
    Write-Host $message -ForegroundColor $ForegroundColor
    Write-Host ("##############################################") -ForegroundColor $ForegroundColor
}

function global:LogTestSummary()
{
    if ($g_testenv.testStarted)
    {
        throw ("Failed to end test")
    }
    
    $ForegroundColor = "Green"
    if ($g_testenv.totalFailedTestCase -gt 0)
    {
        $ForegroundColor = "Red"
    }

    Write-Host ("##############################################") -ForegroundColor $ForegroundColor
    if ($g_testenv.FailedTestCases -ne $null)
    {
        $FailedTestCaseIDs = ""
        Write-Host ("List of failed tests:") -ForegroundColor $ForegroundColor
        $g_testenv.FailedTestCases.Replace("::comma::", "``").Split("``")  | foreach {
            Write-Host $psitem -ForegroundColor $ForegroundColor
            $FailedTestCaseIDs += ($psitem.Split(":") | Select-Object -First 1) + ","
        }
        $FailedTestCaseIDs = $FailedTestCaseIDs.TrimEnd(",")
        $FailedTestCaseIDs = $FailedTestCaseIDs.TrimStart(",")
        ("")
        Write-Host ("NOTE: You can set $" + "global:TargetTestcases=" + $FailedTestCaseIDs + " to rerun failed test cases only") -ForegroundColor $ForegroundColor
        ("")
    }

    Write-Host ("Total Pass: " + $g_testenv.totalPassedTestCase + ", Failure : " + $g_testenv.totalFailedTestCase) -ForegroundColor $ForegroundColor
    Write-Host ("##############################################") -ForegroundColor $ForegroundColor

    if ($global:TargetTestcases -ne $null)
    {
        Write-Host ("$" + "global:TargetTestcases variable is detected with $global:TargetTestcases; cleaned up...") -ForegroundColor Yellow
        $global:TargetTestcases = $null
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogBUGVerifyStrEq
#
#////////////////////////////////////////////
function global:LogBUGVerifyStrEq($param)
{
    $p1 = $param[0]
    $p2 = $param[1] 
    $p3 = $param[2]
    $p4 = $param[3]
    $p5 = $param[4]

    Write-Host ("LogBUGVerifyStrEq") -ForegroundColor Yellow
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogVerifyTrue
#
#////////////////////////////////////////////
function global:LogVerifyTrue($param)
{
    if ($param.length -ne 2)
    {
        throw ("Param number not matched")
    }
    $expected = $param[0]
    $description = $param[1]

    if ($expected)
    {
        LogPass($description) 
    }
    else
    {
        LogFail($description)
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogVerifyFalse
#
#////////////////////////////////////////////
function global:LogVerifyFalse($param)
{
    if ($param.length -ne 2)
    {
        throw ("Param number not matched")
    }
    $expected = $param[0]
    $description = $param[1]

    if ($expected)
    {
        LogFail($description)
    }
    else
    {
        LogPass($description) 
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogVerifyNumEq
#
#////////////////////////////////////////////
function global:LogVerifyNumEq($param)
{
    if ($param.length -ne 3)
    {
        throw ("Param number not matched")
    }
    $expected = $param[0]
    $actual = $param[1]
    $description = $param[2] + ", EXPECTED $expected, ACTUAL $actual"

    if ($expected -eq $actual)
    {
        LogPass($description) 
    }
    else
    {
        LogFail($description)
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogVerifyNumNotEq
#
#////////////////////////////////////////////
function global:LogVerifyNumNotEq($param)
{
    if ($param.length -ne 3)
    {
        throw ("Param number not matched")
    }
    $expected = $param[0]
    $actual = $param[1]
    $description = $param[2] + ", EXPECTED $expected, ACTUAL $actual"

    if ($expected -eq $actual)
    {
        LogFail($description)
    }
    else
    {
        LogPass($description) 
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogVerifyStrEq
#
#////////////////////////////////////////////
function global:LogVerifyStrEq($param)
{
    if ($param.length -ne 3)
    {
        throw ("Param number not matched")
    }
    $expected = $param[0]
    $actual = $param[1]
    $description = $param[2] + ", EXPECTED $expected, ACTUAL $actual"

    # convert $null value to ""
    try
    {
        if ($expected -eq $null)
        {
            $expected = ""
        }
        if ($expected -ne $null -and $expected.Trim() -eq "")
        {
            $expected = ""
        }
        if ($actual -eq $null)
        {
            $actual = ""
        }
        if ($actual -ne $null -and $actual.Trim() -eq "")
        {
            $actual = ""
        }
    }
    catch
    {
        LogComment("Error!!! Failed to convert value")
    }
    
    if ($expected -eq $actual)
    {
        LogPass($description) 
    }
    else
    {
        LogFail($description)
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log LogVerifyStrNotEq
#
#////////////////////////////////////////////
function global:LogVerifyStrNotEq($param)
{
    if ($param.length -ne 3)
    {
        throw ("Param number not matched")
    }
    $expected = $param[0]
    $actual = $param[1]
    $description = $param[2] + ", EXPECTED $expected, ACTUAL $actual"

    if ($expected -eq $actual)
    {
        LogFail($description)
    }
    else
    {
        LogPass($description) 
    }
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Pass
#
#////////////////////////////////////////////
function global:LogPass($strComment)
{
    Write-Host ($strComment)
}

#////////////////////////////////////////////
#
#Routine Description: 
#
#    Log Fail
#
#////////////////////////////////////////////
function global:LogFail($strComment)
{
    $g_testEnv.foundFailure = $true
    Write-Host ("Error!!! " + $strComment) -ForegroundColor Red
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
    Write-Host ($strComment) -ForegroundColor Gray
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
#    Log Trace Information
#
#////////////////////////////////////////////
function global:LogTrace ($strComment, $enumLogType) 
{
    if ( $enumLogType -eq $TRACE_LEVEL_FATAL ) {
        LogFail( $strComment )
    }
    else {
        
        LogComment( $strComment )
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

function global:Reset-IISTestCredential ([switch] $force)
{
    if ($force -or $global:g_password -eq $null)
    {
        $credential = Get-Credential -Message "Initialize administrator password for running IISAdministration test" -UserName "$env:COMPUTERNAME\administrator"
        $global:g_userName = $credential.UserName
        $global:g_password = $credential.Password
    }
    
    if ($global:g_password -ne $null)
    {
        add-member -in $global:g_testEnv noteproperty IISTestAdminUser $global:g_userName -Force
        add-member -in $global:g_testEnv noteproperty IISTestAdminPassword $global:g_password -Force
    }
    else
    {
        ("Use -Force switch to overwrite existing username and password")
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

$global:g_scriptUtil = new-object psobject

$global:g_testEnv = new-object psobject
add-member -in $global:g_testEnv noteproperty WebSite1 "Default Web Site"
add-member -in $global:g_testEnv noteproperty AppPool1 "DefaultAppPool"
add-member -in $global:g_testEnv noteproperty BaseURL "http://localhost:80"
add-member -in $global:g_testEnv noteproperty testStarted $false
add-member -in $global:g_testEnv noteproperty testcase  $null
add-member -in $global:g_testEnv noteproperty foundFailure $false
add-member -in $global:g_testEnv noteproperty totalPassedTestCase 0
add-member -in $global:g_testEnv noteproperty totalFailedTestCase 0
add-member -in $global:g_testEnv noteproperty FailedTestCases $null
global:Reset-IISTestCredential -force:$false
 
#////////////////////////////////////////////
#
# Initialize TestFrameWork
#
#////////////////////////////////////////////

## Initialize IIS common objects
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

