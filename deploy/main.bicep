@description('Name of the log analytics workspace')
param logAnalyticsName string

@description('Name of the connected Container Registry')
param containerRegistryName string

@description('Name of the Container App Environment')
param containerAppEnvName string

@description('Name of the Book Store Container App')
param bookApiContainerName string

@description('Name of the Cosmos DB account')
param cosmosDBAccountName string

@description('Name of the Database inside Cosmos DB')
param databaseName string

@description('Name of the Container inside Cosmos DB')
param containerName string

param location string = resourceGroup().location

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource containerAppEnvironment 'Microsoft.Web/kubeEnvironments@2021-03-01' = {
  name: containerAppEnvName
  location: location 
  kind: 'containerenvironment'
  properties: {
    environmentType: 'managed'
    internalLoadBalancerEnabled: false
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource bookApiContainerApp 'Microsoft.Web/containerApps@2021-03-01' = {
  name: bookApiContainerName
  location: location
  properties: {
    kubeEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistryName
          username: containerRegistry.properties.loginServer
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: bookApiContainerName
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }         
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

module cosmosDb 'modules/cosmosDB.bicep' = {
  name: cosmosDBAccountName
  params: {
    containerName: containerName
    cosmosDBAccountName: cosmosDBAccountName
    databaseName: databaseName
    location: location
  }
}
