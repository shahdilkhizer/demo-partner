/**
 * @description Controller for the Employee Transfer module.
 *              HR admins can manage all transfers; employees see only their own.
 */
public inherited sharing class PWChrono_EmployeeTransferController {
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

  // ─────────────────────────────────────────────────────────────────────────
  // Transfer list
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns transfers. HR admins see all; employees see their own.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Employee_Transfer__c> getTransfers(
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
        ' Company__c, Transfer_Date__c,' +
        ' Current_Branch__c, New_Branch__c,' +
        ' Current_Department__c, Current_Department__r.Name,' +
        ' New_Department__c, New_Department__r.Name,' +
        ' Current_Designation__c, Current_Designation__r.Name,' +
        ' New_Designation__c, New_Designation__r.Name,' +
        ' Current_Reports_To__c, Current_Reports_To__r.Name,' +
        ' New_Reports_To__c, New_Reports_To__r.Name,' +
        ' Transfer_Details__c, Status__c' +
        ' FROM PWChrono_Employee_Transfer__c';

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
      query += ' ORDER BY Transfer_Date__c DESC NULLS LAST LIMIT :queryLimit';

      return Database.query(query);
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeTransferController.getTransfers',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single transfer
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a single transfer by Id.
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Employee_Transfer__c getTransferById(
    String transferId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      List<PWChrono_Employee_Transfer__c> records = [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee__r.Name,
          Employee_Name__c,
          Company__c,
          Transfer_Date__c,
          Current_Branch__c,
          New_Branch__c,
          Current_Department__c,
          Current_Department__r.Name,
          New_Department__c,
          New_Department__r.Name,
          Current_Designation__c,
          Current_Designation__r.Name,
          New_Designation__c,
          New_Designation__r.Name,
          Current_Reports_To__c,
          Current_Reports_To__r.Name,
          New_Reports_To__c,
          New_Reports_To__r.Name,
          Transfer_Details__c,
          Status__c
        FROM PWChrono_Employee_Transfer__c
        WHERE Id = :transferId
        LIMIT 1
      ];
      if (records.isEmpty()) {
        throw new AuraHandledException('Transfer record not found.');
      }
      return records[0];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeTransferController.getTransferById',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Upserts a transfer record.
   */
  @AuraEnabled
  public static String saveTransfer(
    String transferJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      PWChrono_Employee_Transfer__c transfer = (PWChrono_Employee_Transfer__c) JSON.deserialize(
        transferJson,
        PWChrono_Employee_Transfer__c.class
      );

      if (transfer.Id == null) {
        transfer.Status__c = String.isBlank(transfer.Status__c)
          ? 'Draft'
          : transfer.Status__c;
      }

      upsert transfer; // NOPMD
      return transfer.Id;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeTransferController.saveTransfer',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Updates the status. Restricted to HR admins.
   */
  @AuraEnabled
  public static void updateTransferStatus(
    String transferId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can update transfer status.'
        );
      }
      update new PWChrono_Employee_Transfer__c(
        Id = transferId,
        Status__c = newStatus
      );
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeTransferController.updateTransferStatus',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Deletes a transfer record. Restricted to HR admins.
   */
  @AuraEnabled
  public static void deleteTransfer(
    String transferId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can delete transfer records.'
        );
      }
      List<PWChrono_Employee_Transfer__c> transfers = [
        SELECT Id, Status__c
        FROM PWChrono_Employee_Transfer__c
        WHERE Id = :transferId
        LIMIT 1
      ];
      if (transfers.isEmpty()) {
        throw new AuraHandledException('Transfer record not found.');
      }
      if (transfers[0].Status__c != 'Draft') {
        throw new AuraHandledException(
          'Only draft transfer records can be deleted.'
        );
      }
      delete transfers[0];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeTransferController.deleteTransfer',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  /** @description Returns all active designations for dropdowns. */
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
        'PWChrono_EmployeeTransferController.getActiveDesignations',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /** @description Returns all active departments for dropdowns. */
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
        'PWChrono_EmployeeTransferController.getActiveDepartments',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /** @description Returns active portal users for employee / manager dropdowns. */
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
        'PWChrono_EmployeeTransferController.getActiveEmployees',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }
}