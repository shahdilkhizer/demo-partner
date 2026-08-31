/**
 * @description Controller for Job Requisition LWC components
 * @author PWChrono Team
 */
public without sharing class PWChrono_JobRequisitionController {
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
    List<Portal_Users__c> users = [
      SELECT Id, Role__c, Access_Features__c, Is_Active__c
      FROM Portal_Users__c
      WHERE Id = :portalUserId
      LIMIT 1
    ];
    if (users.isEmpty()) {
      return;
    }
  }

  private static PWChrono_Job_Requisition__c parseRequisitionJson(String requisitionJson, String portalUserId) {
    Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(requisitionJson);
    PWChrono_Job_Requisition__c req = new PWChrono_Job_Requisition__c();
    if (raw.containsKey('Id') && raw.get('Id') != null && String.isNotBlank(String.valueOf(raw.get('Id')))) {
      req.Id = (Id) raw.get('Id');
    }
    if (raw.containsKey('Name') && raw.get('Name') != null && String.isNotBlank(String.valueOf(raw.get('Name')))) {
      req.Name = String.valueOf(raw.get('Name'));
    }
    if (raw.containsKey('Company__c') && raw.get('Company__c') != null) {
      req.Company__c = String.valueOf(raw.get('Company__c'));
    }
    if (raw.containsKey('Department__c') && raw.get('Department__c') != null && String.isNotBlank(String.valueOf(raw.get('Department__c')))) {
      req.Department__c = (Id) raw.get('Department__c');
    }
    if (raw.containsKey('Designation__c') && raw.get('Designation__c') != null && String.isNotBlank(String.valueOf(raw.get('Designation__c')))) {
      req.Designation__c = (Id) raw.get('Designation__c');
    }
    if (raw.containsKey('Staffing_Plan__c') && raw.get('Staffing_Plan__c') != null && String.isNotBlank(String.valueOf(raw.get('Staffing_Plan__c')))) {
      req.Staffing_Plan__c = (Id) raw.get('Staffing_Plan__c');
    }
    if (raw.containsKey('No_of_Positions__c') && raw.get('No_of_Positions__c') != null && String.isNotBlank(String.valueOf(raw.get('No_of_Positions__c')))) {
      req.No_of_Positions__c = Decimal.valueOf(String.valueOf(raw.get('No_of_Positions__c')));
    }
    if (raw.containsKey('Expected_Compensation__c') && raw.get('Expected_Compensation__c') != null && String.isNotBlank(String.valueOf(raw.get('Expected_Compensation__c')))) {
      req.Expected_Compensation__c = Decimal.valueOf(String.valueOf(raw.get('Expected_Compensation__c')));
    }
    if (raw.containsKey('Status__c') && raw.get('Status__c') != null && String.isNotBlank(String.valueOf(raw.get('Status__c')))) {
      req.Status__c = String.valueOf(raw.get('Status__c'));
    }
    if (raw.containsKey('Expected_By_Date__c') && raw.get('Expected_By_Date__c') != null && String.isNotBlank(String.valueOf(raw.get('Expected_By_Date__c')))) {
      req.Expected_By_Date__c = Date.valueOf(String.valueOf(raw.get('Expected_By_Date__c')));
    }
    if (raw.containsKey('Posting_Date__c') && raw.get('Posting_Date__c') != null && String.isNotBlank(String.valueOf(raw.get('Posting_Date__c')))) {
      req.Posting_Date__c = Date.valueOf(String.valueOf(raw.get('Posting_Date__c')));
    }
    if (raw.containsKey('Reason_for_Hiring__c') && raw.get('Reason_for_Hiring__c') != null) {
      req.Reason_for_Hiring__c = String.valueOf(raw.get('Reason_for_Hiring__c'));
    }
    if (raw.containsKey('Job_Description__c') && raw.get('Job_Description__c') != null) {
      req.Job_Description__c = String.valueOf(raw.get('Job_Description__c'));
    }
    if (String.isNotBlank(portalUserId)) {
      req.Requested_By__c = portalUserId;
    }
    return req;
  }

  /**
   * @description Returns Job Requisitions with optional status filter
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Requisition__c> getJobRequisitions(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      String query =
        'SELECT Id, Name, Designation__c, Designation__r.Name, Department__c, ' +
        'Department__r.Name, Company__c, Requested_By__c, Requested_By__r.Name, ' +
        'Requested_By_Department__c, No_of_Positions__c, Expected_Compensation__c, ' +
        'Status__c, Expected_By_Date__c, Posting_Date__c, Completed_On__c, ' +
        'Time_to_Fill__c, Staffing_Plan__c, Staffing_Plan__r.Name, ' +
        'Reason_for_Hiring__c, Job_Description__c, CreatedDate ' +
        'FROM PWChrono_Job_Requisition__c';
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        query += ' WHERE Status__c = :statusFilter';
      }
      query += ' ORDER BY CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('getJobRequisitions failed', e);
      throw new AuraHandledException('Error loading job requisitions.');
    }
  }

  /**
   * @description Returns a single Job Requisition by Id
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Job_Requisition__c getJobRequisitionById(
    Id requisitionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      List<PWChrono_Job_Requisition__c> recs = [
        SELECT
          Id,
          Name,
          Designation__c,
          Designation__r.Name,
          Department__c,
          Department__r.Name,
          Company__c,
          Requested_By__c,
          Requested_By__r.Name,
          Requested_By_Department__c,
          No_of_Positions__c,
          Expected_Compensation__c,
          Status__c,
          Expected_By_Date__c,
          Posting_Date__c,
          Completed_On__c,
          Time_to_Fill__c,
          Staffing_Plan__c,
          Staffing_Plan__r.Name,
          Reason_for_Hiring__c,
          Job_Description__c
        FROM PWChrono_Job_Requisition__c
        WHERE Id = :requisitionId
        LIMIT 1
      ];
      if (recs.isEmpty()) {
        throw new AuraHandledException('Job Requisition not found.');
      }
      return recs[0];
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('getJobRequisitionById failed', e);
      throw new AuraHandledException('Error loading job requisition.');
    }
  }

  /**
   * @description Saves (inserts or updates) a Job Requisition
   */
  @AuraEnabled
  public static Id saveJobRequisition(
    String requisitionJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      PWChrono_Job_Requisition__c rec = parseRequisitionJson(requisitionJson, portalUserId);
      upsert rec; // NOPMD
      return rec.Id;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('saveJobRequisition failed', e);
      throw new AuraHandledException(
        'Error saving job requisition: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Updates only the Status field on a Job Requisition
   */
  @AuraEnabled
  public static void updateJobRequisitionStatus(
    Id requisitionId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      List<PWChrono_Job_Requisition__c> recs = [
        SELECT Id, Status__c
        FROM PWChrono_Job_Requisition__c
        WHERE Id = :requisitionId
        LIMIT 1
      ];
      if (recs.isEmpty()) {
        throw new AuraHandledException('Job Requisition not found.');
      }
      recs[0].Status__c = newStatus;
      update recs[0]; // NOPMD
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('updateJobRequisitionStatus failed', e);
      throw new AuraHandledException('Error updating status.');
    }
  }

  /**
   * @description Deletes a Job Requisition
   */
  @AuraEnabled
  public static void deleteJobRequisition(
    Id requisitionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireHRAccess(portalUserId, sessionToken);
      List<PWChrono_Job_Requisition__c> recs = [
        SELECT Id, Status__c
        FROM PWChrono_Job_Requisition__c
        WHERE Id = :requisitionId
        LIMIT 1
      ];
      if (recs.isEmpty()) {
        throw new AuraHandledException('Job Requisition not found.');
      }
      if (recs[0].Status__c != 'Pending') {
        throw new AuraHandledException(
          'Only pending job requisitions can be deleted.'
        );
      }
      delete recs[0]; // NOPMD
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('deleteJobRequisition failed', e);
      throw new AuraHandledException('Error deleting job requisition.');
    }
  }

  /**
   * @description Returns active Designations for lookup dropdowns
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Designation__c> getActiveDesignations() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Designation__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('getActiveDesignations failed', e);
      throw new AuraHandledException('Error loading designations.');
    }
  }

  /**
   * @description Returns active Departments for lookup dropdowns
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Department__c> getActiveDepartments() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Department__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('getActiveDepartments failed', e);
      throw new AuraHandledException('Error loading departments.');
    }
  }

  /**
   * @description Returns submitted/open Staffing Plans for the lookup dropdown
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Staffing_Plan__c> getAvailableStaffingPlans() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Staffing_Plan__c
        WHERE Status__c IN ('Submitted', 'Draft')
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('getAvailableStaffingPlans failed', e);
      throw new AuraHandledException('Error loading staffing plans.');
    }
  }
}