<#
.SYNOPSIS
    A script to enumerate AD groups and members and populate an IT Glue Flexible Asset.

.DESCRIPTION
    Generate report for all Active Directory objects.

.PARAMETER APIKey
    API Key Obtained from IT Glue in Account->Settings->API Keys

.PARAMETER OrgID
    Organization ID located at the end of the IT Glue URL for the organization.

.NOTES
    Script Originally Created by CyberDrain- Kelvin Tegelaar
    Modified By: Noaxxess
    Added: Parameters, comments, formatting, logic to check if group member are users or computers, function to match configs and tag. Also took API call to get all Assets out of the main Foreach loop and created function that matches flexible asset names and returns Flexible asset IDs
    Date: 04/25/2023

#>


param (
    #IT Glue API Key, not required if already added via 'Add-ITGlueAPIKey' command.
    [Parameter(ValueFromPipeline = $true, HelpMessage = "API Key")]
    [String]$APIKey,
    #IT Glue Organization ID
    [Parameter(ValueFromPipeline = $true, Mandatory = $true, HelpMessage = "Organization ID")]
    [String]$OrgID
)

#Check if ITGlueAPI Module Exists. If not, install/import it
if (!(Get-Module -ListAvailable -Name "ITGlueAPI")) {
    Install-Module 'ITGlueAPI' -Force
}

#Check if ActiveDirectory module is present. If not install/import it.
if (Get-Module -ListAvailable -Name "ActiveDirectory") {
    Import-Module 'ActiveDirectory'
}
else {
    Install-Module Import-Module 'ActiveDirectory' -Force
    Import-Module Import-Module 'ActiveDirectory'
}

#Function to return IT Glue Configuration IDs based on Names
function Get-ITGlueConfigurationID {
    param (
        [string]$Name,
        [array]$Configurations
    )

    foreach ($config in $Configurations) {
        #If your tenant uses FQDN instead of HostNames use the this line to split on period and get the hostname.
        $ConfigName = ($Config.attributes.Name).Split('.')[0]
        if ($ConfigName -eq $Name) {
            return $Config.Id
        }
    }
}

function Get-ITGlueFlexAssetID {
    param ( 
        [Object[]]$FlexAssets,   
        [string]$AssetName
    )

    foreach ($FlexAsset in $FlexAssets) {
        $FlexAssetName = $FlexAsset.attributes.traits.'group-name'
        if ($FlexAssetName -eq $($AssetName)) {
            return $FlexAsset.id
        }
    }
}

#Set Variables
$APIEndpoint = "https://api.itglue.com"
$FlexAssetName = "AutoDoc- Active Directory Groups v3"
$Description = "Lists all groups and users in them."



#####################################################################

#Set TLS to 1.2
[System.Net.ServicePointManager]::SecurityProtocol = 'TLS12'

# Set IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKey

# Checking if the FlexibleAsset Type exists.
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data

# If the Flexible Asset Type does not exist create a new one
if (!$FilterID) {
    $NewFlexAssetData = @{
        type          = 'flexible-asset-types'
        attributes    = @{
            name        = $FlexAssetName
            icon        = 'sitemap'
            description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "Group Name"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 2
                            name           = "Members"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "GUID"
                            kind           = "Text"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Tagged Users"
                            kind           = "Tag"
                            "tag-type"     = "Contacts"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Tagged Configurations"
                            kind           = "Tag"
                            "tag-type"     = "Configurations"
                            required       = $false
                            "show-in-list" = $false
                        } 
                    }
                )
            }
        }
    }
    # Write-Host "Creating New Flexible Asset Type"
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
}

#Get Existing Assets from IT Glue
$ITGlueFlexAssets = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID -page_size 1000).data

#Get Existing Configurations fro IT GLue 
$ITGlueConfigs = (Get-ITGlueConfigurations -organization_id $OrgID -page_size 1000).data

# Get all AD Groups
$AllGroups = Get-AdGroup -filter *

#Loop Through Groups and populate flex asset body
foreach ($Group in $AllGroups) {
    
    #Set Arrays for Asset Tags
    $Contacts = @()
    $Configs = @()
    $ExistingFlexAsset = ''    
    
    #Get Group Members
    $Members = Get-AdGroupMember $Group
    
    #Save the members into a table formatted with HTML
    $MembersTable = $Members | Select-Object Name, SamAccountName, distinguishedName | ConvertTo-Html -Fragment | Out-String 
    
    #Loop Through Members
    foreach ($Member in $Members) {
        #Get object type to see if the group contains users or computers
        $ObjType = (Get-ADObject -Filter { SamAccountName -eq $Member.SamAccountName }).ObjectClass
        #Test if Member is USer
        if ($ObjType -eq 'User') {
            #See if User in AD has an email address
            $Email = (Get-AdUser $Member -Properties EmailAddress).EmailAddress
            #If user exists in IT Glue, add it to Contacts array 
            if ($Email) {
                $Contacts += (Get-ITGlueContacts -organization_id $OrgID -filter_primary_email $Email -page_size 1000).data.id
            }
        }
        #Check if Member is a Computer
        if ($ObjType -eq 'Computer') {
            #If it is get the computer name from AD
            $ComputerName = (Get-AdComputer $Member -Properties Name).Name
            #Check if the computer name exists
            if ($ComputerName) {
                #Get id using name and array of configurations from IT Glue, if there is a match add the ID to the Configs array
                $Configs += Get-ITGlueConfigurationID -Name $ComputerName -Configurations $ITGlueConfigs 
            }     
        }
    }
    #Add data to flex asset body that will be uploaded to API
    $FlexAssetBody = @{
        type       = 'flexible-assets'
        attributes = @{
            name   = $FlexAssetName
            traits = @{
                "group-name"            = $($Group.Name)
                "members"               = $MembersTable
                "guid"                  = $($Group.ObjectGuid.Guid)
                "tagged-users"          = $Contacts
                "tagged-configurations" = $Configs
            }
        }
    }

    # Get Existing ITGlue Flex Asset Data (if any) and match existing AD group data
    $ExistingFlexAsset = Get-ITGlueFlexAssetID -FlexAssets $ITGlueFlexAssets -AssetName $($group.name) 

    # If the Asset does not exist, we edit the body to be in the form of a new asset
    if (!$ExistingFlexAsset) {
        # Write-Host "Creating new flexible asset"
        $FlexAssetBody.attributes.add('organization-id', $orgID)
        $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
        New-ITGlueFlexibleAssets -data $FlexAssetBody 
    }
    #Otherwise Just Upload the data
    else {
        Set-ITGlueFlexibleAssets -id $ExistingFlexAsset -data $FlexAssetBody
    }    
}
