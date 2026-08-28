@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_RoleFeatureMappingController {
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Role_Feature_Mapping__mdt> getMappings() {
    // Security Check
    return [
      SELECT Id, MasterLabel, Role__c, Feature__c
      FROM PWChrono_Role_Feature_Mapping__mdt
      ORDER BY Role__c, Feature__c
    ];
  }

  @AuraEnabled
  public static void saveMapping(String role, String feature) {
    try {
      Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
      // Sanitize role and feature for API name
      String safeRole = role.replaceAll('[^a-zA-Z0-9]', '_');
      String safeFeature = feature.replaceAll('[^a-zA-Z0-9]', '_');
      customMetadata.fullName =
        'PWChrono_Role_Feature_Mapping.' +
        safeRole +
        '_' +
        safeFeature;
      customMetadata.label = role + ' ' + feature;

      Metadata.CustomMetadataValue roleValue = new Metadata.CustomMetadataValue();
      roleValue.field = 'Role__c';
      roleValue.value = role;

      Metadata.CustomMetadataValue featureValue = new Metadata.CustomMetadataValue();
      featureValue.field = 'Feature__c';
      featureValue.value = feature;

      customMetadata.values.add(roleValue);
      customMetadata.values.add(featureValue);

      Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
      mdContainer.addMetadata(customMetadata);

      Metadata.Operations.enqueueDeployment(
        mdContainer,
        new PWChrono_Mdt_Deploy_Callback()
      );
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void deleteMapping(String mappingName) {
    try {
      Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
      customMetadata.fullName = 'PWChrono_Role_Feature_Mapping.' + mappingName;

      Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
      mdContainer.addMetadata(customMetadata);

      Metadata.Operations.enqueueDeployment(
        mdContainer,
        new PWChrono_Mdt_Deploy_Callback()
      );
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}