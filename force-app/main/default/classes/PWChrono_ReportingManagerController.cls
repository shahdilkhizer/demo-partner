/**
 * @description Manages Portal User reporting relationships through the canonical
 * Portal_Users__c.Reports_To__c lookup.
 */
public without sharing class PWChrono_ReportingManagerController {
  private static void requireAdminAccess(
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
      SELECT Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId AND Is_Active__c = TRUE
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
   * @description Returns Portal Users and their current manager assignments.
   */
  @AuraEnabled(cacheable=true)
  public static List<PortalUserOption> getReportingOptions(
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminAccess(callerPortalUserId, sessionToken);
    List<PortalUserOption> options = new List<PortalUserOption>();
    for (Portal_Users__c portalUser : [
      SELECT
        Id,
        Name,
        Role__c,
        Designation__c,
        Is_Active__c,
        Reports_To__c,
        Reports_To__r.Name
      FROM Portal_Users__c
      ORDER BY Name
      LIMIT 1000
    ]) {
      PortalUserOption option = new PortalUserOption();
      option.portalUserId = String.valueOf(portalUser.Id);
      option.portalUserName = portalUser.Name;
      option.roleName = portalUser.Role__c;
      option.designation = portalUser.Designation__c;
      option.isActive = portalUser.Is_Active__c == true;
      option.managerId = portalUser.Reports_To__c == null
        ? null
        : String.valueOf(portalUser.Reports_To__c);
      option.managerName = portalUser.Reports_To__r == null
        ? null
        : portalUser.Reports_To__r.Name;
      options.add(option);
    }
    return options;
  }

  /**
   * @description Atomically assigns both the access profile and reporting manager.
   */
  @AuraEnabled
  public static String saveUserSetup(
    Id targetPortalUserId,
    Id profileId,
    Id managerPortalUserId,
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminAccess(callerPortalUserId, sessionToken);
    if (targetPortalUserId == null || profileId == null) {
      throw new AuraHandledException(
        'Portal User and Portal User Profile are required.'
      );
    }
    if (
      [SELECT COUNT() FROM Portal_User_Profile__c WHERE Id = :profileId] == 0
    ) {
      throw new AuraHandledException('Portal User Profile was not found.');
    }
    if (
      [SELECT COUNT() FROM Portal_Users__c WHERE Id = :targetPortalUserId] == 0
    ) {
      throw new AuraHandledException('Portal User was not found.');
    }

    validateReportingManager(targetPortalUserId, managerPortalUserId);
    update new Portal_Users__c(
      Id = targetPortalUserId,
      Portal_User_Profile__c = profileId,
      Reports_To__c = managerPortalUserId
    );
    return 'Success';
  }

  /**
   * @description Creates a Portal User with profile and manager in one transaction.
   */
  @AuraEnabled
  public static Id createPortalUser(
    Portal_Users__c userRecord,
    Id profileId,
    Id managerPortalUserId,
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminAccess(callerPortalUserId, sessionToken);
    if (
      userRecord == null ||
      String.isBlank(userRecord.Name) ||
      String.isBlank(userRecord.Email__c) ||
      profileId == null
    ) {
      throw new AuraHandledException(
        'User Name, Email, and Portal User Profile are required.'
      );
    }
    if (
      [SELECT COUNT() FROM Portal_User_Profile__c WHERE Id = :profileId] == 0
    ) {
      throw new AuraHandledException('Portal User Profile was not found.');
    }
    validateReportingManager(null, managerPortalUserId);
    userRecord.Portal_User_Profile__c = profileId;
    userRecord.Reports_To__c = managerPortalUserId;
    insert userRecord;
    return userRecord.Id;
  }

  private static void validateReportingManager(
    Id targetPortalUserId,
    Id managerPortalUserId
  ) {
    if (managerPortalUserId == null) {
      return;
    }
    if (
      targetPortalUserId != null &&
      targetPortalUserId == managerPortalUserId
    ) {
      throw new AuraHandledException('A Portal User cannot report to itself.');
    }
    if (
      [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Id = :managerPortalUserId AND Is_Active__c = TRUE
      ] == 0
    ) {
      throw new AuraHandledException('The selected manager is not active.');
    }

    Map<Id, Id> managerByPortalUserId = new Map<Id, Id>();
    for (Portal_Users__c portalUser : [
      SELECT Id, Reports_To__c
      FROM Portal_Users__c
      LIMIT 10000
    ]) {
      managerByPortalUserId.put(portalUser.Id, portalUser.Reports_To__c);
    }

    Id currentId = managerPortalUserId;
    Set<Id> visitedIds = new Set<Id>();
    while (currentId != null && !visitedIds.contains(currentId)) {
      if (currentId == targetPortalUserId) {
        throw new AuraHandledException(
          'This manager assignment would create a reporting cycle.'
        );
      }
      visitedIds.add(currentId);
      currentId = managerByPortalUserId.get(currentId);
    }
  }

  public class PortalUserOption {
    @AuraEnabled
    public String portalUserId;
    @AuraEnabled
    public String portalUserName;
    @AuraEnabled
    public String roleName;
    @AuraEnabled
    public String designation;
    @AuraEnabled
    public Boolean isActive;
    @AuraEnabled
    public String managerId;
    @AuraEnabled
    public String managerName;
  }
}