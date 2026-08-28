/**
 * @description Controller for the Employee Promotion module.
 *              Handles CRUD for PWChrono_Employee_Promotion__c and its child
 *              PWChrono_Promotion_Detail__c records.
 *              HR admins can manage all promotions; employees see only their own.
 */
public inherited sharing class PWChrono_EmployeePromotionController {
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
  // Promotion list
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a list of promotions. HR admins see all; employees
   *              see only their own records.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Employee_Promotion__c> getPromotions(
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
        ' Company__c, Promotion_Date__c,' +
        ' Current_Designation__c, Current_Designation__r.Name,' +
        ' New_Designation__c, New_Designation__r.Name,' +
        ' Current_Department__c, Current_Department__r.Name,' +
        ' New_Department__c, New_Department__r.Name,' +
        ' Current_Grade__c, New_Grade__c,' +
        ' Current_Branch__c, New_Branch__c,' +
        ' Current_Reports_To__c, Current_Reports_To__r.Name,' +
        ' New_Reports_To__c, New_Reports_To__r.Name,' +
        ' Current_Salary__c, New_Salary__c,' +
        ' Status__c, Promotion_Details__c' +
        ' FROM PWChrono_Employee_Promotion__c';

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
      query += ' ORDER BY Promotion_Date__c DESC NULLS LAST LIMIT :queryLimit';

      return Database.query(query);
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeePromotionController.getPromotions',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single promotion with detail lines
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a single promotion record.
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Employee_Promotion__c getPromotionById(
    String promotionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      List<PWChrono_Employee_Promotion__c> records = [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee__r.Name,
          Employee_Name__c,
          Company__c,
          Promotion_Date__c,
          Current_Designation__c,
          Current_Designation__r.Name,
          New_Designation__c,
          New_Designation__r.Name,
          Current_Department__c,
          Current_Department__r.Name,
          New_Department__c,
          New_Department__r.Name,
          Current_Grade__c,
          New_Grade__c,
          Current_Branch__c,
          New_Branch__c,
          Current_Reports_To__c,
          Current_Reports_To__r.Name,
          New_Reports_To__c,
          New_Reports_To__r.Name,
          Current_Salary__c,
          New_Salary__c,
          Status__c,
          Promotion_Details__c
        FROM PWChrono_Employee_Promotion__c
        WHERE Id = :promotionId
        LIMIT 1
      ];
      if (records.isEmpty()) {
        throw new AuraHandledException('Promotion record not found.');
      }
      return records[0];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeePromotionController.getPromotionById',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /**
   * @description Returns the detail lines for a promotion.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Promotion_Detail__c> getPromotionDetails(
    String promotionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      return [
        SELECT
          Id,
          Name,
          Property__c,
          Current_Value__c,
          New_Value__c,
          Promotion__c
        FROM PWChrono_Promotion_Detail__c
        WHERE Promotion__c = :promotionId
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeePromotionController.getPromotionDetails',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update) with detail lines
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Upserts a promotion and replaces its detail lines.
   * @param promotionJson  JSON of the PWChrono_Employee_Promotion__c record.
   * @param detailsJson    JSON array of PWChrono_Promotion_Detail__c (without Id).
   */
  @AuraEnabled
  public static String savePromotion(
    String promotionJson,
    String detailsJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);

      Map<String, Object> promoMap = (Map<String, Object>) JSON.deserializeUntyped(
        promotionJson
      );
      PWChrono_Employee_Promotion__c promo = (PWChrono_Employee_Promotion__c) JSON.deserialize(
        promotionJson,
        PWChrono_Employee_Promotion__c.class
      );

      Boolean isInsert = (promo.Id == null);
      if (isInsert) {
        promo.Status__c = String.isBlank(promo.Status__c)
          ? 'Draft'
          : promo.Status__c;
      }

      upsert promo; // NOPMD

      // Replace detail lines
      if (String.isNotBlank(detailsJson) && detailsJson != '[]') {
        List<PWChrono_Promotion_Detail__c> existing = [
          SELECT Id
          FROM PWChrono_Promotion_Detail__c
          WHERE Promotion__c = :promo.Id
        ];
        if (!existing.isEmpty()) {
          delete existing;
        }
        List<Object> rawDetails = (List<Object>) JSON.deserializeUntyped(
          detailsJson
        );
        List<PWChrono_Promotion_Detail__c> newDetails = new List<PWChrono_Promotion_Detail__c>();
        for (Object rawDetail : rawDetails) {
          Map<String, Object> dm = (Map<String, Object>) rawDetail;
          PWChrono_Promotion_Detail__c d = new PWChrono_Promotion_Detail__c(
            Promotion__c = promo.Id,
            Property__c = (String) dm.get('Property__c'),
            Current_Value__c = (String) dm.get('Current_Value__c'),
            New_Value__c = (String) dm.get('New_Value__c')
          );
          newDetails.add(d);
        }
        if (!newDetails.isEmpty()) {
          insert newDetails;
        }
      }

      return promo.Id;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeePromotionController.savePromotion',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Updates the status of a promotion. Restricted to HR admins.
   */
  @AuraEnabled
  public static void updatePromotionStatus(
    String promotionId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can update promotion status.'
        );
      }
      PWChrono_Employee_Promotion__c promo = new PWChrono_Employee_Promotion__c(
        Id = promotionId,
        Status__c = newStatus
      );
      update promo;
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeePromotionController.updatePromotionStatus',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (HR only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Deletes a promotion record. Restricted to HR admins.
   */
  @AuraEnabled
  public static void deletePromotion(
    String promotionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      if (!isHrAdmin(portalUserId)) {
        throw new AuraHandledException(
          'Only HR Admins can delete promotion records.'
        );
      }
      List<PWChrono_Employee_Promotion__c> promotions = [
        SELECT Id, Status__c
        FROM PWChrono_Employee_Promotion__c
        WHERE Id = :promotionId
        LIMIT 1
      ];
      if (promotions.isEmpty()) {
        throw new AuraHandledException('Promotion record not found.');
      }
      if (promotions[0].Status__c != 'Draft') {
        throw new AuraHandledException(
          'Only draft promotion records can be deleted.'
        );
      }
      delete promotions[0];
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_EmployeePromotionController.deletePromotion',
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
        'PWChrono_EmployeePromotionController.getActiveDesignations',
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
        'PWChrono_EmployeePromotionController.getActiveDepartments',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  /** @description Returns active portal users for employee / reports-to dropdowns. */
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
        'PWChrono_EmployeePromotionController.getActiveEmployees',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }
}