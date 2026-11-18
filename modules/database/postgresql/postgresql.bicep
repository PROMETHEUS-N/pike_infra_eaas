@description('PostgreSQL Flexible Server name. Must be globally unique in Azure.')
param serverName string

@description('Azure region. Must match the VNet region for VNet-integrated private access.')
param location string

@description('PostgreSQL administrator login name.')
param administratorLogin string

@secure()
@description('PostgreSQL administrator password.')
param administratorLoginPassword string

@description('PostgreSQL major version.')
@allowed([
  '14'
  '15'
  '16'
])
param version string

@description('Compute SKU name.')
param skuName string

@description('Compute tier.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string

@description('PostgreSQL storage size in GB.')
@minValue(32)
param storageSizeGB int

@description('Backup retention in days.')
@minValue(7)
@maxValue(35)
param backupRetentionDays int

@description('Existing VNet name.')
param vnetName string

@description('Dedicated subnet name.')
param subnetName string

@description('Dedicated subnet CIDR.')
param subnetAddressPrefix string

@description('Private DNS zone.')
param privateDnsZoneName string

@description('Private DNS VNet link name.')
param privateDnsZoneLinkName string

@description('Resource tags.')
param tags object

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vnetName
}

resource postgresqlSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: existingVnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    delegations: [
      {
        name: 'postgresql-flexible-server-delegation'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: privateDnsZoneLinkName
  location: 'global'

  properties: {
    virtualNetwork: {
      id: existingVnet.id
    }
    registrationEnabled: false
  }
}

//resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: serverName
  location: location
  tags: tags

  sku: {
    name: skuName
    tier: skuTier
  }

  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version

    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: 'Disabled'
    }

    highAvailability: {
      mode: 'Disabled'
    }

    network: {
      delegatedSubnetResourceId: postgresqlSubnet.id
      privateDnsZoneArmResourceId: privateDnsZone.id
    }

    storage: {
      storageSizeGB: storageSizeGB
    }
  }

  dependsOn: [
    privateDnsVnetLink
  ]
}

output serverId string = postgresqlServer.id
output serverNameOut string = postgresqlServer.name
output fullyQualifiedDomainName string = postgresqlServer.properties.fullyQualifiedDomainName
output delegatedSubnetId string = postgresqlSubnet.id
output privateDnsZoneId string = privateDnsZone.id
