<#
.SYNOPSIS
    A script to Get General AD info. I did not like the default script created by IT Glue. It didn't seem "automated" enough.

.DESCRIPTION
    Generate report for Active Directory.

.PARAMETER APIKey
    API Key Obtained from IT Glue in Account->Settings->API Keys

.PARAMETER OrgID
    Organization ID located at the end of the IT Glue URL for the organization.

.NOTES
    Created By: Noaxxess
    Date: 04/28/2023

#>


param (

    [Parameter(ValueFromPipeline = $true, Mandatory=$true, HelpMessage = "API Key")]
    [String]$APIKey,
    #IT GLue API Key
    [Parameter(ValueFromPipeline = $true, Mandatory=$true, HelpMessage = "Organization ID")]
    [String]$OrgID
    #IT GLue Organization ID

)

#Set New Flexible Asset Name

#Function to extract hostname from FQDN
function Get-NameFromFQDN {
    param (
        [string]$FQDN
    )
    $DeviceName = $FQDN.Split('.'[0])
}

#Function to get IT Glue Configuration ID
function Get-ITGlueConfigurationID {
    param (
        [string]$Name,
        [array]$Configurations
    )

    foreach ($config in $Configurations) {
        $ConfigName = ($Config.attributes.Name).Split('.')[0]
        if ($ConfigName -eq $Name) {
            return $Config.Id
        }
    }
}

# Get IT Glue Configurations

$ITGConfigs = Get-ITGlueConfigurations -filter_organization_id $OrgId

#Get AD info
# Retrieve the Active Directory forest object
$Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()

# Retrieve the Active Directory domain object
$Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

# Retrieve the domain's directory context
$Context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $domain.Name)

# Retrieve the Active Directory domain information
$DomainInfo = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($context)

# Set Variables
$ADForestName = $($forest.Name)
$ADFunctionalLevel = $((Get-ADDomain -identity $Domain.Name).DomainMode)
$DomainName = $($domain.Name)
$DomainShortName = $($domain.ShortName)
$SchemaMaster = $($forest.SchemaRoleOwner.Name)
$DomainNamingMaster = $($forest.NamingRoleOwner.Name)
$RIDMaster = $($domainInfo.RidRoleOwner.Name)
$PDCEmulator = $($domain.PdcRoleOwner.Name)
$InfrastructureMaster = $($domain.InfrastructureRoleOwner.Name)
$GcServers = @()
# Retrieve the global catalog servers for the domain
$GcServers = $domain.FindAllDiscoverableDomainControllers()

# Store the AD info into a PowerShell object
$adInfo = [PSCustomObject] @{
    ADForestName = $ADForestName
    ADFunctionalLevel = $ADFunctionalLevel
    DomainName = $DomainName
    DomainShortName = $DomainShortName
    SchemaMaster = $SchemaMaster
    DomainNamingMaster = $DomainNamingMaster
    RIDMaster = $RIDMaster
    PDCEmulator = $PDCEmulator
    InfrastructureMaster = $InfrastructureMaster
    GlobalCatalogServers = $GcServers.Name
}

#Add Info to IT Glue Flexible Asset Object

$FlexAssetBody = @{
    type       = 'flexible-assets'
    attributes = @{
        name   = $FlexAssetName
        traits = @{
            "group-name"   = $($Group.Name)
            "members"      = $MembersTable
            "guid"         = $($Group.ObjectGuid.Guid)
            "tagged-users" = $Contacts
            "tagged-configurations" = $Configs
        }
    }
}