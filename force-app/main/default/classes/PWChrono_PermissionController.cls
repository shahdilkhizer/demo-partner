/**
 * @description Controller for managing Portal User Profile permissions
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_PermissionController {
  // --- Guest portal authorization helpers (Admin Settings) ---
  // Permissions management is an admin/config function.
  // In the portal Guest runtime, require a verified portal session AND
  // that the caller has the Admin Settings feature.
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
   * @description Wrapper class for Object Permissions
   */
  public class PermissionWrapper {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String objectName;
    @AuraEnabled
    public String objectApiName;
    @AuraEnabled
    public Boolean canView;
    @AuraEnabled
    public Boolean canCreate;
    @AuraEnabled
    public Boolean canEdit;
    @AuraEnabled
    public Boolean canDelete;
    @AuraEnabled
    public Boolean isAssigned;
  }

  /**
   * @description Wrapper for Portal User rows displayed on a Portal User Profile record page.
   */
  public class PortalUserRow {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public Boolean isActive;
    @AuraEnabled
    public String role;
  }

  /**
   * @description Get Portal Users assigned to a Portal User Profile.
   *              This is an admin/config function.
   * @param profileId The ID of the Portal_User_Profile__c
   */
  @AuraEnabled(cacheable=true)
  public static List<PortalUserRow> getPortalUsersForProfile(
    Id profileId,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);

    List<PortalUserRow> rows = new List<PortalUserRow>();
    if (profileId == null) {
      return rows;
    }

    for (Portal_Users__c u : [
      SELECT Id, Name, Email__c, Is_Active__c, Role__c
      FROM Portal_Users__c
      WHERE Portal_User_Profile__c = :profileId
      ORDER BY Name
      LIMIT 200
    ]) {
      PortalUserRow r = new PortalUserRow();
      r.id = u.Id;
      r.name = u.Name;
      r.email = u.Email__c;
      r.isActive = u.Is_Active__c;
      r.role = u.Role__c;
      rows.add(r);
    }

    return rows;
  }

  /**
   * @description Get all available Portal Objects and their permissions for a specific profile
   * @param profileId The ID of the Portal_User_Profile__c
   * @return List of PermissionWrapper
   */
  @AuraEnabled(cacheable=true)
  public static List<PermissionWrapper> getProfilePermissions(
    Id profileId,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getProfilePermissionsCore(profileId);
  }

  private static List<PermissionWrapper> getProfilePermissionsCore(
    Id profileId
  ) {
    List<PermissionWrapper> result = new List<PermissionWrapper>();

    // 1. Get all defined Portal Objects
    List<Portal_Object__c> allObjects = [
      SELECT Id, Name, Object_API_Name__c
      FROM Portal_Object__c
      ORDER BY Object_API_Name__c
    ];

    // 2. Get existing permissions for this profile
    Map<Id, Portal_Object_Permission__c> existingPerms = new Map<Id, Portal_Object_Permission__c>();
    for (Portal_Object_Permission__c perm : [
      SELECT
        Id,
        Portal_Object__c,
        Can_View__c,
        Can_Create__c,
        Can_Edit__c,
        Can_Delete__c
      FROM Portal_Object_Permission__c
      WHERE Portal_User_Profile__c = :profileId
    ]) {
      existingPerms.put(perm.Portal_Object__c, perm);
    }

    // 3. Merge data
    for (Portal_Object__c obj : allObjects) {
      PermissionWrapper wrapper = new PermissionWrapper();
      // Use Object_API_Name__c if available, otherwise fallback to Name (for backward compatibility or if not populated yet)
      String apiName = String.isNotBlank(obj.Object_API_Name__c)
        ? obj.Object_API_Name__c
        : obj.Name;

      wrapper.objectName = apiName;
      wrapper.objectApiName = apiName;

      if (existingPerms.containsKey(obj.Id)) {
        Portal_Object_Permission__c perm = existingPerms.get(obj.Id);
        wrapper.id = perm.Id;
        wrapper.canView = perm.Can_View__c;
        wrapper.canCreate = perm.Can_Create__c;
        wrapper.canEdit = perm.Can_Edit__c;
        wrapper.canDelete = perm.Can_Delete__c;
        wrapper.isAssigned = true;
      } else {
        wrapper.id = null;
        wrapper.canView = false;
        wrapper.canCreate = false;
        wrapper.canEdit = false;
        wrapper.canDelete = false;
        wrapper.isAssigned = false;
      }
      result.add(wrapper);
    }

    return result;
  }

  /**
   * @description Save permissions for a profile
   * @param profileId The ID of the Portal_User_Profile__c
   * @param permissions List of PermissionWrapper to save
   */
  @AuraEnabled
  public static void saveProfilePermissions(
    Id profileId,
    String permissionsJson,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    saveProfilePermissionsCore(profileId, permissionsJson);
  }

  private static void saveProfilePermissionsCore(
    Id profileId,
    String permissionsJson
  ) {
    try {
      List<PermissionWrapper> permissions = (List<PermissionWrapper>) JSON.deserialize(
        permissionsJson,
        List<PermissionWrapper>.class
      );
      List<Portal_Object_Permission__c> toUpsert = new List<Portal_Object_Permission__c>();
      List<Portal_Object_Permission__c> toDelete = new List<Portal_Object_Permission__c>();

      // Get map of Object Name to Object Id
      Map<String, Id> objectMap = new Map<String, Id>();
      for (Portal_Object__c obj : [
        SELECT Id, Name, Object_API_Name__c
        FROM Portal_Object__c
      ]) {
        String apiName = String.isNotBlank(obj.Object_API_Name__c)
          ? obj.Object_API_Name__c
          : obj.Name;
        objectMap.put(apiName, obj.Id);
      }

      for (PermissionWrapper perm : permissions) {
        if (perm.isAssigned) {
          Portal_Object_Permission__c record = new Portal_Object_Permission__c();
          if (String.isNotBlank(perm.id)) {
            record.Id = perm.id;
          }
          record.Portal_User_Profile__c = profileId;
          record.Portal_Object__c = objectMap.get(perm.objectName);
          record.Can_View__c = perm.canView;
          record.Can_Create__c = perm.canCreate;
          record.Can_Edit__c = perm.canEdit;
          record.Can_Delete__c = perm.canDelete;
          toUpsert.add(record);
        } else if (String.isNotBlank(perm.id)) {
          // If unassigned but has ID, delete it
          toDelete.add(new Portal_Object_Permission__c(Id = perm.id));
        }
      }

      if (!toDelete.isEmpty()) {
        delete toDelete;
      }
      if (!toUpsert.isEmpty()) {
        upsert toUpsert;
      }
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error saving permissions: ' + e.getMessage()
      );
    }
  }
}