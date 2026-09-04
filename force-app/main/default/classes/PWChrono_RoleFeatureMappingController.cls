@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class PWChrono_RoleFeatureMappingController {
  private static void requireAdminAccessForGuest(
    String callerPortalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }

    Id verifiedPortalUserId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      callerPortalUserId,
      sessionToken
    );
    Portal_Users__c caller = [
      SELECT Role__c, Access_Features__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];
    Boolean isAdminRole =
      caller.Role__c == 'HR Admin' ||
      caller.Role__c == 'System Admin';
    Boolean hasAdminFeature = hasFeature(
      caller.Access_Features__c,
      'Admin Settings'
    );
    if (!isAdminRole && !hasAdminFeature) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  private static Boolean hasFeature(String accessFeatures, String featureName) {
    if (String.isBlank(accessFeatures) || String.isBlank(featureName)) {
      return false;
    }
    for (String part : accessFeatures.split('\\s*;\\s*')) {
      if (part == featureName) {
        return true;
      }
    }
    return false;
  }

  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Role_Feature_Mapping__mdt> getMappings(
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminAccessForGuest(callerPortalUserId, sessionToken);
    return [
      SELECT Id, MasterLabel, Role__c, Feature__c
      FROM PWChrono_Role_Feature_Mapping__mdt
      ORDER BY Role__c, Feature__c
    ];
  }

  @AuraEnabled
  public static void saveMapping(
    String role,
    String feature,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      requireAdminAccessForGuest(callerPortalUserId, sessionToken);
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
  public static void deleteMapping(
    String mappingName,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      requireAdminAccessForGuest(callerPortalUserId, sessionToken);
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