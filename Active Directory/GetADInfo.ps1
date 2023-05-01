#Parameters
param(
    [string]$APIKey;
    [string]
)

#Retrieve IT Glue Configurations

# Retrieve the Active Directory forest object
$forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()

# Retrieve the Active Directory domain object
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

# Retrieve the domain's directory context
$context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $domain.Name)

# Retrieve the Active Directory domain information
$domainInfo = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($context)

# Set Variables
Write-Host "ADForestName: $($forest.Name)"
Write-Host "ADFunctionalLevel: $((Get-ADDomain -identity $Domain.Name).DomainMode)"
Write-Host "DomainName: $($domain.Name)"
Write-Host "DomainShortName: $($domain.ShortName)"
$SchemaMaster = $($forest.SchemaRoleOwner.Name)
$DomainNamingMaster = $($forest.NamingRoleOwner.Name)
$RIDMaster = $($domainInfo.RidRoleOwner.Name)
$PDCEmulator = $($domain.PdcRoleOwner.Name)
$InfrastructureMaster = $($domain.InfrastructureRoleOwner.Name)
$gcServers = @()
# Retrieve the global catalog servers for the domain
$gcServers = $domain.FindAllDiscoverableDomainControllers()

function getHostNameFromFQDN {
    param (
        [string]$FQDN
    )
    $HostName = $FQDN.Split('.'[0])
}
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
 #Loop through configurations to find matching names



#Set Flex Asset Attributes
$api__body = @{
    type = "flexible_assets"
    attributes = @{
        organization_id = $OrgId
        flexible_asset_type_id = $api_config.flexible_asset_type_id
        traits = @{
            $api__key_name_ADForestName = $ADForestName
            $api__key_name_ADFunctionalLevel = $ADFunctionalLevel
            $api__key_name_DomainName = $Domain
            $api__key_name_DomainShortName = $ADShortName
            $api__key_name_SchemaMaster = $api__SchemaMaster_id
            $api__key_name_DomainNamingMaster = $api__DomainNamingMaster_id
            $api__key_name_RIDMaster = $api__RIDMaster_id
            $api__key_name_PDCEmulator = $api__PDCEmulator_id
            $api__key_name_InfrastructureMaster = $api__InfrastructureMaster_id
            $api__key_name_GlobalCatalogServers = $api__GlobalCatalogs
        }
    }
}


#find if a flex asset for this domain currently exists
$currentADFlexAssets = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $api__flexible_asset_type_id -filter_organization_id $OrgId)



$api__flex_asset_id = ''
if($currentADFlexAssets.data.attributes.traits.${api_DomainName}) {
    $fa_index = [array]::indexof($currentADFlexAssets.data.attributes.traits.${api__key_name_DomainName} ,$Domain)

    if($fa_index -ne '-1') {
        $api__flex_asset_id = $currentADFlexAssets.data[$fa_index].id
    }
    if($api__flex_asset_id -and $OrgId) {
        Write-Host "Flexible Asset id found! Updating the pre-existing flex asset with any new changes."

        (Set-ITGlueFlexibleAssets -id $api__flex_asset_id -data $api__body).data
    }
    elseif($OrgId) {
        Write-Host "No flexible asset id was found... creating a new flexible asset."

        $api__output_data = New-ITGlueFlexibleAssets -data $api__body

        $api__output_data.data
    }