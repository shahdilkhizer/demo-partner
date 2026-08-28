/**
 * @description Controller for the Exit Interview module.
 *              HR admins can manage all exit interviews; employees see only their own.
 */
public inherited sharing class PWChrono_ExitInterviewController {
  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static void requireAccess(String portalUserId, String sessionToken) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
  }

  private static Boolean isHrAdmin(String portalUserId) {
    List<Portal_Users__c> users = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :portalUserId
      LIMIT 1
    ];
    return !users.isEmpty() &&
      users[0].Role__c == PWChrono_Constants.ROLE_HR_ADMIN;
  }

  private static void requireHrAdmin(String portalUserId) {
    if (!isHrAdmin(portalUserId)) {
      throw new AuraHandledException('Access denied. HR Admin role required.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Interview list
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns exit interviews. HR admins see all; employees see their own.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Exit_Interview__c> getInterviews(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      Boolean isHR = isHrAdmin(portalUserId);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;

      String query =
        'SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Name__c,' +
        ' Department__c, Department__r.Name,' +
        ' Designation__c, Designation__r.Name,' +
        ' Separation__c, Separation__r.Name,' +
        ' Interviewer__c, Interviewer__r.Name,' +
        ' Interview_Date__c, Rating__c, Status__c' +
        ' FROM PWChrono_Exit_Interview__c';

      List<String> filters = new List<String>();
      if (!isHR) {
        filters.add('Employee__c = :portalUserId');
      }
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        filters.add('Status__c = :statusFilter');
      }
      if (!filters.isEmpty()) {
        query += ' WHERE ' + String.join(filters, ' AND ');
      }
      query += ' ORDER BY Interview_Date__c DESC NULLS LAST LIMIT :queryLimit';

      return Database.query(query);
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.getInterviews',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single interview
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a single exit interview by Id.
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Exit_Interview__c getInterviewById(
    String interviewId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      List<PWChrono_Exit_Interview__c> results = [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee__r.Name,
          Employee_Name__c,
          Department__c,
          Department__r.Name,
          Designation__c,
          Designation__r.Name,
          Separation__c,
          Separation__r.Name,
          Interviewer__c,
          Interviewer__r.Name,
          Interview_Date__c,
          Exit_Questionnaire__c,
          Employee_Feedback__c,
          Final_Remarks__c,
          Rating__c,
          Status__c
        FROM PWChrono_Exit_Interview__c
        WHERE Id = :interviewId
        LIMIT 1
      ];
      if (results.isEmpty()) {
        throw new AuraHandledException('Exit interview not found.');
      }
      return results[0];
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.getInterviewById',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Creates or updates an exit interview record.
   */
  @AuraEnabled
  public static String saveInterview(
    String interviewJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
        interviewJson
      );

      PWChrono_Exit_Interview__c rec = new PWChrono_Exit_Interview__c();

      String recId = (String) payload.get('Id');
      if (String.isNotBlank(recId)) {
        rec.Id = recId;
      }
      if (
        payload.containsKey('Employee__c') && payload.get('Employee__c') != null
      ) {
        rec.Employee__c = (String) payload.get('Employee__c');
      }
      if (payload.containsKey('Employee_Name__c')) {
        rec.Employee_Name__c = (String) payload.get('Employee_Name__c');
      }
      if (
        payload.containsKey('Department__c') &&
        payload.get('Department__c') != null
      ) {
        rec.Department__c = (String) payload.get('Department__c');
      }
      if (
        payload.containsKey('Designation__c') &&
        payload.get('Designation__c') != null
      ) {
        rec.Designation__c = (String) payload.get('Designation__c');
      }
      if (
        payload.containsKey('Separation__c') &&
        payload.get('Separation__c') != null
      ) {
        rec.Separation__c = (String) payload.get('Separation__c');
      }
      if (
        payload.containsKey('Interviewer__c') &&
        payload.get('Interviewer__c') != null
      ) {
        rec.Interviewer__c = (String) payload.get('Interviewer__c');
      }
      if (
        payload.containsKey('Interview_Date__c') &&
        payload.get('Interview_Date__c') != null
      ) {
        rec.Interview_Date__c = Date.valueOf(
          (String) payload.get('Interview_Date__c')
        );
      }
      if (payload.containsKey('Exit_Questionnaire__c')) {
        rec.Exit_Questionnaire__c = (String) payload.get(
          'Exit_Questionnaire__c'
        );
      }
      if (payload.containsKey('Employee_Feedback__c')) {
        rec.Employee_Feedback__c = (String) payload.get('Employee_Feedback__c');
      }
      if (payload.containsKey('Final_Remarks__c')) {
        rec.Final_Remarks__c = (String) payload.get('Final_Remarks__c');
      }
      if (
        payload.containsKey('Rating__c') && payload.get('Rating__c') != null
      ) {
        rec.Rating__c = Integer.valueOf(
          String.valueOf(payload.get('Rating__c'))
        );
      }
      if (
        payload.containsKey('Status__c') && payload.get('Status__c') != null
      ) {
        rec.Status__c = (String) payload.get('Status__c');
      }

      upsert rec;
      return rec.Id;
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.saveInterview',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Updates the status of an exit interview. HR Admin only.
   */
  @AuraEnabled
  public static void updateInterviewStatus(
    String interviewId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      requireHrAdmin(portalUserId);

      PWChrono_Exit_Interview__c rec = new PWChrono_Exit_Interview__c(
        Id = interviewId,
        Status__c = newStatus
      );
      update rec;
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.updateInterviewStatus',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Deletes an exit interview record. HR Admin only.
   */
  @AuraEnabled
  public static void deleteInterview(
    String interviewId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      requireHrAdmin(portalUserId);

      List<PWChrono_Exit_Interview__c> interviews = [
        SELECT Id, Status__c
        FROM PWChrono_Exit_Interview__c
        WHERE Id = :interviewId
        LIMIT 1
      ];
      if (interviews.isEmpty()) {
        throw new AuraHandledException('Exit interview not found.');
      }
      if (interviews[0].Status__c != 'Pending') {
        throw new AuraHandledException(
          'Only pending exit interviews can be deleted.'
        );
      }
      delete interviews[0];
    } catch (AuraHandledException ex) {
      throw ex;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.deleteInterview',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns active designations for dropdown.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Designation__c> getActiveDesignations() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Designation__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.getActiveDesignations',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Returns active departments for dropdown.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Department__c> getActiveDepartments() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Department__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.getActiveDepartments',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Returns active portal users for employee / interviewer dropdowns.
   */
  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getActiveEmployees() {
    try {
      return [
        SELECT Id, Name
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.getActiveEmployees',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Returns active employee separations for linking to an exit interview.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Employee_Separation__c> getActiveSeparations() {
    try {
      return [
        SELECT Id, Name, Employee__r.Name
        FROM PWChrono_Employee_Separation__c
        WHERE Status__c != 'Cancelled'
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_ExitInterviewController.getActiveSeparations',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }
}