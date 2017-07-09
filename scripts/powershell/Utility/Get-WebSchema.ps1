########################################################################################################################
# NAME
#     Get-WebSchema
#
# SYNOPSIS
#     Returns IIS config section, attributes and methods for a specific IIS Schema file, or
#     a list of file names and config section names that are available.
#
# SYNTAX
#     Get-WebSchema [-fileName] <string> [-sectionName] <string> 
#     Get-WebSchema [[-filename] <string>] -list
#
# DETAILED DESCRIPTION
#     The Get-WebSchema function returns config section, attributes and methods information.
#
# PARAMETERS
#     -fileName <string>
#         Specifies the full path of schema file
#
#         Required?                    true
#         Position?                    1
#         Default value
#         Accept pipeline input?       false
#         Accept wildcard characters?  false
#
#     -sectionName <string>
#         Specifies the identifier of the IIS config section of IIS Schema files
#
#         Required?                    false
#         Position?                    2
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
#     -verbose <Switch>
#         When this parameter is used by itself, this function shows different ItemXpath result with tokenized values
#         for sectionname  | elementname or [collectionname].
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
#     C:\PS>Get-WebSchema -list
#
#
#     This command retrieves the list of schema files that are available.
#
#
#     -------------------------- EXAMPLE 2 --------------------------
#
#     C:\PS>Get-WebSchema -list -fileName "d:\windows\system32\inetsrv\config\schema\IIS_schema.xml"
#
#
#     This command retrieves the list of sections that are available for IIS_Schema.xml file.
#
#
#     -------------------------- EXAMPLE 3 --------------------------
#
#     C:\PS>Get-WebSchema -list -fileName "d:\windows\system32\inetsrv\config\schema\IIS_schema.xml" -sectionName system.webServer/asp
#
#
#     This command retrieves an xml node object for the asp section in Iis_Schema.xml file.
#
#
#     -------------------------- EXAMPLE 4 --------------------------
#
#     C:\PS>Get-WebSchema -fileName "d:\windows\system32\inetsrv\config\schema\IIS_schema.xml" -sectionName system.webServer/asp
#
#
#     This command list all config information (Ie. attribute/method/element/collection) of the asp section
#
#
#     -------------------------- EXAMPLE 5 --------------------------
#
#     C:\PS>Get-WebSchema -fileName "d:\windows\system32\inetsrv\config\schema\IIS_schema.xml"
#
#
#     This command list all config information (Ie. attribute/method/element/collection) of the IIS_Schema file
#
#

function global:Get-WebSchema()
{
    param(
        [string]$fileName=$null,
        [string]$sectionName=$null,
        [object]$nodeObject=$null,
        [switch]$list,
        [switch]$verbose
    )

    if ($list -and $sectionName -and -not $fileName)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if ($list -and $recurse)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if ($sectionName -and -not $fileName)
    {
        throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
    }

    if ($list)
    {
        if ($sectionName)
        {
            [xml]$xml = Get-Content $filename
            $rootNode = $xml.get_documentElement()
            $rootNode.sectionSchema | ForEach-Object {
                $nodeObject = $_                
                if ($nodeObject.name.tolower() -eq $sectionName.tolower())
                {                  
                    $nodeObject
                }
            }             
        }
        else
        {
            if ($fileName)
            {
                [xml]$xml = Get-Content $filename
                $rootNode = $xml.get_documentElement()
                $rootNode.sectionSchema | ForEach-Object {
                    $sectionName = $_.name
                    $sectionName
                }           
            }
            else
            {
                Get-ChildItem "$env:windir\system32\inetsrv\config\schema" -filter *.xml | ForEach-Object {
                    $filePath = $_.fullname
                    $filePath
                }
            }
        }    
    }
    else
    {
        if (-not $fileName -and -not $nodeObject) {
            throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'fileName')
        }

        if (-not $nodeObject)
        {
            [xml]$xml = Get-Content $filename
            $rootNode = $xml.get_documentElement()
            $rootNode.sectionSchema | ForEach-Object {
                $nodeObject = $_
                if ((-not $sectionName) -or ($nodeObject.name.tolower() -eq $sectionName.tolower()))
                {
                    Get-WebSchema -nodeObject $_ -filename $fileName -sectionName $nodeObject.name -verbose:$verbose
                }
            }            
        }       
        else
        {
            ("element", "collection", "attribute", "method") | ForEach-Object {
                $type = $_.tostring()
                if ($nodeObject.$type -ne $null) 
                {   
                    $nodeObject.$type | ForEach-Object {
                         $leafObject = $_
                         $output = new-object psobject
                         if ($type -eq "collection") 
                         {
                             $name = $leafObject.addElement
                             if ($verbose)
                             {
                                 $name = "[name]"
                             }
                         }
                         else
                         {
                             $name = $leafObject.name
                         }                        

                         $ItemXPath = $null
                         if ($verbose)
                         {
                             $ItemXPath = ($sectionName+"//"+$name)
                         }
                         else
                         {
                             $ItemXPath = ($sectionName+"/"+$name)
                         }
                         add-member -in $output noteproperty ItemXPath $ItemXPath
                         add-member -in $output noteproperty Name $name
                         add-member -in $output noteproperty XmlObject $leafObject
                         add-member -in $output noteproperty Type $leafObject.toString()
                         add-member -in $output noteproperty ParentXPath $sectionName
                         $output

                         if ($type -eq "element" -or $type -eq "collection") 
                         {
                             Get-WebSchema -nodeObject $_ -filename $fileName -sectionName $ItemXPath -verbose:$verbose
                         }
                    }
                }
            }
        }
    }
}
