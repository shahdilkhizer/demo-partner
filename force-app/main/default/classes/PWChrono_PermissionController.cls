/**
 * @description Controller for managing Portal User Profile permissions
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_PermissionController {
  // --- Guest portal authorization helpers (Admin Settings) ---
  // Permissions management is an admin/config function. In the guest runtime,
  // require a verified session and profile-level access to Portal Users.
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

    List<Portal_Users__c> callers = [
      SELECT Id, Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];
    if (callers.isEmpty() || callers[0].Portal_User_Profile__c == null) {
      throw new AuraHandledException('Unauthorized.');
    }
    if (
      [
        SELECT COUNT()
        FROM Portal_Object_Permission__c
        WHERE
          Portal_User_Profile__c = :callers[0].Portal_User_Profile__c
          AND Portal_Object__r.Object_API_Name__c = 'Portal_Users__c'
          AND Can_View__c = TRUE
          AND Can_Edit__c = TRUE
      ] == 0
    ) {
      throw new AuraHandledException('Unauthorized.');
    }
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
    public Boolean canViewAll;
    @AuraEnabled
    public Boolean canModifyAll;
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
        Can_Delete__c,
        Can_View_All__c,
        Can_Modify_All__c
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
        wrapper.canViewAll = perm.Can_View_All__c;
        wrapper.canModifyAll = perm.Can_Modify_All__c;
        wrapper.isAssigned = true;
      } else {
        wrapper.id = null;
        wrapper.canView = false;
        wrapper.canCreate = false;
        wrapper.canEdit = false;
        wrapper.canDelete = false;
        wrapper.canViewAll = false;
        wrapper.canModifyAll = false;
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
          record.Can_View_All__c = perm.canViewAll == true;
          record.Can_Modify_All__c = perm.canModifyAll == true;
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

  public class FieldPermissionWrapper {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String fieldId;
    @AuraEnabled
    public String objectName;
    @AuraEnabled
    public String fieldApiName;
    @AuraEnabled
    public Boolean canView;
    @AuraEnabled
    public Boolean canEdit;
    @AuraEnabled
    public Boolean isAssigned;
    @AuraEnabled
    public Boolean isSystemField;
  }

  @AuraEnabled(cacheable=true)
  public static List<FieldPermissionWrapper> getProfileFieldPermissions(
    Id profileId,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    Map<Id, Portal_Field_Permission__c> existing = new Map<Id, Portal_Field_Permission__c>();
    for (Portal_Field_Permission__c permission : [
      SELECT Id, Portal_Object_Field__c, Can_View__c, Can_Edit__c
      FROM Portal_Field_Permission__c
      WHERE Portal_User_Profile__c = :profileId
    ]) {
      existing.put(permission.Portal_Object_Field__c, permission);
    }

    List<FieldPermissionWrapper> result = new List<FieldPermissionWrapper>();
    for (Portal_Object_Field__c field : [
      SELECT
        Id,
        Field_API_Name__c,
        Is_System_Field__c,
        Portal_Object__r.Object_API_Name__c
      FROM Portal_Object_Field__c
      WHERE Portal_Object__c != NULL
      ORDER BY Portal_Object__r.Object_API_Name__c, Field_API_Name__c
    ]) {
      FieldPermissionWrapper wrapper = new FieldPermissionWrapper();
      wrapper.fieldId = field.Id;
      wrapper.objectName = field.Portal_Object__r.Object_API_Name__c;
      wrapper.fieldApiName = field.Field_API_Name__c;
      wrapper.isSystemField = field.Is_System_Field__c;
      if (existing.containsKey(field.Id)) {
        Portal_Field_Permission__c permission = existing.get(field.Id);
        wrapper.id = permission.Id;
        wrapper.canView = permission.Can_View__c;
        wrapper.canEdit = permission.Can_Edit__c;
        wrapper.isAssigned = true;
      } else {
        wrapper.canView = false;
        wrapper.canEdit = false;
        wrapper.isAssigned = false;
      }
      result.add(wrapper);
    }
    return result;
  }

  @AuraEnabled
  public static void saveProfileFieldPermissions(
    Id profileId,
    String permissionsJson,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    List<FieldPermissionWrapper> permissions = (List<FieldPermissionWrapper>) JSON.deserialize(
      permissionsJson == null ? '[]' : permissionsJson,
      List<FieldPermissionWrapper>.class
    );
    List<Portal_Field_Permission__c> toUpsert = new List<Portal_Field_Permission__c>();
    List<Portal_Field_Permission__c> toDelete = new List<Portal_Field_Permission__c>();
    for (FieldPermissionWrapper permission : permissions) {
      if (
        permission.isAssigned == true && String.isNotBlank(permission.fieldId)
      ) {
        Portal_Field_Permission__c record = new Portal_Field_Permission__c(
          Portal_User_Profile__c = profileId,
          Portal_Object_Field__c = permission.fieldId,
          Can_View__c = permission.canView == true,
          Can_Edit__c = permission.canEdit == true
        );
        if (String.isNotBlank(permission.id)) {
          record.Id = permission.id;
        }
        toUpsert.add(record);
      } else if (String.isNotBlank(permission.id)) {
        toDelete.add(new Portal_Field_Permission__c(Id = permission.id));
      }
    }
    if (!toDelete.isEmpty())
      delete toDelete;
    if (!toUpsert.isEmpty())
      upsert toUpsert;
  }
}