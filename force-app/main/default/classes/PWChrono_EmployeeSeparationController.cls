/**
 * @description Controller for the Employee Separation / Exit module.
 *              HR admins can manage all separations; employees see only their own.
 */
public inherited sharing class PWChrono_EmployeeSeparationController {
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
  // Separation list
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns separations. HR admins see all; employees see their own.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Employee_Separation__c> getSeparations(
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
        ' Company__c, Department__c, Department__r.Name,' +
        ' Designation__c, Designation__r.Name,' +
        ' Resignation_Letter_Date__c, Relieving_Date__c,' +
        ' Reason_for_Leaving__c, Status__c, Separation_Template__c,' +
        ' Separation_Template__r.Name' +
        ' FROM PWChrono_Employee_Separation__c';

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
      query += ' ORDER BY Resignation_Letter_Date__c DESC NULLS LAST LIMIT :queryLimit';

      return Database.query(query);
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.getSeparations',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single separation with checklist
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a single separation by Id.
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Employee_Separation__c getSeparationById(
    String separationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      List<PWChrono_Employee_Separation__c> records = [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee__r.Name,
          Employee_Name__c,
          Company__c,
          Department__c,
          Department__r.Name,
          Designation__c,
          Designation__r.Name,
          Resignation_Letter_Date__c,
          Relieving_Date__c,
          Reason_for_Leaving__c,
          Status__c,
          Separation_Template__c,
          Separation_Template__r.Name
        FROM PWChrono_Employee_Separation__c
        WHERE Id = :separationId
        LIMIT 1
      ];
      if (records.isEmpty()) {
        throw new AuraHandledException('Separation record not found.');
      }
      return records[0];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.getSeparationById',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Returns checklist items for a separation.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Separation_Checklist__c> getChecklistItems(
    String separationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      return [
        SELECT
          Id,
          Name,
          Separation__c,
          Assigned_To__c,
          Assigned_To__r.Name,
          Status__c,
          Is_Required__c,
          Notes__c
        FROM PWChrono_Separation_Checklist__c
        WHERE Separation__c = :separationId
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.getChecklistItems',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update) with checklist
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Upserts a separation record and replaces its checklist items.
   */
  @AuraEnabled
  public static String saveSeparation(
    String separationJson,
    String checklistJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      PWChrono_Employee_Separation__c separation = (PWChrono_Employee_Separation__c) JSON.deserialize(
        separationJson,
        PWChrono_Employee_Separation__c.class
      );

      if (separation.Id == null) {
        separation.Status__c = String.isBlank(separation.Status__c)
          ? 'Pending'
          : separation.Status__c;
      }
      upsert separation; // NOPMD

      // Replace checklist items
      if (String.isNotBlank(checklistJson) && checklistJson != '[]') {
        List<PWChrono_Separation_Checklist__c> existingItems = [
          SELECT Id
          FROM PWChrono_Separation_Checklist__c
          WHERE Separation__c = :separation.Id
        ];
        delete existingItems;

        List<Object> rawItems = (List<Object>) JSON.deserializeUntyped(
          checklistJson
        );
        List<PWChrono_Separation_Checklist__c> newItems = new List<PWChrono_Separation_Checklist__c>();
        for (Object obj : rawItems) {
          Map<String, Object> itemMap = (Map<String, Object>) obj;
          PWChrono_Separation_Checklist__c item = new PWChrono_Separation_Checklist__c();
          item.Separation__c = separation.Id;
          item.Name = (String) itemMap.get('Name');
          item.Assigned_To__c = (String) itemMap.get('Assigned_To__c');
          item.Status__c = itemMap.containsKey('Status__c')
            ? (String) itemMap.get('Status__c')
            : 'Pending';
          item.Is_Required__c =
            itemMap.containsKey('Is_Required__c') &&
            (Boolean) itemMap.get('Is_Required__c');
          item.Notes__c = (String) itemMap.get('Notes__c');
          newItems.add(item);
        }
        if (!newItems.isEmpty()) {
          insert newItems;
        }
      }

      return separation.Id;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.saveSeparation',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Updates separation status. Restricted to HR admins.
   */
  @AuraEnabled
  public static void updateSeparationStatus(
    String separationId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can update separation status.'
        );
      }
      update new PWChrono_Employee_Separation__c(
        Id = separationId,
        Status__c = newStatus
      );
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.updateSeparationStatus',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Deletes a separation record. Restricted to HR admins.
   */
  @AuraEnabled
  public static void deleteSeparation(
    String separationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can delete separation records.'
        );
      }
      List<PWChrono_Employee_Separation__c> separations = [
        SELECT Id, Status__c
        FROM PWChrono_Employee_Separation__c
        WHERE Id = :separationId
        LIMIT 1
      ];
      if (separations.isEmpty()) {
        throw new AuraHandledException('Separation record not found.');
      }
      if (separations[0].Status__c != 'Pending') {
        throw new AuraHandledException(
          'Only pending separation records can be deleted.'
        );
      }
      delete separations[0];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.deleteSeparation',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Employee Exit CRUD
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns employee exit records. HR sees all; employees see own.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Employee_Exit__c> getExitRecords(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      Boolean isHR = isHrAdmin(portalUserId);
      String query =
        'SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Name__c,' +
        ' Department__c, Department__r.Name, Designation__c, Designation__r.Name,' +
        ' Date_of_Joining__c, Resignation_Date__c, Relieving_Date__c,' +
        ' Exit_Type__c, Reason_for_Exit__c, Exit_Interview_Status__c,' +
        ' Full_and_Final_Status__c, Final_Decision__c, Separation__c' +
        ' FROM PWChrono_Employee_Exit__c';
      if (!isHR) {
        query +=
          ' WHERE Employee__c = \'' +
          String.escapeSingleQuotes(portalUserId) +
          '\'';
      }
      query +=
        ' ORDER BY Resignation_Date__c DESC NULLS LAST' +
        ' LIMIT ' +
        PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      return Database.query(query); // NOPMD
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.getExitRecords',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Upserts an employee exit record.
   */
  @AuraEnabled
  public static String saveExitRecord(
    String exitJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      PWChrono_Employee_Exit__c exitRec = (PWChrono_Employee_Exit__c) JSON.deserialize(
        exitJson,
        PWChrono_Employee_Exit__c.class
      );
      upsert exitRec; // NOPMD
      return exitRec.Id;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.saveExitRecord',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  /** @description Returns active designations for dropdowns. */
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
        'PWChrono_EmployeeSeparationController.getActiveDesignations',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /** @description Returns active departments for dropdowns. */
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
        'PWChrono_EmployeeSeparationController.getActiveDepartments',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /** @description Returns active portal users (employees) for dropdowns. */
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
        'PWChrono_EmployeeSeparationController.getActiveEmployees',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /** @description Returns active separation templates for dropdowns. */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Separation_Template__c> getActiveSeparationTemplates() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Separation_Template__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeeSeparationController.getActiveSeparationTemplates',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }
}