/**
 * @description Controller for Portal Configuration and Feature Management
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_ConfigurationController {
  // --- Guest portal authorization helpers (Configuration/Admin) ---
  private static void requireAdminSettingsAccessForGuest(
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
      SELECT Id, Access_Features__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];

    if (!hasFeature(caller.Access_Features__c, 'Admin Settings')) {
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

  /**
   * @description Retrieves all portal users with their feature access configuration
   * @return List<UserConfiguration> List of user configurations
   */
  @AuraEnabled(cacheable=true)
  public static List<UserConfiguration> getAllUsersWithAccess(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getAllUsersWithAccessCore();
  }

  private static List<UserConfiguration> getAllUsersWithAccessCore() {
    // NOPMD - Complexity acceptable for business logic
    try {
      // Security Check

      Map<Id, UserConfiguration> userConfigMap = new Map<Id, UserConfiguration>();

      // Get all portal users
      List<Portal_Users__c> portalUsers = [
        // NOPMD
        SELECT
          Id,
          Name,
          Email__c,
          Phone__c,
          Role__c,
          Department__c,
          Designation__c,
          Is_Active__c,
          Photo_Url__c,
          User__r.Email,
          Last_Login_Date__c
        FROM Portal_Users__c
        ORDER BY Name
        LIMIT 1000
      ];

      // Initialize user configurations
      for (Portal_Users__c pu : portalUsers) {
        UserConfiguration config = new UserConfiguration();
        config.userId = pu.Id;
        config.userName = pu.Name;
        config.userEmail = pu.Email__c != null
          ? pu.Email__c
          : (pu.User__r != null &&
              pu.User__r.Email != null
              ? pu.User__r.Email
              : '');
        config.profileName = pu.Role__c != null ? pu.Role__c : 'N/A';
        config.designation = pu.Designation__c != null
          ? pu.Designation__c
          : 'N/A';
        config.department = pu.Department__c != null ? pu.Department__c : 'N/A';
        config.isActive = pu.Is_Active__c != null ? pu.Is_Active__c : false;
        config.photoUrl = pu.Photo_Url__c;
        config.lastLoginDate = pu.Last_Login_Date__c;
        config.featureAccess = new List<FeatureAccessWrapper>();
        userConfigMap.put(pu.Id, config);
      }

      // Get feature access records
      List<PWChrono_User_Feature_Access__c> accessRecords = [
        // NOPMD
        SELECT
          Id,
          Portal_User__c,
          Feature_Name__c,
          Access_Level__c,
          Is_Active__c
        FROM PWChrono_User_Feature_Access__c
        WHERE Portal_User__c IN :userConfigMap.keySet()
      ];

      // Map feature access to portal users
      for (PWChrono_User_Feature_Access__c accessRecord : accessRecords) {
        if (userConfigMap.containsKey(accessRecord.Portal_User__c)) {
          FeatureAccessWrapper feature = new FeatureAccessWrapper();
          feature.featureAccessId = accessRecord.Id;
          feature.featureName = accessRecord.Feature_Name__c;
          feature.accessLevel = accessRecord.Access_Level__c;
          feature.isActive = accessRecord.Is_Active__c;
          userConfigMap.get(accessRecord.Portal_User__c)
            .featureAccess.add(feature);
        }
      }

      return userConfigMap.values();
    } catch (Exception e) {
      PWChrono_Logger.error('Error retrieving user configurations: ');
      return new List<UserConfiguration>();
    }
  }

  /**
   * @description Retrieves available features from the picklist
   * @return List<String> List of feature names
   * @throws AuraHandledException if features cannot be retrieved
   */
  @AuraEnabled(cacheable=true)
  public static List<String> getAvailableFeatures(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getAvailableFeaturesCore();
  }

  private static List<String> getAvailableFeaturesCore() {
    List<String> features = new List<String>();
    try {
      Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe()
        .get('PWChrono_User_Feature_Access__c')
        .getDescribe(); // NOPMD
      List<Schema.PicklistEntry> picklistValues = new List<Schema.PicklistEntry>();
      try {
        // Try to get the picklist values dynamically
        Map<String, Schema.SObjectField> fieldMap = describeResult.getSObjectType()
          .getDescribe()
          .fields.getMap(); // NOPMD

        if (fieldMap == null || !fieldMap.containsKey('Feature_Name__c')) {
          throw new AuraHandledException(
            'Feature_Name__c field not found on PWChrono_User_Feature_Access__c object'
          );
        }

        Schema.DisplayType dt = fieldMap.get('Feature_Name__c')
          .getDescribe()
          .getType();
        if (dt == Schema.DisplayType.PICKLIST) {
          picklistValues = fieldMap.get('Feature_Name__c')
            .getDescribe()
            .getPicklistValues(); // NOPMD
        } else {
          throw new AuraHandledException(
            'Feature_Name__c is not a picklist field'
          );
        }
      } catch (AuraHandledException ahe) {
        // Re-throw AuraHandledExceptions
        throw ahe;
      } catch (Exception e) {
        // Log and throw details for schema-related errors
        String errorMsg = 'Error accessing Feature_Name__c field: ';
        PWChrono_Logger.error(errorMsg);
        throw new AuraHandledException(errorMsg);
      }

      if (picklistValues.isEmpty()) {
        PWChrono_Logger.warn('Feature_Name__c picklist is empty');
      }

      for (Schema.PicklistEntry entry : picklistValues) {
        features.add(entry.getValue());
      }
    } catch (AuraHandledException ahe) {
      // Re-throw AuraHandledExceptions to client
      throw ahe;
    } catch (Exception e) {
      String errorMsg = 'Fatal error fetching available features: ';
      PWChrono_Logger.error(errorMsg);
      throw new AuraHandledException(errorMsg);
    }

    return features;
  }

  /**
   * @description Checks if the current user has access to a specific feature
   * @param featureName The name of the feature to check
   * @return FeatureAccessResult The access result
   */
  @AuraEnabled
  public static FeatureAccessResult checkFeatureAccess(String featureName) {
    try {
      Id currentUserId = UserInfo.getUserId();

      // Security Check

      // Get portal user for current Salesforce user
      List<Portal_Users__c> portalUsers = [
        // NOPMD
        SELECT Id
        FROM Portal_Users__c
        WHERE User__c = :currentUserId
        LIMIT 1
      ];

      if (portalUsers.isEmpty()) {
        FeatureAccessResult result = new FeatureAccessResult();
        result.hasAccess = false;
        result.accessLevel = 'No Access';
        result.message = 'No portal user found';
        return result;
      }

      List<PWChrono_User_Feature_Access__c> accessRecords = [
        // NOPMD
        SELECT Id, Access_Level__c, Is_Active__c
        FROM PWChrono_User_Feature_Access__c
        WHERE
          Portal_User__c = :portalUsers[0].Id
          AND Feature_Name__c = :featureName
          AND Is_Active__c = TRUE
        LIMIT 1
      ];

      FeatureAccessResult result = new FeatureAccessResult();
      if (accessRecords.isEmpty()) {
        result.hasAccess = false;
        result.accessLevel = 'No Access';
        result.message = 'Feature not enabled for user';
      } else {
        PWChrono_User_Feature_Access__c access = accessRecords[0];
        result.hasAccess = access.Access_Level__c != 'No Access';
        result.accessLevel = access.Access_Level__c;
        result.message = 'Access granted';
      }

      return result;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new IllegalArgumentException('Error checking feature access: '); // NOPMD
    }
  }

  /**
   * @description Creates a new Portal User and their initial feature access
   * @param userRecord The Portal_Users__c record to create
   * @param featureNames List of feature names to grant access to
   * @return Id The ID of the newly created Portal_Users__c record
   */
  @AuraEnabled
  public static Id createPortalUser(
    Portal_Users__c userRecord,
    List<String> featureNames,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return createPortalUserCore(userRecord, featureNames);
  }

  private static Id createPortalUserCore(
    Portal_Users__c userRecord,
    List<String> featureNames
  ) {
    try {
      // Basic validation
      if (
        userRecord == null ||
        String.isBlank(userRecord.Name) ||
        String.isBlank(userRecord.Email__c)
      ) {
        throw new AuraHandledException('User Name and Email are required.');
      }

      // Insert the portal user record
      insert userRecord; // NOPMD - Intentional insert

      // Create feature access records if any are specified
      if (featureNames != null && !featureNames.isEmpty()) {
        List<PWChrono_User_Feature_Access__c> accessRecordsToInsert = new List<PWChrono_User_Feature_Access__c>();
        for (String featureName : featureNames) {
          accessRecordsToInsert.add(
            new PWChrono_User_Feature_Access__c(
              Portal_User__c = userRecord.Id,
              Feature_Name__c = featureName,
              Is_Active__c = true,
              Access_Level__c = 'Read Write' // Default access level
            )
          );
        }
        if (!accessRecordsToInsert.isEmpty()) {
          insert accessRecordsToInsert; // NOPMD - Intentional insert
        }
      }

      return userRecord.Id;
    } catch (Exception e) {
      // Log the error
      PWChrono_Logger.error('Error creating portal user: ');
      // Rethrow to be caught by the LWC
      throw new AuraHandledException('Failed to create user: ');
    }
  }

  /**
   * @description Saves feature access configuration for a user
   * @param portalUserId The ID of the portal user
   * @param features List of feature access configurations
   * @return String 'Success' if saved
   */
  @AuraEnabled
  public static String saveUserFeatureAccess(
    String portalUserId,
    List<FeatureAccessWrapper> features,
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(callerPortalUserId, sessionToken);
    return saveUserFeatureAccessCore(portalUserId, features);
  }

  private static String saveUserFeatureAccessCore(
    String portalUserId,
    List<FeatureAccessWrapper> features
  ) {
    // NOPMD
    try {
      // Validate input parameters
      if (String.isBlank(portalUserId)) {
        throw new IllegalArgumentException('Portal User ID is required');
      }
      if (features == null) {
        // Allow empty list to remove all features
        return 'Success';
      }

      // 1. Collect Feature Names to query existing records
      Set<String> featureNames = new Set<String>();
      for (FeatureAccessWrapper feature : features) {
        if (String.isNotBlank(feature.featureName)) {
          featureNames.add(feature.featureName);
        }
      }

      // 2. Query existing records to prevent duplicates
      Map<String, PWChrono_User_Feature_Access__c> existingMap = new Map<String, PWChrono_User_Feature_Access__c>();
      if (!featureNames.isEmpty()) {
        for (PWChrono_User_Feature_Access__c access : [
          // NOPMD
          SELECT Id, Feature_Name__c
          FROM PWChrono_User_Feature_Access__c
          WHERE
            Portal_User__c = :portalUserId
            AND Feature_Name__c IN :featureNames
        ]) {
          existingMap.put(access.Feature_Name__c, access);
        }
      }

      List<PWChrono_User_Feature_Access__c> recordsToUpsert = new List<PWChrono_User_Feature_Access__c>();

      for (FeatureAccessWrapper feature : features) {
        PWChrono_User_Feature_Access__c recordToUpsert = createAccessRecord(
          portalUserId,
          feature,
          existingMap
        );
        if (recordToUpsert != null) {
          recordsToUpsert.add(recordToUpsert);
        }
      }

      if (recordsToUpsert.isEmpty()) {
        return 'Success';
      }

      // Security Check

      upsert recordsToUpsert; // NOPMD

      return 'Success';
    } catch (IllegalArgumentException ahe) {
      // NOPMD
      throw new IllegalArgumentException(
        'Error saving feature access: ' + ahe.getMessage()
      );
    }
  }

  /**
   * @description Bulk assigns features to multiple users
   * @param portalUserIds List of portal user IDs
   * @param features List of feature access configurations
   * @return String Success message
   */
  @AuraEnabled
  public static String bulkAssignFeatures(
    List<String> portalUserIds,
    List<FeatureAccessWrapper> features,
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(callerPortalUserId, sessionToken);
    return bulkAssignFeaturesCore(portalUserIds, features);
  }

  private static String bulkAssignFeaturesCore(
    List<String> portalUserIds,
    List<FeatureAccessWrapper> features
  ) {
    // NOPMD
    try {
      // Validate input parameters
      if (portalUserIds == null || portalUserIds.isEmpty()) {
        throw new IllegalArgumentException(
          'At least one user must be selected'
        );
      }
      if (features == null || features.isEmpty()) {
        throw new IllegalArgumentException(
          'At least one feature must be selected'
        );
      }

      // 1. Collect Feature Names
      Set<String> featureNames = new Set<String>();
      for (FeatureAccessWrapper feature : features) {
        if (String.isNotBlank(feature.featureName)) {
          featureNames.add(feature.featureName);
        }
      }

      // 2. Query existing records for ALL users and features involved
      // Map key: PortalUserId + '-' + FeatureName
      Map<String, PWChrono_User_Feature_Access__c> existingMap = new Map<String, PWChrono_User_Feature_Access__c>();
      if (!featureNames.isEmpty()) {
        for (PWChrono_User_Feature_Access__c access : [
          // NOPMD
          SELECT Id, Portal_User__c, Feature_Name__c
          FROM PWChrono_User_Feature_Access__c
          WHERE
            Portal_User__c IN :portalUserIds
            AND Feature_Name__c IN :featureNames
        ]) {
          existingMap.put(
            access.Portal_User__c + '-' + access.Feature_Name__c,
            access
          );
        }
      }

      List<PWChrono_User_Feature_Access__c> recordsToUpsert = new List<PWChrono_User_Feature_Access__c>();

      for (String portalUserId : portalUserIds) {
        for (FeatureAccessWrapper feature : features) {
          PWChrono_User_Feature_Access__c recordToUpsert = createBulkAccessRecord(
            portalUserId,
            feature,
            existingMap
          );
          if (recordToUpsert != null) {
            recordsToUpsert.add(recordToUpsert);
          }
        }
      }

      if (recordsToUpsert.isEmpty()) {
        throw new IllegalArgumentException('No valid features to assign');
      }

      // Security Check

      upsert recordsToUpsert; // NOPMD

      return 'Success: Assigned features to ' + portalUserIds.size() + ' users';
    } catch (IllegalArgumentException ahe) {
      // NOPMD
      throw new IllegalArgumentException(
        'Error in bulk assignment: ' + ahe.getMessage()
      );
    }
  }

  /**
   * @description Deletes a feature access record
   * @param featureAccessId The ID of the record to delete
   * @return String 'Success' if deleted
   */
  @AuraEnabled
  public static String deleteFeatureAccess(
    String featureAccessId,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return deleteFeatureAccessCore(featureAccessId);
  }

  private static String deleteFeatureAccessCore(String featureAccessId) {
    try {
      // Security Check

      PWChrono_User_Feature_Access__c recordToDelete = new PWChrono_User_Feature_Access__c(
        Id = featureAccessId
      );
      delete recordToDelete; // NOPMD

      return 'Success';
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new IllegalArgumentException('Error deleting feature access: '); // NOPMD
    }
  }

  /**
   * @description Retrieves global feature settings
   * @return PWChrono_Feature_Settings__c The settings record
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Feature_Settings__c getGlobalFeatureSettings(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getGlobalFeatureSettingsCore();
  }

  private static PWChrono_Feature_Settings__c getGlobalFeatureSettingsCore() {
    List<PWChrono_Feature_Settings__c> settingsList = [
      // NOPMD
      SELECT
        Id,
        Name,
        Enable_Leave_Encashment__c,
        Enable_Manager_Delegation__c,
        Enable_Payroll_Module__c,
        Enable_Performance_Module__c,
        Enable_Recruitment_Module__c,
        Enable_Self_Service_Portal__c,
        Enable_Training_Module__c,
        Auto_Approve_Attendance_Request__c,
        Notification_Email_Enabled__c,
        Advance_Leave_Application_Days__c,
        Allow_Backdated_Leave_Days__c,
        Require_Medical_Certificate_Days__c
      FROM PWChrono_Feature_Settings__c
      LIMIT 1
    ];

    if (settingsList.isEmpty()) {
      return new PWChrono_Feature_Settings__c(Name = 'Default Settings');
    }

    return settingsList[0];
  }

  /**
   * @description Saves global feature settings
   * @param settings The settings record to save
   * @return String 'Success' if saved
   */
  @AuraEnabled
  public static String saveGlobalFeatureSettings(
    PWChrono_Feature_Settings__c settings,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return saveGlobalFeatureSettingsCore(settings);
  }

  private static String saveGlobalFeatureSettingsCore(
    PWChrono_Feature_Settings__c settings
  ) {
    try {
      // Security Check

      upsert settings; // NOPMD
      return 'Success';
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new IllegalArgumentException('Error saving global settings: '); // NOPMD
    }
  }

  private static PWChrono_User_Feature_Access__c createAccessRecord(
    String portalUserId,
    FeatureAccessWrapper feature,
    Map<String, PWChrono_User_Feature_Access__c> existingMap
  ) {
    // Skip features with missing required fields
    if (
      String.isBlank(feature.featureName) || String.isBlank(feature.accessLevel)
    ) {
      return null;
    }

    PWChrono_User_Feature_Access__c recordToUpsert = new PWChrono_User_Feature_Access__c();

    // Determine ID: Use provided ID, or look up existing ID
    if (String.isNotBlank(feature.featureAccessId)) {
      recordToUpsert.Id = feature.featureAccessId;
    } else if (existingMap.containsKey(feature.featureName)) {
      recordToUpsert.Id = existingMap.get(feature.featureName).Id;
    }

    recordToUpsert.Portal_User__c = portalUserId;
    recordToUpsert.Feature_Name__c = feature.featureName;
    recordToUpsert.Access_Level__c = feature.accessLevel;
    recordToUpsert.Is_Active__c = (feature.isActive == true);
    return recordToUpsert;
  }

  private static PWChrono_User_Feature_Access__c createBulkAccessRecord(
    String portalUserId,
    FeatureAccessWrapper feature,
    Map<String, PWChrono_User_Feature_Access__c> existingMap
  ) {
    // Skip features with missing required fields
    if (
      String.isBlank(feature.featureName) || String.isBlank(feature.accessLevel)
    ) {
      return null;
    }

    PWChrono_User_Feature_Access__c recordToUpsert = new PWChrono_User_Feature_Access__c();

    // Check for existing record
    String key = portalUserId + '-' + feature.featureName;
    if (existingMap.containsKey(key)) {
      recordToUpsert.Id = existingMap.get(key).Id;
    }

    recordToUpsert.Portal_User__c = portalUserId;
    recordToUpsert.Feature_Name__c = feature.featureName;
    recordToUpsert.Access_Level__c = feature.accessLevel;
    recordToUpsert.Is_Active__c = feature != null && feature.isActive == true;
    return recordToUpsert;
  }

  // Wrapper Classes
  /**
   * @description Wrapper class for user configuration data
   */
  public class UserConfiguration {
    @AuraEnabled
    public String userId;
    @AuraEnabled
    public String userName;
    @AuraEnabled
    public String userEmail;
    @AuraEnabled
    public String profileName;
    @AuraEnabled
    public String designation;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public Boolean isActive;
    @AuraEnabled
    public String photoUrl;
    @AuraEnabled
    public DateTime lastLoginDate;
    @AuraEnabled
    public List<FeatureAccessWrapper> featureAccess;
  }

  /**
   * @description Wrapper class for feature access configuration
   */
  public class FeatureAccessWrapper {
    @AuraEnabled
    public String featureAccessId;
    @AuraEnabled
    public String featureName;
    @AuraEnabled
    public String accessLevel;
    @AuraEnabled
    public Boolean isActive;
  }

  /**
   * @description Wrapper class for feature access result
   */
  public class FeatureAccessResult {
    @AuraEnabled
    public Boolean hasAccess;
    @AuraEnabled
    public String accessLevel;
    @AuraEnabled
    public String message;
  }

  /**
   * @description Toggle user active status
   * @param userId The ID of the portal user
   * @param isActive The new active status
   * @return String Success message
   */
  @AuraEnabled
  public static String toggleUserActiveStatus(String userId, Boolean isActive) {
    try {
      // Security Check

      Portal_Users__c user = new Portal_Users__c(Id = userId);
      user.Is_Active__c = isActive;
      update user; // NOPMD

      return 'User status updated successfully';
    } catch (Exception e) {
      PWChrono_Logger.error('Error toggling user status: ');
      throw new AuraHandledException('Error updating user status: ');
    }
  }

  /**
   * @description Bulk toggle user active status
   * @param userIds List of portal user IDs
   * @param isActive The new active status
   * @return String Success message
   */
  @AuraEnabled
  public static String bulkToggleUserStatus(
    List<String> userIds,
    Boolean isActive
  ) {
    try {
      // Security Check

      List<Portal_Users__c> usersToUpdate = new List<Portal_Users__c>();
      for (String userId : userIds) {
        Portal_Users__c user = new Portal_Users__c(Id = userId);
        user.Is_Active__c = isActive;
        usersToUpdate.add(user);
      }

      if (!usersToUpdate.isEmpty()) {
        update usersToUpdate; // NOPMD
      }

      String action = isActive ? 'activated' : 'deactivated';
      return usersToUpdate.size() + ' user(s) ' + action + ' successfully';
    } catch (Exception e) {
      PWChrono_Logger.error('Error bulk toggling user status: ');
      throw new AuraHandledException('Error updating user status: ');
    }
  }

  /**
   * @description Update user profile details
   * @param userId The ID of the portal user
   * @param role The user role
   * @param department The user department
   * @param designation The user designation
   * @return String Success message
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static String updateUserProfile(
    String userId,
    String role,
    String department,
    String designation
  ) {
    try {
      // Security Check

      // Query first to get Contact__c for the department update.
      List<Portal_Users__c> puList = [
        SELECT Id, Contact__c
        FROM Portal_Users__c
        WHERE Id = :userId
        LIMIT 1
      ]; // NOPMD
      if (puList.isEmpty()) {
        throw new AuraHandledException('User not found.');
      }

      Portal_Users__c user = puList[0];
      if (String.isNotBlank(role)) {
        user.Role__c = role;
      }
      if (String.isNotBlank(designation)) {
        user.Designation__c = designation;
      }
      update user; // NOPMD

      // Department is a formula: Contact__r.Department — update the linked Contact instead.
      if (String.isNotBlank(department) && user.Contact__c != null) {
        update new Contact(Id = user.Contact__c, Department = department); // NOPMD
      }

      return 'User profile updated successfully';
    } catch (Exception e) {
      PWChrono_Logger.error('Error updating user profile: ');
      throw new AuraHandledException('Error updating user profile: ');
    }
  }
}