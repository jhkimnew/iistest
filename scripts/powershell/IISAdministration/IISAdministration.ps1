#///////////////////////////////////////////////////////////////////////////////
#
# Module Name:
#    
#    IISAdministration.ps1
#
# Abstract:
#    
#    Functional tests for IISAdministration
#
#///////////////////////////////////////////////////////////////////////////////

# Disale transcript by default
$global:transScriptFile = "SKIP"

# Initialze $global:g_testDir
$testscriptName = "IISAdministration.ps1"
$testscriptPath = $null
if ($global:g_testDir -eq $null)
{
    # get the test script path
    $testscriptPath = $MyInvocation.MyCommand.Definition
    if (-not (test-path $testscriptPath))
    {
        # if this is executed from powershell command window, the testscriptPath should be set manually or the current directory location should be where the test script file exists.
        if (test-path ".\$testscriptName")
        {
            $testscriptPath = Join-Path (get-item .).FullName $testScriptName
        }
        else
        {
            Write-host ("Error!!!! You need to set variable $" + "global:g_testDir manually if you want to debug withour running test script.") -ForegroundColor Red
            return
        }
    }
    if (Test-Path $testscriptPath)
    {
        $tempPath = Split-Path -Parent -Path $currentPath
        $tempPath = Split-Path -Parent -Path $tempPath
        $tempPath = Split-Path -Parent -Path $tempPath
        $tempPath = Split-Path -Parent -Path $tempPath
        $global:g_testDir = $tempPath
    }
}

# Excute test framework to load libary functions and variables
#
&($global:g_testDir+'\scripts\Powershell\IISAdministration\IISAdministration_Include.ps1')

$IISVersionMaj = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\InetStp" -Name "MajorVersion").MajorVersion
if($IISVersionMaj -ge 10)
{
    # TBD
}

$TEXT_SCRIPT_SUMMARY     = "N/A";

function Initialize($objContext)
{
    $result = $true
    # Execute Initalize function for this test area
    if( ($testarea.Initialize($objContext) ) -ne $true ) 
    {
        $result = $false
    }

    import-module webadministration
    if (-not (get-module webadministration))
    {
        LogComment("webadministration module not found, test canceled")
        $result = $false
    }
    import-module iisadministration
    if (-not (get-module iisadministration))
    {
        LogComment("iisadministration module not found, test canceled")
        $result = $false
    }    
    if ((get-module iisadministration).Version -eq "1.0.0.0")
    {
        LogComment("iisadministration module is not updated, test canceled")
        $result = $false
    }
    return $result
} 

function Execute($objContext)
{
    # Execute Excute function for this test area    
    LogComment("Test::Execute");    
    $testarea.Execute($objContext)
    # Call TestScenario function    
    TestScenario
    return $true
}

function Terminate($objContext) {
    # Execute Terminate function for this test area    
    if ( ($testarea.Terminate($objContext) ) -ne $true )
    {  
        return $false;
    }    
    return $true     
}

function TestScenario() {
    if ( LogStartTest("IISAdministration BVT #1 New-IISSite", 128796) -eq $true )
    {
        if ( IISTest-Ready )
        {

            #Execute 
            Reset-IISServerManager -Confirm:$false
            New-IISSite -Name "demo" -BindingInformation "*:81:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
   
            #verify
            $status = $null = Get-IISSite -Name "demo"  
            LogVerifyNumEq(2, $status.Id, "New-IISSite :created new web site")

            #Execute
            Start-IISCommitDelay
            $result = New-IISSite -Name demo1 -BindingInformation "*:82:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -Passthru
            $result.Applications["/"].ApplicationPoolName = "TestSiteAppPool"
            Stop-IISCommitDelay
           
            #verify
            $status = $null = Get-IISSite -Name "demo1"
            LogVerifyStrEq($null, $status.State, "New-IISSite :the status of site without pool");   

            #Execute 
            New-IISSite -Name "duplicatebind" -BindingInformation "*:80:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -force
   
            #verify
            $status = $null = Get-IISSite -Name "duplicatebind"  
            LogVerifyNumEq(4, $status.Id, "New-IISSite :created new web site with duplicate bind")
            
            #Execute
            New-IISSite -Name "demo2" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -BindingInformation "*:83:" -Passthru | Remove-IISSite -Confirm:$false
            
            #Verify
            $result = Get-IISSite -Name "test" -WarningVariable warning
            LogVerifyTrue($warning.Item(0).Message.Contains("does not exist"), "Verify the warning message")
            
            # cleanup
            IISTest-RestoreAppHostConfig
                      
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if ( LogStartTest("IISAdministration BVT #2 New-IISSite: Error handling", 128797) -eq $true )
    {
        if ( IISTest-Ready )
        {
			#Execute 
            Reset-IISServerManager -Confirm:$false
            $exceptionExpected = $true
            New-IISSite -Name "#$*" -BindingInformation "*:123:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -ErrorVariable errorMessage
            
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("The site name cannot contain the following characters"), 
            "New-IISSite: verify site name with invalid characters")

            #Execute 
            try 
            { 
                New-IISSite -Name "" -BindingInformation "*:12:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -ErrorVariable errorMessage 
            }
            catch 
            { 
                $errorMessage = $null = $error[0] 
            }
   
            #verify
            LogVerifyTrue($errorMessage.ToString().Contains("Cannot bind argument to parameter 'Name' because it is an empty string"), 
            "New-IISSite: verify site name with empth string")  

            #Execute 
            $exceptionExpected = $true
            New-IISSite -Name "test" -BindingInformation "*:80" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("The specified HTTPS binding is invalid"), "New-IISSite: verify binding is invalid") 

            #Execute 
            $exceptionExpected = $true
            New-IISSite -Name "wrongpath" -BindingInformation ":80:" -PhysicalPath "$env:systemdrive\inetpub\www" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Parameter 'PhysicalPath' should point to an existing path"), "New-IISSite: verify physicalPath doesn't exist") 
            
            #Execute 
            New-IISSite -Name "duplicatename" -BindingInformation "*:82:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
            $exceptionExpected = $true
            New-IISSite -Name "duplicatename" -BindingInformation "*:83:" -PhysicalPath "$env:systemdrive\inetpub\" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened"); 
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Web site 'duplicatename' already exist"), "New-IISSite: cannot create site with duplicate name without parameter -Force") 

            #Execute
            New-IISSite -Name "duplicatename" -BindingInformation "*:83:" -PhysicalPath "$env:systemdrive\inetpub\" -Force
   
            #verify
            $status = Get-IISSite -Name "duplicatename"  
            LogVerifyNumEq(2, $status.Id, "New-IISSite :created site with duplicate name")
            LogVerifyNumEq(2, (Get-IISSite).Count, "Count equal")

            #Execute 
            New-IISSite -Name "nonexistpath" -BindingInformation "*:8080:" -PhysicalPath "$env:systemdrive\inetpub\wwwroo" -Force 
   
            #verify
            $status = Get-IISSite -Name "nonexistpath"  
            LogVerifyNumEq(3, $status.Id, "New-IISSite :created site with non-exist path")
            
            # cleanup
            IISTest-RestoreAppHostConfig
                      
            trap
            {
                LogTestCaseError $_ $exceptionExpected
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
        
    if ( LogStartTest("IISAdministration BVT #3 Get-IISSite", 128798) -eq $true )
    {
        if ( IISTest-Ready )
        {
            #Execute 
            Reset-IISServerManager -Confirm:$false
            New-IISSite -Name "demo" -BindingInformation "*:80:hostname" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
            start-sleep 1
   
            #verify
            $result = $null = Get-IISSite -Name "demo"
            LogVerifyTrue(($result.State -eq "Started"), "Get-IISSite: right state")

            #Execute
            $logging = Get-IISConfigElement -ConfigElement $result -ChildelementName "traceFailedRequestsLogging"
            $dir = Get-IISConfigAttributeValue -ConfigElement $logging -AttributeName "directory"
   
            #verify
            LogVerifyStrEq("%SystemDrive%\inetpub\logs\FailedReqLogFiles", $dir, "Get-IISSite: Directory")

            #Execute
            New-IISSite -Name "test" -BindingInformation "*:80:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -force
            start-sleep 1
   
            #verify
            $result = $null = Get-IISSite -Name "test"
            LogVerifyTrue(($result.State -eq "Stopped"), "Get-IISSite: stopped")

            #Execute
            Start-IISCommitDelay
            $TestSite = New-IISSite -Name TestSite -BindingInformation "*:8080:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -Passthru
            $TestSite.Applications["/"].ApplicationPoolName = "TestSiteAppPool"
            Stop-IISCommitDelay
            start-sleep 1
   
            #verify
            $result = $null = Get-IISSite -Name "TestSite"
            LogVerifyTrue(($result.State -eq $null), "Get-IISSite: Unknown")

            #Execute
            $result = $null = Get-IISSite
   
            #verify
            LogVerifyNumEq(4, $result.Count, "Get-IISSite: right count")
            
            #Execute
            Get-IISSite -Name "non-exist" -WarningVariable warning

            #Execute
            LogVerifyTrue($warning.Item(0).Message.Contains("Web site 'non-exist' does not exist"), "Try to get non-exist site");
            
            #Get-IISSite with no -Name (just specify site name)
            #Execute
            $result = Get-IISSite "Default Web Site"
            
            #Verify
            LogVerifyTrue(("Default Web Site" -eq $result.Name), "Verify the web site name")

            #Pipe site name to Get-IISSite
            #Execute
            (1..3) | foreach{New-IISSite -Name "test$_"  -BindingInformation "*:80:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -force}
            
            #Verify
            $result = "test1","test2","test99","test3"| Get-IISSite -WarningVariable warning
            LogVerifyTrue($warning.Item(0).Message.Equals("Web site 'test99' does not exist."), "Verify the warning message")
            LogVerifyTrue((3 -eq $result.count), "Verify the web sites count")

            #Remove all sites, then call them
            #Execute
            Get-IISSite | Remove-IISSite -Confirm:$false
            $result = Get-IISSite
            
            #Verify
            LogVerifyTrue(($null -eq $result), "Verify null web site left")

            #Call with no parameters, ensure collection is returned
            #Execute
            $siteCount = (Get-IISSite).count
            (1..5) | foreach{New-IISSite -Name "test$_"  -BindingInformation "*:80:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -force}
            
            #Verify
            $result = Get-IISSite
            LogVerifyTrue(($siteCount + 5 -eq $result.count), "Verify web site count")
            (1..5) | foreach{LogVerifyTrue($result.name.Contains("test$_"), "Verify the  web site left")}
            
            # cleanup
            IISTest-RestoreAppHostConfig
            
                                         
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if ( LogStartTest("IISAdministration BVT #4 Remove-IISSite", 128799) -eq $true )
    {
        if ( IISTest-Ready )
        {
            #Preparation 
            Reset-IISServerManager -Confirm:$false
            New-IISSite -Name "demo" -BindingInformation "*:80:hostname" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
            $result = Get-IISSite -Name "demo"
            LogVerifyTrue(($result -ne $null), "Site Created");
            
            #Execute
            Remove-IISSite -Name "demo" -Confirm:$false
   
            #verify
            LogVerifyTrue($?, "No error happened");
            $result = Get-IISSite -Name "demo"
            LogVerifyTrue(($result -eq $null), "Site removed")

            #Execute
            $result = Remove-IISSite -Name "non-exist" -WarningVariable warning
   
            #verify
            LogVerifyTrue($?, "No error happened");
            LogVerifyTrue($warning.Item(0).Message.Contains("Web site 'non-exist' does not exist"), "Try to deletd non-exist site");    
            
            #Get-IISSite | remove-IISSite
            #Preparation
            $siteNum = (Get-IISSite).count
            (1..5) | foreach{
                     $binding="*:8"+$_+":"; 
                     New-IISSite -Name "test$_" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -BindingInformation $binding
            }
            
            #Execute
            Get-IISSite -Name "test1" | Remove-IISSite -Confirm:$false

            #Verify            
            LogVerifyTrue($?, "No error happened");
            $result = Get-IISSite | ?{$_.name -like "test*"}
            LogVerifyTrue((4 -eq $result.count), "Verify the web sites count.")

            #Execute
            (Get-IISSite | ?{$_.name -like "test*"})|Remove-IISSite -Confirm:$false

            #Verify            
            LogVerifyTrue($?, "No error happened");
            $result = Get-IISSite
            LogVerifyTrue(($siteNum -eq $result.count), "Verify the web sites count.")
            
            #No -name parameter
            #Execute
            New-IISSite -Name "test" -PhysicalPath "$env:systemdrive\inetpub\wwwroot" -BindingInformation "*:80:" -force
            Remove-IISSite "test" -Confirm:$False

            #Verify
            $result = Get-IISSite -Name "test" -WarningVariable warning
            LogVerifyTrue($warning.Item(0).Message.Equals("Web site 'test' does not exist."), "Verify the warning message")
            
            #Cleanup
            IISTest-RestoreAppHostConfig
                      
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration BVT #5 Stop-IISSite and Start-IISSite", 128800) -eq $true )
    {
        if ( IISTest-Ready )
        {        
            #Preparation            
            $appcmd = ($env:windir+"\system32\inetsrv\appcmd") 
            Reset-IISServerManager -Confirm:$false
            New-IISSite -Name "demo" -BindingInformation "*:80:hostname" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
            start-sleep 1

            #verify
            $result = $null = (Get-IISSite -Name "demo").State
            LogVerifyTrue(("Started" -eq $result), "Site Created")
            
            #Execute
            Stop-IISSite -Name "demo" -Confirm:$false
   
            #verify
            $result = $null = (Get-IISSite -Name "demo").State
            LogVerifyTrue(("Stopped" -eq $result), "Stop-IISSite :stopped demosite")

            #Execute
            Start-IISSite -Name "demo"
   
            #verify
            $result = $null = (Get-IISSite -Name "demo").State
            LogVerifyTrue(("Started" -eq $result), "Start-IISSite :started demosite") 
            
            #Stop a site with something other than powershell Stop-IISSite then call
            #Execute
            &$appcmd stop site "demo"
            Start-Sleep 1
            $result = Get-IISSite -Name "demo"
            LogVerifyTrue(("Stopped" -eq $result.State), "Verify the site state")
            Stop-IISSite -Name "demo" -Confirm:$false
            
            #Verify
            LogVerifyTrue($?, "No error happened")
            $result = Get-IISSite -Name "demo"
            LogVerifyTrue(("Stopped" -eq $result.State), "Verify the site state")

            #Get-IISSite | Stop-IISSite            
            Start-IISSite -Name "demo"
            #Execute
            Get-IISSite -Name "demo" | Stop-IISSite -Confirm:$false
            #Verify
            LogVerifyTrue($?, "No error happened")
            $result = Get-IISSite -Name "demo"
            LogVerifyTrue(("Stopped" -eq $result.State), "Verify the site state")

            #Create a new site with non-PS, stop it with Stop-IISSite
            #Execute
            &$appcmd add site /name:"test" /bindings:http/*:81: /physicalpath:$env:systemdrive\inetpub\wwwroot
            Start-Sleep 1
            Reset-IISServerManager -Confirm:$false
            Stop-IISSite -Name "test" -Confirm:$false
            #Verify
            $result = Get-IISSite -Name "test"
            LogVerifyTrue(("Stopped" -eq $result.State), "Verify the site state")

            
            #clean up
            IISTest-RestoreAppHostConfig
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }   

    if ( LogStartTest("IISAdministration BVT #6 Get-IISAppPool", 128801) -eq $true )
    {
        if ( IISTest-Ready )
        {
            
            $result = (Get-IISAppPool -Name DefaultAppPool,".NET v4.5 Classic",".NET v4.5").count
            #1: DefaultAppPool
            #2: .NET v4.5 Classic
            #3: .NET v4.5
            LogVerifyNumEq(3, $result, "Get the correct pool count")
            
            Get-IISAppPool -Name "non-exist" -WarningVariable warning
            LogVerifyTrue($warning.Item(0).Message.Contains("Application pool 'non-exist' does not exist"), "Try to get non-exist pool");

            $pool = Get-IISAppPool -Name "DefaultAppPool"
            $pool.Stop()
            $state = $pool.State
            LogVerifyTrue(("Stopped" -eq $state), "Get the currect status") 

            $auto = Get-IISConfigAttributeValue -ConfigElement $pool -AttributeName "autoStart"
            LogVerifyTrue($auto, "Auto start");

            $recycling = Get-IISConfigElement -ConfigElement $pool -ChildelementName "recycling"
            $change = Get-IISConfigAttributeValue -ConfigElement $recycling -AttributeName "disallowRotationOnConfigChange"
            LogVerifyFalse($change, "disallow Rotation On Config Change")

            $pool.Start()
            $state = $pool.State
            LogVerifyTrue(("Started" -eq $state), "Get the currect status")
            
            $result = Get-IISAppPool -Name "DefaultAppPool" | Get-IISConfigAttributeValue -AttributeName "autoStart"
            LogVerifyTrue($result, "Verify the value")          
       
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }  
    
    if ( LogStartTest("IISAdministration BVT #7 Get-IISConfig", 128802) -eq $true )
    {
        if ( IISTest-Ready )
        {            
            #Execute
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"            
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $state = Get-IISConfigAttributeValue -ConfigElement $site -AttributeName "State"
   
            #verify
            LogVerifyTrue(("Started" -eq $state), "Get the right state")  

            #Execute
            $elem = Get-IISConfigElement  -ConfigElement $site -ChildelementName "limits"
            $max = Get-IISConfigAttributeValue -ConfigElement $elem -AttributeName "maxUrlSegments"
   
            #verify
            LogVerifyNumEq(32, $max, "Get the correct value")

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument" -CommitPath "Default Web Site"
   
            #verify
            LogVerifyNumEq(6, $configSection.ChildElements.Item(0).count, "Get the correct count")

            #Execute
            $pool = Get-IISAppPool -Name "DefaultAppPool"
            $pro = Get-IISConfigElement -ConfigElement $pool -ChildelementName "processModel"
            $time = Get-IISConfigAttributeValue -ConfigElement $pro -AttributeName "shutdownTimeLimit"
   
            #verify
            LogVerifyStrEq("00:01:30", $time.ToString(), "Get the correct time")

            #Execute
            $recycling = Get-IISConfigElement -ConfigElement $pool -ChildelementName "recycling"
            $flags = Get-IISConfigAttributeValue -ConfigElement $recycling -AttributeName "logEventOnRecycle"

            #verify
            LogVerifyTrue($flags.Equals("Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory"), "Get the correct flags")
            
            #Get-IISConfigCollectionElement | Set-IISConfigAttributeValue
            #Execute
            New-IISSite -Name "test" -BindingInformation "*:8080:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
            $configSection = Get-IISConfigSection -Section "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "test"} | Set-IISConfigAttributeValue -AttributeName "serverAutoStart" -AttributeValue "False"
            LogVerifyTrue($?, "No error happened")            
            
            #Verify
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $site = Get-IISConfigCollection -ConfigElement $configSection | Get-IISConfigCollectionElement -ConfigAttribute @{Name = "test"}
            $result = Get-IISConfigAttributeValue -ConfigElement $site -AttributeName "serverAutoStart"
            LogVerifyFalse($result, "Verify the config value")
           
            #cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 
    
    if ( LogStartTest("IISAdministration BVT #8 Get-IISConfig: return object", 128803) -eq $true )
    {
        if ( IISTest-Ready )
        {
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/requestFiltering"
   
            #verify
            LogVerifyStrEq("ConfigurationSection",$configSection.GetType().Name, "Get-IISConfigSection:return object is configuration section");

            #Execute
            $fileExtensions = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "fileExtensions"
            $file = Get-IISConfigCollectionElement -ConfigCollection $fileExtensions -ConfigAttribute @{fileExtension = ".asa"}
   
            #verify
            LogVerifyStrEq("ConfigurationElement",$file.GetType().Name, "Get-IISConfigCollectionElement:return object is configuration element");
            
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/applicationPools"
            $applicationPoolsCollection = Get-IISConfigCollection -ConfigElement $configSection
            $default = Get-IISConfigCollectionElement -ConfigCollection $applicationPoolsCollection -ConfigAttribute @{name = "DefaultAppPool"}
            $model = Get-IISConfigElement -ConfigElement $default -ChildelementName "processModel"

            #verify  
            LogVerifyStrEq("ConfigurationElement",$model.GetType().Name, "Get-IISConfigElement:return object is configuration element");
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration BVT #9 Get-IISConfig: Error handling", 128804) -eq $true )
    {
        if ( IISTest-Ready )
        {
            #Execute 
            Reset-IISServerManager -Confirm:$false
            $exceptionExpected = $true
            Get-IISConfigSection -sectionPath "system.applicationHost\applicationPools" -ErrorVariable errorMessage
            
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Config section 'system.applicationHost\applicationPools' does not exist."), "Backslash cannot be recognized")

            #Execute 
            try 
            { 
                Get-IISConfigSection -sectionPath $null -ErrorVariable errorMessage 
            }
            catch 
            { 
                $errorMessage = $error[0] 
            }
   
            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Cannot validate argument on parameter 'SectionPath'. The argument is null or empty"), "Verify argument is null")  

            #Execute 
            try 
            { 
                Get-IISConfigSection -sectionPath "" -ErrorVariable errorMessage 
            }
            catch 
            { 
                $errorMessage = $error[0] 
            }
   
            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Cannot validate argument on parameter 'SectionPath'. The argument is null or empty"), "Verify argument is empty") 

            #Execute 
            $exceptionExpected = $true
            Get-IISConfigSection -sectionPath "system.webServer" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false
            #we expected to verify the error message here, however, according to Threshold bug #1326453 (issue5), MWA throws a different exception, so just leave this as it is.            

            #Execute 
            $exceptionExpected = $true
            Get-IISConfigSection -sectionPath "system.applicationHost/site" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Config section 'system.applicationHost/site' does not exist"), "Verify error section") 

            #Execute 
            $exceptionExpected = $true
            Get-IISConfigSection -sectionPath "system.applicationhost/sites" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Config section 'system.applicationhost/sites' does not exist"), "Verify parameters are case-sensitive") 

            #Execute 
            try 
            { 
                Get-IISConfigCollectionElement -ConfigCollection $nonexist -ErrorVariable errorMessage
            }
            catch 
            { 
                $errorMessage = $error[0] 
            }

            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Cannot validate argument on parameter 'ConfigCollection'"), "Verify argument is non-exist") 

            #Execute 
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/requestFiltering"
            $fileExtension = $null
            $exceptionExpected = $true
            try
            {
                Get-IISConfigCollectionElement -ConfigCollection $fileExtension -ConfigAttribute @{fileExtension = ".asa"} -ErrorVariable errorMessage
                LogVerifyTrue($?, "Error not happened"); #not expected
            }
            catch 
            { 
                LogVerifyFalse($?, "Error happened");
                $errorMessage = $error[0] 
            }
            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Cannot validate argument on parameter 'ConfigCollection'. The argument is null."), "Verify non-exist collection") 

            #Execute 
            $exceptionExpected = $true
            $fileExtensions = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "fileExtensions"
            try
            {
                Get-IISConfigCollectionElement -ConfigCollection $fileExtensions -ConfigAttribute @{fileExtensions = ".asa"} -ErrorVariable errorMessage
                LogVerifyTrue($?, "Error not happened"); #not expected
            }
            catch 
            { 
                LogVerifyFalse($?, "Error happened");
                $errorMessage = $error[0] 
            }  
            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Attribute 'fileExtensions' does not exist"), "Verify non-exist attribute") 

            #Execute 
            Get-IISConfigCollectionElement -ConfigCollection $fileExtensions -ConfigAttribute @{fileExtension = ".asaa"} -WarningVariable warning
   
            #verify
            $msg = $null = $warning.Item(0)
            LogVerifyTrue($msg.Message.Contains("Config collection element does not exist"), "Verify non-exist attribute value") 
            
            #Execute 
            try 
            { 
                Get-IISConfigElement -ConfigElement $null -ChildelementName "processModel" -ErrorVariable errorMessage 
            }
            catch 
            { 
                $errorMessage = $error[0] 
            }
   
            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Cannot validate argument on parameter 'ConfigElement'. The argument is null"), "Verify a null value for config object") 
            
            #Execute 
            try 
            { 
                Get-IISConfigElement -ConfigElement "12345" -ChildelementName "processModel" -ErrorVariable errorMessage 
            }
            catch 
            { 
                $errorMessage = $error[0] 
            }
   
            #verify
            LogVerifyTrue($errorMessage.Exception.Message.Contains("Cannot bind parameter 'ConfigElement'."), "Verify a string value for config object") 
            
            #Execute 
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/applicationPools"
            $applicationPoolsCollection = Get-IISConfigCollection -ConfigElement $configSection
            $default = Get-IISConfigCollectionElement -ConfigCollection $applicationPoolsCollection -ConfigAttribute @{name = "DefaultAppPool"}
            $exceptionExpected = $true
            Get-IISConfigElement -ConfigElement $default -ChildelementName "processMode" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Unrecognized element 'processMode'"), "Verify non-exist element") 

            #Execute 
            $model = Get-IISConfigElement -ConfigElement $default -ChildelementName "processModel"
            $exceptionExpected = $true
            Get-IISConfigAttributeValue -ConfigElement $model -AttributeName "pingResponseTim" -ErrorVariable errorMessage
   
            #verify
            LogVerifyFalse($?, "Error happened");
            $exceptionExpected = $false

            $msg = $null = $errorMessage.Item(0)
            LogVerifyTrue($msg.Message.Contains("Parameter 'pingResponseTim' does not exist"), "Verify non-exist attribute") 
            
            trap
            {
                LogTestCaseError $_ $exceptionExpected
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration BVT #10 New-IISConfigCollectionElement and Remove-IISConfigCollectionElement : Add and remove a binding for Default Web Site", 128805) -eq $true)
    {
        if ( IISTest-Ready )
        {
            #Get the count of bindings under Default Web Site
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            $beforeAddCount = $site.ChildElements["Bindings"].count

            #add a binding for default web site
            Start-IISCommitDelay
            New-IISConfigCollectionElement -ConfigCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation="*:85:foo12345"}
            Stop-IISCommitDelay
            $addedCount = $site.ChildElements["Bindings"].count
            LogVerifyNumEq($addedCount, ($beforeAddCount + 1), "Added count should be bigger by one")

            #remove the added binding for default web site
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
	
            Start-IISCommitDelay
            Remove-IISConfigCollectionElement -ConfigCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation="*:85:foo12345"} -Confirm:$false
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $removedCount = $site.ChildElements["Bindings"].count
            LogVerifyNumEq($removedCount, $beforeAddCount, "OK")

            # cleanup
            IISTest-RestoreAppHostConfig
            
            trap
            {
                LogTestCaseError $_
            }
        }
		else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration BVT #11 New-IISConfigCollectionElement and Remove-IISConfigCollectionElement : Add and remove a default document for Server", 128806) -eq $true)
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -confirm:$false
            #Get the count of bindings under Default Web Site
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument"
            $beforeAddCount = $configSection.ChildElements["files"].count
            $filesCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "files"

            #add a default document for the server
            Start-IISCommitDelay
            New-IISConfigCollectionElement -ConfigCollection $filesCollection -ConfigAttribute @{Value = "myDoc.htm"}
            Stop-IISCommitDelay
            $addedCount = $configSection.ChildElements["files"].count
            LogVerifyNumEq($addedCount, ($beforeAddCount + 1), "OK")

            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument"
            $filesCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "files"
            #remove the added document for the server
            Start-IISCommitDelay
            Remove-IISConfigCollectionElement -ConfigCollection $filesCollection -ConfigAttribute @{Value = "myDoc.htm"} -Confirm:$false
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument"
            $removedCount = $configSection.ChildElements["files"].count
            LogVerifyNumEq($removedCount, $beforeAddCount, "OK")
  
            # cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
		else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration BVT #12 New-IISConfigCollectionElement and Remove-IISConfigCollectionElement : Error-handling", 128807) -eq $true)
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -confirm:$false
            # TH bug #1966230 "Get-IISConfigSection should enumerate all the sections when -sectionPath parameter is null"            
            $count_ServerLevel = (Get-IISConfigSection).Count
            LogVerifyTrue($?, "No error happened")
            $count_SiteLevel = (Get-IISConfigSection -Location "Default Web Site").Count
            LogVerifyTrue($?, "No error happened")
            LogVerifyTrue(($count_ServerLevel -ge 120), "All sections for server levle have been found.")
            LogVerifyTrue(($count_SiteLevel -ge 101), "All sections for site levle have been found.")
            # TH bug #2283914 "BugBash: Get-IISConfigSection should show different result when it is called from site level" 
            LogVerifyTrue(($count_ServerLevel -gt $count_SiteLevel), "The numbers of scetions that called from server and site levles should be different.")
            
                        
            # Add duplicate configcollectionitem(duplicate unique key)
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            $error.Clear()
            Try
            {
                New-IISConfigCollectionElement -ConfigCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation=":82:localhost"}
                $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
                $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
                $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
                $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
                New-IISConfigCollectionElement -ConfigCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation=":82:localhost"}
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot add duplicate collection entry")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            # Try to remove a default document for Server that does not exist
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument"
            $filesCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "files"
            Remove-IISConfigCollectionElement -ConfigCollection $filesCollection -ConfigAttribute @{value = "nonexistentDoc.htm"} -WarningVariable Message -Confirm:$false
            $WarningMessage = ($message | out-string)
            LogVerifyTrue($WarningMessage.Contains("Config collection element does not exist."), "The error message is expected.")

            # Incorrect inputs
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            Try
            {
                # -ConfogCollection
                New-IISConfigCollectionElement -ConfogCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"}
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("A parameter cannot be found that matches parameter")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            Try
            {
                # -ConfogCollection
                Remove-IISConfigCollectionElement -ConfogCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"} -Confirm:$false
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("A parameter cannot be found that matches parameter")
                LogVerifyTrue($equal, "The error message is expected.")
            }
            
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            Try
            {
                New-IISConfigCollectionElement -ConfigCollection "" -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"}
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot bind parameter 'ConfigCollection'.")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            Try
            {
                Remove-IISConfigCollectionElement -ConfigCollection "" -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"} -Confirm:$false
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot bind parameter 'ConfigCollection'.")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            Try
            {
                New-IISConfigCollectionElement -ConfigCollection  -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"}
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Missing an argument for parameter 'ConfigCollection'. Specify a parameter")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            Try
            {
                Remove-IISConfigCollectionElement -ConfigCollection "" -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"} -Confirm:$false
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot bind parameter 'ConfigCollection'.")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            Try
            {
                New-IISConfigCollectionElement -ConfigCollection "string" -ConfigAttribute @{protocol="http";bindingInformation="*:91:foo11122"}
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot bind parameter 'ConfigCollection'")
                LogVerifyTrue($equal, "The error message is expected.")      
            }

            # Regression test for MSFT: 5041463: remove collection item right after handling duplicated item error
            $collection = Get-IISConfigSection -SectionPath "appSettings" -clr 4.0 | Get-IISConfigCollection
            New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{"key"="test";"value"="test"}
            $collection = Get-IISConfigSection -SectionPath "appSettings" -clr 4.0 | Get-IISConfigCollection
            $saveCollectionCount = $collection.Count
            Try
            {
                New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{"key"="test";"value"="test"}
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot add duplicate collection entry of type 'add' with unique key attribute 'key' set to 'test'")
                LogVerifyTrue($equal, "The error message is expected.")      
            }
            $collection = Get-IISConfigSection -SectionPath "appSettings" | Get-IISConfigCollection
            $equal = $collection.Count -eq $saveCollectionCount
            LogVerifyTrue($equal, "collection result no change")
            Remove-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{"key"="test";"value"="test"} -confirm:$false
            $collection = Get-IISConfigSection -SectionPath "appSettings" | Get-IISConfigCollection
            $equal = $collection.Count -eq ($saveCollectionCount - 1)
            LogVerifyTrue($equal, "collection result decreased by 1")

            # cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration BVT #13 Set-IISConfigAttributeValue : change a few default settings and check", 128808) -eq $true)
    {
        if ( IISTest-Ready )
        {
            # Allow directory browsing of server node (borrowed the idea from case id 74169)
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse"
            Start-IISCommitDelay
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled" -AttributeValue "true"
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse"
            $DBEnabled = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            LogVerifyTrue($DBEnabled, "OK")
            start-sleep 3            

            # Set the directory browsing settings for server node back
            # It may be a by design issue, but I have to assign to var configSection every time I try to modify the config file, Baris says a passthru parameter may be added to these commands later, until then the script may have to be this way
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse"
            Start-IISCommitDelay
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled" -AttributeValue "false"
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse"
            $DBEnabled = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            LogVerifyFalse($DBEnabled, "OK")
            start-sleep 3	

            # Change the extension name for certain handler (borrowed the idea from case 74173)
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/handlers"
            $collection = Get-IISConfigCollection -ConfigElement $configSection
            $handler = Get-IISConfigCollectionElement -ConfigCollection $collection -configAttribute @{name = "ASPClassic"}
            Start-IISCommitDelay
            Set-IISConfigAttributeValue -ConfigElement $handler -AttributeName "path" -AttributeValue "*.asp1"
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse"
            $handlerPath = Get-IISConfigAttributeValue -ConfigElement $handler -AttributeName "path"
            LogVerifyStrEq($handlerPath, "*.asp1", "Verify newly-set handler path")
            start-sleep 3

            # Set the handler path back
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/handlers"
            $collection = Get-IISConfigCollection -ConfigElement $configSection
            $handler = Get-IISConfigCollectionElement -ConfigCollection $collection -configAttribute @{name = "ASPClassic"}
            Start-IISCommitDelay
            Set-IISConfigAttributeValue -ConfigElement $handler -Attributename "path" -AttributeValue "*.asp"
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/handlers"
            $collection = Get-IISConfigCollection -ConfigElement $configSection
            $handler = Get-IISConfigCollectionElement -ConfigCollection $collection -configAttribute @{name = "ASPClassic"}
            $handlerPath = Get-IISConfigAttributeValue -ConfigElement $handler -AttributeName "path"
            LogVerifyStrEq($handlerPath, "*.asp", "Verify that the handler path is reset")
            start-sleep 3

            # Change the settings of clearance for some authentication of IIS Server
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/authentication/windowsAuthentication"
            Start-IISCommitDelay
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled" -AttributeValue "true"
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/authentication/windowsAuthentication"
            $WAEnabled = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            LogVerifyTrue($WAEnabled, "OK")
            start-sleep 3

            # Set the authentication setting back
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/authentication/windowsAuthentication"
            Start-IISCommitDelay
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled" -AttributeValue "false"
            Stop-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse"
            $WAEnabled = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            LogVerifyFalse($WAEnabled, "OK")
            start-sleep 3

            # cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration BVT #14 Set-IISConfigAttributeValue : test error-handling for the command", 128809) -eq $true)
    {
        if ( IISTest-Ready )
        {
            # Assign null value to the parameter ConfigObject 
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try{
                Set-IISConfigAttributeValue -ConfigElement $null -AttributeName "maxUrlSegments" -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("The argument is null")
            LogVerifyTrue($equal, "The error message is expected.")
            }
            
            # Assign a string to the parameter ConfigObject
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try{
                Set-IISConfigAttributeValue -ConfigElement "12345" -AttributeName "maxUrlSecments" -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot bind parameter 'ConfigElement'.")
                LogVerifyTrue($equal, "The error message is expected.")
            }
            # Input nothing for the parameter
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try{
                Set-IISConfigAttributeValue -ConfigElement -AttributeName "maxUrlSegments" -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Missing an argument for parameter 'ConfigElement'")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            # A typo of the parameter name ConfigElement
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try{
                Set-IISConfigAttributeValue -ConfigElements $elem -AttributeName "maxUrlSegments" -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("A parameter cannot be found that matches parameter name 'ConfigElements'")
                LogVerifyTrue($equal, "The error message is expected.")
            }
            # A null string for the parameter Attribute
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try{
                Set-IISConfigAttributeValue -ConfigElement $elem -AttributeName "" -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Cannot validate argument on parameter 'AttributeName'. The argument is null or empty.")
                LogVerifyTrue($equal, "The error message is expected.") 
            }  
            # An object not of type string ( a little confusing )
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $SitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try
            {
                Set-IISConfigAttributeValue -ConfigElement $elem -AttributeName $elem -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Parameter 'Microsoft.Web.Administration.ConfigurationElement' does not exist")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            # Input nothing for the parameter Attribute	
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $SitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try
            {
                Set-IISConfigAttributeValue -ConfigElement $elem -AttributeName -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)
                $equal = $errorMessage.Contains("Missing an argument for parameter 'AttributeName'.")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            # A typo of the parameter name AttributeName
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $SitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $elem = Get-IISConfigElement -ConfigElement $site -ChildelementName "limits"
            Try
            {
                Set-IISConfigAttributeValue -ConfigElement $elem -AttributeName1 "maxUrlSegments" -AttributeValue 16
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string) 
                $equal = $errorMessage.Contains("A parameter cannot be found that matches parameter name 'AttributeName1'")
                LogVerifyTrue($equal, "The error message is expected.")
            }

            # cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration #15 Get-IISConfig: Web site", 129143) -eq $true )
    {
        if ( IISTest-Ready )
        {                      
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/httpCompression" -CommitPath "Default Web Site"
            $cacheControlHeader = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "cacheControlHeader"
            
            #verify
            LogVerifyStrEq("max-age=86400", $cacheControlHeader, "Verify string") 

            #Execute
            $staticTypesCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "staticTypes"
            $mime = Get-IISConfigCollectionElement -ConfigCollection $staticTypesCollection -ConfigAttribute @{mimeType = "*/*"}
            $enable = Get-IISConfigAttributeValue -ConfigElement $mime -AttributeName "enabled"

            #verify
            LogVerifyFalse($enable, "Verify bool") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse" -CommitPath "Default Web Site"
            $showflags = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "showFlags"

            #verify
            LogVerifyStrEq("Date,Time,Size,Extension", $showflags, "Verify flags") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/httpErrors" -CommitPath "Default Web Site"
            $errormode = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "errorMode"

            #verify
            LogVerifyStrEq("DetailedLocalOnly", $errormode, "Verify enum") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/serverRuntime" -CommitPath "Default Web Site"
            $maxRequestEntityAllowed = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "maxRequestEntityAllowed"
            $frequentHitTimePeriod = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "frequentHitTimePeriod"

            #verify
            LogVerifyStrEq("00:00:10", $frequentHitTimePeriod.tostring(), "Verify timeSpan")  
            LogVerifyTrue((4294967295 -eq $maxRequestEntityAllowed), "Verify uint")  
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration #16 - Get-IISConfig: Ftp site", 129144) -eq $true )
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -Confirm:$false
            Start-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection
            $site = New-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "ftp"; id=2} -Passthru
            $applicationsCollection = Get-IISConfigCollection -ConfigElement $site
            $app = New-IISConfigCollectionElement -ConfigCollection $applicationsCollection -ConfigAttribute @{ path = "/"; applicationPool="DefaultAppPool"} -Passthru
            $vdirsCollection = Get-IISConfigCollection -ConfigElement $app
            $vdir = New-IISConfigCollectionElement -ConfigCollection $vdirsCollection -ConfigAttribute @{ path = "/"; physicalPath="$env:systemdrive\inetpub\ftproot" } -Passthru
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            New-IISConfigCollectionElement -ConfigCollection $bindingsCollection -ConfigAttribute @{ protocol="ftp"; bindingInformation="*:21:" }
            Stop-IISCommitDelay 
            
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/log"
            $flags = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "centralLogFile"
            $logExtFileFlags = Get-IISConfigAttributeValue -ConfigElement $flags -AttributeName "logExtFileFlags"
            $truncateSize = Get-IISConfigAttributeValue -ConfigElement $flags -AttributeName "truncateSize"
            $period = Get-IISConfigAttributeValue -ConfigElement $flags -AttributeName "period"
            
            #verify
            LogVerifyStrEq("Date,Time,ClientIP,UserName,ServerIP,Method,UriStem,FtpStatus,Win32Status,ServerPort,FtpSubStatus,Session,FullPath", $logExtFileFlags, "Verify flags") 
            LogVerifyNumEq(20971520, $truncateSize, "Verify int64")  
            LogVerifyStrEq("Daily", $period.tostring(), "Verify enum")

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/authentication" -CommitPath "ftp"
            $denyByFailure = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "denyByFailure"
            $entryExpiration = Get-IISConfigAttributeValue -ConfigElement $denyByFailure -AttributeName "entryExpiration"
            $maxFailure = Get-IISConfigAttributeValue -ConfigElement $denyByFailure -AttributeName "maxFailure"

            #verify
            LogVerifyStrEq("00:00:30", $entryExpiration.tostring(), "Verify timeSpan")
            LogVerifyNumEq(4, $maxFailure, "Verify uint")    

            #Execute
            $site = Get-IISSite -Name "ftp"
            $traceFailedRequestsLogging = Get-IISConfigElement -ConfigElement $site -ChildelementName "traceFailedRequestsLogging"
            $enabled = Get-IISConfigAttributeValue -ConfigElement $traceFailedRequestsLogging -AttributeName "enabled"
            $directory = Get-IISConfigAttributeValue -ConfigElement $traceFailedRequestsLogging -AttributeName "directory"

            #verify
            LogVerifyStrEq("%SystemDrive%\inetpub\logs\FailedReqLogFiles", $directory, "Verify string") 
            LogVerifyFalse($enabled, "Verify bool") 

            #Clean
            IISTest-RestoreAppHostConfig
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration #17 - Get-IISConfig: Application pool", 129145) -eq $true )
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -Confirm:$false
            Start-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/applicationPools"
            $applicationPoolsCollection = Get-IISConfigCollection -ConfigElement $configSection
            $appPool = New-IISConfigCollectionElement -ConfigCollection $applicationPoolsCollection -ConfigAttribute @{Name = "MyNewSiteAppPool"; autoStart=$true; managedPipelineMode="Integrated" } -Passthru
            Stop-IISCommitDelay

            #Execute
            $pool = Get-IISAppPool -Name "MyNewSiteAppPool"
            $managedRuntimeLoader = Get-IISConfigAttributeValue -ConfigElement $pool -AttributeName "managedRuntimeLoader"

            #verify
            LogVerifyStrEq("webengine4.dll", $managedRuntimeLoader, "Verify string") 

            #Execute
            $processModel = Get-IISConfigElement -ConfigElement $pool -ChildelementName "processModel"
            $pingResponseTime = Get-IISConfigAttributeValue -ConfigElement $processModel -AttributeName "pingResponseTime"
            $idleTimeoutAction = Get-IISConfigAttributeValue -ConfigElement $processModel -AttributeName "idleTimeoutAction"
            $logEventOnProcessModel = Get-IISConfigAttributeValue -ConfigElement $processModel -AttributeName "logEventOnProcessModel"

            #verify
            LogVerifyStrEq("00:01:30", $pingResponseTime.tostring(), "Verify timeSpan")  
            LogVerifyStrEq("Terminate", $idleTimeoutAction, "Verify enum")
            LogVerifyStrEq("IdleTimeout", $logEventOnProcessModel, "Verify flags")  

            #Execute
            $failure = Get-IISConfigElement -ConfigElement $pool -ChildelementName "failure"
            $rapidFailProtectionMaxCrashes = Get-IISConfigAttributeValue -ConfigElement $failure -AttributeName "rapidFailProtectionMaxCrashes"
            $rapidFailProtection = Get-IISConfigAttributeValue -ConfigElement $failure -AttributeName "rapidFailProtection"

            #verify
            LogVerifyNumEq(5, $rapidFailProtectionMaxCrashes, "Verify uint") 
            LogVerifyTrue($rapidFailProtection, "Verify bool") 

            #Clean
            IISTest-RestoreAppHostConfig
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration #18 - Get-IISConfig: Application", 129146) -eq $true )
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -Confirm:$false
            Start-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $applicationsCollection = Get-IISConfigCollection -ConfigElement $site
            $app = New-IISConfigCollectionElement -ConfigCollection $applicationsCollection -ConfigAttribute @{ path = "/newapp"; applicationPool="DefaultAppPool"} -Passthru
            $vdirsCollection = Get-IISConfigCollection -ConfigElement $app
            New-IISConfigCollectionElement -ConfigCollection $vdirsCollection -ConfigAttribute @{ path = "/"; physicalPath="$env:systemdrive\inetpub\wwwroot" }
            Stop-IISCommitDelay
            
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/staticContent" -CommitPath "Default Web Site/newapp"
            $cache = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "clientCache"
            $cacheControlMode = Get-IISConfigAttributeValue -ConfigElement $cache -AttributeName "cacheControlMode"
            $cacheControlMaxAge = Get-IISConfigAttributeValue -ConfigElement $cache -AttributeName "cacheControlMaxAge"

            #verify
            LogVerifyStrEq("1.00:00:00", $cacheControlMaxAge.tostring(), "Verify timeSpan")  
            LogVerifyStrEq("NoControl", $cacheControlMode, "Verify enum")

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/urlCompression" -CommitPath "Default Web Site/newapp"
            $doDynamicCompression = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "doDynamicCompression"

            #verify
            LogVerifyTrue($doDynamicCompression, "Verify bool")

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/webSocket" -CommitPath "Default Web Site/newapp"
            $receiveBufferLimit = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "receiveBufferLimit"

            #verify
            LogVerifyNumEq(4194304, $receiveBufferLimit, "Verify uint") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/webdav/authoring" -CommitPath "Default Web Site/newapp"
            $locks = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "locks"
            $lockStore = Get-IISConfigAttributeValue -ConfigElement $locks -AttributeName "lockStore"
            $compatFlags = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "compatFlags"

            #verify
            LogVerifyStrEq("webdav_simple_lock", $lockStore, "Verify string") 
            LogVerifyStrEq("MsAuthorVia,MultiProp,CompactXml,IsHidden,IsCollection", $compatFlags, "Verify flags") 

            #Clean
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration #19 - Get-IISConfig: Virtual directory", 129147) -eq $true )
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -Confirm:$false
            Start-IISCommitDelay
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $applicationsCollection = Get-IISConfigCollection -ConfigElement $site
            $app = Get-IISConfigCollectionElement -ConfigCollection $applicationsCollection -ConfigAttribute @{path="/"}
            $vdirsCollection = Get-IISConfigCollection -ConfigElement $app
            $vdir = New-IISConfigCollectionElement -ConfigCollection $vdirsCollection -ConfigAttribute @{ path = "/vvdir"; physicalPath="$env:systemdrive\inetpub\wwwroot" }
            Stop-IISCommitDelay 
            
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/httpRedirect" -CommitPath "Default Web Site/vvdir"
            $enabled = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            $httpResponseStatus = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "httpResponseStatus"

            #verify
            LogVerifyFalse($enabled, "Verify bool")
            LogVerifyStrEq("Found", $httpResponseStatus, "Verify enum")

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/cgi" -CommitPath "Default Web Site/vvdir"
            $timeout = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "timeout"
   
            #verify
            LogVerifyStrEq("00:15:00", $timeout.tostring(), "Verify timeSpan") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/asp" -CommitPath "Default Web Site/vvdir"
            $comPlus = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "comPlus"
            $appServiceFlags = Get-IISConfigAttributeValue -ConfigElement $comPlus -AttributeName "appServiceFlags"
            $partitionId = Get-IISConfigAttributeValue -ConfigElement $comPlus -AttributeName "partitionId"
   
            #verify
            LogVerifyStrEq("none", $appServiceFlags, "Verify flags")
            LogVerifyStrEq("00000000-0000-0000-0000-000000000000", $partitionId, "Verify string") 

            #Execute
            $session = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "session"
            $max = Get-IISConfigAttributeValue -ConfigElement $session -AttributeName "max"
   
            #verify
            LogVerifyTrue((4294967295 -eq $max), "Verify uint")

            #Execute

            #verify
            
              
            #Clean
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration #20 - Get-IISConfig: File", 129148) -eq $true )
    {
        if ( IISTest-Ready )
        {                      
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/authentication/windowsAuthentication" -CommitPath "Default Web Site/iisstart.htm"
            $extendedProtection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "extendedProtection"
            $tokenChecking = Get-IISConfigAttributeValue -ConfigElement $extendedProtection -AttributeName "tokenChecking"
            $flags = Get-IISConfigAttributeValue -ConfigElement $extendedProtection -AttributeName "flags"
   
            #verify
            LogVerifyStrEq("none", $flags, "Verify flags")
            LogVerifyStrEq("None", $tokenChecking, "Verify enum") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/asp" -CommitPath "Default Web Site/iisstart.htm"
            $appAllowDebugging = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "appAllowDebugging"   
            $scriptLanguage = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "scriptLanguage"   
   
            #verify
            LogVerifyStrEq("VBScript", $scriptLanguage, "Verify string") 
            LogVerifyFalse($appAllowDebugging, "Verify bool") 
             

            #Execute
            $limits = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "limits"
            $maxRequestEntityAllowed = Get-IISConfigAttributeValue -ConfigElement $limits -AttributeName "maxRequestEntityAllowed"

            #verify
            LogVerifyNumEq(200000, $maxRequestEntityAllowed, "Verify uint")

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/webSocket" -CommitPath "Default Web Site/iisstart.htm"
            $pingInterval = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "pingInterval"   
            
            #verify
            LogVerifyStrEq("00:00:00", $pingInterval.tostring(), "Verify timeSpan") 
                                                      
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration #21 - Get-IISConfig: Machine root", 129149) -eq $true )
    {
        if ( IISTest-Ready )
        {                      
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitedefaults = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "siteDefaults"
            $ftp = Get-IISConfigElement -ConfigElement $sitedefaults -ChildelementName "ftpServer"
            $security = Get-IISConfigElement -ConfigElement $ftp -ChildelementName "security"
            $ssl = Get-IISConfigElement -ConfigElement $security -ChildelementName "sslClientCertificates"
            $validationFlags = Get-IISConfigAttributeValue -ConfigElement $ssl -AttributeName "validationFlags"
            
            #verify
            LogVerifyStrEq("", $validationFlags, "Verify flags") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/asp"
            $cache = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "cache"
            $scriptFileCacheSize = Get-IISConfigAttributeValue -ConfigElement $cache -AttributeName "scriptFileCacheSize"

            #verify
            LogVerifyNumEq(500, $scriptFileCacheSize, "Verify uint") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/authentication/anonymousAuthentication"
            $user = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "userName"
            $logonMethod = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "logonMethod"

            #verify
            LogVerifyStrEq("IUSR", $user, "Verify string") 
            LogVerifyStrEq("ClearText", $logonMethod, "Verify enum") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/security/authorization"
            $bypassLoginPages = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "bypassLoginPages"

            #verify
            LogVerifyTrue($bypassLoginPages, "Verify bool") 

            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/configHistory"
            $period = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "period"
   
            #verify
            LogVerifyStrEq("00:02:00", $period.tostring(), "Verify timeSpan")  
                                          
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    } 

    if ( LogStartTest("IISAdministration #22 - Set-IISConfigAttributeValue : Try create a vast number of IIS sites and set them differently, then manage them", 129150) -eq $true)
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -Confirm:$false
            $elapsedTime = [System.Diagnostics.StopWatch]::StartNew()
            $SitesCount = 1
            cd $env:homedrive\inetpub\wwwroot
            Start-IISCommitDelay

            #
            # Use 100 instead of 10000
            #
            while($SitesCount -lt 100)
            {
                 $SiteName = "TestSite" + $SitesCount
                 new-item -path  $env:homedrive\inetpub\wwwroot -name $SiteName -type directory | Out-Null
                 $SiteBinding = "*:81:foo12345" + $SitesCount
                 $Path = join-path $env:homedrive\inetpub\wwwroot\ $SiteName
                 New-IISSite -Name $SiteName -PhysicalPath $Path -BindingInformation $SiteBinding
                 $SitesCount++
                 #Stop-WebSite -Name $SiteName -Passthru
            }
            Stop-IISCommitDelay
            
            $SitesPos = 1
            Start-IISCommitDelay            
            #
            # Use 100 instead of 10000
            #
            while($SitesPos -lt 100)
            {
                $SiteName = "TestSite" + $SitesPos
                #commit to apphost instead of each web.cofig, to save memeory.
                $configSection = Get-IISConfigSection -sectionPath "system.webServer/asp" -Location $SiteName
                Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "lcid" -AttributeValue $SitesPos                
                $SitesPos++               
                
            }
            Stop-IISCommitDelay
            LogComment("Total Elapsed Time: $($elapsedTime.Elapsed.ToString())")
            $SitesPos = 1
            
            #
            # Use 100 instead of 10000
            #            
            while($SitesPos -lt 100)
            {
                $SiteName = "TestSite" + $SitesPos
                $configSection = Get-IISConfigSection -sectionPath "system.webServer/asp" -Location $SiteName
                $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "lcid"
                LogVerifyNumEq($SitesPos, $result, "Verify that setting has been changed")                
                $SitesPos++
            }

            
            #delete the sites, improve the performance
            $SitesPos--
            Get-ChildItem -Path $env:homedrive\inetpub\wwwroot -filter TestSite* | remove-item -force -recurse

            # cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration #23 - Test ETs of IIS configuration: App and VDir Level; Different data types; Rare Setting places", 129151) -eq $true)
    {
        if ( IISTest-Ready )
        { 
            Reset-IISServerManager -Confirm:$false
            #FTP Part
            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/log" 
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "centralLogFileMode" -AttributeValue "Central"
            $logMode = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "centralLogFileMode"
            LogVerifyStrEq("Central", $logMode, "Verify log file mode is changed to Central.")

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/log"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "centralLogFile"
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "LocalTimeRollover" -AttributeValue $True
            $rollOver = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "LocalTimeRollover"
            LogVerifyTrue($rollOver, "Verify LocalTimeRollover is modified to true.");

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/log"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "centralLogFile"
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "period" -AttributeValue "Monthly"
            $logPeriod = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "period"
            LogVerifyStrEq("Monthly", $logPeriod, "Verify that log period is changed to monthly.")

            #Get-IISConfigAttributeValue return null for collection data type bug still not fixed
            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/log"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "centralLogFile"
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "logExtFileFlags" -AttributeValue "Date,Time,ClientIP,UserName,ServerIP,Method,UriStem,FtpStatus,Win32Status,ServerPort,FtpSubStatus"
            $flags = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "logExtFileFlags"
            LogVerifyTrue($flags.Contains("Date,Time,ClientIP,UserName,ServerIP,Method,UriStem,FtpStatus,Win32Status,ServerPort,FtpSubStatus"), "Verify that flags has been set.")
            
            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/log"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "loginUTF8" -AttributeValue $False
            $utf8Enabled = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "loginUTF8"
            LogVerifyFalse($utf8Enabled, "Verify that utf8 login is disabled")

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/authentication"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "denyByFailure"
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "enabled" -AttributeValue $True
            $denyEnabled = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "enabled"
            LogVerifyTrue($denyEnabled, "Verify that denyByFailure is enabled")

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/authentication"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "denyByFailure"
            $timeSpan = New-TimeSpan -Hours 0 -Minutes 0 -Seconds 51            
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "entryExpiration" -AttributeValue $timeSpan
            $setTimeSpan = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "entryExpiration"
            LogVerifyNumEq(51, $setTimeSpan.Seconds, "Verify timespan has been set")
            #Threshol bug #1973084
            Reset-IISServerManager -Confirm:$false            
            $timeSpan2 = "00:01:51"
            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/authentication"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "denyByFailure"
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "entryExpiration" -AttributeValue $timeSpan2
            LogVerifyTrue($?, "No error happened")
            $setTimeSpan2 = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "entryExpiration"
            LogVerifyStrEq($timeSpan2, $setTimeSpan2.ToString(), "String object can be used to set timeSpan value")  

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/authentication"
            $configCollection = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "denyByFailure"
            Set-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "maxFailure" -AttributeValue 60000
            $maxFailure = Get-IISConfigAttributeValue -ConfigElement $configCollection -AttributeName "maxFailure"
            LogVerifyNumEq(60000, $maxFailure, "Verify that maxFailure has been set")

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/ipSecurity"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "allowUnlisted" -AttributeValue $False
            $allowUnlisted = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "allowUnlisted"
            LogVerifyFalse($allowUnlisted, "Verify that allowUnlisted is set to false")

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/ipSecurity"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enableReverseDns" -AttributeValue $True
            $reverseDns = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enableReverseDns"
            LogVerifyTrue($reverseDns, "Verify that DNS reverse is set to true")

            $configSection = Get-IISConfigSection -sectionPath "system.ftpServer/security/requestFiltering"
            $beforeAddCount = $configSection.ChildElements["fileExtensions"].count
            $fileExtensionsCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "fileExtensions"
            New-IISConfigCollectionElement -ConfigCollection $fileExtensionsCollection -ConfigAttribute @{"fileExtension" = "*.asp"}
            $addedCount = $configSection.ChildElements["fileExtensions"].count
            LogVerifyNumEq($addedCount, ($beforeAddCount + 1), "OK")

            #App Part
            if(Test-Path -Path $env:homedrive\MySite)
            {
                Remove-Item -Path $env:homedrive\MySite -Recurse -Force
            }
            New-Item -ItemType directory -Path $env:homedrive\MySite -Force
            New-IISSite -Name "MySite" -PhysicalPath "$env:homedrive\MySite" -BindingInformation "*:85:foo12351"
            #Not able to add Application using IISAdministration Module, So use the WebAdministration Module
            New-Item -ItemType directory -Path $env:homedrive\MySite\MyApp -Force
            New-Item -ItemType directory -Path $env:homedrive\MySite\MyDir -Force
            New-WebApplication -Site "MySite" -Name "MyApp" -PhysicalPath "$env:homedrive\MySite\MyApp" -Force
            New-WebVirtualDirectory -Site "MySite" -Name "MyDir" -PhysicalPath "$env:homedrive\MySite\MyDir" -Force
            Reset-IISServerManager -confirm:$false 
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument" -CommitPath "MySite/MyApp"
            $beforeAddCount = $configSection.ChildElements["files"].count
            $filesCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "files"
            New-IISConfigCollectionElement -ConfigCollection $filesCollection -ConfigAttribute @{"Value" = "myDoc.htm"}
            $addedCount = $configSection.ChildElements["files"].count
            LogVerifyNumEq($addedCount, ($beforeAddCount + 1), "OK")
            		
            Reset-IISServerManager -confirm:$false 
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse" -CommitPath "MySite/MyApp"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled" -AttributeValue $true
            $directoryBrowse = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            LogVerifyTrue($directoryBrowse, "verify that directoryBrowse is enabled at application level")

            #Vdir Part
            Reset-IISServerManager -confirm:$false 
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/defaultDocument" -CommitPath "MySite/MyDir"
            $beforeAddCount = $configSection.ChildElements["files"].count
            $filesCollection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "files"
            New-IISConfigCollectionElement -ConfigCollection $filesCollection -ConfigAttribute @{"Value" = "myDoc.htm"}
            $addedCount = $configSection.ChildElements["files"].count
            LogVerifyNumEq($addedCount, ($beforeAddCount + 1), "OK")
            
            Reset-IISServerManager -confirm:$false 
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/directoryBrowse" -CommitPath "MySite/MyDir"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled" -AttributeValue $true
            $directoryBrowse = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "enabled"
            LogVerifyTrue($directoryBrowse, "verify that directoryBrowse is enabled at virtual directory level")
            
            #TH bug #1917687 "When comma separated values are used, flags cannot be set."
            Reset-IISServerManager -confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.webServer/asp"
            $comPlus = Get-IISConfigElement -ConfigElement $configSection -ChildelementName "comPlus"
            Set-IISConfigAttributeValue -ConfigElement $comPlus -AttributeName "appServiceFlags" -AttributeValue "EnableTracker, EnableSxS "
            LogVerifyTrue($?, "No error happened")
            $result = Get-IISConfigAttributeValue -ConfigElement $comPlus -AttributeName "appServiceFlags"
            LogVerifyStrEq("EnableTracker,EnableSxS" ,$result , "Verify the appService Flags is changed")

            # cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest        
    }

    if (LogStartTest("IISAdministration #38 - Confirm updated values when the flag value does not start from 0", 129556) -eq $true)
    {
        if ( IISTest-Ready )
        {
            Copy-Item -Path "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml" -Destination "$g_testDir\scripts\powershell\IISAdministration\Backup.xml" -Force
            $xml = New-Object XML
            $xml.Load("$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml")
            $myNode = $xml.CreateElement("attribute")
            $myNode.SetAttribute("name", "myFlags2")
            $myNode.SetAttribute("type", "flags")
            $myNode.SetAttribute("defaultValue", "Flag00, Flag01, Flag03")
            $exampleFlag = $xml.CreateElement("flag")
            $exampleFlag.SetAttribute("name", "None")
            $exampleFlag.SetAttribute("value", "1")
            $exampleFlag1 = $xml.CreateElement("flag")
            $exampleFlag1.SetAttribute("name", "Flag00")
            $exampleFlag1.SetAttribute("value", "2")
            $exampleFlag2 = $xml.CreateElement("flag")
            $exampleFlag2.SetAttribute("name", "Flag01")
            $exampleFlag2.SetAttribute("value", "4")
            $exampleFlag3 = $xml.CreateElement("flag")
            $exampleFlag3.SetAttribute("name", "Flag02")
            $exampleFlag3.SetAttribute("value", "8")
            $exampleFlag4 = $xml.CreateElement("flag")
            $exampleFlag4.SetAttribute("name", "Flag03")
            $exampleFlag4.SetAttribute("value", "16")
            $myNode.AppendChild($exampleFlag)
            $myNode.AppendChild($exampleFlag1)
            $myNode.AppendChild($exampleFlag2)
            $myNode.AppendChild($exampleFlag3)
            $myNode.AppendChild($exampleFlag4)
            $xml.ConfigSchema.SectionSchema.AppendChild($myNode)
            $xml.Save("$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml")
            
            ## Copy custom schema files to IIS config schema directory
            IISTest-SafeCopy ("$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml") ("$env:SystemRoot\system32\inetsrv\config\schema\IISPSTest_CustomSchema.xml")
            
            ## Register IIS custom schema section
            if ($null -eq (get-WebConfigurationProperty / -name sectionGroups["iispowershell"]))
            {
                add-WebConfigurationProperty / -name SectionGroups -value iispowershell
            }
            if ($null -eq (get-WebConfigurationProperty /iispowershell -name sections["complextest"]))
            {
                add-WebConfigurationProperty /iispowershell -name sections -value complextest
            }

            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "iispowershell/complextest"
            Try
            {
                Set-IISConfigAttributeValue  -ConfigElement $configSection -AttributeName "myFlags2" -AttributeValue ""
            }
            Catch
            {
                $errorMessage = ($error[0] | out-string)                 
                $equal = $errorMessage.Contains("Parameter '' is not a valid flag for attribute")
                LogVerifyTrue($equal, "The error message is expected.")
            }
            $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "myFlags2"
            #LogVerifyStrEq("" , $result, "Verify that the flag field has been set")

            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "iispowershell/complextest"
            Set-IISConfigAttributeValue  -ConfigElement $configSection -AttributeName "myFlags2" -AttributeValue "Flag00, Flag03"
            $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "myFlags2"
            LogVerifyStrEq("Flag00,Flag03", $result, "Verify that the flag field has been set")

            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "iispowershell/complextest"
            Set-IISConfigAttributeValue  -ConfigElement $configSection -AttributeName "myFlags2" -AttributeValue " Flag00,Flag03 "
            $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "myFlags2"
            LogVerifyStrEq("Flag00,Flag03", $result, "Verify that the flag field has been set")

            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "iispowershell/complextest"
            Set-IISConfigAttributeValue  -ConfigElement $configSection -AttributeName "myFlags2" -AttributeValue "Flag00 "
            $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "myFlags2"
            LogVerifyStrEq("Flag00", $result, "Verify that the flag field has been set")

            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "iispowershell/complextest"
            Set-IISConfigAttributeValue  -ConfigElement $configSection -AttributeName "myFlags2" -AttributeValue Flag00
            $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "myFlags2"
            LogVerifyStrEq("Flag00", $result, "Verify that the flag field has been set")

            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "iispowershell/complextest"
            Set-IISConfigAttributeValue  -ConfigElement $configSection -AttributeName "myFlags2" -AttributeValue "None"
            $result = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "myFlags2"
            LogVerifyStrEq("None" ,$result , "Verify that the flag field has been set")

            #cleanup
            IISTest-RestoreAppHostConfig
            Copy-Item -Path "$g_testDir\scripts\powershell\IISAdministration\Backup.xml" -Destination "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml" -Force
            remove-item -Path "$g_testDir\scripts\powershell\IISAdministration\Backup.xml" -Force
            cd iis:\
            IISTEST-SafeDelete ("$env:SystemRoot\system32\inetsrv\config\schema\IISPSTest_CustomSchema.xml")
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
   
    if ( LogStartTest("IISAdministration #40 - Remove-Module iisadministration should refresh the config state",129837 ) -eq $true )
    {
        if ( IISTest-Ready )
        {
            #This is the bug coverage for TH bug #1966842
            #Preparation 
            $error.Clear()
            Reset-IISServerManager -Confirm:$false
            Import-Module IISAdministration
            New-IISSite -Name "demo" -BindingInformation "*:81:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
            Import-Module IISAdministration
            Remove-Website -name demo
            #verify
            Try
            {
               Remove-Module IISAdministration
               Import-module IISAdministration
               New-IISSite -Name "demo" -BindingInformation "*:81:" -PhysicalPath "$env:systemdrive\inetpub\wwwroot"
               $result = Get-IISSite -Name "demo"
               LogVerifyNumEq(1, $result.Count, "Matched new site")

            }
            Catch
            {
               LogVerifyNumEq(0, $error.Count, "Should no Error-handling happened")
            }

            #clean up
            IISTest-RestoreAppHostConfig
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if ( LogStartTest("IISAdministration #41 - Warning message is shown when using Reset-IISServerManager to roll back a transaction",129838 ) -eq $true )
    {
        if ( IISTest-Ready )
        {
           Start-IISCommitDelay
           Reset-IISServerManager -WarningVariable warning -Confirm:$false
           $result = $warning.Item(0).Message.Contains("Active transaction will be aborted")
           LogVerifyTrue($result, "The warning message is expected.") 
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if ( LogStartTest("IISAdministration #42 - Get/Remove-IISConfigCollectionElement support multiple items", 130155 ) -eq $true )
    {
        if ( IISTest-Ready )
        {
            Reset-IISServerManager -Confirm:$false 
            #Execute
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindingsCollection = Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            New-IISConfigCollectionElement -ConfigCollection $bindingsCollection -ConfigAttribute @{protocol="http";bindingInformation="*:85:foo12345"}
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection            
            $site = Get-IISConfigCollectionElement -ConfigCollection $sitesCollection -ConfigAttribute @{Name = "Default Web Site"}
            $bindings =  Get-IISConfigCollection -ConfigElement $site -CollectionName "bindings"
            
            #Verify
            LogVerifyNumEq(2, $bindings.Count, "Two binding element should be found.")

            #Execute 
            Remove-IISConfigCollectionElement -ConfigCollection $bindings -ConfigAttribute @{protocol="http"} -Confirm:$false
            $count = (Get-IISSite -Name "Default Web Site").Bindings.Count
            
            #Verify
            LogVerifyNumEq(0, $count, "should no bindings found")

            #Get/Remove-IISConfigCollectionElement no -ConfigAttribute 
            #Execute 
            $siteCount = (Get-IISSite).Count
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/sites"
            $count = (Get-IISConfigCollection -ConfigElement $configSection).Count
            
            #Verify
            LogVerifyTrue(($siteCount -eq $count), "Verify the site count")
            
            #Execute
            $sitesCollection = Get-IISConfigCollection -ConfigElement $configSection
            Remove-IISConfigCollectionElement -ConfigCollection $sitesCollection -Confirm:$false
            $siteCount = (Get-IISSite).Count
            
            #Verify
            LogVerifyTrue(($siteCount -eq 0), "Verify the site count")
            
            #Clean Up
            IISTest-RestoreAppHostConfig         

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
   
    if (LogStartTest("IISAdministration #43 - Get-IISConfigSection - CommitPath and Location", 130156) -eq $true)
    {
        if ( IISTest-Ready )
        {
            #Setup
            #
            Copy-Item -Path "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml" -Destination "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema_Backup.xml" -Force
            ## Copy custom schema files to IIS config schema directory
            IISTest-SafeCopy ("$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml") ("$env:SystemRoot\system32\inetsrv\config\schema\IISPSTest_CustomSchema.xml")
            
            ## Register IIS custom schema section
            if ($null -eq (get-WebConfigurationProperty / -name sectionGroups["iispowershell"]))
            {
                add-WebConfigurationProperty / -name SectionGroups -value iispowershell
            }
            if ($null -eq (get-WebConfigurationProperty /iispowershell -name sections["complextest"]))
            {
                add-WebConfigurationProperty /iispowershell -name sections -value complextest
            }
                       
            #Execute tests
            #1 Verify sectionpaths
            Reset-IISServerManager -Confirm:$false
            $ConfigSectionPath= (Get-IISConfigSection | Select-Object SectionPath)
            $AppsettinsItem= $ConfigSectionPath.Item(0).SectionPath                                 
            #verify no exception here and section path do not null.
            LogVerifyTrue($?, "No error happened")
            LogVerifyTrue(($null -ne $ConfigSectionPath), "Sectionpath not null");
            LogVerifyTrue(($AppsettinsItem -eq "appSettings"),"Verify a right Sectionpath value here: appSettings");

            #2 Set asp.net attribute of which deepest path on root web.config
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection appSettings
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "file" -AttributeValue "test" 
            $value = Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "file";         
            LogVerifyStrEq("test",$value,"Set asp.net attribute of which deepest path on root web.config success"); 
            
            #3 Use -location
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection appSettings -location "Default Web Site"
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "file" -AttributeValue "location"
            $locationvalue =Get-IISConfigAttributeValue -ConfigElement $section -Attributename "file";            
            LogVerifyStrEq("location",$locationvalue,"User location set vaule correctly");            
            
            #4 Use -CommitPath            
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection appSettings -CommitPath "Default Web Site"
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "file" -AttributeValue "Commit"
            $CommitValue = Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "file";
            
            LogVerifyStrEq("Commit",$CommitValue,"Use CommitPath set vaule correctly");
            
            #5 Use both -CommitPath and -location
            new-item -path  $env:homedrive\inetpub\wwwroot -name TC130156S5 -type directory -Force
            Reset-IISServerManager -confirm:$false
            # Create a test application in defaulte web site.            
            New-WebApplication -Name "test" -Site "Default Web Site" -ApplicationPool "DefaultApppool" -PhysicalPath $env:homedrive\inetpub\wwwroot\TC130156S5
            $section = Get-IISConfigSection appSettings -CommitPath "Default Web Site/test" -Location "foo/bar"
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "file" -AttributeValue "both"
            $BothValue= Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "file";
            
            LogVerifyStrEq("both",$BothValue,"Use CommitPath and Location set vaule correctly");
            Remove-Item -path $env:homedrive\inetpub\wwwroot\TC130156S5 -Force -Recurse
            
            #6 Verify config section which does not exist under site level can't be set from site level which is specified with the commitPath parameter
            Reset-IISServerManager -confirm:$false
            try{
                Get-IISConfigSection "system.applicationHost/webLimits" -CommitPath "Default Web Site" -ErrorVariable errorMessage            
            }
            catch
            {                    
                $msg = $null = $errorMessage.Item(0)
            }
            #verify             
            LogVerifyTrue($msg.Message.Contains("Config section 'system.applicationHost/webLimits' does not exist."), "Config section which does not exist under site level can't be set from site level which is specified with the commitPath parameter")
            

            #7 Verify config section which does not exist under site level can't be set from site level which is specified with the location parameter
            Reset-IISServerManager -confirm:$false
            try{
                Get-IISConfigSection "system.applicationHost/webLimits" -Location "Default Web Site" -ErrorVariable errorMessage            
            }
            catch
            {        
                $msg = $null = $errorMessage.Item(0)
            }
            #verify            
            LogVerifyTrue($msg.Message.Contains("Config section 'system.applicationHost/webLimits' does not exist."), "config section which does not exist under site level can't be set from site level which is specified with the location parameter")

            #8 Verify config section can set in server level 
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection "system.applicationHost/webLimits" 
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "dynamicIdleThreshold" -AttributeValue 1
            $Value = Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "dynamicIdleThreshold"; 
            
            LogVerifyTrue(($Value -eq "1"), "Verify config section can set in server level.")

            #9 Verify a custom config section at sever level
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection "iispowershell/complextest" -Location "Default Web Site"
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "boolTopLevelAttribute" -AttributeValue "false"
            $Value= Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "boolTopLevelAttribute";
            
            LogVerifyFalse($Value,"A custom config section at sever level by location");

            #10 Verify a custom config section with setting -commitPath
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection "iispowershell/complextest" -CommitPath "Default Web Site"
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "boolTopLevelAttribute" -AttributeValue "true"
            $Value= Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "boolTopLevelAttribute";
            
            LogVerifyTrue($Value,"A custom config section at sever level by commitpath");


            #11 Verify a custom config section with setting -Location
            Reset-IISServerManager -confirm:$false
            $section = Get-IISConfigSection "iispowershell/complextest" -Location "Default Web Site/test/foo/bar"
            Set-IISConfigAttributeValue -ConfigElement $section -AttributeName "boolTopLevelAttribute" -AttributeValue "false"
            $Value= Get-IISConfigAttributeValue -ConfigElement $section -AttributeName "boolTopLevelAttribute";
            
            LogVerifyFalse($Value,"A custom config section at sever level by locationPath");

            #12 Verify invalid commit path
            Reset-IISServerManager -confirm:$false
            try
            {          
                Get-IISConfigSection "iispowershell/complextest" -CommitPath "bogus" -ErrorVariable errorMessage                       
            }
            catch
            {            
                $msg = $null = $errorMessage.Item(0)
            }
            #verify
            LogVerifyTrue($msg.Message.Contains("Unrecognized configuration path 'MACHINE/WEBROOT/APPHOST/bogus'"), "Verify invalid commit path")
            
            #cleanup
            IISTest-RestoreAppHostConfig
            Copy-Item -Path "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema_Backup.xml" -Destination "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema.xml" -Force
            remove-item -Path "$g_testDir\scripts\powershell\IISAdministration\IISPSTest_CustomSchema_Backup.xml" -Force
            # we added some lines in root web.config that may casue test issues in other scenarios, so need to restore the file
            IISTest-RestoreRootWebConfig
            cd iis:\
            IISTEST-SafeDelete ("$env:SystemRoot\system32\inetsrv\config\schema\IISPSTest_CustomSchema.xml")
          
            
            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("IISAdministration BVT #44 - Clear-IISConfigCollection", 130472) -eq $true )
    {
        if ( IISTest-Ready )
        {
        
           #1 Try to clear the exist collection, and then verify the result
           
           #Execute
           Reset-IISServerManager -Confirm:$false
           $section = Get-IISConfigSection -SectionPath "system.applicationHost/sites"
           $sites = Get-IISConfigCollection -ConfigElement $section
           Clear-IISConfigCollection -ConfigCollection $sites -Confirm:$false
           
           #Verify
           Get-IISConfigCollectionElement -ConfigCollection $sites -WarningVariable warning
           LogVerifyTrue($warning[0].ToString().Contains("Config collection element does not exist"), "Verify the site element left")
           LogVerifyTrue(((Get-IISSite).count -eq 0),"Verify the sites left")
           
           #Clean UP
           IISTest-RestoreAppHostConfig
                      
           #2 Get-IISConfigCollection | Clear-IISConfigCollection
           #Execute
           Reset-IISServerManager -Confirm:$false
           $section = Get-IISConfigSection -SectionPath "system.applicationHost/sites"
           Get-IISConfigCollection -ConfigElement $section | Clear-IISConfigCollection -Confirm:$false

           #Verify
           Get-IISConfigCollectionElement -ConfigCollection $sites -WarningVariable warning
           LogVerifyTrue($warning[0].ToString().Contains("Config collection element does not exist"), "Verify the site element left")
           LogVerifyTrue(((Get-IISSite).count -eq 0),"Verify the sites left")

           #Clean UP
           IISTest-RestoreAppHostConfig
           
           #3 No -ConfigCollection parameter
           #Execute
           Reset-IISServerManager -Confirm:$false
           $section = Get-IISConfigSection -SectionPath "system.applicationHost/sites"
           $sites = Get-IISConfigCollection -ConfigElement $section
           Clear-IISConfigCollection $sites -Confirm:$false

           #Verify
           Get-IISConfigCollectionElement -ConfigCollection $sites -WarningVariable warning
           LogVerifyTrue($warning[0].ToString().Contains("Config collection element does not exist"), "Verify the site element left")
           LogVerifyTrue(((Get-IISSite).count -eq 0),"Verify the sites left")

           #Clean UP
           IISTest-RestoreAppHostConfig
           
           #4 Clear the locked collection
           #SetUp
           Reset-IISServerManager -Confirm:$false
           $configSection = Get-IISConfigSection -SectionPath system.ftpServer/security/authorization
           $config = Get-IISConfigCollection -ConfigElement $configSection
           New-IISConfigCollectionElement -ConfigCollection $config -ConfigAttribute @{accessType="Allow";roles="test";permissions="Read"}
           
           #Execute           
           $configSection = Get-IISConfigSection -SectionPath system.ftpServer/security/authorization -CommitPath "Default Web Site"
           $config = Get-IISConfigCollection -ConfigElement $configSection
           try
           {
               Clear-IISConfigCollection -ConfigCollection $config -Confirm:$false -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("because another process has locked a portion of the file."), "Verify the locked collection")

           #Clean UP
           $configSection = Get-IISConfigSection -SectionPath system.ftpServer/security/authorization
           $config = Get-IISConfigCollection -ConfigElement $configSection
           Clear-IISConfigCollection -ConfigCollection $config -Confirm:$false
           
           #5 Error-handling
           
           #Execute
           try
           {
               Clear-IISConfigCollection -ConfigCollection $nonexist -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("The argument is null"), "Verify the error message")

           #Execute
           try{
               Clear-IISConfigCollection -ConfigCollection "" -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("Cannot bind parameter"), "Verify the error message")
           
           #Execute
           try
           {
               Clear-IISConfigCollection -ConfigCollection -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("Missing an argument for parameter"), "Verify the error message")
            
           #Clean UP
           IISTest-RestoreAppHostConfig
           
           trap
           {
               LogTestCaseError $_
           }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if ( LogStartTest("IISAdministration BVT #45 - Remove-IISConfigElement", 130473) -eq $true )
    {
        if ( IISTest-Ready )
        {
           #1 Try to remove the existing element, and then verify the result
           
           #Execute
           Reset-IISServerManager -Confirm:$false
           $configSection = Get-IISConfigSection -SectionPath "system.webServer/defaultDocument"
           $element = Get-IISConfigElement -ConfigElement $configSection -ChildElementName "files"
           Remove-IISConfigElement -ConfigElement $element -Confirm:$false

           #Verify
           $configSection = Get-IISConfigSection -SectionPath "system.webServer/defaultDocument"
           LogVerifyTrue(($configSection.ChildElements["files"].count -eq 0),"Verify the elements left")
           
           #Clean UP
           IISTest-RestoreAppHostConfig
           
           #2 Get-IISConfigElement | Remove-IISConfigElement 

           #Execute
           Reset-IISServerManager -Confirm:$false
           $configSection = Get-IISConfigSection -Section "system.webServer/defaultDocument"
           Get-IISConfigElement -ConfigElement $configSection -ChildElementName "files" | Remove-IISConfigElement -Confirm:$false

           #Verify
           $configSection = Get-IISConfigSection -SectionPath "system.webServer/defaultDocument"
           LogVerifyTrue(($configSection.ChildElements["files"].count -eq 0),"Verify the elements left")

           #Clean UP
           IISTest-RestoreAppHostConfig
           
           #3 No -ConfigCollection parameter
           Reset-IISServerManager -Confirm:$false
           $configSection = Get-IISConfigSection -SectionPath "system.webServer/defaultDocument"
           $element = Get-IISConfigElement -ConfigElement $configSection -ChildElementName "files"
           Remove-IISConfigElement  $element -Confirm:$false
           
           #Verify
           $configSection = Get-IISConfigSection -SectionPath "system.webServer/defaultDocument"
           LogVerifyTrue(($configSection.ChildElements["files"].count -eq 0),"Verify the elements left")

           #Clean UP
           IISTest-RestoreAppHostConfig
           
           #4 Error-handling
           
           #Execute
           try
           {
               Remove-IISConfigElement -ConfigElement $null -Confirm:$false -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("The argument is null"), "Verify the error message")

           #Execute
           try
           {
               Remove-IISConfigElement -ConfigElement "" -Confirm:$false -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("Cannot bind parameter"), "Verify the error message")
           
           #Execute
           try
           {
               Remove-IISConfigElement -ConfigElement -Confirm:$false -ErrorVariable errorMessage
           }
           catch
           {
               $errorMessage = $null = $error[0]
           }
           #verify 
           LogVerifyTrue($errorMessage.ToString().Contains("Missing an argument for parameter"), "Verify the error message")
           
           #Clean UP
           IISTest-RestoreAppHostConfig
           
           trap
           {
               LogTestCaseError $_
           }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if (LogStartTest("IISAdministration BVT #46 - Get-IISConfigCollection", 130474) -eq $true)
    {
        if ( IISTest-Ready )
        {    
            #Scenarios1: Normal Scenarios with -collectionName
            Reset-IISServerManager -Confirm:$false            
            #Execute
            $configSection = Get-IISConfigSection system.webServer/defaultDocument
            $collection = Get-IISConfigCollection -ConfigElement $configSection -CollectionName "files"
            $defaultDocumentFiles= Get-IISConfigCollectionElement -ConfigCollection $collection
            $defaultDocumentFileName= Get-IISConfigAttributeValue -ConfigElement $defaultDocumentFiles[0] -AttributeName "value"            
           
            #Verify
            LogVerifyStrEq("Default.htm",$defaultDocumentFileName, "Get-IISConfigCollection with -collectionName works well")
            
            
            #Scenarios2: Verify Normal Scenarios with -collectionName and without -collectionName
            Reset-IISServerManager -confirm:$false
            #Execute
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $collection= Get-IISConfigCollection -ConfigElement $configSection
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{Name = "Default Web Site"}
            $bindings= Get-IISConfigCollection -ConfigElement $sites -CollectionName "bindings"
            $bind =Get-IISConfigCollectionElement -ConfigCollection $bindings
            $SSLFlagsInfo = Get-IISConfigAttributeValue -ConfigElement $bind -AttributeName "sslFlags"

            #Verify
            LogVerifyNumEq(0, $SSLFlagsInfo, "Get-IISConfigCollection with no -collectionName works well.")
            
            #Scenarios3: Verify Get-IISConfigCollection | Get-IISConfigCollectionElement
            Reset-IISServerManager -confirm:$false
            #Execute
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $sites = (Get-IISConfigCollection -ConfigElement $configSection | Get-IISConfigCollectionElement)
            $SitesID = Get-IISConfigAttributeValue -ConfigElement $sites -AttributeName "id"
            
            #Verify
            LogVerifyNumEq(1, $SitesID, "Commands Get-IISConfigCollection | Get-IISConfigCollectionElement works well.")
            
            
            #Scenarios4: Verify Get-IISConfigSection | Get-IISConfigCollection
            Reset-IISServerManager -confirm:$false
            #Execute
            $collection= (Get-IISConfigSection -Sectionpath "system.applicationHost/sites"|Get-IISConfigCollection)
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection
            $State= Get-IISConfigAttributeValue -ConfigElement $sites -AttributeName "state"
            
            #Verify
            LogVerifyTrue(($State -eq "Started"),"Commands Get-IISConfigSection | Get-IISConfigCollection works well")

            
            #Scenarios5: Verify Section ChildElement(Not a collection) used for -collectionName error handler
            Reset-IISServerManager -confirm:$false
            #Execute
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            try
            {
                Get-IISConfigCollection -ConfigElement $configSection -CollectionName "siteDefaults" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Config collection does not exist"), "Section ChildElement(Not a collection) used for -collectionName test")
            
            
            #Scenarios6: Verify NotExist test for -collectionName error handler
            #Execute
            try
            { 
                Get-IISConfigCollection -ConfigElement $configSection -CollectionName "NotExist" -ErrorVariable errorMessage
            }
            catch
            {                    
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Unrecognized element"), "NotExist -collectionName test")
            
            
            #Scenarios7: Verify Empty string -collectionName error handler
            #Execute
            try
            {
                Get-IISConfigCollection -ConfigElement $configSection -CollectionName "" -ErrorVariable errorMessage
            }
            catch
            {
                 $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("The argument is null or empty"), "Empty string -collectionName test")
            
            
            #Scenarios8: Verify Null -collectionName error handler            
            #Execute
            try
            { 
                Get-IISConfigCollection -ConfigElement $configSection -CollectionName $null -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("The argument is null or empty"), "Null -collectionName test")

            
            #Scenarios9: Verify Nothing for -collectionName error handler    
            #Execute
            try
            { 
                $collection= Get-IISConfigCollection -ConfigElement $configSection -CollectionName -ErrorVariable errorMessage
            } 
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Missing an argument for parameter 'CollectionName'"), "Empty -collectionName test")

            
            #Scenarios10:Verify String type -configElement error handler
            Reset-IISServerManager -confirm:$false
            #Execute
            try
            { 
                Get-IISConfigCollection -ConfigElement "system.applicationHost/sites" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Cannot bind parameter 'ConfigElement'"), "String type -configElement test")
            
           
            #Scenarios11: Verify $null  -configElement error handler
            #Execute
            try
            { 
                Get-IISConfigCollection -ConfigElement $null -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Cannot validate argument on parameter 'ConfigElement'"), "Null -configElement test")
            
            
            #Scenarios12: Verify Nothing in -configElement error handler
            #Execute
            try
            { 
                Get-IISConfigCollection -ConfigElement -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Missing an argument for parameter 'ConfigElement'"), "Empty -configElement test")
            
            
            #Scenarios13:  Verify no parmeters name testing            
            Reset-IISServerManager -confirm:$false
            #Execute
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $collection= Get-IISConfigCollection $configSection
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{Name = "Default Web Site"}
            $bindings= Get-IISConfigCollection $sites "bindings"
            $bind =Get-IISConfigCollectionElement -ConfigCollection $bindings
            $SSLFlagsInfo = Get-IISConfigAttributeValue -ConfigElement $bind -AttributeName "sslFlags"

            #Verify
            LogVerifyNumEq(0, $SSLFlagsInfo, "Get-IISConfigCollection without parameters name works well.")


            #Scenarios14:Verify Get-IISConfigCollection | New-IISConfigCollectionElement  and Get-IISConfigCollection | Remove-IISConfigCollectionElement
            #Execute
            #Get Before count
            Reset-IISServerManager -confirm:$false
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $collection= Get-IISConfigCollection -ConfigElement $configSection                                
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{id= "1"}
            $beforeAddCount = $sites.ChildElements["Bindings"].count

            #add a binding for default web site
            Get-IISConfigCollection -ConfigElement $sites -CollectionName "bindings"| New-IISConfigCollectionElement -ConfigAttribute @{protocol="http";bindingInformation="*:85:foo12345"}
            $addedCount= $sites.ChildElements["Bindings"].count

            #Verify
            LogVerifyNumEq($addedCount, ($beforeAddCount + 1), "Added count should be bigger by one")


            #Scenarios15:Remove the new added binding for default website            
            Reset-IISServerManager -confirm:$false
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $collection= Get-IISConfigCollection -ConfigElement $configSection                                
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{id= "1"}
            Get-IISConfigCollection -ConfigElement $sites -CollectionName "bindings"| Remove-IISConfigCollectionElement -ConfigAttribute @{protocol="http";bindingInformation="*:85:foo12345"} -Confirm:$false            

            #Verify
            Reset-IISServerManager -confirm:$false
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $collection= Get-IISConfigCollection -ConfigElement $configSection                                
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{id= "1"}
            $afterRemoval= $sites.ChildElements["Bindings"].count
            
            LogVerifyNumEq($beforeAddCount,$afterRemoval, "After remove new added ones, the number of all bindings should be equal with before")


            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if (LogStartTest("IISAdministration BVT #47 - Remove-IISConfigAttribute", 130475) -eq $true)
    {
        if ( IISTest-Ready )
        {   
            #Scenarios1: Get-IISConfigSection  | Remove-IISConfigAttribute  
            #SetUp a base attribute value
            Reset-IISServerManager -Confirm:$false
            $ConfigSection = Get-IISConfigSection appSettings    
            Set-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName "file" -AttributeValue "Test" 

            #Execute
            Get-IISConfigSection appSettings | Remove-IISConfigAttribute -AttributeName "file"

            #Verify
            $ConfigSection = Get-IISConfigSection appSettings 
            $FileValue = Get-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName "file"
            LogVerifyStrEq("", $FileValue, "File value is empty after removal")
            
            #Scenarios2:Remove private set attribute
            #SetUp
            Reset-IISServerManager -Confirm:$false
            $ConfigSection = Get-IISConfigSection appSettings    
            Set-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName "file" -AttributeValue "Test2"  

            #Execute
            $ConfigSection = Get-IISConfigSection appSettings 
            Remove-IISConfigAttribute -ConfigElement $ConfigSection -AttributeName "file"
            
            #Verify
            Reset-IISServerManager -Confirm:$false 
            $ConfigSection = Get-IISConfigSection appSettings 
            $FileValue = Get-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName "file"
            LogVerifyStrEq("", $FileValue, "File value is empty after removal")

            #Scenarios3: Site level value was removed but server level value should still there
            #SetUp            
            Reset-IISServerManager -Confirm:$false
            $Serversection = Get-IISConfigSection appSettings
            Set-IISConfigAttributeValue -ConfigElement $Serversection -AttributeName "file" -AttributeValue "ServerLevel"            
            $Sitesection = Get-IISConfigSection appSettings -CommitPath "Default Web Site"
            Set-IISConfigAttributeValue -ConfigElement $Sitesection -AttributeName "file" -AttributeValue "SiteLevel" 

            #Execute
            $Sitesection = Get-IISConfigSection appSettings -CommitPath "Default Web Site"
            Remove-IISConfigAttribute -ConfigElement $Sitesection -AttributeName "file"

            #Verify
            $Sitesection = Get-IISConfigSection appSettings -CommitPath "Default Web Site"
            $SiteFileValue = Get-IISConfigAttributeValue -ConfigElement $Sitesection -AttributeName "file"
            LogVerifyStrEq("ServerLevel", $SiteFileValue, "Site level File value is base on server level after sitelevel value was removed")

            $Serversection = Get-IISConfigSection appSettings
            $ServerFileValue = Get-IISConfigAttributeValue -ConfigElement $Serversection -AttributeName "file"
            LogVerifyStrEq("ServerLevel", $ServerFileValue, "Server level file value still in root web config")

            #clearn Up
            $Serversection = Get-IISConfigSection appSettings 
            Remove-IISConfigAttribute -ConfigElement $Serversection -AttributeName "file"

            #Scenarios4:Execute Remove-IISConfigAttribute without -ConfigElement and -AttributeName parameter name 
            #SetUp
            Reset-IISServerManager -Confirm:$false
            $ConfigSection = Get-IISConfigSection appSettings    
            Set-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName "file" -AttributeValue "Test3"  

            #Execute
            $ConfigSection = Get-IISConfigSection appSettings 
            Remove-IISConfigAttribute $ConfigSection "file"
            LogVerifyTrue($?, "No error happened")
            
            #Verify
            Reset-IISServerManager -Confirm:$false 
            $ConfigSection = Get-IISConfigSection appSettings 
            $FileValue = Get-IISConfigAttributeValue -ConfigElement $ConfigSection -AttributeName "file"
            LogVerifyStrEq("", $FileValue, "File value is empty after removal")

            #Scenarios5:Cannot Remove default exists value attribute  in applicationHost
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -Sectionpath "system.applicationHost/sites"
            $collection= Get-IISConfigCollection -ConfigElement $configSection
            $sites =Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{Name = "Default Web Site"}            
            
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement $sites -AttributeName "name" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("The request is not supported"), "Cannot remove default exists value attribute  in applicationHost")

            #Scenarios6: Verify -AttributeName with "NotExist"
            Reset-IISServerManager -Confirm:$false 
            $ConfigSection = Get-IISConfigSection appSettings 

            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement $ConfigSection -AttributeName "NotExist" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Parameter 'NotExist' does not exist"), "Verify -AttributeName with 'NotExist'")

            #Scenarios7: Verify -AttributeName with ""
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement $ConfigSection -AttributeName "" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("The argument is null or empty"), "Verify -AttributeName with ''")

            #Scenarios8: Verify -AttributeName with $Null
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement $ConfigSection -AttributeName $null -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("The argument is null or empty"), "Verify -AttributeName with null")
            
            #Scenarios9: Verify -AttributeName with nothing
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement $ConfigSection -AttributeName -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Missing an argument for parameter 'AttributeName'"), "Verify -AttributeName with nothing")
            
            #Scenarios10: Verify -ConfigElement with string
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement "NoExist" -AttributeName "file" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Cannot bind parameter 'ConfigElement'"), "Verify -ConfigElement with string")

            #Scenarios11: Verify -ConfigElement with nothing
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement -AttributeName "file" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("Missing an argument for parameter 'ConfigElement'"), "Verify -ConfigElement with nothing")

            #Scenarios12: Verify -ConfigElement with null
            try
            {
                #Execute
                Remove-IISConfigAttribute -ConfigElement $null -AttributeName "file" -ErrorVariable errorMessage
            }
            catch
            {        
                $errorMessage = $null = $error[0]
            }
            #verify            
            LogVerifyTrue($errorMessage.ToString().Contains("The argument is null"), "Verify -ConfigElement with null")

            #Cleanup
            IISTest-RestoreAppHostConfig

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }    
    
    if ( LogStartTest("Verify CLR parameter and bitness", 133425) -eq $true)
    {
        if((Get-ItemPropertyValue -Path "hklm:software\microsoft\windows nt\currentversion" -Name "InstallationType") -eq "Server Core")
        {
           # 11/2/2016 Updated by v-sixu, to unblock bvt daily run on servercore, becasue of bug #8400674
           LogPass("Skip this test unless bug #8400674 is fixed.")
        }
        else
        {
            $v2Version = "v2.0.50727"
            $v4Version = "v4.0.30319"
            $netFXRootPath = $null

            # This test suite requires .Net v2.0. Here we make fake .net v2.0 because test machines does not have .net v2.0 by default.    
            LogDebug "Enter making dummy .net v2.0..."    
            $installFakeNetV2 = $false

            $registry =  (get-item HKLM:\Software\Microsoft\.NETFramework)
            $netFXRootPath = $registry.GetValue("InstallRoot")
            $v4Path = dir $netFXRootPath -filter "v4.0.*" | Select-Object -First 1
            LogVerifyTrue(($v4Path -ne $null) , "Verify .Net V4 installed")
            # reset $v4Version if it is not matched to the installed version
            if ($v4Version -ne $v4Path.Name)
            {
                $v4Version = $v4Path.Name
            }

            $v2Path = dir $netFXRootPath -filter "v2.0.*" | Select-Object -First 1
            if ($v2Path -eq $null) 
            {
                new-item ($netFXRootPath + "\" + $v2Version) -type directory
                $installFakeNetV2 = $true
            } 
            else 
            {
                # reset $v2Version if it is not matched to the installed version
                if ($v2Version -ne $v2Path.Name)
                {
                    $v2Version = $v2Path.Name
                }

                # if mscorlib.dll exists, don't need to create fake .Net 2.0 directory
                if ($null -eq  (dir ($netFXRootPath + "\" + $v2Version) -filter mscorlib.dll)) 
                {
                    $installFakeNetV2 = $true
                } 
            }

            if ($installFakeNetV2)
            {
                # remove all files of .net v2.0 directory first
                dir ($netFXRootPath + "\" + $v2Version) -recurse | remove-item -recurse -ErrorAction Continue

                $installFakeNetV2 = $false
                # copy all config files under .Net 4.0 to this .Net 2.0 to make the dummy .net v2.0
                #xcopy ($netFXRootPath + "\" + $v4Version + "\*.*") ($netFXRootPath + "\" + $v2Version) /s /y        

                copy-item ($netFXRootPath + "\" + $v4Version + "\*") ($netFXRootPath + "\" + $v2Version) -force -recurse -verbose  -ErrorAction Continue

                $installFakeNetV2 = $true

                trap
                {
                    # do nothing here
                    continue
                }

            }
            LogDebug "Exit making dummy .net v2.0..."    

            if ( IISTest-Ready )
            {
                # constant variables
                $targetSite = "Default Web Site"
                $targetApp = "Win8IISPSTestApp"
                $targetPhysicalDirectory = ($env:systemdrive+"\inetpub\wwwroot\Win8IISPSTestApp")

                # preparation    
                cd ("iis:\sites\" + $targetSite)           
                remove-item $targetPhysicalDirectory -confirm:$false -recurse 2> $null
                new-item -type directory $targetPhysicalDirectory
                New-WebApplication -site $targetSite -name $targetApp -PhysicalPath $targetPhysicalDirectory
                new-item -type file ($targetPhysicalDirectory + "\file.txt")
                $targetPSPath = ('MACHINE/WEBROOT/APPHOST/' + $targetSite + '/' + $targetApp + '/file.txt')

                # test scenarios                        
                cd iis:\
                Clear-WebConfiguration -pspath machine/webroot -clr v2.0 -filter //appSettings 
                Clear-WebConfiguration -pspath machine/webroot -clr v4.0 -filter //appSettings 
                Clear-WebConfiguration -pspath "iis:\Sites\Default Web Site" -filter //appSettings 

                # configure machine level with different framework version and verify the value on root web.config and on child level such as web sitel
                $parentPSPath = "machine"

                # Update value with $wcm of MWA for .Net v2  
                Reset-IISServerManager -confirm:$false
                $sm = Get-IISServerManager 
                $v2_config_path = join-path $netFXRootPath $v2Version
                $v2_config_path = join-path $v2_config_path "CONFIG"

                # Verify value is empty at first
                $actual = "na"
                $wcm = New-Object -TypeName Microsoft.Web.Administration.WebConfigurationMap -ArgumentList (join-path $v2_config_path "machine.config"),(join-path $v2_config_path "web.config") 
                $config = $sm.GetWebConfiguration($wcm, $null) 
                if ($null -ne $config)
                {
                    $actual = $config.GetSection("appSettings") | Get-IISConfigAttributeValue -AttributeName 'file' 
                }
                else
                {
                    $actual = $null
                }
                LogVerifyStrEq($null, $actual, "Verify value is empty at first")

                # update the empty value to test with IISAdministration cmdlet and verify updated value
                Get-IISConfigSection -SectionPath "appSettings" -CLR 2.0 | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'test'

                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CLR 2.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test", $actual, "update the empty value to test with IISAdministration cmdlet and verify updated value")

                $sm = Get-IISServerManager 
                $config = $sm.GetWebConfiguration($wcm, $null) 
                $config.GetSection("appSettings") | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'test'

                $sm = Get-IISServerManager             
                $config = $sm.GetWebConfiguration($wcm, $null) 
                $actual = $config.GetSection("appSettings") | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test", $actual, "Verify modified value via wcm")

                # update the value to test2 with IISAdministration's MWA and verify the value
                Reset-IISServerManager -confirm:$false
                $sm = Get-IISServerManager 
                $config = $sm.GetWebConfiguration($wcm, $null) 
                $config.GetSection("appSettings") | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'test2'

                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CLR 2.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "update the value to test2 with IISAdministration's MWA and verify the value via IISAdministration")

                Reset-IISServerManager -confirm:$false
                $sm = Get-IISServerManager 
                $config = $sm.GetWebConfiguration($wcm, $null) 
                $actual = "na"
                $actual = $config.GetSection("appSettings") | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "update the value to test2 with IISAdministration's MWA and verify the value via wcm")

                # update value for .Net 4.0 to 4_0 and verify
                $v4_config_path = join-path $netFXRootPath $v4Version
                $v4_config_path = join-path $v4_config_path "CONFIG"
                Reset-IISServerManager -confirm:$false
                $sm = Get-IISServerManager 
                $wcm = New-Object -TypeName Microsoft.Web.Administration.WebConfigurationMap -ArgumentList (join-path $v4_config_path "machine.config"),(join-path $v4_config_path "web.config") 
                $config = $sm.GetWebConfiguration($wcm, $null) 
                $config.GetSection("appSettings") | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue '4_0'

                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "update value for .Net 4.0 to 4_0 and verify with default CLR value, which is 4.0")

                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CLR 4.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "update value for .Net 4.0 to 4_0 and verify with CLR 4.0")

                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CLR 4 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "update value for .Net 4.0 to 4_0 and verify with CLR 4")
            
                Reset-IISServerManager -confirm:$false
                $sm = Get-IISServerManager 
                $config = $sm.GetWebConfiguration($wcm, $null)
                $actual = "na"
                $actual = $config.GetSection("appSettings") | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "update value for .Net 4.0 to 4_0 and verify via MSA")

                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CLR 2 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "verify no change for .Net 2.0")

                # switch .Net runtime to .Net 2.0 and verify from site level
                sleep 1
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "managedRuntimeVersion" -value "v2.0"
            
                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite -Clr 4.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "switch .Net runtime to .Net 2.0 and verify from site level ignoring wrong CLR value")

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite -Clr 2.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "switch .Net runtime to .Net 2.0 and verify from site level with CLR 2.0")

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "switch .Net runtime to .Net 2.0 and verify from site level with default CLR value")

                # switch back .Net runtime to 4.0 and verify again
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "managedRuntimeVersion" -value "v4.0"

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite -Clr 4.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "switch back .Net runtime to 4.0 and verify again")

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite -Clr 2.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "switch back .Net runtime to 4.0 and verify again")

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("4_0", $actual, "switch back .Net runtime to 4.0 and verify again")
            
                # switch to 2.0 again and verify
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "managedRuntimeVersion" -value "v2.0"

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite -Clr 4.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "switch to 2.0 again and verify")

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite -Clr 2.0 | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "switch to 2.0 again and verify")

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                LogVerifyStrEq("test2", $actual, "switch to 2.0 again and verify")

                # add a collection item to root web.config for .Net 2.0
                Reset-IISServerManager -confirm:$false
                Get-IISConfigSection -SectionPath "appSettings" -Clr 2.0 | Get-IISConfigCollection | New-IISConfigCollectionElement -ConfigAttribute @{key="k2.0";value="v2.0"}
            
                # add anoter collection item to root web.config for .Net 2.0
                Reset-IISServerManager -confirm:$false
                Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection | New-IISConfigCollectionElement -ConfigAttribute @{assembly='a2_0'}
            
                # add a collection item to root web.config for .Net 4.0
                Reset-IISServerManager -confirm:$false
                Get-IISConfigSection -SectionPath "appSettings" | Get-IISConfigCollection | New-IISConfigCollectionElement -ConfigAttribute @{key="k4.0";value="v4.0"}

                # add anoter collection item to root web.config for .Net 4.0
                Reset-IISServerManager -confirm:$false
                Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 4.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection | New-IISConfigCollectionElement -ConfigAttribute @{assembly='a4_0'}

                Reset-IISServerManager -confirm:$false
                Get-IISConfigSection -SectionPath "appSettings" | Get-IISConfigCollection | New-IISConfigCollectionElement -ConfigAttribute @{key="k4.0_2";value="v4.0_2"}

                # verify collections from child level
                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigCollection
                LogVerifyStrEq("1", $actual.count.ToString(), "Verify collection element for .Net 2.0")
                LogVerifyStrEq("k2.0", $actual[0].Attributes["key"].Value, "Verify collection element for .Net 2.0")
                LogVerifyStrEq("v2.0", $actual[0].Attributes["value"].Value, "Verify collection element for .Net 2.0")
            
                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $collection = "na"
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $actual = $collection | Select-Object -Last 1
                LogVerifyStrEq("a2_0", $actual.Attributes["assembly"].Value, "Verify collection element for .Net 2.0")
            
                $actual = "na"
                $collection = "na"
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -CommitPath $targetsite | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $actual = $collection | Select-Object -Last 1
                LogVerifyStrEq("a2_0", $actual.Attributes["assembly"].Value, "Verify collection element for .Net 2.0")

                # change .Net runtime of DefaultAppPool to 4.0 and verify from site level            
                Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "managedRuntimeVersion" -value "v4.0"

                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigCollection
                LogVerifyStrEq("2", $actual.count.ToString(), "Verify collection element")
                LogVerifyStrEq("k4.0", $actual[0].Attributes["key"].Value, "Verify collection element for .Net 4.0")
                LogVerifyStrEq("v4.0", $actual[0].Attributes["value"].Value, "Verify collection element for .Net 4.0")
                LogVerifyStrEq("k4.0_2", $actual[1].Attributes["key"].Value, "Verify collection element for .Net 4.0")
                LogVerifyStrEq("v4.0_2", $actual[1].Attributes["value"].Value, "Verify collection element for .Net 4.0")
            
                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $collection = "na"
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 4.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $actual = $collection | Select-Object -Last 1
                LogVerifyStrEq("a4_0", $actual.Attributes["assembly"].Value, "Verify collection element for .Net 4.0")
            
                $actual = "na"
                $collection = "na"
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -CommitPath $targetsite | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $actual = $collection | Select-Object -Last 1
                LogVerifyStrEq("a4_0", $actual.Attributes["assembly"].Value, "Verify collection element for .Net 4.0")

                # verify removing the collection item
                $collection = "na"
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $old_collectionCounter = 0
                $old_collectionCounter = $collection.Count
            
                # initialize $tempCollection
                $tempCollection = "na"
                $tempCollection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection
            
                # check the collection item can be obtained via a collection variable before removing it
                $actual = "na"
                $actual = Get-IISConfigCollectionElement -ConfigCollection $tempCollection -ConfigAttribute @{assembly='a2_0'}          
                LogVerifyStrEq("a2_0", $actual.Attributes["assembly"].Value, "check the collection item can be obtained via a collection variable before removing it")
            
                # Remove collection element using pipeline without using $tempCollection
                Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection | Remove-IISConfigCollectionElement -ConfigAttribute @{assembly='a2_0'} -Confirm:$false 

                # check the collection item is shown as removed via a collection variable after removing it
                $actual = "na"
                $tempCollection = "na"
                $tempCollection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection            
                $actual = Get-IISConfigCollectionElement -ConfigCollection $tempCollection -ConfigAttribute @{assembly='a2_0'}
                LogVerifyStrEq($null, $actual, "check the collection item is shown as removed via a collection variable after removing it")
            
                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $collection = "na"
                $collectionCounter = -1
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 2.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $collectionCounter = $collection.Count
                $actual = $collection | Select-Object -Last 1
                LogVerifyNumEq(($collectionCounter + 1), $old_collectionCounter, "Verify collection element removed for .Net 2.0")
                LogVerifyStrNotEq("a2_0", $actual.Attributes["assembly"].Value, "Verify collection element removed for .Net 2.0")

                $collection = "na"
                $old_collectionCounter = 0
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 4.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $old_collectionCounter = $collection.Count
            
                # initialize $tempCollection
                $tempCollection = "na"
                $tempCollection = Get-IISConfigSection -SectionPath "system.web/compilation" -Clr 4.0 | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection
            
                # check the collection item can be obtained via a collection variable before removing it
                $actual = "na"
                $actual = Get-IISConfigCollectionElement -ConfigCollection $tempCollection -ConfigAttribute @{assembly='a4_0'}          
                LogVerifyStrEq("a4_0", $actual.Attributes["assembly"].Value, "check the collection item can be obtained via a collection variable before removing it")
            
                # Remove collection element using a collection variable
                Remove-IISConfigCollectionElement -ConfigCollection $tempCollection -ConfigAttribute @{assembly='a4_0'} -Confirm:$false
            
                # check the collection item is shown as removed via a collection variable after removing it
                $actual = "na"
                $actual = Get-IISConfigCollectionElement -ConfigCollection $tempCollection -ConfigAttribute @{assembly='a4_0'}          
                LogVerifyStrEq($null, $actual, "check the collection item is shown as removed via a collection variable after removing it")
            
                Reset-IISServerManager -confirm:$false
                $actual = "na"
                $collection = "na"
                $collection = Get-IISConfigSection -SectionPath "system.web/compilation" -CommitPath $targetsite | Get-IISConfigElement -ChildElementName assemblies | Get-IISConfigCollection 
                $collectionCounter = $collection.Count
                $actual = $collection | Select-Object -Last 1
                LogVerifyNumEq(($collectionCounter + 1), $old_collectionCounter, "Verify collection element removed for .Net 4.0")
                LogVerifyStrNotEq("a4_0", $actual.Attributes["assembly"].Value, "Verify collection element removed for .Net 4.0")

                $wow64Exists = test-path 'Env:\ProgramFiles(x86)'
                & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 4.0 | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'Net4 32bit' "

                if ( $wow64Exists )
                {
                    # backup old executionpolicy for 32bit mode
                    $oldExecutionPolicy = & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "Get-ExecutionPolicy"                    
                    & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "Set-ExecutionPolicy Unrestricted -Force"
                    
                    # configure test data on 64bit/32bit root web.config files
                    & ("$env:windir\system32\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 4.0 | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'Net4 64bit' "
                    & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 4.0 | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'Net4 32bit' "
                    & ("$env:windir\system32\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 2.0 | Set-IISConfigAttributeValue -AttributeName 'file' -AttributeValue 'Net2 64bit' "

                    # switch bitness to 64 bit 
                    sleep 1
                    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "enable32BitAppOnWin64" -value "False"

                    # switch .Net runtime to 2.0 
                    sleep 1
                    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "managedRuntimeVersion" -value "v2.0"

                    Reset-IISServerManager -confirm:$false
                    $actual = "na"
                    $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                    LogVerifyStrEq("Net2 64bit", $actual, "switch bitness to 64 bit with .Net 2.0")

                    # switch .Net runtime to 4.0 
                    sleep 1
                    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "managedRuntimeVersion" -value "v4.0"

                    Reset-IISServerManager -confirm:$false
                    $actual = "na"
                    $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                    LogVerifyStrEq("Net4 64bit", $actual, "switch bitness to 64 bit with .Net 4.0")

                    # switch bitness to 32 bit 
                    sleep 1
                    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "enable32BitAppOnWin64" -value "True"

                    Reset-IISServerManager -confirm:$false
                    $actual = "na"
                    $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                    LogVerifyStrEq("Net4 32bit", $actual, "switch bitness to 32 bit with .Net 4.0")
            
                    # switch bitness back to 64 bit 
                    sleep 1
                    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']" -name "enable32BitAppOnWin64" -value "False"

                    Reset-IISServerManager -confirm:$false
                    $actual = "na"
                    $actual = Get-IISConfigSection -SectionPath "appSettings" -CommitPath $targetsite | Get-IISConfigAttributeValue -AttributeName 'file' 
                    LogVerifyStrEq("Net4 64bit", $actual, "switch bitness back to 64 bit")
            
                    # clean up test data
                    & ("$env:windir\system32\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 4.0 | Remove-IISConfigAttribute -AttributeName 'file' "
                    & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 4.0 | Remove-IISConfigAttribute -AttributeName 'file' "
                    & ("$env:windir\system32\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "import-module iisadministration; Get-IISConfigSection -SectionPath "appSettings" -Clr 2.0 | Remove-IISConfigAttribute -AttributeName 'file' "
                    
                    # rollback old executionpolicy for 32bit mode
                    $oldExecutionPolicy = & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command "Get-ExecutionPolicy"                    
                    & ("$env:windir\syswow64\WindowsPowerShell\v1.0\PowerShell.exe" ) -command ("Set-ExecutionPolicy " + $oldExecutionPolicy + " -Force")
                    trap
                    {
                        LogTestCaseError $_ $exceptionExpected
                    }    
                }
        
                # clean up test data
                Sleep 1
                Clear-WebConfiguration -pspath $parentPSPath -clr v2.0 -filter //appSettings 
                Clear-WebConfiguration -pspath $parentPSPath -clr v4.0 -filter //appSettings 
                Clear-WebConfiguration -pspath "iis:\Sites\Default Web Site" -filter //appSettings 

                # verify warning messages
                if ((Get-Culture).Name.ToLower() -eq "en-us")
                {
                    $exceptionExpected = $true
                    $Error.Clear(); $ErrorMsg = ""
                    Get-IISConfigSection -SectionPath "appSettings" -Clr bogus -WarningAction stop
                    $ErrorMsg = $Error[0].ToString()
                    $BoolReturn=$ErrorMsg.Contains("Unable to get the web configuration map for the 'Clr' version")
                    LogVerifyTrue($BoolReturn, "Verify Warnig Message against not existing clr value bogus")
                
                    $Error.Clear(); $ErrorMsg = ""
                    Get-IISConfigSection -SectionPath "appSettings" -Clr 20 -WarningAction stop                
                    $ErrorMsg = $Error[0].ToString()
                    $BoolReturn=$ErrorMsg.Contains("Unable to get the web configuration map for the 'Clr' version")
                    LogVerifyTrue($BoolReturn, "Verify Warnig Message against not existing clr value 20")

                    $Error.Clear(); $ErrorMsg = ""
                    Get-IISConfigSection -SectionPath "appSettings" -Clr 4.0 -CommitPath $targetSite -WarningAction stop
                    $ErrorMsg = $Error[0].ToString()
                    $BoolReturn=$ErrorMsg.Contains("The parameter 'Clr' is ignored because a CommitPath is set.")
                    LogVerifyTrue($BoolReturn, "Verify Warnig Message against invalid clr parameter value from non root level")
                
                    $Error.Clear(); $ErrorMsg = ""
                    Get-IISConfigSection -SectionPath "appSettings" -Clr $null -ErrorAction Continue
                    $ErrorMsg = $Error[0].ToString()
                    $BoolReturn=$ErrorMsg.Contains("The argument is null or empty.")
                    LogVerifyTrue($BoolReturn, "Verify Error Message against null value of clr parameter")
                
                    $Error.Clear(); $ErrorMsg = ""
                    Get-IISConfigSection -SectionPath "appSettings" -Clr "" -ErrorAction Continue 
                    $ErrorMsg = $Error[0].ToString()
                    $BoolReturn=$ErrorMsg.Contains("The argument is null or empty.")
                    LogVerifyTrue($BoolReturn, "Verify Error Message against empty string value of clr parameter")
                    $exceptionExpected = $false

                    trap
                    {
                        LogTestCaseError $_ $exceptionExpected
                    }
                }

                # cleanup
                Remove-WebApplication -site $targetSite -name $targetApp
                remove-item $targetPhysicalDirectory -confirm:$false -recurse
            
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }
            else
            {       
                LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
            }

            #
            # cleanup
            #
            LogDebug "Enter Cleanup test environment..."
            if ($installFakeNetV2)
            {
                # remove all files of .net v2.0 directory
                dir ($netFXRootPath + "\" + $v2Version) -recurse | remove-item -recurse -ErrorAction Continue

                trap
                {
                    # do nothing here
                    continue
                }
            }
            LogDebug "Exit Cleanup test environment..."
        }

        LogEndTest
    }

    if ( LogStartTest("Verify IISCentralCertProvider cmdlets", 133454) -eq $true)
    {
        if ( IISTest-Ready )
        {
            # test scenarios                        
            $username = ($global:g_testEnv.IISTestAdminUser)
            $unsecuredPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:g_testEnv.IISTestAdminPassword))
            $securedPassword = $global:g_testEnv.IISTestAdminPassword
            $keyPassword = convertto-securestring "xxx" -asplaintext -force
            $bogusPassword = convertto-securestring "bogus" -asplaintext -force
            
            LogComment("verify after disabling with IISAdministration")
            Disable-IISCentralCertProvider
            $result1 = get-webcentralcertprovider
            $result2 = get-iiscentralcertprovider
            LogVerifyNumEq($result1.Count, $result2.Count, "verify after disabling with IISAdministration")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
            }
            
            LogComment("verify after enabling with IISAdministration")
            Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
            $iis = "na2"
            $iis = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            # verify get after enabling
            $result1 = get-webcentralcertprovider
            $result2 = get-iiscentralcertprovider
            LogVerifyNumEq($result1.Count, $result2.Count, "verify after enabling with IISAdministration")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                if (-not ($result2[$i].Contains("**")))
                {
                    LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                }
            }

            LogComment("verify after disabling with WebAdministration")
            Disable-WebCentralCertProvider
            $result1 = get-webcentralcertprovider
            $result2 = get-iiscentralcertprovider
            LogVerifyNumEq($result1.Count, $result2.Count, "verify after disabling with WebAdministration")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                if (-not ($result2[$i].Contains("**")))
                {
                    LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                }
            }

            Enable-WebCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
            $web = "na"
            $web = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider

            LogComment("verify after enabling with WebAdministration")
            $result1 = get-webcentralcertprovider
            $result2 = get-iiscentralcertprovider
            LogVerifyNumEq($result1.Count, $result2.Count, "verify after enabling with WebAdministration")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                if (-not ($result2[$i].Contains("**")))
                {
                    LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                }
            }

            LogComment("Verify registry key values with comparing the result between IISAdministration and WebAdministration")
            for ($i=0; $i-lt $web.Property.count; $i++) 
            { 
                LogVerifyStrEq($web.GetValue($web.Property[$i]).ToString(), $iis.GetValue($iis.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $web.GetValue($web.Property[$i]).ToString()))
            }
        
            LogComment("Verify Clear-IISCentralCertProvider")
            Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword           
          
            if ((get-command Clear-IISCentralCertProvider).Parameters.Keys.Contains("Force"))
            {
                ("Force parameter mode")
                if ((Get-Culture).Name.ToLower() -eq "en-us")
                {
                    # initialize $exceptionExpected
                    $exceptionExpected = $true

                    $Error.Clear(); $ErrorMsg = ""                
                    Clear-IISCentralCertProvider
                    $ErrorMsg = $Error[0].ToString()
                    $BoolReturn=$ErrorMsg.Contains("Disable-IISCentralCertProvider")
                    LogVerifyTrue($BoolReturn, "Clear-IISCentralCertProvider: Central Certificate Provider is enabled.")

                    # cleanup $exceptionExpected
                    $exceptionExpected = $false

                    trap
                    {
                        LogTestCaseError $_ $exceptionExpected
                    }
                }

                Disable-IISCentralCertProvider
                Clear-IISCentralCertProvider 
                
                # Verify get-iiscentralcertprovider shows updated result
                $result1 = get-webcentralcertprovider
                $result2 = get-iiscentralcertprovider
                LogVerifyNumEq($result1.Count, $result2.Count, "Verify Clear-IISCentralCertProvider")
                for ($i=0; $i-lt $result1.count; $i++) 
                { 
                    if (-not ($result2[$i].Contains("**")))
                    {
                        LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                    }
                }

                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword           
                Clear-IISCentralCertProvider -Force
                $result2 = get-iiscentralcertprovider
                LogVerifyNumEq($result1.Count, $result2.Count, "Verify Clear-IISCentralCertProvider")
                for ($i=0; $i-lt $result1.count; $i++) 
                { 
                    if (-not ($result2[$i].Contains("**")))
                    {
                        LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                    }
                }
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword           
            }
            else
            {
                Clear-IISCentralCertProvider -PrivateKeyPassword 
                $iis = "na2"
                $iis = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
                Clear-WebCentralCertProvider -PrivateKeyPassword 
                $web = "na"
                $web = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            
                # Verify registry key values between IISAdministration and WebAdministration
                for ($i=0; $i-lt $web.Property.count; $i++) 
                { 
                    LogVerifyStrEq($web.GetValue($web.Property[$i]).ToString(), $iis.GetValue($iis.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $web.GetValue($web.Property[$i]).ToString()))
                }

                # Verify get-iiscentralcertprovider shows updated result
                $result1 = get-webcentralcertprovider
                $result2 = get-iiscentralcertprovider
                LogVerifyNumEq($result1.Count, $result2.Count, "Verify Clear-IISCentralCertProvider")
                for ($i=0; $i-lt $result1.count; $i++) 
                { 
                    if (-not ($result2[$i].Contains("**")))
                    {
                        LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                    }
                }
            }
            
            LogComment("Verify Set-IISCentralCertProvider")
            $properties = $web.Property            
            Set-WebCentralCertProvider -UserName $username -Password $unsecuredPassword -PrivateKeyPassword xxx -CertStoreLocation "$env:systemdrive\inetpub"
            $web = "na"
            $web = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            
            Set-IISCentralCertProvider -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword -CertStoreLocation "$env:systemdrive\inetpub"
            $iis = "na2"
            $iis = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider

            #Verify registry key values between IISAdministration and WebAdministration
            for ($i=0; $i-lt $web.Property.count; $i++) 
            { 
                LogVerifyStrEq($web.GetValue($web.Property[$i]).ToString(), $iis.GetValue($iis.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $web.GetValue($web.Property[$i]).ToString()))
            }

            # Verify get-iiscentralcertprovider shows updated result
            $result1 = get-webcentralcertprovider
            $result2 = get-iiscentralcertprovider
            LogVerifyNumEq($result1.Count, $result2.Count, "Verify Set-IISCentralCertProvider")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                if (-not ($result2[$i].Contains("**")))
                {
                    LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                }
            }

            # Verify get-iiscentralcertprovider shows updated result
            $result1 = get-webcentralcertprovider
            $result2 = get-iiscentralcertprovider
            LogVerifyNumEq($result1.Count, $result2.Count, "Verify size of get command's result")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                if (-not ($result2[$i].Contains("**")))
                {
                    LogVerifyStrEq($result1[$i], $result2[$i], ("Verify value of get command: " + $result1[$i]))
                }
            }

            LogComment("verify error messages")
            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $exceptionExpected = $true

                $Error.Clear(); $ErrorMsg = ""                
                Disable-WebCentralCertProvider
                LogVerifyTrue(($Error[0] -eq $null), "Initially there should be no error")

                $Error.Clear(); $ErrorMsg = ""                
                Disable-WebCentralCertProvider
                LogVerifyTrue(($Error[0] -eq $null), "Initially there should be no error with retrial")

                #########################################
                # Enable-IISCentralCertProvider test scenarios
                #########################################
                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation $null -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword 2> $null
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("CertStoreLocation")
                LogVerifyTrue($BoolReturn, "Enable-IISCentralCertProvider: Verify error message of wrong CertStoreLocation")

                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\notexistingIISCertCent" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("should point to an existing path.")
                LogVerifyTrue($BoolReturn, "Enable-IISCentralCertProvider: Verify error message of not existing CertStoreLocation")

                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $null -Password $securedPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("UserName")
                LogVerifyTrue($BoolReturn, "Enable-IISCentralCertProvider: Verify error message of null username")

                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $bogusPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Credential is invalid.")
                LogVerifyTrue($BoolReturn, "Enable-IISCentralCertProvider: Verify error message of wrong Password")

                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $null
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("PrivateKeyPassword")
                LogVerifyTrue($BoolReturn, "Enable-IISCentralCertProvider: Verify error message of null privatekeypassword")

                #########################################
                # Set-IISCentralCertProvider test scenarios
                #########################################
                $Error.Clear(); $ErrorMsg = ""                
                Disable-WebCentralCertProvider
                LogVerifyTrue(($Error[0] -eq $null), "Initially there should be no error")

                $Error.Clear(); $ErrorMsg = ""
                Set-IISCentralCertProvider -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Central Certificate Provider is disabled.")
                LogVerifyTrue($BoolReturn, "Verify error message when feature is disabled")
                
                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
                LogVerifyTrue(($Error[0] -eq $null), "There should be no error")

                $Error.Clear(); $ErrorMsg = ""                
                Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
                LogVerifyTrue(($Error[0] -eq $null), "There should be no error with retrial")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -UserName $username -Password $bogusPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Credential is invalid")
                LogVerifyTrue($BoolReturn, "Verify error message of wrong password")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -UserName $username -Password $null -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Password")
                LogVerifyTrue($BoolReturn, "Verify error message of null password")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -UserName bogus -Password $bogusPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Credential is invalid")
                LogVerifyTrue($BoolReturn, "Verify error message of not existing user")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -UserName $null -Password $securedPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("UserName")
                LogVerifyTrue($BoolReturn, "Verify error message of null username")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -Password $securedPassword -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Either UserName or Password was missing.")
                LogVerifyTrue($BoolReturn, "Verify error message of missing username")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -UserName $userName -PrivateKeyPassword $keyPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Either UserName or Password was missing.")
                LogVerifyTrue($BoolReturn, "Verify error message of missing password")

                $Error.Clear(); $ErrorMsg = ""                
                Set-IISCentralCertProvider -CertStoreLocation c:\bogus_notexisting
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("should point to an existing path")
                LogVerifyTrue($BoolReturn, "Verify error message of wrong path")

                $Error.Clear(); $ErrorMsg = ""
                Set-IISCentralCertProvider -CertStoreLocation $null
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Cannot validate argument on parameter 'CertStoreLocation'. The argument is null or empty.")
                LogVerifyTrue($BoolReturn, "Verify error message of null CertStoreLocation")

                $Error.Clear(); $ErrorMsg = ""
                Set-IISCentralCertProvider -PrivateKeyPassword $null -CertStoreLocation c:\bogus_notexisting
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Cannot validate argument on parameter 'PrivateKeyPassword'. The argument is null.")
                LogVerifyTrue($BoolReturn, "Verify error message of null PrivateKeyPassword")

                # cleanup $exceptionExpected
                $exceptionExpected = $false

                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }

            # cleanup
            Disable-WebCentralCertProvider
            
            trap
            {
                LogTestCaseError $_ $exceptionExpected
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("Verify AddAt parameter", 133456) -eq $true)
    {
        if ( IISTest-Ready )
        {
            # test scenarios                        

            # cleanup before testing
            Remove-WebConfigurationProperty  -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/oneToOneMappings" -name "."

            # add collection item with using -AddAt 0 parameter 
            Reset-IISServerManager -Confirm:$false
            Start-IISCommitDelay
            (1..100) | foreach {
                $config = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication"
                $collection = Get-IISConfigCollection -ConfigElement $config -CollectionName "oneToOneMappings"
                $value = "test" + $psitem
                if ($psitem % 2 -eq 0)
                {
                    New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{userName=$value;password=$value;certificate=$value} -AddAt 0
                }
                else
                {
                    New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{userName=$value;password=$value;certificate=$value} 
                }
            }

            # add collection item with using -AddAt 100 parameter 
            (101..201) | foreach {
                $config = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication"
                $collection = Get-IISConfigCollection -ConfigElement $config -CollectionName "oneToOneMappings"
                $value = "test" + $psitem
                New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{userName=$value;password=$value;certificate=$value}  -AddAt 100
            }
            Stop-IISCommitDelay

            $result1 = "na"
            $result1 = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" | Get-IISConfigCollection -CollectionName "oneToOneMappings"
            
            # do the same thing with webadministration commands
            Remove-WebConfigurationProperty  -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/oneToOneMappings" -name "."
            Start-WebCommitDelay
            (1..100) | foreach {
                $config = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication"
                $collection = Get-IISConfigCollection -ConfigElement $config -CollectionName "oneToOneMappings"
                $value = "test" + $psitem
                if ($psitem % 2 -eq 0)
                {
                    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/oneToOneMappings" -name "." -value @{userName=$value;password=$value;certificate=$value} -AtIndex 0
                }
                else
                {
                    Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/oneToOneMappings" -name "." -value @{userName=$value;password=$value;certificate=$value} 
                }
            }

            (101..201) | foreach {
                $config = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication"
                $collection = Get-IISConfigCollection -ConfigElement $config -CollectionName "oneToOneMappings"
                $value = "test" + $psitem
                Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Default Web Site' -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/oneToOneMappings" -name "." -value @{userName=$value;password=$value;certificate=$value} -AtIndex 100 
            }
            Stop-WebCommitDelay

            $result2 = "na"
            $result2 = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" | Get-IISConfigCollection -CollectionName "oneToOneMappings"

            # compare the test result is identical between IISAdministration and WebAdministration
            LogVerifyNumEq($result1.Count, $result2.Count, "Verify size of get command's result")
            for ($i=0; $i-lt $result1.count; $i++) 
            { 
                LogVerifyStrEq($result1[$i].Attributes["userName"].Value, $result2[$i].Attributes["userName"].Value, ("Verify value of collection item: " + $result1[$i].Attributes["userName"].Value))
            }
            
            # verify error messages
            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                $config = Get-IISConfigSection -Location "Default Web Site" -SectionPath "system.webServer/security/authentication/iisClientCertificateMappingAuthentication"
                $collection = Get-IISConfigCollection -ConfigElement $config -CollectionName "oneToOneMappings"
                
                # initialize $exceptionExpected
                $exceptionExpected = $true

                $Error.Clear(); $ErrorMsg = ""                
                New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{userName='negative';password='negative';certificate='negative'}  -AddAt -1
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot convert value "-1" to type "System.UInt32"')
                LogVerifyTrue($BoolReturn, "Verify -1")
                    
                $Error.Clear(); $ErrorMsg = ""                
                New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{userName='negative';password='negative';certificate='negative'}  -AddAt bogus
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot convert value "bogus" to type "System.UInt32"')
                LogVerifyTrue($BoolReturn, "Verify bogus")
                               
                $Error.Clear(); $ErrorMsg = ""                
                New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{userName='negative';password='negative';certificate='negative'}  -AddAt $null
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("AddAt")
                LogVerifyTrue($BoolReturn, "Verify null")
                
                # clean up $exceptionExpected                
                $exceptionExpected = $false
                                           
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }

            # cleanup
            Reset-IISServerManager -Confirm:$false
            $sm = Get-IISServerManager
            $appHost = $sm.GetApplicationHostConfiguration()
            $appHost.RemoveLocationPath("Default Web Site")
            $sm.CommitChanges()
            
            trap
            {
                LogTestCaseError $_ $exceptionExpected
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("Verify CNG Encryption", 133461) -eq $true)
    {
        if ( IISTest-Ready )
        {
            LogComment("START: Initialize")
            Reset-IISServerManager -Confirm:$false

            $section = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools 
            LogVerifyTrue($section, ("seciton is not null"))

            $collectionElement = $section | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} 
            LogVerifyTrue($collectionElement, ("collectionElement is not null"))

            $configElement = $collectionElement | Get-IISConfigElement -ChildElementName processModel  
            LogVerifyTrue($configElement, ("configElement is not null"))

            $attribute = $configElement | Get-IISConfigAttributeValue -AttributeName password
            if ($attribute)
            {
                $configElement | Remove-IISConfigAttribute -AttributeName password
            }

            $attribute = $configElement | Get-IISConfigAttributeValue -AttributeName password
            LogVerifyFalse($attribute, ("attribute is removed"))

            Reset-IISServerManager -Confirm:$false
            LogComment("End")
            
            # test scenarios                        

            LogComment("Verify old IISPowershell provider works with the new security provider of CNG")
            [byte[]] $byteArray = 64, 216, 0, 220, 64, 216, 1, 220, 64, 216, 3, 220, 64, 216, 4, 220, 64, 216, 5, 220
            $FourBytesUnicodeSampleString = [System.Text.Encoding]::Unicode.GetString($byteArray)
            
            Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue ""
            Reset-IISServerManager -Confirm:$false
            $result = "na"                
            (1..5) | foreach {
                $t = $_
                $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
                if ($result -ne "")
                {
                    LogComment("Try again...")            
                    if ($_ -eq 1)
                    {
                        Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue ""            
                        Reset-IISServerManager -Confirm:$false
                    }
                    Sleep 1
                }
            }

            # for some reasons, there is null reference object error happened here, which seems to be a side-effect of a certain test issue
            $exceptionHappenedForInitialSetting = $false            
            $newValue = $FourBytesUnicodeSampleString
            try
            {
               Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" -value $newValue
            }
            catch 
            {
                $exceptionHappenedForInitialSetting = $true
            }
            (1..5) | foreach {
                if ($exceptionHappenedForInitialSetting)
                {
                    sleep 2
                    ("Try again...")
                    $exceptionHappenedForInitialSetting = $false            
                    try
                    {
                        Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" -value $newValue
                    }
                    catch 
                    {
                        $exceptionHappenedForInitialSetting = $true
                    }
                }
            }
            LogVerifyFalse($exceptionHappenedForInitialSetting, ("Verify there is no exception error"))

            $result = $result2 = "na"            
            Reset-IISServerManager -Confirm:$false
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password

            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password"
            LogVerifyStrEq($newValue, $result, ("webadministration: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("webadministration: verify value is matched to " + $newValue))
            
            LogComment("Set a new value with iisadministration and verify value is updated correctly")
            Reset-IISServerManager -Confirm:$false
            $newValue = $FourBytesUnicodeSampleString + "abcXYZ123@!?"
            Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" 
            LogVerifyStrEq($newValue, $result, ("modify: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("modify: verify value is matched to " + $newValue))
            
            LogComment("Set empty string and verify value is updated correctly")
            $newValue = ""
            Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue $newValue            
            $result = $result2 = "na"
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" 
            LogVerifyStrEq($newValue, $result, ("empty: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("empty: verify value is matched to " + $newValue))
            
            LogComment("Cleanup")
            Reset-IISServerManager -Confirm:$false
            Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Remove-IISConfigAttribute -AttributeName password
            Reset-IISServerManager -Confirm:$false
            
            LogComment("Set up custom schema with old security providers: AesProvider, IISWASOnlyAesProvider")
            $testSchemaFilepath = join-path $env:windir "system32\inetsrv\config\schema\CNGTest_schema.xml"
            if (Test-Path $testSchemaFilepath)
            {
                Remove-Item $testSchemaFilepath -Force -Confirm:$false
            }
            New-Item $testSchemaFilepath -ItemType file -Value '<configSchema><sectionSchema name="iispowershell/cngtest"><attribute name="attribute1" type="string" encrypted="true" defaultValue="[enc:AesProvider::enc]"/><attribute name="attribute2" type="string" encrypted="true" defaultValue="[enc:IISWASOnlyAesProvider::enc]"/></sectionSchema></configSchema>'

            LogComment("Register the custom schema section")
            if ($null -eq (get-WebConfigurationProperty / -name sectionGroups["iispowershell"]))
            {
                add-WebConfigurationProperty / -name sectionGroups -value iispowershell
            }
            if ($null -eq (get-WebConfigurationProperty /iispowershell -name sections["cngtest"]))
            {
                add-WebConfigurationProperty /iispowershell -name sections -value cngtest
            }
            sleep 1

            LogComment("Verify old security provider")
            Reset-IISServerManager -Confirm:$false
            $newValue = $FourBytesUnicodeSampleString + "abcXYZ123@!?"
            $attributename = "attribute1"
            Get-IISConfigSection -SectionPath iispowershell/cngtest | Set-IISConfigAttributeValue -AttributeName $attributename -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("old security provider: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("old security provider:verify value is matched to " + $newValue))
            
            $attributename = "attribute2"
            Get-IISConfigSection -SectionPath iispowershell/cngtest | Set-IISConfigAttributeValue -AttributeName $attributename -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("old security provider: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("old security provider: verify value is matched to " + $newValue))

            # Do below scenario only when the current machine supports CNG encryption
            $cngFound = (Get-Content -Path (join-path $env:windir "system32\inetsrv\config\schema\IIS_schema.xml") | foreach { if ($psitem.tolower().contains("cng")) { ("find") } })
            if ($cngFound -ne $null)
            {
                LogComment("Switch to the new security providers of CNG from the old security provider")
                if (Test-Path $testSchemaFilepath)
                {
                    Remove-Item $testSchemaFilepath -Force -Confirm:$false
                }
                New-Item $testSchemaFilepath -ItemType file -Value '<configSchema><sectionSchema name="iispowershell/cngtest"><attribute name="attribute1" type="string" encrypted="true" defaultValue="[enc:IISCngProvider::enc]"/><attribute name="attribute2" type="string" encrypted="true" defaultValue="[enc:IISWASOnlyCngProvider::enc]"/></sectionSchema></configSchema>'
                sleep 1
            }

            LogComment("Verify old value still works")            
            Reset-IISServerManager -Confirm:$false
            $newValue = $FourBytesUnicodeSampleString + "abcXYZ123@!?"
            $attributename = "attribute1"
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("after switch: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("after switch: verify value is matched to " + $newValue))
            
            $attributename = "attribute2"
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("after switch: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("after switch: verify value is matched to " + $newValue))
            
            LogComment("Set a new value")
            Reset-IISServerManager -Confirm:$false
            $newValue = $FourBytesUnicodeSampleString + "new***abcXYZ123@!?"
            $attributename = "attribute1"
            Get-IISConfigSection -SectionPath iispowershell/cngtest | Set-IISConfigAttributeValue -AttributeName $attributename -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("modify value: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("modify value: verify value is matched to " + $newValue))
            
            $attributename = "attribute2"
            Get-IISConfigSection -SectionPath iispowershell/cngtest | Set-IISConfigAttributeValue -AttributeName $attributename -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("modify value: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("modify value: verify value is matched to " + $newValue))
            
            LogComment("Remove and then reset with another value")             
            Sleep 1
            Clear-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST'-filter //iispowershell/cngtest

            Reset-IISServerManager -Confirm:$false
            $newValue = $FourBytesUnicodeSampleString + "new2***abcXYZ123@!?"
            $attributename = "attribute1"
            Get-IISConfigSection -SectionPath iispowershell/cngtest | Set-IISConfigAttributeValue -AttributeName $attributename -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("reset value with CNG: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("reset value with CNG: verify value is matched to " + $newValue))
            
            $attributename = "attribute2"
            Get-IISConfigSection -SectionPath iispowershell/cngtest | Set-IISConfigAttributeValue -AttributeName $attributename -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection -SectionPath iispowershell/cngtest | Get-IISConfigAttributeValue -AttributeName $attributename
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "iispowershell/cngtest" -name $attributename
            LogVerifyStrEq($newValue, $result, ("verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("verify value is matched to " + $newValue))
            
            # cleanup
            Sleep 1
            Clear-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST'-filter //iispowershell/cngtest

            if ($null -ne (get-WebConfigurationProperty /iispowershell -name sections["complextest"])."sections[cngtest]")
            {
                remove-WebConfigurationProperty /iispowershell -name sections["cngtest"]
            }
            if ($null -ne (get-WebConfigurationProperty / -name sectionGroups["iispowershell"])."sectionGroups[iispowershell]")
            {
                remove-WebConfigurationProperty / -name sectionGroups["iispowershell"]
            }
            if (Test-Path $testSchemaFilepath)
            {
                Remove-Item $testSchemaFilepath -Force -Confirm:$false
            }

            trap
            {
                LogTestCaseError $_ $exceptionExpected
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    if ( LogStartTest("Verify Shared Configuration", 133466) -eq $true)
    {
        if ( IISTest-Ready )
        {
            ###########################
            #
            # Get-IISSharedConfig 
            #
            ###########################

            LogComment("Get-IISSharedConfig: Prepare the clean state of redirection.config and then verify initial state")
            Reset-IISServerManager -Confirm:$false            
            $sm = Get-IISServerManager
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["enabled"].Delete()
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["path"].Delete()
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["userName"].Delete()
            $sm.CommitChanges()
            
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Get-IISSharedConfig: default state")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            LogComment("Get-IISSharedConfig: Modify value in redirection.config")            
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").SetAttributeValue("Enabled", $true)
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").SetAttributeValue("path", "bogusPath")
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").SetAttributeValue("userName", "bogusUser")
            $sm.CommitChanges()
            
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Get-IISSharedConfig: updated values")
            LogVerifyStrEq("Physical Path = bogusPath", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName = bogusUser", $result[2].Trim(), "Verify User Name")

            LogComment("Get-IISSharedConfig: Modify value in redirection.config with empty string value")            
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").SetAttributeValue("Enabled", $false)
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").SetAttributeValue("path", "")
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").SetAttributeValue("userName", "")
            $sm.CommitChanges()
            
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Get-IISSharedConfig: updated values with empty string")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            LogComment("Get-IISSharedConfig: delete value in redirection.config")            
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["enabled"].Delete()
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["path"].Delete()
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["userName"].Delete()
            $sm.CommitChanges()
            
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Get-IISSharedConfig: delete values")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            ###########################
            #
            # Export-IISConfiguration
            #
            ###########################

            [byte[]] $byteArray = 64, 216, 0, 220, 64, 216, 1, 220, 64, 216, 3, 220, 64, 216, 4, 220, 64, 216, 5, 220
            $FourBytesUnicodeSampleString = [System.Text.Encoding]::Unicode.GetString($byteArray)
            LogComment("Export-IISConfiguration: create a unicode string: " + $FourBytesUnicodeSampleString) 
            
            $sharedPath = "$env:systemdrive\$FourBytesUnicodeSampleString"
            $sharedUNCPath = "\\$env:computername\$FourBytesUnicodeSampleString"

            LogComment("Export-IISConfiguration: create shared directory : " + $sharedPath) 
            LogComment("Export-IISConfiguration: create shared directory : " + $sharedUNCPath) 
            if (Get-FileShare -Name $FourBytesUnicodeSampleString)
            {
                Remove-FileShare -Name $FourBytesUnicodeSampleString -Confirm:$false 2> $null
            }
            if (test-path $sharedPath)
            {
                remove-item $sharedPath -Recurse -Confirm:$false
            }
            md $sharedPath
            net share $FourBytesUnicodeSampleString=$sharedPath /GRANT:everyone,FULL

            LogComment("Export-IISConfiguration: initialize variables") 
            $username = ($global:g_testEnv.IISTestAdminUser)
            $unsecuredPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:g_testEnv.IISTestAdminPassword))
            $securedPassword = $global:g_testEnv.IISTestAdminPassword
            $bogusPassword = convertto-securestring "bogus" -asplaintext -force
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securedPassword) 
            $securedPassword_plaintext = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 

            $keyEncryptionPassword = convertto-securestring "Password1!" -asplaintext -force
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyEncryptionPassword) 
            $keyEncryptionPassword_plaintext = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 

            LogComment("Export-IISConfiguration: Use -DontExportKeys parameter") 
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword -DontExportKeys
            LogVerifyNumEq(2, (get-childitem $sharedPath).Length, "Export-IISConfiguration: Export with -DontExportKeys parameter")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            
            LogComment("Export-IISConfiguration: Without -DontExportKeys parameter") 
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword -Force
            LogVerifyNumEq(3, (get-childitem $sharedPath).Length, "Export-IISConfiguration: Export without -DontExportKeys parameter")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            
            LogComment("Export-IISConfiguration: Try again without -DontExportKeys parameter") 
            $SharedConfigBefore = get-childitem $sharedPath
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword -Force
            LogVerifyNumEq(3, (get-childitem $sharedPath).Length, "Export-IISConfiguration: Export without -DontExportKeys parameter again and verify files are newly overwritte")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            $SharedConfigAfter = get-childitem $sharedPath
            $compareSharedConfig = compare-object -referenceobject ($SharedConfigBefore).LastWriteTime -differenceobject ($SharedConfigAfter).LastWriteTime
            LogVerifyTrue(($compareSharedConfig -ne $null), "Verify configuration files are updated")
            
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Verify Enabled")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            LogComment("Export-IISConfiguration: Try again after some configuration changes") 
            LogVerifyFalse((get-iissite -name NewTestSite_Foo), "Verify site is not available")
            New-IISSite -Name NewTestSite_Foo -BindingInformation "*:8082:" -PhysicalPath $sharedPath 
            LogVerifyTrue((get-iissite -name NewTestSite_Foo), "Verify site is available")
            
            remove-item "$sharedPath\configEncKeyAes.key"
            remove-item "$sharedPath\administration.config" -Confirm:$false 
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -Force -DontExportKeys
            LogVerifyNumEq(2, (get-childitem $sharedPath).Length, "Export-IISSharedConfig: Number of exported files with -force")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            
            Remove-IISSite -Name NewTestSite_Foo -Confirm:$false
            LogVerifyFalse((get-iissite -name NewTestSite_Foo), "Verify site is removed")
           
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword -Force
            LogVerifyNumEq(3, (get-childitem $sharedPath).Length, "Export-IISSharedConfig:  try again with UNC path")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            
            LogComment("Export-IISConfiguration: UNC path") 
            $before = (get-item "$sharedPath\configEncKeyAes.key").Length
            new-item -ItemType file -value bogus ("$sharedPath\applicationhost.config") -Force 
            new-item -ItemType file -value bogus ("$sharedPath\administration.config") -Force 
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -force
            LogVerifyNumEq(3, (get-childitem $sharedPath).Length, "Export-IISSharedConfig: try again with UNC path with -force after modifying files in the output path directory")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            LogVerifyNumEq($before, (get-item "$sharedPath\configEncKeyAes.key").Length, "Verify configEncKeyAes.key")
            
            LogComment("Export-IISConfiguration: UNC path without credentials, supposing the logon user has the right permission") 
            new-item -ItemType file -value bogus ("$sharedPath\applicationhost.config") -Force 
            new-item -ItemType file -value bogus ("$sharedPath\administration.config") -Force 
            Export-IISConfiguration -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -force
            LogVerifyNumEq(3, (get-childitem $sharedPath).Length, "Export-IISSharedConfig:  try again with UNC path with -force without credentials supposing the logon user has the right permission")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            LogVerifyNumEq($before, (get-item "$sharedPath\configEncKeyAes.key").Length, "Verify configEncKeyAes.key")
                        
            ###########################
            #
            # Enable-IISSharedConfig and Disable-IISSharedConfig
            #
            ###########################
            
            $backupKeyFilePath = "$env:windir\system32\inetsrv\config\configEncKey.bak"
            if (test-path $backupKeyFilePath)
            {
                remove-item $backupKeyFilePath -Recurse -Confirm:$false
            }
            $exceptionExpected = $true
            Disable-IISSharedConfig -DontRestoreBackedUpKeys
            $exceptionExpected = $false

            LogComment("Enable-IISSharedConfig: -DontCopyRemoteKeys") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -DontCopyRemoteKeys
            $beforebackupKeyFile = get-item $backupKeyFilePath
            LogVerifyTrue(($beforebackupKeyFile -ne $null), "Verify key backup file is created even though -DontCopyRemoteKeys are used")
   
            $NewSharePath = "$env:systemdrive\$FourBytesUnicodeSampleString" + "foo"
            md $NewSharePath
            Sleep 1
            $result = (Test-Path $NewSharePath)
            (1..5) | foreach {
                if (-not $result)
                {
                    ("Trying again... ")
                    Sleep 2
                    md $NewSharePath -Force 
                    $result = (Test-Path $NewSharePath)
                } 
            }
            LogVerifyTrue((Test-Path $NewSharePath), ("Verify the share directory is created:" + $NewSharePath))
            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $exceptionExpected = $true

                LogComment("Enable-IISSharedConfig: Errorhandling without -Force") 
                $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
                $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Shared Configuration is already enabled.')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid username")

                $result = "na"
                $result = Get-IISSharedConfig
                LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Enable-IISSharedConfig: Enable shared configuration")
                LogVerifyStrEq(("Physical Path = $sharedPath"), $result[1].Trim(), "Verify Physical Path")
                LogVerifyStrEq(("UserName = $username"), $result[2].Trim(), "Verify User Name")
            
                $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
                $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
                $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
                $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
                LogVerifyTrue(($compareCNG -eq $null), "Verify CNGKeys are not updated")
                LogVerifyTrue(($compareRSA -eq $null), "Verify RSAKeys are not updated")

                Export-IISConfiguration -PhysicalPath $NewSharePath -KeyEncryptionPassword $keyEncryptionPassword -force -WarningAction stop
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Shared Configuration is currently enabled.')
                LogVerifyTrue($BoolReturn, "Export-IISConfiguration: Shared Configuration is currently enabled.")
                
                # clean up $exceptionExpected
                $exceptionExpected = $false            
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }

            LogComment("Export-IISConfiguration: Use -force when IISShared config is already enabled") 
            Export-IISConfiguration -PhysicalPath $NewSharePath -KeyEncryptionPassword $keyEncryptionPassword -force 
            LogVerifyNumEq(3, (get-childitem $NewSharePath).Length, "Export-IISSharedConfig:  try again after enabling IISShared config")
            LogVerifyNumEq((get-item "$sharedPath\applicationhost.config").Length, (get-item "$NewSharePath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$sharedPath\administration.config").Length, (get-item "$NewSharePath\administration.config").Length, "Verify administration.config")
            LogVerifyNumEq($before, (get-item "$NewSharePath\configEncKeyAes.key").Length, "Verify configEncKeyAes.key")
            Sleep 1
            rd $NewSharePath -confirm:$false -Recurse
            Sleep 1
            $result = (Test-Path $NewSharePath)
            (1..5) | foreach {
                if ($result)
                {
                    ("Trying again... ")
                    Sleep 2
                    md $NewSharePath -Force 
                    $result = (Test-Path $NewSharePath)
                } 
            }
            LogVerifyFalse((Test-Path $NewSharePath), ("Verify the share directory is removed:" + $NewSharePath))

            LogComment("Enable-IISSharedConfig: Try -DontCopyRemoteKeys again") 
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -DontCopyRemoteKeys -Force
            
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Enable-IISSharedConfig: Enable shared configuration")
            LogVerifyStrEq(("Physical Path = $sharedPath"), $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq(("UserName = $username"), $result[2].Trim(), "Verify User Name")
            
            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -eq $null), "Verify CNGKeys are not updated")
            LogVerifyTrue(($compareRSA -eq $null), "Verify RSAKeys are not updated")
            
            LogComment("Enable-IISSharedConfig: Dont use -DontCopyRemoteKeys") 
            $beforebackupKeyFile = get-item $backupKeyFilePath
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword -force
            LogVerifyTrue(($beforebackupKeyFile.CreationTime -eq (get-item $backupKeyFilePath).CreationTime), "Verify keyBackup file is not changed")

            md $NewSharePath
            Sleep 1
            $result = (Test-Path $NewSharePath)
            (1..5) | foreach {
                if (-not $result)
                {
                    ("Trying again... ")
                    Sleep 2
                    md $NewSharePath -Force 
                    $result = (Test-Path $NewSharePath)
                } 
            }
            LogVerifyTrue((Test-Path $NewSharePath), ("Verify the share directory is created:" + $NewSharePath))

            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $exceptionExpected = $true

                LogComment("Export-IISConfiguration: Warning when IISShared config is already enabled") 
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -PhysicalPath $NewSharePath -KeyEncryptionPassword $keyEncryptionPassword -force -WarningAction stop
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Shared Configuration is currently enabled.')
                LogVerifyTrue($BoolReturn, "Export-IISConfiguration: Shared Configuration is currently enabled.")
                
                # clean up $exceptionExpected
                $exceptionExpected = $false            
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }

            LogComment("Export-IISConfiguration: Use -force when IISShared config is already enabled") 
            Export-IISConfiguration -PhysicalPath $NewSharePath -KeyEncryptionPassword $keyEncryptionPassword -force 
            LogVerifyNumEq(3, (get-childitem $NewSharePath).Length, "Export-IISSharedConfig:  try again after enabling IISShared config")
            LogVerifyNumEq((get-item "$sharedPath\applicationhost.config").Length, (get-item "$NewSharePath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$sharedPath\administration.config").Length, (get-item "$NewSharePath\administration.config").Length, "Verify administration.config")
            LogVerifyNumEq($before, (get-item "$NewSharePath\configEncKeyAes.key").Length, "Verify configEncKeyAes.key")
            rd $NewSharePath -confirm:$false -Recurse
            Sleep 1
            $result = (Test-Path $NewSharePath)
            (1..5) | foreach {
                if ($result)
                {
                    ("Trying again... ")
                    Sleep 2
                    md $NewSharePath -Force 
                    $result = (Test-Path $NewSharePath)
                } 
            }
            LogVerifyFalse((Test-Path $NewSharePath), ("Verify the share directory is removed:" + $NewSharePath))

            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Enable-IISSharedConfig: Enable shared configuration")
            LogVerifyStrEq(("Physical Path = $sharedPath"), $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq(("UserName = $username"), $result[2].Trim(), "Verify User Name")

            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")

            LogComment("Enable-IISSharedConfig: Verify encrypted configuration value change after enabling IISShared Config") 
            $newValue = "abcXYZ123@!?"
            Get-IISConfigSection -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" 
            LogVerifyStrEq($newValue, $result, ("modify: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("modify: verify value is matched to " + $newValue))

            # try again after reset-iisservermanager
            Reset-IISServerManager -Confirm:$false            
            $newValue2 = "newValueabcXYZ123@!?"
            Get-IISConfigSection -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue $newValue2
            $result = $result2 = "na"
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" 
            LogVerifyStrEq($newValue2, $result, ("modify: verify value is matched to " + $newValue2))
            LogVerifyStrEq($newValue2, $result2.Value, ("modify: verify value is matched to " + $newValue2))

            LogComment("Disable-IISSharedConfig: Verify encrypted configuration value change after disabling IISShared Config") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Disable-IISSharedConfig 
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Disable-IISSharedConfig: Disable shared configuration")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")

            # Verify keybackup file is removed 
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")

            # set a new value after disabling IISShared config verify value is updated correctly
            $newValue = "abcXYZ123@!?"
            Get-IISConfigSection -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue $newValue
            $result = $result2 = "na"
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" 
            LogVerifyStrEq($newValue, $result, ("modify: verify value is matched to " + $newValue))
            LogVerifyStrEq($newValue, $result2.Value, ("modify: verify value is matched to " + $newValue))

            # try again after reset-iisservermanager
            Reset-IISServerManager -Confirm:$false            
            $newValue2 = "newValueabcXYZ123@!?"
            Get-IISConfigSection -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Set-IISConfigAttributeValue -AttributeName password -AttributeValue $newValue2
            $result = $result2 = "na"
            $result = Get-IISConfigSection  -SectionPath system.applicationHost/applicationPools | Get-IISConfigCollection | Get-IISConfigCollectionElement -ConfigAttribute @{name="DefaultAppPool"} | Get-IISConfigElement -ChildElementName processModel  | Get-IISConfigAttributeValue -AttributeName password
            $result2 = Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='DefaultAppPool']/processModel" -name "password" 
            LogVerifyStrEq($newValue2, $result, ("modify: verify value is matched to " + $newValue2))
            LogVerifyStrEq($newValue2, $result2.Value, ("modify: verify value is matched to " + $newValue2))

            LogComment("Enable-IISSharedConfig: Try again") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Enable-IISSharedConfig: Enable shared configuration")
            LogVerifyStrEq(("Physical Path = $sharedPath"), $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq(("UserName = $username"), $result[2].Trim(), "Verify User Name")
            
            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")
            
            # Verify keybackup file is created
            $beforebackupKeyFile = get-item $backupKeyFilePath
            LogVerifyTrue(($beforebackupKeyFile -ne $null), "Verify key backup file is created")

            # try enabling again and verify keybackup file is not changed
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword -force
            LogVerifyTrue(($beforebackupKeyFile.CreationTime -eq (get-item $backupKeyFilePath).CreationTime), "Verify keyBackup file has no change")

            LogComment("Disable-IISSharedConfig: Try again") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Disable-IISSharedConfig 
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Disable-IISSharedConfig: Disable shared configuration")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")
            
            # Verify keybackup file is removed 
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")

            LogComment("Enable-IISSharedConfig: Use UNC path") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Enable-IISSharedConfig: try again")
            LogVerifyStrEq(("Physical Path = $sharedUNCPath"), $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq(("UserName = $username"), $result[2].Trim(), "Verify User Name")

            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")
            
            # Verify keybackup file is created
            $beforebackupKeyFile = get-item $backupKeyFilePath
            LogVerifyTrue(($beforebackupKeyFile -ne $null), "Verify key backup file is created")

            Disable-IISSharedConfig 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            
            # Verify keybackup file is removed 
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")
            
            LogComment("Enable-IISSharedConfig: Try again with UNC path") 
            Enable-IISSharedConfig -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Enable-IISSharedConfig: try again")
            LogVerifyStrEq(("Physical Path = $sharedUNCPath"), $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")
            
            # Verify keybackup file is created
            $beforebackupKeyFile = get-item $backupKeyFilePath
            LogVerifyTrue(($beforebackupKeyFile -ne $null), "Verify key backup file is created")

            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $exceptionExpected = $true

                LogComment("Enable-IISSharedConfig: Error handling against bogusPassword") 
                $configBefore = get-childitem "$env:windir\system32\inetsrv\config"
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $bogusPassword -force
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Invalid password')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid keyEncryptionPassword")
                $configAfter = get-childitem "$env:windir\system32\inetsrv\config"
                $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
                LogVerifyTrue(($compareConfig -eq $null), "Use bogusPassword and verify keybackup file is not changed")

                # clean up $exceptionExpected
                $exceptionExpected = $false            
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }
            
            # Verify keybackup file is not changed after enabling again
            $configBefore = get-childitem "$env:windir\system32\inetsrv\config" | where-Object Name -ne redirection.config
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -force
            $configAfter = get-childitem "$env:windir\system32\inetsrv\config" | where-Object Name -ne redirection.config 
            
            $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
            LogVerifyTrue(($compareConfig -eq $null), "Verify config files are not changed after enabling again")

            remove-item $backupKeyFilePath -Recurse -Confirm:$false
            $configBefore = get-childitem "$env:windir\system32\inetsrv\config" | where-Object Name -ne redirection.config
 
            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $exceptionExpected = $true

                LogComment("Disable-IISSharedConfig: Error handling against not existing backupkey") 
                $Error.Clear(); $ErrorMsg = ""
                Disable-IISSharedConfig
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('DontRestoreBackedUpKeys')
                LogVerifyTrue($BoolReturn, "Disabling should fail if backupKey does not exist")
                $configAfter = get-childitem "$env:windir\system32\inetsrv\config" | where-Object Name -ne redirection.config
                $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
                LogVerifyTrue(($compareConfig -eq $null), "Verify config files are not changed")

                # clean up $exceptionExpected
                $exceptionExpected = $false            
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }
            
            sleep 1
            LogComment("Disable-IISSharedConfig: -DontRestoreBackedUpKeys") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Disable-IISSharedConfig -DontRestoreBackedUpKeys
            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "disable IISShared config and files are not updated")

            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -eq $null), "Verify CNGKeys are not updated")
            LogVerifyTrue(($compareRSA -eq $null), "Verify RSAKeys are not updated")

            # Verify keybackup file does not exist 
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")

            LogComment("Disable-IISSharedConfig: -CopyRemoteConfigToLocalFiles") 

            # Enable sharedconfig and update applicationhost.config on shared config with creating a new site
            if (Get-IISSite -name CreatedToShared)
            {
                Remove-IISSite -name CreatedToShared -Confirm:$false
            }
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -force
            Start-Sleep 3
            $configBefore = get-childitem "$env:windir\system32\inetsrv\config" -filter *.config | where-object Name -ne redirection.config
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            if (Get-IISSite -name CreatedToShared)
            {
                Remove-IISSite -name CreatedToShared -Confirm:$false
            }
            New-IISSite -Name CreatedToShared -BindingInformation "*:1234:" -PhysicalPath $sharedPath 
            $configAfter = get-childitem "$env:windir\system32\inetsrv\config" -filter *.config | where-object Name -ne redirection.config
            $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
            LogVerifyTrue(($compareConfig -eq $null), "Verify config files are not changed")

            # Verify keybackup file is created
            LogVerifyTrue((test-path $backupKeyFilePath), "Verify keyBackup file is created")

            # Disable sharedconfig with the CopyRemoteConfigToLocalFiles in order to overwriting the local applicationhost.config
            Disable-IISSharedConfig -CopyRemoteConfigToLocalFiles

            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "disable shared config with overwriting the local applicationhost.config with the shared config")
            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -eq $null), "Verify CNGKeys are not updated")
            LogVerifyTrue(($compareRSA -eq $null), "Verify RSAKeys are not updated")

            # Verify keybackup file was removed after disabling sharedconfig
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")

            $configAfter = get-childitem "$env:windir\system32\inetsrv\config" -filter *.config | where-object Name -ne redirection.config
            $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
            LogVerifyFalse(($compareConfig -eq $null), "Verify config files are changed")

            $result = "na"
            $result = Get-IISSite -name CreatedToShared
            LogVerifyTrue(($result -ne $null), "verify the local applicationhost config is now updated with showing the new site")

            # Remove the site from the local config
            Remove-IISSite -name CreatedToShared -Confirm:$false

            # Enable shared config and remove the site from the shared config
            Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -force
            $result = "na"
            $result = Get-IISSite -name CreatedToShared
            LogVerifyTrue(($result -ne $null), "verify the local applicationhost config is updated with the new site")
            Remove-IISSite -name CreatedToShared -Confirm:$false

            # Verify keybackup file is created
            LogVerifyTrue((test-path $backupKeyFilePath), "Verify keyBackup file is created")

            # Disable sharedconfig again
            Disable-IISSharedConfig -CopyRemoteConfigToLocalFiles

            $result = "na"
            $result = Get-IISSite -name CreatedToShared
            LogVerifyTrue(($result -eq $null), "verify the local applicationhost config is updated and the new site does not exist anymore")
            Remove-IISSite -name CreatedToShared -Confirm:$false

            # Verify keybackup file was removed after disabling sharedconfig
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")
            
            ###########################
            #
            # E2E 
            #
            ###########################

            LogComment("E2E: Backup config value of IISCentralCertProvider of two differenct value sets") 
            $keyPassword = convertto-securestring "xxx" -asplaintext -force
            Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
            $before = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            $keyPassword2 = convertto-securestring "xxx2" -asplaintext -force
            Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword2
            $before2 = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider

            LogComment("E2E: Create a new web site") 
            Reset-IISServerManager -Confirm:$false
            LogVerifyFalse((get-iissite -name NewTestSite), "Verify site is not available")
            New-IISSite -Name NewTestSite -BindingInformation "*:8081:" -PhysicalPath $sharedPath 
            LogVerifyTrue((get-iissite -name NewTestSite), "Verify site is available")

            Reset-IISServerManager -Confirm:$false
            $result = Get-IISSite -Name NewTestSite
            LogVerifyTrue(($result -ne $null), "E2E: site is created")

            # clean up the files of $sharePath
            Reset-IISServerManager -Confirm:$false            
            if (test-path $sharedPath)
            {
                remove-item $sharedPath -Recurse -Confirm:$false
            }
            md $sharedPath

            LogComment("E2E: Export config so that the first site is exported together") 
            Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")

            # Verify keybackup file is not created after Export-IISConfiguration
            LogVerifyFalse((test-path $backupKeyFilePath), "E2E: Verify keyBackup file is not created")

            Reset-IISServerManager -Confirm:$false
            LogVerifyTrue((get-iissite -name NewTestSite), "E2E: export config so that the first site is exported together")

            LogComment("E2E: Create a second site") 
            LogVerifyFalse((get-iissite -name NewTestSite2), "E2E: Verify site2 is not available")
            New-IISSite -Name NewTestSite2 -BindingInformation "*:8082:" -PhysicalPath $sharedPath 
            LogVerifyTrue((get-iissite -name NewTestSite2), "E2E: create second site")
            LogVerifyNumNotEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"            

            LogComment("E2E: Overwrite applicationhost config with exported files and verify the updated state of the web sites") 
            Copy $sharedPath\administration.config "$env:windir\system32\inetsrv\config" 
            Copy $sharedPath\applicationhost.config "$env:windir\system32\inetsrv\config"

            Reset-IISServerManager -Confirm:$false
            $result = Get-IISSite -Name NewTestSite2
            LogVerifyTrue(($result -eq $null), "Copy-IISRemoteConfigToLocal: import config to override to the previous state")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            
            LogComment("E2E: Enabling IISSharedConfig") 
            Enable-IISSharedConfig  -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword -force

            LogComment("E2E: Verify Central Cert Provider settings are preserved after enabling IISSharedConfig") 
            $after2 = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            for ($i=0; $i-lt $after2.Property.count; $i++) 
            { 
                if ($after2.Property[$i] -ne $null -and $before2.Property[$i])
                {
                    LogVerifyStrEq($after2.GetValue($after2.Property[$i]).ToString(), $before2.GetValue($before2.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $after2.GetValue($after2.Property[$i]).ToString()))
                }
            }

            LogComment("E2E: Update Central Cert Provider settings after enabling IISSharedConfig") 
            Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword
            $after = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            for ($i=0; $i-lt $after.Property.count; $i++) 
            { 
                if ($after.Property[$i] -ne $null -and $before.Property[$i])
                {
                    LogVerifyStrEq($after.GetValue($after.Property[$i]).ToString(), $before.GetValue($before.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $after.GetValue($after.Property[$i]).ToString()))
                }
            }

            # Verify keybackup file is created
            $beforebackupKeyFile = get-item $backupKeyFilePath
            LogVerifyTrue(($beforebackupKeyFile -ne $null), "Verify key backup file is created")
            LogVerifyFalse((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal: enabling IISSharedConfig and then verify the second site is not available")

            LogComment("E2E: Create the second site again because it is gone now") 
            New-IISSite -Name NewTestSite2 -BindingInformation "*:8082:" -PhysicalPath $sharedPath 
            LogVerifyTrue((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal: create second site when sharedconfig is enabled")
            LogVerifyNumNotEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
            LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
            Start-Sleep 3
            LogComment("E2E: Overwrite applicationhost config with exported files again and verify the updated state of the web sites") 
            # import config and there should be no change because they are the same with using UNCPath
            Copy $sharedPath\administration.config "$env:windir\system32\inetsrv\config" 
            Copy $sharedPath\applicationhost.config "$env:windir\system32\inetsrv\config"

            Reset-IISServerManager -Confirm:$false
            LogVerifyTrue((get-iissite -name NewTestSite), "Copy-IISRemoteConfigToLocal: import config and there should be no change because they are the same - site1")
            LogVerifyTrue((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal: import config and there should be no change because they are the same - site2")

            LogComment("E2E: Disable SharedConfiguration") 
            $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            Disable-IISSharedConfig 
            Start-Sleep 3
            $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
            $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
            $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
            $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
            LogVerifyTrue(($compareCNG -ne $null), "Verify CNGKeys are updated")
            LogVerifyTrue(($compareRSA -ne $null), "Verify RSAKeys are updated")

            LogVerifyTrue((get-iissite -name NewTestSite), "verify after disabling - site1")
            LogVerifyTrue((get-iissite -name NewTestSite2), "verify after disabling - site2")
            Remove-IISSite -Name NewTestSite2 -Confirm:$false
            LogVerifyTrue((get-iissite -name NewTestSite), "verify after removing site2 - site1")
            LogVerifyFalse((get-iissite -name NewTestSite2), "verify after removing site2 - site2")

            # Verify keybackup file is removed 
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")

            LogComment("E2E: Verify Central Cert Provider settings are preserved after disabling IISSharedConfig") 
            # verify central certprovider settings after disbling IISSharedConfig
            $after = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            for ($i=0; $i-lt $after.Property.count; $i++) 
            { 
                if ($after.Property[$i] -ne $null -and $before.Property[$i])
                {
                    LogVerifyStrEq($after.GetValue($after.Property[$i]).ToString(), $before.GetValue($before.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $after.GetValue($after.Property[$i]).ToString()))
                }
            }

            LogComment("E2E: Modify Central Cert Provider settings are preserved after disabling IISSharedConfig") 
            Enable-IISCentralCertProvider -CertStoreLocation "$env:systemdrive\inetpub" -UserName $username -Password $securedPassword -PrivateKeyPassword $keyPassword2
            $after2 = get-item HKLM:\SOFTWARE\Microsoft\iis\CentralCertProvider
            for ($i=0; $i-lt $after2.Property.count; $i++) 
            { 
                if ($after2.Property[$i] -ne $null -and $before2.Property[$i])
                {
                    LogVerifyStrEq($after2.GetValue($after2.Property[$i]).ToString(), $before2.GetValue($before2.Property[$i]).ToString(), ("Verify registry values [" + $i + "]: " + $after2.GetValue($after2.Property[$i]).ToString()))
                }
            }

            LogComment("E2E: Disable Central Cert Provider settings") 
            Disable-IISCentralCertProvider

            LogComment("E2E: Overwrite applicationhost config with exported files again and verify the updated state of the web sites") 
            Copy $sharedPath\administration.config "$env:windir\system32\inetsrv\config" 
            Copy $sharedPath\applicationhost.config "$env:windir\system32\inetsrv\config"

            Reset-IISServerManager -Confirm:$false
            LogVerifyTrue((get-iissite -name NewTestSite), "Copy-IISRemoteConfigToLocal: import config and the config should go to the previous state - site1")
            LogVerifyTrue((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal import config and the config should go to the previous state - site2")
            
            LogComment("E2E: Remove both first/second site") 
            Remove-IISSite -Name NewTestSite -Confirm:$false
            Remove-IISSite -Name NewTestSite2 -Confirm:$false
            Reset-IISServerManager -Confirm:$false
            LogVerifyFalse((get-iissite -name NewTestSite), "verify after removing site1 - site1")
            LogVerifyFalse((get-iissite -name NewTestSite2), "verify after removing site2 - site2")
            
            LogComment("E2E: Overwrite applicationhost config with exported files again and verify the updated state of the web sites") 
            Copy $sharedPath\administration.config "$env:windir\system32\inetsrv\config" 
            Copy $sharedPath\applicationhost.config "$env:windir\system32\inetsrv\config"
            Reset-IISServerManager -Confirm:$false

            LogVerifyTrue((get-iissite -name NewTestSite), "Copy-IISRemoteConfigToLocal: import config again and the config should go to the previous state - site1")
            LogVerifyTrue((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal import config again and the config should go to the previous state - site2")

            LogComment("E2E: Enable shared config then remove the sites again") 
            Enable-IISSharedConfig  -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword
            LogVerifyTrue((get-iissite -name NewTestSite), "enable shared config then remove the sites again - site1")
            LogVerifyTrue((get-iissite -name NewTestSite2), "enable shared config then remove the sites again - site2")            
            Remove-IISSite -Name NewTestSite -Confirm:$false
            Remove-IISSite -Name NewTestSite2 -Confirm:$false
            Reset-IISServerManager -Confirm:$false
            LogVerifyFalse((get-iissite -name NewTestSite), "verify after removing site1 - site1")
            LogVerifyFalse((get-iissite -name NewTestSite2), "verify after removing site2 - site2")
            
            # Verify keybackup file is created
            $beforebackupKeyFile = get-item $backupKeyFilePath
            LogVerifyTrue(($beforebackupKeyFile -ne $null), "Verify key backup file is created")

            LogComment("E2E: Overwrite applicationhost config with exported files again and verify the updated state of the web sites") 
            Copy $sharedPath\administration.config "$env:windir\system32\inetsrv\config" 
            Copy $sharedPath\applicationhost.config "$env:windir\system32\inetsrv\config"
            Reset-IISServerManager -Confirm:$false

            LogVerifyFalse((get-iissite -name NewTestSite), "Copy-IISRemoteConfigToLocal: import config again and then verify sites are all gone now with using DontCopyRemoteKeys - site1")
            LogVerifyFalse((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal: import config again and then verify sites are all gone now with using DontCopyRemoteKeys - site2")
            
            LogComment("E2E: Disable shared config again and then verify sites are still not shown") 
            Disable-IISSharedConfig
            Start-Sleep 3
            LogVerifyFalse((get-iissite -name NewTestSite), "Copy-IISRemoteConfigToLocal: disable shared config again and then verify sites are still not shown - site1")
            LogVerifyFalse((get-iissite -name NewTestSite2), "Copy-IISRemoteConfigToLocal: disable shared config again and then verify sites are still not shown - site2")

            # Verify keybackup file is removed 
            LogVerifyFalse((test-path $backupKeyFilePath), "Verify keyBackup file is removed")

            LogComment("Verify error messages...") 
            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $exceptionExpected = $true

                # initialize $CNGKeysBefore and $RDAKeysBefore
                $CNGKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
                $RSAKeysBefore = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
                $configBefore = get-childitem "$env:windir\system32\inetsrv\config"
            
                #########################################
                # Export-IISConfiguration test scenarios
                #########################################
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Configuration files already exist in the specified path')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of already exist")

                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath ("$sharedPath" + "NotExisting") -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of not existing path")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName "bogusUser" -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of invalid user")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $null -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('UserName')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of invalid UserName")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Export of configuration files failed')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of missing UserName")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $bogusPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of invalid password")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $unsecuredPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Password')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of invalid password")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of missing password")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $bogusPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('The specified password is not a strong password')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of not strong password")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword "Password1!"
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('KeyEncryptionPassword')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of clear text password of KeyEncryptionPassword")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $null -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Password')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of null Password")               
                
                $Error.Clear(); $ErrorMsg = ""
                Export-IISConfiguration -UserName $username -Password $securedPassword -PhysicalPath $null -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('PhysicalPath')
                LogVerifyTrue($BoolReturn, "Export-IISSharedConfig: Verify error message of invalid PhysicalPath")               
                
                # verify config files are not updated after verifying error messages                
                $configAfter = get-childitem "$env:windir\system32\inetsrv\config"
                $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
                LogVerifyTrue(($compareConfig -eq $null), "Verify Config files are not not updated")
                
                #########################################
                # Disable-IISSharedConfig test scenarios
                #########################################
                $Error.Clear(); $ErrorMsg = ""
                Disable-IISSharedConfig 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Shared Configuration is already disabled.')
                LogVerifyTrue($BoolReturn, "Disable-IISSharedConfig: Verify error message of already enabled")

                # verify config files are not updated after verifying error messages                
                $configAfter = get-childitem "$env:windir\system32\inetsrv\config"
                $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
                LogVerifyTrue(($compareConfig -eq $null), "Verify Config files are not not updated")
                
                #########################################
                # Enable-IISSharedConfig test scenarios
                #########################################

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath ($sharedUNCPath + "bogus") -KeyEncryptionPassword $keyEncryptionPassword -DontCopyRemoteKeys
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("KeyEncryptionPassword is specified")
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of not existing physical path")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath ($sharedUNCPath + "bogus") -DontCopyRemoteKeys
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Configuration Files don't exist in location")
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of not existing physical path")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath ("$env:systemdrive\inetpub") -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Configuration Files don't exist in location")
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of not existing configuration files")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName "bogus\bogus" -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid username")
                
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of missing username")
                 
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $null -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('UserName')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid username")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $null -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Password')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid Password")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $null -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Password')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid Password")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Cannot access the location')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of missing Password")

                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName "administrator" -Password $securedPassword -PhysicalPath $null -KeyEncryptionPassword $keyEncryptionPassword
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('PhysicalPath')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid PhysicalPath")
                
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $null 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('KeyEncryptionPassword')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid KeyEncryptionPassword")
                
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('The parameter KeyEncryptionPassword was not provided.')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of missing KeyEncryptionPassword without DontCopy parameter")
                
                # verify config files are not updated after verifying error messages                
                $configAfter = get-childitem "$env:windir\system32\inetsrv\config"
                $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
                LogVerifyTrue(($compareConfig -eq $null), "Verify Config files are not not updated")
                
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -UserName $username -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $bogusPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Invalid password')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid KeyEncryptionPassword")
                
                $Error.Clear(); $ErrorMsg = ""
                Enable-IISSharedConfig -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $bogusPassword 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('Invalid password')
                LogVerifyTrue($BoolReturn, "Enable-IISSharedConfig: Verify error message of invalid KeyEncryptionPassword")
            
                # verify key files and config files are not changed after verifying error messages
                $CNGKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\Keys"
                $RSAKeysAfter = get-childitem "$env:systemdrive\ProgramData\Application Data\microsoft\Crypto\RSA\MachineKeys"
                $compareCNG = compare-object -referenceobject ($CNGKeysBefore).LastWriteTime -differenceobject ($CNGKeysAfter).LastWriteTime
                $compareRSA = compare-object -referenceobject ($RSAKeysBefore).LastWriteTime -differenceobject ($RSAKeysAfter).LastWriteTime
                LogVerifyTrue(($compareCNG -eq $null), "Verify CNGKeys are not updated")
                LogVerifyTrue(($compareRSA -eq $null), "Verify RSAKeys are not updated")
                
                # verify config files are not updated after verifying error messages                
                $configAfter = get-childitem "$env:windir\system32\inetsrv\config"
                $compareConfig = compare-object -referenceobject ($configBefore).LastWriteTime -differenceobject ($configAfter).LastWriteTime
                LogVerifyTrue(($compareConfig -eq $null), "Verify Config files are not not updated")
                
                # verify there applicationhost.config of shared directory
                LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\applicationhost.config").Length, (get-item "$sharedPath\applicationhost.config").Length, "Verify applicationhost.config")
                LogVerifyNumEq((get-item "$env:windir\system32\inetsrv\config\administration.config").Length, (get-item "$sharedPath\administration.config").Length, "Verify administration.config")
                       
                # clean up $exceptionExpected
                $exceptionExpected = $false            
                trap
                {
                    LogTestCaseError $_ $exceptionExpected
                }
            }
            
            trap
            {
                LogTestCaseError $_ $exceptionExpected
            }

            #clean up
            LogComment("Cleanup: Disabling IISShared Config") 
            if ((Get-IISSharedConfig)[0].Contains("True"))
            {
                Disable-IISSharedConfig
            }

            LogComment("Cleanup: Remove the shared UNC path") 
            if (Get-FileShare -Name $FourBytesUnicodeSampleString)
            {
                Remove-FileShare -Name $FourBytesUnicodeSampleString -Confirm:$false
            }
            
            LogComment("Cleanup: Remove the shared directory") 
            if (test-path $sharedPath)
            {
                remove-item $sharedPath -Recurse -Confirm:$false
            }
        }
        else
        {       
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }

    # Regression test for MSFT: 9625353: WAS fails to start with "Access Denied" when dynamicSiteRegistration is enabled
    if ( LogStartTest("Verify Shared Configuration with enabling dynamicRegistrationThreashhold", 133734) -eq $true)
    {
        if ( IISTest-Ready )
        {
            # Clean up test environment
            $unsecuredPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:g_testEnv.IISTestAdminPassword))
            $securedPassword = $global:g_testEnv.IISTestAdminPassword
            $nonAdminUser = "nonAdminUser"
            $existingUser = Get-LocalUser -Name $nonAdminUser -ErrorAction SilentlyContinue
            if ($existingUser)
            {
               Remove-LocalUser -Name $nonAdminUser -Confirm:$false
            }
            New-LocalUser -name $nonAdminUser -Password $securedPassword

            LogComment("Initial cleanup: prepare the clean state of redirection.config and then verify initial state")
            Reset-IISServerManager -Confirm:$false
            $sm = Get-IISServerManager
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["enabled"].Delete()
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["path"].Delete()
            $sm.GetRedirectionConfiguration().GetSection("configurationRedirection").Attributes["userName"].Delete()
            $sm.CommitChanges()

            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = False", $result[0].Trim(), "Get-IISSharedConfig: default state")
            LogVerifyStrEq("Physical Path =", $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq("UserName =", $result[2].Trim(), "Verify User Name")

            # Set dynamicRegistrationThreashhold with 1 to make it work
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/webLimits"
            $backupValue = Get-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "dynamicIdleThreshold"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "dynamicIdleThreshold" -AttributeValue 1

            # Restart W3SVC to apply the configuration change
            Stop-Service W3SVC
            Stop-Service WAS
            Start-Service W3SVC
            LogVerifyStrEq("Running", (Get-Service was).Status.ToString(), "Verify WAS service running")
            LogVerifyStrEq("Running", (Get-Service w3svc).Status.ToString(), "Verify W3SVC service running")

            # Create a new share and export IIS configuration 
            [byte[]] $byteArray = 64, 216, 0, 220, 64, 216, 1, 220, 64, 216, 3, 220, 64, 216, 4, 220, 64, 216, 5, 220
            $FourBytesUnicodeSampleString = [System.Text.Encoding]::Unicode.GetString($byteArray)
            LogComment("Export-IISConfiguration: create a unicode string: " + $FourBytesUnicodeSampleString)

            $sharedPath = "$env:systemdrive\$FourBytesUnicodeSampleString"
            $sharedUNCPath = "\\$env:computername\$FourBytesUnicodeSampleString"
            LogComment("Export-IISConfiguration: create shared directory : " + $sharedUNCPath)
            $shareExisting = Get-FileShare -Name $FourBytesUnicodeSampleString  -ErrorAction SilentlyContinue
            if ($shareExisting)
            {
                Remove-FileShare -Name $FourBytesUnicodeSampleString -Confirm:$false
            }
            if (test-path $sharedPath)
            {
                remove-item $sharedPath -Recurse -Confirm:$false
            }
            md $sharedPath
            net share $FourBytesUnicodeSampleString=$sharedPath /GRANT:everyone,FULL
            Reset-IISServerManager -Confirm:$false
            $sites_before = (Get-IISSite)

            # configure IIS Shared Configuration
            $keyEncryptionPassword = convertto-securestring "Password1!" -asplaintext -force            
            Export-IISConfiguration -UserName $nonAdminUser -Password $securedPassword -PhysicalPath $sharedPath -KeyEncryptionPassword $keyEncryptionPassword
            Enable-IISSharedConfig -UserName $nonAdminUser -Password $securedPassword -PhysicalPath $sharedUNCPath -KeyEncryptionPassword $keyEncryptionPassword

            # Restart W3SVC and verify WAS and W3SVC
            Stop-Service W3SVC
            Stop-Service WAS
            Start-Service W3SVC
            LogVerifyStrEq("Running", (Get-Service was).Status.ToString(), "Verify WAS service running")
            LogVerifyStrEq("Running", (Get-Service w3svc).Status.ToString(), "Verify W3SVC service running")

            Reset-IISServerManager -Confirm:$false
            $sites_after = (Get-IISSite)
            LogVerifyNumEq($sites_after.count, $sites_before.count, "No change after enabling IIS Shared Config")

            $result = "na"
            $result = Get-IISSharedConfig
            LogVerifyStrEq("Enabled = True", $result[0].Trim(), "Get-IISSharedConfig: default state")
            LogVerifyStrEq(("Physical Path = "  + $sharedUNCPath), $result[1].Trim(), "Verify Physical Path")
            LogVerifyStrEq(("UserName = " + $nonAdminUser), $result[2].Trim(), "Verify User Name")

            # Disable IIS Shared Config
            Disable-IISSharedConfig
            
            # Restore dynamicIdleThreshold to default value
            Reset-IISServerManager -Confirm:$false
            $configSection = Get-IISConfigSection -sectionPath "system.applicationHost/webLimits"
            Set-IISConfigAttributeValue -ConfigElement $configSection -AttributeName "dynamicIdleThreshold" -AttributeValue ($backupValue * 1)

            # Restart W3SVC and verify WAS and W3SVC
            Stop-Service W3SVC
            Stop-Service WAS
            Start-Service W3SVC
            LogVerifyStrEq("Running", (Get-Service was).Status.ToString(), "Verify WAS service running")
            LogVerifyStrEq("Running", (Get-Service w3svc).Status.ToString(), "Verify W3SVC service running")

            Reset-IISServerManager -Confirm:$false
            $sites_after = (Get-IISSite)
            LogVerifyNumEq($sites_after.count, $sites_before.count, "No change after disabling IIS Shared Config")

            # cleanup
            IISTest-RestoreAppHostConfig
            if (Get-LocalUser -Name $nonAdminUser)
            {
               Remove-LocalUser -Name $nonAdminUser -Confirm:$false
            }

            trap
            {
                LogTestCaseError $_
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
    
    if ( LogStartTest("Verify IISSiteBinding cmdlets", 133745) -eq $true)
    {
        $SiteBindingCmdletAvailable = (get-command -Name "New-IISSiteBinding") -ne $null
        if ( $SiteBindingCmdletAvailable -and (IISTest-Ready) )
        {
            # Reset IISServerManager
            Reset-IISServerManager -Confirm:$false
            
            # Clean up test environment
            dir Cert:\LocalMachine\my | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
            dir Cert:\LocalMachine\root | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
            dir Cert:\LocalMachine\webhosting | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
            [byte[]] $byteArray = 64, 216, 0, 220, 64, 216, 1, 220, 64, 216, 3, 220, 64, 216, 4, 220, 64, 216, 5, 220
            $FourBytesUnicodeSampleString = [System.Text.Encoding]::Unicode.GetString($byteArray)
            $sharedPath = "$env:systemdrive\$FourBytesUnicodeSampleString"
            if (test-path $sharedPath)
            {
                remove-item $sharedPath -Recurse -Confirm:$false
            }
            md $sharedPath

            # create a new certificate for testing
            # FYI, Nano OS does not have New-SelfSignedCertificate
            $storeLocation = "Cert:\LocalMachine\My"
            $certificate = New-SelfSignedCertificate -DnsName foo.com -CertStoreLocation $storeLocation
            $certificate2 = New-SelfSignedCertificate -DnsName foo.com -CertStoreLocation $storeLocation
            $certificatePath = ("cert:\localmachine\my\" + $certificate.Thumbprint)

            # Verify certificate with using Test-Certificate, you will get "False" value because all the certificate chain is trusted 
            # FYI, Nano OS does not have Test-Certificate
            $testResult = ($certificate | Test-Certificate -Policy SSL -DNSName "foo.com" -ErrorAction SilentlyContinue)
            LogVerifyTrue((-not $testResult), "The intermediate certificate chain is not trusted, which is expected for a newly created selfsigned certificate")
            
            # Make the certificate trusted with exporting it to "Root" cert store
            LogVerifyTrue((test-path $certificatePath), "Certificate is created")
            LogPass("Certificate creation succeed")
            $mypwd = ConvertTo-SecureString -String "xxx" -Force -AsPlainText
            Export-PfxCertificate -FilePath "$sharedPath\temp.pfx" -Cert $certificatePath -Password $mypwd
            Import-PfxCertificate -FilePath "$sharedPath\temp.pfx" -CertStoreLocation "Cert:\LocalMachine\Root" -Password $mypwd

            # Initialize certificateRoot Path
            $certificateRootPath = ("cert:\localmachine\root\" + $certificate.Thumbprint)
            LogVerifyTrue((test-path $certificateRootPath), "Exporting succeed")
            
            # Verify certificate with using Test-Certificate again and you should get "True" here
            $testResult = ($certificate | Test-Certificate -Policy SSL -DNSName "foo.com")
            LogVerifyTrue($testResult, "Certificate verified")
            
            # Enable CCS
            $temp = Get-IISCentralCertProvider
            $user = "foo"                
            if ($temp[0].Contains("Enabled") -and $temp[0].Contains("False")) {
                $PrivateKeyPassword = "xxx"
                $securedPasswordSecure = $global:g_testEnv.IISTestAdminPassword
                $PrivateKeyPasswordSecure = convertto-securestring $PrivateKeyPassword -asplaintext -force 
                $temp = Get-LocalUser -Name $user -ErrorAction SilentlyContinue
                if ($temp -eq $null) {
                    New-LocalUser -Name $user -Password $securedPasswordSecure
                }
                Enable-IISCentralCertProvider -CertStoreLocation $sharedPath -UserName $user -Password $securedPasswordSecure -PrivateKeyPassword $PrivateKeyPasswordSecure
            }
            $temp = Get-IISCentralCertProvider
            LogVerifyTrue(($temp[0].Contains("Enabled") -and $temp[0].Contains("True")), "Centralized Certificate Store is enabled")
            
            # Initialize variables
            $Sni = [Microsoft.Web.Administration.SslFlags]::Sni
            $Sni_CCS = [Microsoft.Web.Administration.SslFlags]::Sni + [Microsoft.Web.Administration.SslFlags]::CentralCertStore
            
            # Clean up bindings
            Remove-IISSiteBinding "Default Web Site" "*:443:" -confirm:$false -Protocol http -verbose
            Remove-IISSiteBinding "Default Web Site" "*:443:" -confirm:$false -Protocol https -verbose
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" -confirm:$false -Protocol http -verbose
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" -confirm:$false -Protocol https -verbose
            Remove-IISSiteBinding "Default Web Site" "*:444:" -confirm:$false -Protocol http -verbose
            
            # Reset IISServerManager 
            Reset-IISServerManager -Confirm:$false
            
            # Basic test
            $result = Get-IISSite -name "Default Web Site" | Get-IISSiteBinding
            LogVerifyNumEq(1, $result.count, "Get one result")
            $storeLocation2 = "My"
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -CertificateThumbPrint $certificate.Thumbprint -CertStoreLocation $storeLocation -Protocol https -Force
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" https
            LogVerifyStrEq("*:443:", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("None", $result.sslFlags, "Verify ssl flag: None")            
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:444:" -Protocol http
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:444:" http
            LogVerifyStrEq("*:444:", $result.BindingInformation, "Verify new binding created *:444:")
            LogVerifyStrEq("None", $result.sslFlags, "Verify ssl flag: None")            
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            
            Remove-IISSiteBinding "Default Web Site" "*:444:" -confirm:$false -Protocol http -verbose
            Remove-IISSiteBinding "Default Web Site" "*:443:" -confirm:$false -Protocol https -verbose
            $storeLocation2 = "My"
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -CertificateThumbPrint $certificate.Thumbprint -CertStoreLocation $storeLocation2 -Protocol https -Force
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -Protocol http -force
            
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:"
            LogVerifyNumEq(2, $result.count, "Get two results of *:443:")
            $result = get-iissite -Name "Default Web Site" | Get-IISSiteBinding -BindingInformation "*:443:"
            LogVerifyNumEq(2, $result.count, "Get two results of *:443:")
            
            $result = Get-IISSiteBinding -Name "Default Web Site" -Protocol https
            LogVerifyNumEq(1, $result.count, "Get one result of *:443:")
            $result = get-iissite -Name "Default Web Site" | Get-IISSiteBinding -Protocol https
            LogVerifyNumEq(1, $result.count, "Get one result of *:443:")
            
            $result = Get-IISSiteBinding -Name "Default Web Site" -Protocol https -BindingInformation "*:443:"
            LogVerifyNumEq(1, $result.count, "Get one result of *:443:")
            $result = get-iissite -Name "Default Web Site" | Get-IISSiteBinding -Protocol https -BindingInformation "*:443:"
            LogVerifyNumEq(1, $result.count, "Get one result of *:443:")
            
            $result = Get-IISSiteBinding -Name "Default Web Site" -Protocol http -BindingInformation "*:443:"
            LogVerifyNumEq(1, $result.count, "Get one result of *:443:")
            $result = get-iissite -Name "Default Web Site" | Get-IISSiteBinding -Protocol http -BindingInformation "*:443:"
            LogVerifyNumEq(1, $result.count, "Get one result of *:443:")

            $result = Get-IISSiteBinding -Name "Default Web Site"
            LogVerifyNumEq(3, $result.count, "Get all binding")
            $result = get-iissite -name "Default Web Site" | Get-IISSiteBinding
            LogVerifyNumEq(3, $result.count, "Get all binding")
            
            Remove-IISSiteBinding "Default Web Site" "*:443:" -confirm:$false -verbose
            Remove-IISSiteBinding "Default Web Site" "*:443:" -confirm:$false -Protocol https -verbose
            $result = Get-IISSite -Name "Default Web Site" | Get-IISSiteBinding
            LogVerifyNumEq(1, $result.count, "Get one result")
            $result = get-iissite -name "Default Web Site" | Get-IISSiteBinding
            LogVerifyNumEq(1, $result.count, "Get one result")
            
            # New-IISSiteBinding -passThru
            Remove-IISSiteBinding "Default Web Site" "*:1234:" -confirm:$false
            $result = new-iissitebinding -Name "Default Web Site" -BindingInformation "*:1234:" -Passthru | Get-IISSiteBinding -name "Default Web Site"
            LogVerifyStrEq("*:1234:", $result.BindingInformation, "Verify new binding created *:1234:")
            LogVerifyStrEq("None", $result.sslFlags, "Verify ssl flag: None")            
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            
            # Remove-iissitebinding
            Remove-IISSiteBinding "Default Web Site" "*:1234:" -confirm:$false
            new-iissitebinding -Name "Default Web Site" -BindingInformation "*:1234:" -Passthru | Remove-IISSiteBinding -name "Default Web Site" -confirm:$false
            $result = Get-IISSiteBinding "Default Web Site" "*:1234:"
            LogVerifyStrEq($null, $result, "Verify new binding is removed *:1234:")
            
            # New-IISSiteBinding SNI
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
            New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint $Sni $storeLocation
            $result = Get-IISSiteBinding "Default Web Site" "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("Sni", $result.sslFlags, "Verify ssl flag: Sni")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false

            # New-IISSiteBinding SNI string
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
            New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint Sni $storeLocation
            $result = Get-IISSiteBinding "Default Web Site" "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("Sni", $result.sslFlags, "Verify ssl flag: Sni")            
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false

            # New-IISSiteBinding SNI, CCS 
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
            New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint $Sni_CCS $storeLocation -Verbose
            $result = Get-IISSiteBinding "Default Web Site" "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("Sni, CentralCertStore", $result.sslFlags, "Verify ssl flag: Sni")
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")            
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false

            # overwrite $Sni_CCS with property value 
            $Sni_CCS = "Sni, CentralCertStore"
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
            New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint "Sni, CentralCertStore" $storeLocation -Verbose
            $result = Get-IISSiteBinding "Default Web Site" "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("Sni, CentralCertStore", $result.sslFlags, "Verify ssl flag: Sni")            
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            $Sni_CCS = (Get-IISSiteBinding "Default Web Site" "*:443:foo.com" https).sslFlags
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false

            # New-IISSiteBinding SNI, CCS with the property value
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
            New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint $Sni_CCS $storeLocation -Verbose
            $result = Get-IISSiteBinding "Default Web Site" "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("Sni, CentralCertStore", $result.sslFlags, "Verify ssl flag: Sni")
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false

            # nickname of My
            $storeLocation2 = "mY"
            Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -CertificateThumbPrint $certificate.Thumbprint -CertStoreLocation $storeLocation2 -Protocol https -Force -verbose
            $result = Get-IISSiteBinding "Default Web Site" "*:443:" https
            LogVerifyStrEq("*:443:", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false

            # New-IISSite
            $siteName = "foo"
            Remove-IISSite $siteName -confirm:$false
            New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:foo.com" https $certificate.Thumbprint Sni $storeLocation
            $result = Get-IISSiteBinding $siteName "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("Sni", $result.SslFlags, "Verify new binding created Sni")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            
            New-IISSiteBinding $siteName "*:1234:" http -Verbose
            $result = Get-IISSiteBinding $siteName "*:1234:" http
            LogVerifyStrEq("*:1234:", $result.BindingInformation, "Verify new binding created *:1234:")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("http", $result.Protocol, "Verify new binding created http")
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            Remove-IISSite $siteName -confirm:$false

            # New-IISSite with mY
            Remove-IISSite $siteName -confirm:$false
            New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:foo.com" https $certificate.Thumbprint Sni $storeLocation2
            $result = Get-IISSiteBinding $siteName "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("Sni", $result.SslFlags, "Verify new binding created Sni")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSite $siteName -confirm:$false

            # Pipeline with New-IISSite
            Remove-IISSite $siteName -confirm:$false
            New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:foo.com" https $certificate.Thumbprint Sni $storeLocation -passthru | New-IISSiteBinding -bindingInformation "*:1234:" -Protocol http -Verbose
            $result = Get-IISSiteBinding $siteName "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("Sni", $result.SslFlags, "Verify new binding created Sni")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")

            $result = Get-IISSiteBinding $siteName "*:1234:" http
            LogVerifyStrEq("*:1234:", $result.BindingInformation, "Verify new binding created *:1234:")
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            LogVerifyStrEq("http", $result.Protocol, "Verify new binding created http")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            Remove-IISSite $siteName -confirm:$false

            # New-IISSite Pipeline
            Remove-IISSite $siteName -confirm:$false
            $result = New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:foo.com" https $certificate.Thumbprint Sni $storeLocation -passthru | New-IISSiteBinding -bindingInformation "*:1234:" -Protocol http -Verbose -passthru | foreach {$_}
            LogVerifyStrEq("*:1234:", $result.BindingInformation, "Verify new binding created *:1234:")
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            LogVerifyStrEq("http", $result.Protocol, "Verify new binding created http")
            LogVerifyStrEq("", $result.CertificateHash, "Verify new binding created empty hash")
            
            $result = Get-IISSiteBinding $siteName "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("Sni", $result.SslFlags, "Verify new binding created Sni")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSite $siteName -confirm:$false

            # New-IISSite PassThru
            Remove-IISSite $siteName -confirm:$false
            New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:foo.com" https $certificate.Thumbprint Sni $storeLocation -passthru
            $result = Get-IISSiteBinding $siteName "*:443:foo.com" https
            LogVerifyStrEq("*:443:foo.com", $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("Sni", $result.SslFlags, "Verify new binding created Sni")            
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSite $siteName -confirm:$false

            # Default value -Protocol
            $BindingInformation = "*:443:"
            $Thumbprint = $certificate.ThumbPrint
            Remove-IISSiteBinding "Default Web Site" $BindingInformation -confirm:$false
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -verbose
            $result = Get-IISSiteBinding "Default Web Site"$BindingInformation
            LogVerifyStrEq("http", $result.Protocol, "Verify new binding created http")
            Remove-IISSiteBinding "Default Web Site" $BindingInformation -confirm:$false
            
            Remove-IISSiteBinding "Default Web Site" $BindingInformation -confirm:$false            
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $Thumbprint -CertStoreLocation $storeLocation -Force -verbose
            $result = Get-IISSiteBinding "Default Web Site"$BindingInformation
            LogVerifyStrEq("http", $result.Protocol, "Verify new binding created http")
            Remove-IISSiteBinding "Default Web Site" $BindingInformation -confirm:$false
            
            # Export the certificate trusted with exporting it to "WebHosting" cert store
            $mypwd = ConvertTo-SecureString -String "xxx" -Force -AsPlainText
            Import-PfxCertificate -FilePath "$sharedPath\temp.pfx" -CertStoreLocation "Cert:\LocalMachine\WebHosting" -Password $mypwd
            $certificatePath = ("cert:\localmachine\webhosting\" + $certificate.Thumbprint)
            LogVerifyTrue((test-path $certificatePath),"Export to webhosting")

            # Default value -CertificateLocation and SslFlag
            Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $certificate.Thumbprint -Protocol https -Force -verbose
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation https
            LogVerifyStrEq($BindingInformation, $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("WebHosting", $result.CertificateStoreName, "Verify new binding created WebHosting")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            LogVerifyTrue(($result.CertificateHash.length -gt 0), "Verify new binding created hash")
            Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false

            # -removeConfigOnly
            $BindingInformation1 = "*:443:"
            $BindingInformation2 = "*:443:foo.com"
            Remove-IISSiteBinding "Default Web Site" $BindingInformation1 https -confirm:$false
            Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $certificate.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
            New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 -CertificateThumbPrint $certificate.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation https
            LogVerifyStrEq($BindingInformation, $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")            
            $result2 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 https
            LogVerifyStrEq($BindingInformation2, $result2.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("My", $result2.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result2.SslFlags, "Verify new binding created None")            
            LogVerifyStrEq("https", $result2.Protocol, "Verify new binding created https")            
            Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false -RemoveConfigOnly
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 https
            LogVerifyStrEq($null, $result, "Verify binding removed with -RemoveConfigOnly")
            $result = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation https
            LogVerifyStrEq($BindingInformation, $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")
            $resultCompare = Compare-Object $result.CertificateHash $result2.CertificateHash
            LogVerifyStrEq($null, $resultCompare, "Verify hash value identical")
            
            # Overwriting https certificate with -force
            New-IISSiteBinding -Force -Name "Default Web Site" -BindingInformation $BindingInformation2 -CertificateThumbPrint $certificate2.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
            $result3 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 https
            LogVerifyStrEq($BindingInformation2, $result3.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("My", $result3.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result3.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result3.Protocol, "Verify new binding created https")
            $result4 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation https
            LogVerifyStrEq($BindingInformation, $result4.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result4.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result4.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result4.Protocol, "Verify new binding created https")
            $resultCompare = Compare-Object $result3.CertificateHash $result4.CertificateHash
            LogVerifyStrEq($null, $resultCompare, "Verify hash value identical")
            $resultCompare = Compare-Object $result.CertificateHash $result3.CertificateHash
            LogVerifyTrue(($resultCompare.Length -gt 0), "Verify hash value not identical")
            
            # remove config only, leaving conflicted-force https binding confliction and then overwrite with previous certificate
            Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false -RemoveConfigOnly
            $result5 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 https
            LogVerifyStrEq($null, $result5, "Verify binding removed with -RemoveConfigOnly")
            New-IISSiteBinding -Force -Name "Default Web Site" -BindingInformation $BindingInformation2 -CertificateThumbPrint $certificate.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
            $result3 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 https
            LogVerifyStrEq($BindingInformation2, $result3.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("My", $result3.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result3.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result3.Protocol, "Verify new binding created https")
            $result4 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation https
            LogVerifyStrEq($BindingInformation, $result4.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result4.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result4.SslFlags, "Verify new binding created None")            
            LogVerifyStrEq("https", $result4.Protocol, "Verify new binding created https")  
            $resultCompare = Compare-Object $result3.CertificateHash $result4.CertificateHash
            LogVerifyStrEq($null, $resultCompare, "Verify hash value identical")
            $resultCompare = Compare-Object $result.CertificateHash $result3.CertificateHash
            LogVerifyStrEq($null, $resultCompare, "Verify hash value identical")
            Remove-IISSiteBinding "Default Web Site" $BindingInformation1 https -confirm:$false -RemoveConfigOnly
            $result3 = Get-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 https
            LogVerifyStrEq($BindingInformation2, $result3.BindingInformation, "Verify new binding created *:443:foo.com")
            LogVerifyStrEq("My", $result3.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result3.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result3.Protocol, "Verify new binding created https")
            Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false
            $result = Get-IISSiteBinding -Name "Default Web Site" -Protocol https
            LogVerifyStrEq($null, $result5, "Verify https binding removed")
            
            # Binding port confliction for https protocol
            $siteName = "confictTest"
            Remove-IISSite $siteName -confirm:$false
            Remove-IISSiteBinding "Default Web Site" $BindingInformation https -confirm:$false
            Remove-IISSiteBinding "Default Web Site" $BindingInformation http -confirm:$false
            New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:" https $certificate.Thumbprint None $storeLocation 
            New-IISSiteBinding "Default Web Site" "*:443:" https $certificate.Thumbprint None $storeLocation -force
            $result = Get-IISSiteBinding "Default Web Site" "*:443:" https
            LogVerifyStrEq($BindingInformation, $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("My", $result.CertificateStoreName, "Verify new binding created My")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("https", $result.Protocol, "Verify new binding created https")        

            # Binding port confliction for non-https protocol
            Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
            New-IISSiteBinding "Default Web Site" "*:443:" http -force
            $result = Get-IISSiteBinding "Default Web Site" "*:443:" http
            LogVerifyStrEq($BindingInformation, $result.BindingInformation, "Verify new binding created *:443:")
            LogVerifyStrEq("", $result.CertificateStoreName, "Verify new binding created empty storename")
            LogVerifyStrEq("None", $result.SslFlags, "Verify new binding created None")
            LogVerifyStrEq("http", $result.Protocol, "Verify new binding created http")
            Remove-IISSiteBinding "Default Web Site" "*:443:" http -confirm:$false
            Remove-IISSite $siteName -confirm:$false

            if ((Get-Culture).Name.ToLower() -eq "en-us")
            {
                # initialize $exceptionExpected
                $expectedException = $true

                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:444:!@#" -Protocol http
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('The specified host name is incorrect')
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Invalid hostname")

                $siteName = "tempSiteInvalid"
                Remove-IISSite $siteName -confirm:$false
                $Error.Clear(); $ErrorMsg = ""
                New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:!@#" https $certificate.Thumbprint Sni $storeLocation
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('The specified host name is incorrect')
                LogVerifyTrue($BoolReturn, "New-IISSite: Invalid hostname")

                #Warning message of not existing binding
                $warning = ""
                Get-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -Protocol bogus -WarningVariable warning
                LogVerifyTrue($warning.Item(0).Message.Contains("bogus *:443:"), "Get-IISSiteBinding: Not existing binding")
                
                $warning = ""                
                Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -Protocol bogus -WarningVariable warning
                LogVerifyTrue($warning.Item(0).Message.Contains("bogus *:443:"), "Remove-IISSiteBinding: Not existing binding")
                
                #Error message of not existing site
                $Error.Clear(); $ErrorMsg = ""
                Get-IISSiteBinding -Name "bogus" -BindingInformation "*:443:" -Protocol bogus
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('does not exist')
                LogVerifyTrue($BoolReturn, "Get-IISSiteBinding: Web site does not exist")
                $BoolReturn=$ErrorMsg.Contains('bogus')
                LogVerifyTrue($BoolReturn, "Get-IISSiteBinding: Web site does not exist")

                $Error.Clear(); $ErrorMsg = ""
                Remove-IISSiteBinding -Name "bogus" -BindingInformation "*:443:" -Protocol bogus
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains('does not exist')
                LogVerifyTrue($BoolReturn, "Remove-IISSiteBinding: Web site does not exist")
                $BoolReturn=$ErrorMsg.Contains('bogus')
                LogVerifyTrue($BoolReturn, "Remove-IISSiteBinding: Web site does not exist")

                # Warning certificateThumbprint will be ignored 
                $warning = ""
                Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -Protocol http -confirm:$false
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -CertificateThumbPrint $certificate.Thumbprint -CertStoreLocation $storeLocation -Protocol http -Force -WarningVariable warning
                LogVerifyTrue($warning.Item(0).Message.Contains("The parameter 'CertificateThumbprint' is ignored"), "IISSiteBinding: CertificateThumbPrint is ignored")
                Remove-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -Protocol http -confirm:$false

                $Sni = [Microsoft.Web.Administration.SslFlags]::Sni
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:" https $certificate.Thumbprint $Sni $storeLocation -force
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Hostheader in '*:443:' should not be empty")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Hostheader should not be empty")

                # Error handling - invalid certificateStore
                Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
                $Error.Clear(); $ErrorMsg = ""       
                New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint -SslFlag "Sni" "bogusStore" -Verbose -ErrorAction Continue
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("CertStoreLocation")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - invalid certificateStore")
                
                # Error handling - invalid sslflag value
                Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint -SslFlag "Sni,CCS" $storeLocation -Verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("SslFlag")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - invalid sslflag value")

                # Disable CCS
                $temp = Get-IISCentralCertProvider
                if ($temp[0].Contains("Enabled") -and $temp[0].Contains("True")) {
                    Disable-IISCentralCertProvider
                }
                Reset-IISServerManager -Confirm:$false
                $temp = Get-IISCentralCertProvider
                $BoolReturn = $temp[0].Contains("Enabled") -and $temp[0].Contains("False")
                LogVerifyTrue($BoolReturn, "CentralCert is disabled before testing below scenario")

                # Error handling - invalid sslflag (CCS) when CCS is disabled
                Remove-IISSiteBinding "Default Web Site" "*:443:foo.com" https -confirm:$false
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:foo.com" https $certificate.Thumbprint $Sni_CCS $storeLocation -Verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Central Certificate Provider is disabled. It should be enabled first. Try 'Enable-IISCentralCertProvider'")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - invalid sslflag value")

                # Error -ReadConfigOnly
                $BindingInformation1 = "*:443:"
                $BindingInformation2 = "*:443:foo.com"
                Remove-IISSiteBinding "Default Web Site" $BindingInformation1 https -confirm:$false 
                Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $certificate.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 -CertificateThumbPrint $certificate.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
                $Error.Clear(); $ErrorMsg = ""
                Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("At least one other site is using the same HTTPS binding. Use the -RemoveConfigOnly switch to remove this HTTPS binding.")
                LogVerifyTrue($BoolReturn, "Remove-IISSiteBinding: Error handling -removeConfigOnly")
                Remove-IISSiteBinding "Default Web Site" $BindingInformation1 https -confirm:$false -RemoveConfigOnly
                Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false
                
                # Error -Force for conflicting https bindinginformation
                Remove-IISSiteBinding "Default Web Site" $BindingInformation1 https -confirm:$false -RemoveConfigOnly
                Remove-IISSiteBinding "Default Web Site" $BindingInformation2 https -confirm:$false
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $certificate.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation2 -CertificateThumbPrint $certificate2.Thumbprint -Protocol https -verbose -CertStoreLocation $storeLocation
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("At least one other site is using the same HTTPS binding and the binding is configured with a different certificate.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling -force")
                Remove-IISSiteBinding "Default Web Site" $BindingInformation1 https -confirm:$false -RemoveConfigOnly
                
                # Error -Force for conflicting http bindinginformation between sites, one https and the other https
                $siteName = "confictTest"
                Remove-IISSite $siteName -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" http -confirm:$false
                New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:" https $certificate.Thumbprint None $storeLocation 
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:" https $certificate.Thumbprint None $storeLocation
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("If you assign the same binding to this site, you will only be able to start one of the sites.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling -force")
                
                # Error -Force for conflicting http bindinginformation between sites, one https and the other http
                $siteName = "confictTest"
                Remove-IISSite $siteName -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" http -confirm:$false
                New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:" https $certificate.Thumbprint None $storeLocation 
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:" http
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("If you assign the same binding to this site, you will only be able to start one of the sites.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling -force")
                
                # Error -Force for conflicting http bindinginformation between sites, one http and the other https
                $siteName = "confictTest"
                Remove-IISSite $siteName -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" http -confirm:$false
                New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:" http
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:" https $certificate.Thumbprint None $storeLocation 
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("If you assign the same binding to this site, you will only be able to start one of the sites.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling -force")
                
                # Error -Force for conflicting http bindinginformation between sites, one http and the other http
                Remove-IISSite $siteName -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" http -confirm:$false
                New-IISSite $siteName "$env:systemdrive\inetpub\wwwroot" "*:443:" http
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding "Default Web Site" "*:443:" http
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("If you assign the same binding to this site, you will only be able to start one of the sites.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling -force")
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                Remove-IISSiteBinding "Default Web Site" "*:443:" http -confirm:$false
                Remove-IISSIte $siteName -Confirm:$false
                
                # Error handling - invalid $null value
                $storeLocation = "Cert:\LocalMachine\My"
                $BindingInformation = "*:443:"
                $Protocol = "https"
                $Thumbprint = $certificate.Thumbprint
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                
                $Error.Clear(); $ErrorMsg = ""
                $BindingInformation = $null
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $Thumbprint -CertStoreLocation $storeLocation -Protocol $Protocol -Force -verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("BindingInformation")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - BindingInformation")
                                
                $Error.Clear(); $ErrorMsg = ""
                $BindingInformation = "*:443:"
                $Protocol = $null
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $Thumbprint -CertStoreLocation $storeLocation -Protocol $Protocol -Force -verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("Protocol")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - Protocol")
                
                $Error.Clear(); $ErrorMsg = ""
                $Protocol = "https"
                $Thumbprint = $null
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $Thumbprint -CertStoreLocation $storeLocation -Protocol $Protocol -Force -verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("CertificateThumbPrint")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - CertificateThumbPrint")

                $Error.Clear(); $ErrorMsg = ""
                $Thumbprint = $certificate.Thumbprint
                $storeLocation = $null
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $Thumbprint -CertStoreLocation $storeLocation -Protocol $Protocol -Force -verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("CertStoreLocation")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - CertStoreLocation")

                $Error.Clear()
                $storeLocation = "Cert:\LocalMachine\My"
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation $BindingInformation -CertificateThumbPrint $Thumbprint -CertStoreLocation $storeLocation -Protocol $Protocol -Force -verbose
                LogVerifyTrue(($Error.count -eq 0), "No error")
                Get-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" https
                LogVerifyTrue(($Error.count -eq 0), "No error")
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                LogVerifyTrue(($Error.count -eq 0), "No error")

                # Error handling - invalid storelocation
                dir Cert:\LocalMachine\webhosting | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
                $storeLocation_invalid = "Cert:\LocalMachine\WebHosting"
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -CertificateThumbPrint $certificate.Thumbprint -CertStoreLocation $storeLocation_invalid -Protocol https -Force -verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("CertificateThumbprint is invalid.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - invalid sslflag value")
                
                # Error handling - invalid storename
                $storeLocation_invalid = "WebHosting"
                Remove-IISSiteBinding "Default Web Site" "*:443:" https -confirm:$false
                $Error.Clear(); $ErrorMsg = ""
                New-IISSiteBinding -Name "Default Web Site" -BindingInformation "*:443:" -CertificateThumbPrint $certificate.Thumbprint -CertStoreLocation $storeLocation_invalid -Protocol https -Force -verbose
                $ErrorMsg = $Error[0].ToString()
                $BoolReturn=$ErrorMsg.Contains("CertificateThumbprint is invalid.")
                LogVerifyTrue($BoolReturn, "New-IISSiteBinding: Error handling - invalid storename")

                # rollback $expectedException
                $expectedException = $false
            }            
 
            # cleanup
            dir Cert:\LocalMachine\my | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
            dir Cert:\LocalMachine\root | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
            dir Cert:\LocalMachine\webhosting | Where-Object {$_.Subject -eq "CN=foo.com" } | remove-item
            
            IISTest-RestoreAppHostConfig

            # Disable CCS
            $temp = Get-IISCentralCertProvider
            if ($temp[0].Contains("Enabled") -and $temp[0].Contains("True")) {
                Disable-IISCentralCertProvider
            }
            Reset-IISServerManager -Confirm:$false
            if (Get-LocalUser -Name $user)
            {
               Remove-LocalUser -Name $user -Confirm:$false
            }

            trap
            {
                LogTestCaseError $_ $expectedException
            }
        }
        else
        {
            LogBUGVerifyStrEq(0, "no", "no", "yes", "Skipping testcase...")
        }

        LogEndTest
    }
}

# backup and clean IIS configuration files before starting
IISTest-BackupAppHostConfig
IISTest-BackupRootWebConfig

#
# Call global function of RunTest to invoke TestScenario function
#
RunTest

# clean up IIS configuration files after finishing
IISTest-RestoreAppHostConfig
IISTest-RestoreRootWebConfig