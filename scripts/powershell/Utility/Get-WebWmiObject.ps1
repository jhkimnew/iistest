########################################################################################################################
# NAME
#     Get-WebWmiObject
#
# SYNOPSIS
#     Returns IIS Wmi Object, or a list of properties and methods that are available.
#
# SYNTAX
#     Get-WebWmiObject [-sectionName] <string> 
#
# DETAILED DESCRIPTION
#     The Get-WebWmiObject returns IIS Wmi Ojbects using IIS config section name which can be used for both
#     IIS powershell provider cmdlets and Get-WebSchema cmdlet of this script.
#
# PARAMETERS
#     -sectionName <string>
#         Specifies the identifier of the IIS config section of IIS Schema files
#
#         Required?                    false
#         Position?                    1
#         Default value
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
#     -list <Switch>
#         When this parameter is used by itself, this function outputs the root names that are available. When this
#         parameter is used in conjunction with the fileName parameter, this function outputs the sections
#         that are availab.e
#
#         Required?                    false
#         Position?                    named
#         Default value                false
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
# INPUT TYPE
#     String,Switch
#
# RETURN TYPE
#     String,String[],PsObject[]
#
# NOTES
#     For more information the IIS schema file consult the relevant MSDN documentation or visit http:\\iis.net website.
#
#     -------------------------- EXAMPLE 1 --------------------------
#
#     C:\PS>Get-WebWmiObject -list
#
#
#     This command retrieves the list of section names that are available in WebAdministration WMI.
#
#
#     -------------------------- EXAMPLE 2 --------------------------
#
#     C:\PS>Get-WebWmiObject 
#
#
#     This command retrieves all of the WMI object methods and attributes that are available in webadministration WMI.
#
#
#     -------------------------- EXAMPLE 3 --------------------------
#
#     C:\PS>Get-WebWmiObject -sectionName system.webServer/modules
#
#
#     This command retrieves the WMI object method and attribute that are available in webadministration WMI for system.webServer/modules config section.
#
#

$global:GetWMIOBJECT_CollectoinInfoArray = $null
function global:Get-WebWmiObject()
{    
    param(
        [string]$sectionName=$null,
        [string]$className=$null,
        [object]$nodeObject=$null,
        [switch]$list
    )

    if ($global:GetWMIOBJECT_CollectoinInfoArray -eq $null)
    {
        $schemaFileNameArray = Get-WebSchema -list
        $schemaObjectArray = $schemaFileNameArray | foreach {get-webschema -fileName $_ } 
        $global:GetWMIOBJECT_CollectoinInfoArray = $schemaObjectArray | foreach { 
             if ($_.type -eq "collection") {
                 $_
             } 
        }
    }

    if ($list -and $sectionName)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if (-not $nodeObject)
    {
        if (-not $className) {
            $wmi_classes = Get-WmiObject -namespace "root/webadministration" -list
            $wmi_classes | foreach {
                $nodeObeject = $_
                $nodeObeject.qualifiers | ForEach-Object {
                    $qualifier = $_
                    if ($qualifier.name -and $qualifier.value -and $qualifier.name.tolower() -eq "section_path")
                    { 
                        if (-not $list)
                        {
                            if (-not $sectionName -or $qualifier.value.tolower() -eq $sectionName)
                            {
                                Get-WebWmiObject -nodeObject $nodeObeject -sectionName $qualifier.value
                            }
                        }
                        else
                        {
                            $qualifier.value
                        }                    
                    }
                }
            } 
        }
        else
        {
            $wmi_classes = Get-WmiObject -namespace "root/webadministration" -list
            $global:targetNode = $null
            $wmi_classes | foreach {
                $nodeObeject = $_
                if (($targetNode -eq $null) -and ($nodeObeject.name.tolower() -eq $className))
                {   
                    $global:targetNode = $_                   
                    Get-WebWmiObject -nodeObject $targetNode -sectionName $sectionName 
                }
            } 
        }
    }
    else
    {
        if (-not $sectionName) {
            throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'sectionName')
        }      
         
        ("properties", "methods") | ForEach-Object {
            $type = $_            
            $nodeObeject.$type | ForEach-Object {  
                $leafObject = $_
                $qualifier = $leafObject.qualifiers | select -first 1
                $name = $leafObject.name.trim()
                $name = $name.substring(0,1).tolower() + $name.substring(1)
                
                #
                # replace "sites/" to "sites/site"
                #
                $sitesSectionPath = "system.applicationHost/sites/"
                if ($sectionName.indexof($sitesSectionPath) -eq 0)
                {
                    if ($sectionName.indexof(($sitesSectionPath + "site/")) -eq -1)
                    {
                        $sectionName = $sitesSectionPath + "site/" + $sectionName.substring($sitesSectionPath.length)
                    }
                }
        
                $index = -1
                if (($qualifier -ne $null) -and ($qualifier.Name.trim().ToUpper() -eq "CIMTYPE"))
                {
                    $index = $qualifier.Value.trim().indexof("object:")                 
                }
                if ($index -eq 0)
                {
                    $className = $qualifier.Value.trim().subString("object:".length)
                    if ($className.tolower() -ne "SectionInformation".tolower())
                    {
                        $newSectionName = $sectionName + "/" + $name
                        $collectionObject = $null
                        $global:GetWMIOBJECT_CollectoinInfoArray | foreach {
                            if ($_.ParentXPath.tolower() -eq $sectionName.tolower())
                            {
                                $collectionObject = $_
                            }
                        }
                        if ($collectionObject -ne $null)
                        {
                            $tokens = $collectionObject.ItemXpath.split("/")
                            $parentSectionName = $tokens | select -last 2 | select -first 1

                            #
                            # if this this collection, use addElement value instead
                            #
                            if (($parentSectionName -ne $null) -and ($parentSectionName -eq $name))
                            {
                                $newSectionName = $sectionName + "/" + $collectionObject.name 
                            }
                        } 
                        Get-WebWmiObject -className $className -sectionName $newSectionName
                    }
                }
                else
                {
                    $output = new-object psobject
                    
                    add-member -in $output noteproperty ItemXPath ($sectionName+"/"+$name)
                    add-member -in $output noteproperty Name $name
                    add-member -in $output noteproperty WmiObject $leafObject
                    $output
                }
            }
        }
    }
}
