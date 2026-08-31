/**
 * @description Controller for Staffing Plan LWC components
 * @author PWChrono Team
 */
public without sharing class PWChrono_StaffingPlanController {
  private static void requireHRAccess(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }
    if (String.isBlank(portalUserId)) {
      return;
    }
    Id verifiedId = (Id) PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    List<Portal_Users__c> users = [
      SELECT Id, Role__c
      FROM Portal_Users__c
      WHERE Id = :verifiedId
      LIMIT 1
    ];
    if (users.isEmpty()) {
      return;
    }
    if (
      users[0].Role__c != PWChrono_Constants.ROLE_HR_ADMIN &&
      users[0].Role__c != 'System Admin'
    ) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  private static PWChrono_Staffing_Plan__c parsePlanJson(String planJson, String portalUserId) {
    Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(planJson);
    PWChrono_Staffing_Plan__c plan = new PWChrono_Staffing_Plan__c();
    if (raw.containsKey('Id') && raw.get('Id') != null && String.isNotBlank(String.valueOf(raw.get('Id')))) {
      plan.Id = (Id) raw.get('Id');
    }
    if (raw.containsKey('Name') && raw.get('Name') != null && String.isNotBlank(String.valueOf(raw.get('Name')))) {
      plan.Name = String.valueOf(raw.get('Name'));
    }
    if (raw.containsKey('Company__c') && raw.get('Company__c') != null) {
      plan.Company__c = String.valueOf(raw.get('Company__c'));
    }
    if (raw.containsKey('Department__c') && raw.get('Department__c') != null && String.isNotBlank(String.valueOf(raw.get('Department__c')))) {
      plan.Department__c = (Id) raw.get('Department__c');
    }
    if (raw.containsKey('From_Date__c') && raw.get('From_Date__c') != null && String.isNotBlank(String.valueOf(raw.get('From_Date__c')))) {
      plan.From_Date__c = Date.valueOf(String.valueOf(raw.get('From_Date__c')));
    }
    if (raw.containsKey('To_Date__c') && raw.get('To_Date__c') != null && String.isNotBlank(String.valueOf(raw.get('To_Date__c')))) {
      plan.To_Date__c = Date.valueOf(String.valueOf(raw.get('To_Date__c')));
    }
    if (raw.containsKey('Status__c') && raw.get('Status__c') != null && String.isNotBlank(String.valueOf(raw.get('Status__c')))) {
      plan.Status__c = String.valueOf(raw.get('Status__c'));
    }
    if (raw.containsKey('Notes__c') && raw.get('Notes__c') != null) {
      plan.Notes__c = String.valueOf(raw.get('Notes__c'));
    }
    if (String.isNotBlank(portalUserId)) {
      plan.Requested_By__c = portalUserId;
    }
    return plan;
  }

  private static List<PWChrono_Staffing_Plan_Detail__c> parseDetailsJson(String detailsJson, Id planId) {
    List<PWChrono_Staffing_Plan_Detail__c> details = new List<PWChrono_Staffing_Plan_Detail__c>();
    if (String.isBlank(detailsJson)) {
      return details;
    }
    List<Object> rawList = (List<Object>) JSON.deserializeUntyped(detailsJson);
    for (Object obj : rawList) {
      Map<String, Object> m = (Map<String, Object>) obj;
      PWChrono_Staffing_Plan_Detail__c d = new PWChrono_Staffing_Plan_Detail__c();
      d.Staffing_Plan__c = planId;
      if (m.containsKey('Designation__c') && m.get('Designation__c') != null && String.isNotBlank(String.valueOf(m.get('Designation__c')))) {
        d.Designation__c = (Id) m.get('Designation__c');
      }
      if (m.containsKey('Vacancies__c') && m.get('Vacancies__c') != null && String.isNotBlank(String.valueOf(m.get('Vacancies__c')))) {
        d.Vacancies__c = Decimal.valueOf(String.valueOf(m.get('Vacancies__c')));
      }
      if (m.containsKey('Estimated_Cost_Per_Position__c') && m.get('Estimated_Cost_Per_Position__c') != null && String.isNotBlank(String.valueOf(m.get('Estimated_Cost_Per_Position__c')))) {
        d.Estimated_Cost_Per_Position__c = Decimal.valueOf(String.valueOf(m.get('Estimated_Cost_Per_Position__c')));
      }
      if (m.containsKey('Number_of_Positions__c') && m.get('Number_of_Positions__c') != null && String.isNotBlank(String.valueOf(m.get('Number_of_Positions__c')))) {
        d.Number_of_Positions__c = Decimal.valueOf(String.valueOf(m.get('Number_of_Positions__c')));
      }
      details.add(d);
    }
    return details;
  }

  /**
   * @description Returns all Staffing Plans ordered by creation date
   */
  @AuraEnabled
  public static List<PWChrono_Staffing_Plan__c> getStaffingPlans(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      String query =
        'SELECT Id, Name, Company__c, Department__c, Department__r.Name, ' +
        'From_Date__c, To_Date__c, Status__c, Requested_By__c, Requested_By__r.Name, ' +
        'Total_Estimated_Cost__c, Notes__c, CreatedDate ' +
        'FROM PWChrono_Staffing_Plan__c';
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        query += ' WHERE Status__c = :statusFilter';
      }
      query += ' ORDER BY CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('getStaffingPlans failed', e);
      throw new AuraHandledException('Error loading staffing plans.');
    }
  }

  /**
   * @description Returns a single Staffing Plan with its detail rows
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Staffing_Plan__c getStaffingPlanById(
    Id planId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      List<PWChrono_Staffing_Plan__c> plans = [
        SELECT
          Id,
          Name,
          Company__c,
          Department__c,
          Department__r.Name,
          From_Date__c,
          To_Date__c,
          Status__c,
          Requested_By__c,
          Requested_By__r.Name,
          Total_Estimated_Cost__c,
          Notes__c,
          (
            SELECT
              Id,
              Name,
              Designation__c,
              Designation__r.Name,
              Vacancies__c,
              Estimated_Cost_Per_Position__c,
              Total_Estimated_Cost__c,
              Number_of_Positions__c
            FROM Staffing_Plan_Details__r
            ORDER BY Name ASC
          )
        FROM PWChrono_Staffing_Plan__c
        WHERE Id = :planId
        LIMIT 1
      ];
      if (plans.isEmpty()) {
        throw new AuraHandledException('Staffing Plan not found.');
      }
      return plans[0];
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('getStaffingPlanById failed', e);
      throw new AuraHandledException('Error loading staffing plan.');
    }
  }

  /**
   * @description Saves (inserts or updates) a Staffing Plan header
   */
  @AuraEnabled
  public static Id saveStaffingPlan(
    String planJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      PWChrono_Staffing_Plan__c plan = parsePlanJson(planJson, portalUserId);
      upsert plan; // NOPMD
      return plan.Id;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('saveStaffingPlan failed', e);
      throw new AuraHandledException(
        'Error saving staffing plan: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Saves detail rows for a given Staffing Plan.
   *              Deletes existing rows first, then inserts the provided set.
   */
  @AuraEnabled
  public static void saveStaffingPlanDetails(
    Id planId,
    String detailsJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);

      // Delete existing detail rows for this plan
      List<PWChrono_Staffing_Plan_Detail__c> existing = [
        SELECT Id
        FROM PWChrono_Staffing_Plan_Detail__c
        WHERE Staffing_Plan__c = :planId
      ];
      if (!existing.isEmpty()) {
        delete existing; // NOPMD
      }

      List<PWChrono_Staffing_Plan_Detail__c> details = parseDetailsJson(detailsJson, planId);

      if (!details.isEmpty()) {
        insert details; // NOPMD
      }
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('saveStaffingPlanDetails failed', e);
      throw new AuraHandledException(
        'Error saving detail rows: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Updates the status of a Staffing Plan
   */
  @AuraEnabled
  public static void updateStaffingPlanStatus(
    Id planId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      List<PWChrono_Staffing_Plan__c> plans = [
        SELECT Id, Status__c
        FROM PWChrono_Staffing_Plan__c
        WHERE Id = :planId
        LIMIT 1
      ];
      if (plans.isEmpty()) {
        throw new AuraHandledException('Staffing Plan not found.');
      }
      plans[0].Status__c = newStatus;
      update plans[0]; // NOPMD
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('updateStaffingPlanStatus failed', e);
      throw new AuraHandledException('Error updating status.');
    }
  }

  /**
   * @description Deletes a Staffing Plan (and its detail rows via cascade)
   */
  @AuraEnabled
  public static void deleteStaffingPlan(
    Id planId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      List<PWChrono_Staffing_Plan__c> plans = [
        SELECT Id, Status__c
        FROM PWChrono_Staffing_Plan__c
        WHERE Id = :planId
        LIMIT 1
      ];
      if (plans.isEmpty()) {
        throw new AuraHandledException('Staffing plan not found.');
      }
      if (plans[0].Status__c != 'Draft') {
        throw new AuraHandledException(
          'Only draft staffing plans can be deleted.'
        );
      }
      delete plans[0]; // NOPMD
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('deleteStaffingPlan failed', e);
      throw new AuraHandledException('Error deleting staffing plan.');
    }
  }

  /**
   * @description Returns active Designations for the detail row picklist
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Designation__c> getActiveDesignations() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Designation__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('getActiveDesignations failed', e);
      throw new AuraHandledException('Error loading designations.');
    }
  }

  /**
   * @description Returns active Departments for the plan header picklist
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Department__c> getActiveDepartments() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Department__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('getActiveDepartments failed', e);
      throw new AuraHandledException('Error loading departments.');
    }
  }
}