/**
 * @description Controller for Staffing Plan LWC components
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_StaffingPlanController {
  private static void requireHRAccess(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }
    Id verifiedId = (Id) PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    Portal_Users__c pu = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :verifiedId
      LIMIT 1
    ];
    if (pu.Role__c != PWChrono_Constants.ROLE_HR_ADMIN) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  /**
   * @description Returns all Staffing Plans ordered by creation date
   */
  @AuraEnabled(cacheable=true)
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
      PWChrono_Staffing_Plan__c plan = (PWChrono_Staffing_Plan__c) JSON.deserialize(
        planJson,
        PWChrono_Staffing_Plan__c.class
      );
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

      // Insert new rows supplied by the LWC
      List<PWChrono_Staffing_Plan_Detail__c> details = (List<PWChrono_Staffing_Plan_Detail__c>) JSON.deserialize(
        detailsJson,
        List<PWChrono_Staffing_Plan_Detail__c>.class
      );

      for (PWChrono_Staffing_Plan_Detail__c d : details) {
        d.Staffing_Plan__c = planId;
        d.Id = null; // ensure insert, not update
      }

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