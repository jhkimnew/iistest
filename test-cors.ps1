function Test-Assertion 
{ 
    [CmdletBinding()] 
    Param( 
        #The value to assert. 
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)] 
        [AllowNull()] 
        [AllowEmptyCollection()] 
        [System.Object] 
        $InputObject 
    ) 
 
    Begin 
    { 
        $info = '{0}, file {1}, line {2}' -f @( 
            $MyInvocation.Line.Trim(), 
            $MyInvocation.ScriptName, 
            $MyInvocation.ScriptLineNumber 
        ) 
        $inputCount = 0 
        $inputFromPipeline = -not $PSBoundParameters.ContainsKey('InputObject') 
    } 
 
    Process 
    { 
        $inputCount++ 
        if ($inputCount -gt 1) { 
            $message = "Assertion failed (more than one object piped to Test-Assertion): $info" 
            Write-Debug -Message $message 
            throw $message 
        } 
        if ($null -eq $InputObject) { 
            $message = "Assertion failed (`$InputObject is `$null): $info" 
            Write-Debug -Message $message 
            throw  $message 
        } 
        if ($InputObject -isnot [System.Boolean]) { 
            $type = $InputObject.GetType().FullName 
            $value = if ($InputObject -is [System.String]) {"'$InputObject'"} else {"{$InputObject}"} 
            $message = "Assertion failed (`$InputObject is of type $type with value $value): $info" 
            Write-Debug -Message $message 
            throw $message 
        } 
        if (-not $InputObject) { 
            $message = "Assertion failed (`$InputObject is `$false): $info" 
            Write-Debug -Message $message 
            throw $message 
        } 
        Write-Verbose -Message "Assertion passed: $info" 
    } 
 
    End 
    { 
        if ($inputFromPipeline -and $inputCount -lt 1) { 
            $message = "Assertion failed (no objects piped to Test-Assertion): $info" 
            Write-Debug -Message $message 
            throw $message 
        } 
    } 
} 

function Test-CORS($t)
{ 
    # $afterAllowOrgin = '<add origin="www.foo.com" allowed="true" />'

    $configFilePath = "C:\inetpub\wwwroot\web.config"

    $allowHeaders = $null
    $t.expectedAccessControlAllowHeaders = $null
    $t.allowHeader | ForEach-Object {
        $allowHeaders += '<add header="' + $psitem + '" />'
        $t.expectedAccessControlAllowHeaders += $psitem + ","
        #$t.expectedAccessControlAllowHeaders += $psitem + " "
    }
    $t.expectedAccessControlAllowHeaders = $t.expectedAccessControlAllowHeaders.Trim().TrimEnd(",")

    $allowMethods = $null
    $t.expectedAccessControlAllowMethods = $null
    $t.allowMethod | ForEach-Object {
        $allowMethods += '<add method="' + $psitem + '" />'
        $t.expectedAccessControlAllowMethods += $psitem + ","
        #$t.expectedAccessControlAllowMethods += $psitem + " "
    }
    $t.expectedAccessControlAllowMethods = $t.expectedAccessControlAllowMethods.Trim().TrimEnd(",")

    $t.expectedAccessControlExposeHeaders = $null
    $t.exposeHeader | ForEach-Object {
        $exposeHeaders += '<add header="' + $psitem + '" />'
        $t.expectedAccessControlExposeHeaders += $psitem + ","
        #$t.expectedAccessControlExposeHeaders += $psitem + " "
    }
    $t.expectedAccessControlExposeHeaders = $t.expectedAccessControlExposeHeaders.Trim().TrimEnd(",")
    
    $allowedOrigins = $null
    if ($null -ne $t.origin) { 
        $t.origin | ForEach-Object {
            $allowedOrigins += '
                   <add allowed="true" origin="' + $psitem + '" allowCredentials="' + $t.allowCredentials+ '" maxAge="' + $t.maxAge + '">
                        <allowHeaders allowAllRequestedHeaders="' + $t.allowAllRequestedHeaders + '">
                            ' + $allowHeaders + '                        
                        </allowHeaders>
                        <allowMethods>
                            ' + $allowMethods + '                        
                        </allowMethods>
                        <exposeHeaders>
                            ' + $exposeHeaders + '
                        </exposeHeaders>
                    </add>'
        }
    }

    $disallowedOrigins = $null
    if ($t.disallowedOrigin -ne $null) { 
        $t.disallowedOrigin | ForEach-Object {
            $disallowedOrigins += '
                   <add allowed="false" origin="' + $psitem + '"/>'
        }
    }

    $configFile = `
    '<?xml version="1.0" encoding="UTF-8"?>
    <configuration>
        <system.webServer>
            <cors enabled="true" failUnlistedOrigins="' + $t.failUnlistedOrigins + '">
                ' +
                $t.beforeAllowOrigin + 
                $allowedOrigins + 
                $disallowedOrigins + 
                $t.afterAllowOrigin + '
	        </cors>
        </system.webServer>
    </configuration>'

    $uri = $t.uri
    $respose = $t.null

    stop-process -name w3wp -confirm:$false -force 2> out-null
    if ((Get-WebAppPoolState DefaultAppPool).Value -ne "Started") {
        Start-WebAppPool DefaultAppPool
    }

    remove-item $configFilePath -Force -Confirm:$false 2> out-null
    new-item -ItemType file -Value $configFile $configFilePath -Force > out-null

    $invokeRequestFailureExpected = $false
    if ($t.expectedStatusCode -eq 500)
    {
        $invokeRequestFailureExpected = $true
    }

    $preFlight = $true
    if ($t.headers["Access-Control-Request-Method"] -eq $null)
    {
        $preFlight = $false;
    }
    if ($t.request_method.ToUpper() -ne "OPTIONS")
    {
        $preFlight = $false;
    }

    (1..$t.retryCount) | ForEach-Object {
        $error.Clear()
        $responseBody = $null
        if (-not $invokeRequestFailureExpected)
        {
            $respose = $null
            $respose = Invoke-WebRequest $uri -Headers $t.headers -Method $t.request_method
            Test-Assertion ($respose.StatusCode -eq $t.expectedStatusCode) -Verbose
            Test-Assertion ($respose.Headers.'Access-Control-Allow-Origin' -eq $t.expectedAccessControlAllowOrigin) -Verbose
            $responseBody = $respose.RawContent
            $respose.Headers

            if ($preFlight)
            {
                if ($t.allowAllRequestedHeaders -eq "true")
                {
                    $t.expectedAccessControlAllowHeaders = $null
                    $t.expectedAccessControlAllowHeaders = $t.headers["Access-Control-Request-Headers"]
                }
                if ($t.maxAge -eq "-1")
                {
                    $t.expectedAccessControlMaxAge = $null
                }
                else
                {
                    $t.expectedAccessControlMaxAge = $t.maxAge;
                }
                Test-Assertion ($respose.Headers.'Access-Control-Allow-Methods' -eq $t.expectedAccessControlAllowMethods) -Verbose
                Test-Assertion ($respose.Headers.'Access-Control-Expose-Headers' -eq $null) -Verbose
                Test-Assertion ($respose.Headers.'Access-Control-Allow-Headers' -eq $t.expectedAccessControlAllowHeaders) -Verbose
                Test-Assertion ($respose.Headers.'Access-Control-Max-Age' -eq $t.expectedAccessControlMaxAge) -Verbose
            }
            else
            {
                Test-Assertion ($respose.Headers.'Access-Control-Allow-Methods' -eq $null) -Verbose
                Test-Assertion ($respose.Headers.'Access-Control-Expose-Headers' -eq $t.expectedAccessControlExposeHeaders) -Verbose
                Test-Assertion ($respose.Headers.'Access-Control-Allow-Headers' -eq $null) -Verbose
                Test-Assertion ($respose.Headers.'Access-Control-Max-Age' -eq $null) -Verbose
            }
        }
        else
        {
            $error_respose = $null
            $error_respose = try 
                { 
                    Invoke-WebRequest $uri -Headers $t.headers -Method $t.request_method
                } 
                catch 
                { 
                    $_.Exception
                }
            Test-Assertion ($error_respose.Response.StatusCode -eq "InternalServerError") -Verbose
            $result = $error_respose.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
        }

        if ($t.expectedBodyKeyword)
        {
            $t.expectedBodyKeyword | ForEach-Object {
                Test-Assertion ($responseBody.Contains($psitem)) -Verbose
            }
        }   
    }
}

function Invoke-TestCORS ($item)
{
    $global:g_scenario = @{
        "uri"="http://foo.com";
        "request_method"="GET";
        "headers"=$null; # Ex. "headers"=(@{"Origin"="https://foo.com"});
        "allowCredentials"="true";
        "allowAllRequestedHeaders"="true";
        "failUnlistedOrigins"="false";
        "origin"=$null;
        "disallowedOrigin"=$null;
        "beforeAllowOrigin"=$null;
        "afterAllowOrigin"=$null;
        "retryCount"=1;
        "maxAge"=555;
        "allowHeader"="allowHeader_foo";
        "allowMethod"="allowMethod";
        "exposeHeader"="exposeHeader";
        "expectedStatusCode"=200;
        "expectedAccessControlAllowOrigin"=$null;
        "expectedBodyKeyword"=$null;
        "expectedAccessControlAllowMethods" = $null
        "expectedAccessControlExposeHeaders" = $null
        "expectedAccessControlAllowHeaders" = $null
        "expectedAccessControlMaxAge" = $null
    }

    $scenario = $global:g_scenario
    if ($item.uri -ne $null) 
    {  
        $scenario.uri = $item.uri  
    }
    if ($item.request_method -ne $null) 
    {  
        $scenario.request_method = $item.request_method  
    }
    if ($item.headers -ne $null) 
    {  
        $scenario.headers = $item.headers  
    }
    if ($item.allowCredentials -ne $null) 
    {  
        $scenario.allowCredentials = $item.allowCredentials  
    }
    if ($item.allowAllRequestedHeaders -ne $null) 
    {  
        $scenario.allowAllRequestedHeaders = $item.allowAllRequestedHeaders  
    }
    if ($item.failUnlistedOrigins -ne $null) 
    {  
        $scenario.failUnlistedOrigins = $item.failUnlistedOrigins  
    }
    if ($item.origin -ne $null) 
    {  
        $scenario.origin = $item.origin  
    }
    if ($item.beforeAllowOrigin -ne $null) 
    {  
        $scenario.beforeAllowOrigin = $item.beforeAllowOrigin  
    }
    if ($item.afterAllowOrigin -ne $null) 
    {  
        $scenario.afterAllowOrigin = $item.afterAllowOrigin  
    }
    if ($item.retryCount -ne $null) 
    {  
        $scenario.retryCount = $item.retryCount  
    }
    if ($item.maxAge -ne $null) 
    {  
        $scenario.maxAge = $item.maxAge  
    }
    if ($item.allowHeader -ne $null) 
    {  
        $scenario.allowHeader = $item.allowHeader  
    }
    if ($item.allowMethod -ne $null) 
    {  
        $scenario.allowMethod = $item.allowMethod  
    }
    if ($item.exposeHeader -ne $null) 
    {  
        $scenario.exposeHeader = $item.exposeHeader  
    }
    if ($item.disallowedOrigin -ne $null) 
    {  
        $scenario.disallowedOrigin = $item.disallowedOrigin  
    }
    if ($item.expectedStatusCode -ne $null) 
    {  
        $scenario.expectedStatusCode = $item.expectedStatusCode  
    }
    if ($item.expectedAccessControlAllowOrigin -ne $null) 
    {  
        $scenario.expectedAccessControlAllowOrigin = $item.expectedAccessControlAllowOrigin  
    }
    if ($item.expectedBodyKeyword -ne $null) 
    {  
        $scenario.expectedBodyKeyword = $item.expectedBodyKeyword  
    }
    if ($item.expectedAccessControlAllowMethods -ne $null) 
    {  
        $scenario.expectedAccessControlAllowMethods = $item.expectedAccessControlAllowMethods  
    }
    if ($item.expectedAccessControlExposeHeaders -ne $null) 
    {  
        $scenario.expectedAccessControlExposeHeaders = $item.expectedAccessControlExposeHeaders  
    }
    if ($item.expectedAccessControlAllowHeaders -ne $null) 
    {  
        $scenario.expectedAccessControlAllowHeaders = $item.expectedAccessControlAllowHeaders  
    }
    if ($item.expectedAccessControlMaxAge -ne $null) 
    {  
        $scenario.expectedAccessControlMaxAge = $item.expectedAccessControlMaxAge  
    }

    Test-CORS $scenario
}

$global:g_scenario = $null

##################
# Origin test
##################

$testDataArray = @()
$item = @{
    "headers"=(@{"Origin"="https://127.0.0.1"});
    "origin"="*";
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="*";
}
Invoke-TestCORS $item

$testDataArray = @()
$item = @{
    "headers"=(@{"Origin"="https://127.0.0.1:1234"});
    "origin"="https://*:1234";
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="https://127.0.0.1:1234";
}
Invoke-TestCORS $item

$testDataArray = @()
$item = @{
    "headers"=(@{"Origin"="http://127.0.0.1:1234"});
    "origin"="http://*:1234";
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="http://127.0.0.1:1234";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://127.0.0.1"});
    "origin"="https://*";
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="https://127.0.0.1";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://127.0.0.1 bogus"});
    "origin"="https://*";
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="https://127.0.0.1 bogus";
}
Invoke-TestCORS $item

$testDataArray = @()
$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https://foo.com";
    "expectedAccessControlAllowOrigin"="https://foo.com";
}
Invoke-TestCORS $item

$testDataArray = @()
$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https://foo.com";
    "expectedAccessControlAllowOrigin"="https://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="*";
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="*";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("*", "https://foo.com");
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="https://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("https://*", "*");
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="https://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("https://foo.com", "*");
    "allowCredentials"="false";
    "expectedAccessControlAllowOrigin"="https://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="*";
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007000d")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("*", "https://foo.com");
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007000d")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("https://foo.com", "*");
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007000d")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https://*";
    "expectedAccessControlAllowOrigin"="https://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https://*.com";
    "expectedAccessControlAllowOrigin"="https://foo.com"; 
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https://*.com";
    "expectedAccessControlAllowOrigin"="https://foo.com"; 
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https://*";
    "expectedAccessControlAllowOrigin"="https://foo.com"; 
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("https://*", "http://*");
    "expectedAccessControlAllowOrigin"="https://foo.com"; 
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://*", "http://*");
    "expectedAccessControlAllowOrigin"="http://foo.com"; 
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://bogus.com", "http://bogus.com", "https://*", "http://*");
    "expectedAccessControlAllowOrigin"="http://foo.com"; 
}
Invoke-TestCORS $item

##################
# Disallowed rules
##################
$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://*", "http://*");
    "disallowedOrigin"=("https://foo.com");    
    "expectedAccessControlAllowOrigin"="http://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("https://*", "http://*");
    "disallowedOrigin"=("https://foo.com");
    "exposeHeader"=("foo","bar")
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("https://*", "http://*");
    "disallowedOrigin"=("https://*.com");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("*");
    "allowCredentials"="false";
    "disallowedOrigin"=("https://*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("http://*");
    "disallowedOrigin"=("https://*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://*");
    "disallowedOrigin"=("http://*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "allowCredentials"="false";
    "origin"=("https://*");
    "disallowedOrigin"=("*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "allowCredentials"="false";
    "origin"=("http://*.com");
    "disallowedOrigin"=("*");
    "expectedAccessControlAllowOrigin"="http://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "allowCredentials"="false";
    "origin"=("http://foo.com");
    "disallowedOrigin"=("*");
    "expectedAccessControlAllowOrigin"="http://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "allowCredentials"="false";
    "origin"=("http://*.com");
    "disallowedOrigin"=("*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "allowCredentials"="false";
    "origin"=("https://*.com");
    "disallowedOrigin"=("*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://www.foo.com"});
    "origin"=("https://*.com");
    "disallowedOrigin"=("https://*.foo.com");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://www.foo.com"});
    "origin"=("https://*.foo.com");
    "disallowedOrigin"=("https://*.com");
    "expectedAccessControlAllowOrigin"="https://www.foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://www.foo.com"});
    "allowCredentials"="true";
    "origin"=("https://*.com");
    "disallowedOrigin"=("*");
    "expectedAccessControlAllowOrigin"="https://www.foo.com";
}
Invoke-TestCORS $itemstCORS $item

$item = @{
    "headers"=(@{"Origin"="https://www.foo.com"});
    "allowCredentials"="false";
    "origin"=("*");
    "disallowedOrigin"=("https://*.com");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "allowCredentials"="false";
    "origin"=("*");
    "disallowedOrigin"=("https://*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "allowCredentials"="true";
    "origin"=$null;
    "disallowedOrigin"=("*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://www.a.b.c"});
    "allowCredentials"="false";
    "origin"=("https://*.b.c", "https://*.c");
    "disallowedOrigin"=("https://*.a.b.c");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://a.b.c"});
    "allowCredentials"="false";
    "origin"=("https://*.b.c", "https://*.c");
    "disallowedOrigin"=("https://*.a.b.c");
    "expectedAccessControlAllowOrigin"="https://a.b.c";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://a.b.c"});
    "allowCredentials"="false";
    "origin"=("https://*.b.c", "https://*.c");
    "disallowedOrigin"=("https://*.a.b.c");
    "expectedAccessControlAllowOrigin"="https://a.b.c";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://a.b.c"});
    "allowCredentials"="false";
    "origin"=("https://*.b.c", "https://*.c");
    "disallowedOrigin"=("https://*.a.b.c", "https://a.b.c");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://a.b.c"});
    "allowCredentials"="false";
    "origin"=("https://*.c");
    "disallowedOrigin"=("https://*.b.c");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://a.b.c"});
    "allowCredentials"="false";
    "origin"=("https://*.b.c");
    "disallowedOrigin"=("https://*.c");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "allowCredentials"="false";
    "origin"=$null;
    "disallowedOrigin"=("https://*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x80070577")
}
Invoke-TestCORS $item

# Invalid value
$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "allowCredentials"="false";
    "origin"="";
    "disallowedOrigin"=("https://*");
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500,60", "0x8007000d")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "allowCredentials"="false";
    "origin"="*";
    "disallowedOrigin"="";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500,60", "0x8007000d")
}
Invoke-TestCORS $item

##################
# Invalid configuration and CORS request is being ignored
##################

$testDataArray = @()
$item = @{
    "headers"=(@{"Origin"="http://127.0.0.1:1234"});
    "origin"="http://*:*";      # this is invalid origin value; we don't support wildcard character for port number
    "allowCredentials"="true";
    "expectedAccessControlAllowOrigin"=$null;
}
Invoke-TestCORS $item

##################
# With external CORS application
##################
$item = @{
    "uri"="http://foo.com/PublishOutput/testCORS";
    # "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://*", "http://*");
    "expectedAccessControlAllowOrigin"="testCORS";
}
Invoke-TestCORS $item

$item = @{
    "uri"="http://foo.com/PublishOutput/testCORS";
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://*", "http://*");
    expectedAccessControlAllowOrigin="testCORS";    
}
Invoke-TestCORS $item

##################
# With external CORS application - Preflight
##################
$item = @{
    "request_method"="OPTIONS";
    "uri"="http://foo.com/PublishOutput/testCORS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST"});
    "origin"=("https://*", "http://*");
    "expectedStatusCode"=204;
    expectedAccessControlAllowOrigin="http://foo.com";
}
Invoke-TestCORS $item

##################
# Invalid wild card sequnce
##################
$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="https**";
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007064a")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="*://*";
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007064a")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"="*://*";
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007064a")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("*://*", "https://foo.com");
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007064a")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("*", "*://*", "https://foo.com");
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007064a")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("*", "http://*.com", "https://foo.com");
    "allowCredentials"="true";
    "expectedStatusCode"=500;
    "expectedBodyKeyword"=("500.60", "0x8007064a")
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo."});
    "origin"=("*", "https://*.", "https://foo.com");
    "allowCredentials"="false";
    expectedAccessControlAllowOrigin="https://foo.";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="HTTP://foo."});
    "origin"=("*", "HTTP://*.", "https://foo.com");
    "allowCredentials"="false";
    expectedAccessControlAllowOrigin="*";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("HTTPS://*.com", "https://foo.com");
    "allowCredentials"="true";
    expectedAccessControlAllowOrigin="https://foo.com";
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="https://foo.com"});
    "origin"=("HTTPS:\\*.com", "https://foo.com");
    "allowCredentials"="true";
    expectedAccessControlAllowOrigin="https://foo.com";
}
Invoke-TestCORS $item

##################
# multiple values test
##################

$multipleValue = @()
$multipleValueString = $null
(1..100) | ForEach-Object {
    $multipleValue += ("foo" + $psitem)
    $multipleValueString += ("foo" + $psitem) + ","
}

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=$multipleValue;
    "allowCredentials"="false";
    "exposeHeader"=$multipleValue
    "allowHeader"=$multipleValue
    "allowAllRequestedHeaders"="false";
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=$multipleValue;
    "allowCredentials"="false";
    "exposeHeader"=$multipleValue
    "allowHeader"=$multipleValue
    "allowAllRequestedHeaders"="false";
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Headers"=$multipleValueString});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=$multipleValue;
    "allowCredentials"="false";
    "exposeHeader"=$multipleValue
    "allowHeader"=$multipleValue
    "allowAllRequestedHeaders"="true";
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="!@#$%^&*()_+=-[]\;',./?><"":|}{abcdefghijklmnopqrstuvwxyz01234567890"});
    "origin"=("http://*", "http://bar.com");
    "allowMethod"=$multipleValue;
    "allowCredentials"="false";
    "exposeHeader"=$multipleValue
    "allowHeader"=$multipleValue
    "allowAllRequestedHeaders"="true";
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";
}
Invoke-TestCORS $item


##################
# Preflight test
##################

$item = @{
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://bogus.com", "http://bogus.com", "https://*", "http://*");
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com"});
    "origin"=("https://bogus.com", "http://bogus.com", "https://*", "http://*");
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST"});
    "origin"=("https://bogus.com", "http://bogus.com", "https://*", "http://*");
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "allowAllRequestedHeaders"="false";
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "allowAllRequestedHeaders"="false";
    "maxAge" = "-1";
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "allowAllRequestedHeaders"="false";
    "maxAge" = "0";
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item

$item = @{
    "request_method"="OPTIONS";
    "headers"=(@{"Origin"="http://foo.com";"Access-Control-Request-Method"="POST";"Access-Control-Request-Headers"="x, y, z"});
    "origin"=("http://foo.com", "http://bar.com");
    "allowMethod"=("m_foo", "m_bar");
    "allowCredentials"="false";
    "exposeHeader"=("e_foo","e_bar")
    "allowHeader"=("a_foo","a_bar")
    "allowAllRequestedHeaders"="false";
    "maxAge" = "2147483647";
    "expectedStatusCode"=204;
    "expectedAccessControlAllowOrigin"="http://foo.com";     
}
Invoke-TestCORS $item