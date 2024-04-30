targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@sys.description('Location where to deploy compute services.')
param location string

@sys.description('AVD workload subscription ID, multiple subscriptions scenario.')
param subscriptionId string

@sys.description('Enables a zero trust configuration on the session host disks.')
param diskZeroTrust bool

@sys.description('Enables Encryption At Host on the session host disk.')
param encryptionAtHost bool

@sys.description('Enables Azure Disk Encryption on the session host disk.')
param azureDiskEncryption bool

@sys.description('AVD Resource Group Name for the service objects.')
param serviceObjectsRgName string

@sys.description('AVD Resource Group Name for the service objects.')
param computeObjectsRgName string

@sys.description('This value is used to set the expiration date on the disk encryption key.')
param diskEncryptionKeyExpirationInDays int

@sys.description('This value is used to set the expiration date on the disk encryption key.')
param diskEncryptionKeyExpirationInEpoch int

@sys.description('Deploy private endpoints for key vault and storage.')
param deployPrivateEndpointKeyvaultStorage bool

@sys.description('Key vault private endpoint name.')
param ztKvPrivateEndpointName string

@sys.description('Private endpoint subnet resource ID')
param privateEndpointsubnetResourceId string

@sys.description('Tags to be applied to resources')
param tags object

@sys.description('Tags to be added to key vault')
param kvTags object

@sys.description('Encryption set name')
param diskEncryptionSetName string

@sys.description('Key vault name')
param ztKvName string

@sys.description('Private DNS zone for key vault private endpoint')
param keyVaultprivateDNSResourceId string

@sys.description('Do not modify, used to set unique value for resource deployment.')
param time string = utcNow()

@sys.description('Enable purge protection on the key vault')
param enableKvPurgeProtection bool = true

@sys.description('Specifies the SKU for the vault.')
param vaultSku string

// =========== //
// Variable declaration //
// =========== //
var varCustomPolicyDefinitions = [
    {
        deploymentName: 'ZT-Disk'
        libDefinition: json(loadTextContent('../../../policies/zeroTrust/policyDefinitions/policy-definition-es-vm-disk-zero-trust.json'))
    }
]
// =========== //
// Deployments //
// =========== //

// Policy Definition for Managed Disk Network Access.
module ztPolicyDefinitions '../../../../carml/1.3.0/Microsoft.Authorization/policyDefinitions/subscription/deploy.bicep' = [for customPolicyDefinition in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: subscription('${subscriptionId}')
    name: 'Policy-Defin-${customPolicyDefinition.deploymentName}-${time}'
    params: {
        description: customPolicyDefinition.libDefinition.properties.description
        displayName: customPolicyDefinition.libDefinition.properties.displayName
        location: location
        name: customPolicyDefinition.libDefinition.name
        metadata: customPolicyDefinition.libDefinition.properties.metadata
        mode: customPolicyDefinition.libDefinition.properties.mode
        parameters: customPolicyDefinition.libDefinition.properties.parameters
        policyRule: customPolicyDefinition.libDefinition.properties.policyRule
    }
}]

// Policy Assignment for Managed Disk Network Access.
module ztPolicyAssignmentServiceObjects '../../../../carml/1.3.0/Microsoft.Authorization/policyAssignments/resourceGroup/deploy.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: resourceGroup('${subscriptionId}', '${serviceObjectsRgName}')
    name: 'Pol-Assign-ServObj${customPolicyDefinition.deploymentName}-${time}'
    params: {
        name: customPolicyDefinition.libDefinition.name
        displayName: customPolicyDefinition.libDefinition.properties.displayName
        description: customPolicyDefinition.libDefinition.properties.description
        identity: 'SystemAssigned'
        location: location
        policyDefinitionId: diskZeroTrust ? ztPolicyDefinitions[i].outputs.resourceId : ''
        resourceSelectors: [
            {
                name: 'VirtualMachineDisks'
                selectors: [
                    {
                        in: [
                            'Microsoft.Compute/disks'
                        ]
                        kind: 'resourceType'
                    }
                ]
            }
        ]
    }
}]

// Policy Remediation Task for Zero Trust.
module ztPolicyServBojRemediationTask '../azurePolicyAssignmentRemediation/deploy.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: resourceGroup('${subscriptionId}', '${serviceObjectsRgName}')
    name: 'Remm-ServObj-${customPolicyDefinition.deploymentName}-${i}'
    params: {
        deploymentName: '${customPolicyDefinition.deploymentName}-${i}'
        policyAssignmentId: diskZeroTrust ? ztPolicyAssignmentServiceObjects[i].outputs.resourceId : ''
    }
}]

// Policy Assignment for Managed Disk Network Access.
module ztPolicyAssignmentCompute '../../../../carml/1.3.0/Microsoft.Authorization/policyAssignments/resourceGroup/deploy.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
    name: 'Pol-Assign-Comp-${customPolicyDefinition.deploymentName}-${time}'
    params: {
        name: customPolicyDefinition.libDefinition.name
        displayName: customPolicyDefinition.libDefinition.properties.displayName
        description: customPolicyDefinition.libDefinition.properties.description
        identity: 'SystemAssigned'
        location: location
        policyDefinitionId: diskZeroTrust ? ztPolicyDefinitions[i].outputs.resourceId : ''
        resourceSelectors: [
            {
                name: 'VirtualMachineDisks'
                selectors: [
                    {
                        in: [
                            'Microsoft.Compute/disks'
                        ]
                        kind: 'resourceType'
                    }
                ]
            }
        ]
    }
}]

// Policy Remediation Task for Zero Trust.
module ztPolicyComputeRemediationTask '../azurePolicyAssignmentRemediation/deploy.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
    name: 'Remm-Comp-${customPolicyDefinition.deploymentName}-${i}'
    params: {
        deploymentName: '${customPolicyDefinition.deploymentName}-${i}'
        policyAssignmentId: diskZeroTrust ? ztPolicyAssignmentCompute[i].outputs.resourceId : ''
    }
}]

// Role Assignment for Zero Trust.
module ztRoleAssignmentCompute '../../../../carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
    name: 'ZT-RA-Comp-${customPolicyDefinition.deploymentName}-${time}'
    params: {
        principalId: diskZeroTrust ? ztPolicyAssignmentCompute[i].outputs.principalId : ''
        roleDefinitionIdOrName: 'Disk Pool Operator'
        principalType: 'ServicePrincipal'
    }
}]

// Role Assignment for Zero Trust.
module ztRoleAssignmentServObj '../../../../carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: if (diskZeroTrust == true) {
    scope: resourceGroup('${subscriptionId}', '${serviceObjectsRgName}')
    name: 'ZT-RA-ServObj-${customPolicyDefinition.deploymentName}-${time}'
    params: {
        principalId: diskZeroTrust ? ztPolicyAssignmentServiceObjects[i].outputs.principalId : ''
        roleDefinitionIdOrName: 'Disk Pool Operator'
        principalType: 'ServicePrincipal'
    }
}]

// Role Assignment for Zero Trust.
module ztRoleAssignment '../../../../carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = if (encryptionAtHost) {
    scope: resourceGroup('${subscriptionId}', '${serviceObjectsRgName}')
    name: 'ZT-RoleAssign-${time}'
    params: {
        principalId: encryptionAtHost ? ztKeyVault.outputs.ztDiskEncryptionSetPrincipalId : ''
        roleDefinitionIdOrName: 'Key Vault Crypto Service Encryption User'
        principalType: 'ServicePrincipal'
    }
}

// Zero trust key vault.
module ztKeyVault './.bicep/zeroTrustKeyVault.bicep' = if (azureDiskEncryption || encryptionAtHost) {
    scope: resourceGroup('${subscriptionId}', '${serviceObjectsRgName}')
    name: 'ZT-Key-Vault-${time}'
    params: {
        location: location
        subscriptionId: subscriptionId
        rgName: serviceObjectsRgName
        kvName: ztKvName
        vaultSku: vaultSku
        deployPrivateEndpointKeyvaultStorage: deployPrivateEndpointKeyvaultStorage
        ztKvPrivateEndpointName: ztKvPrivateEndpointName
        privateEndpointsubnetResourceId: privateEndpointsubnetResourceId
        keyVaultprivateDNSResourceId: keyVaultprivateDNSResourceId
        diskEncryptionKeyExpirationInDays: diskEncryptionKeyExpirationInDays
        diskEncryptionKeyExpirationInEpoch: diskEncryptionKeyExpirationInEpoch
        diskEncryptionSetName: diskEncryptionSetName
        tags: union(tags, kvTags)
        enableKvPurgeProtection: enableKvPurgeProtection
    }
}

// =========== //
// Outputs //
// =========== //

output ztDiskEncryptionSetResourceId string = encryptionAtHost ? ztKeyVault.outputs.ztDiskEncryptionSetResourceId : ''
output ztKeyVaultUri string = (azureDiskEncryption || encryptionAtHost) ? ztKeyVault.outputs.ztKeyVaultUri : ''
output ztKeyVaultResourceId string = (azureDiskEncryption || encryptionAtHost) ? ztKeyVault.outputs.ztKeyVaultResourceId : ''
output ztKeyVaultKeyUri string = (azureDiskEncryption || encryptionAtHost) ? ztKeyVault.outputs.ztKeyVaultKeyUri : ''
