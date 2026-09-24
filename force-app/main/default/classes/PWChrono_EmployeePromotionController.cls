/**
 * @description Controller for the Employee Promotion module. Manages
 *              PWChrono_Employee_Promotion__c records and their
 *              PWChrono_Promotion_Detail__c lines, and applies an approved
 *              promotion to the employee record.
 *
 *              Declared without sharing because portal requests run as the
 *              Experience Cloud site guest user and these objects use a private
 *              external sharing model, so with-sharing queries would return
 *              nothing. Authorization is enforced in code instead:
 *              - every @AuraEnabled method verifies the portal session token and
 *                requires the Employee Lifecycle feature;
 *              - status changes and deletes also require an administrator
 *                (HR Admin, System Administrator or System Admin);
 *              - non-administrators only see and edit promotions for employees
 *                inside their access scope, and only while they are Draft;
 *              - nobody can create, edit, change the status of or delete a
 *                promotion about themselves.
 *
 *              The employee name and the current department, designation and
 *              reporting manager are a snapshot of the employee record. The
 *              server takes it on every save and again at approval; values sent
 *              by the client for these fields are ignored.
 *
 *              Approving a promotion updates the employee's department,
 *              designation and reporting manager. Salary is recorded for
 *              reference only; pay changes are made in the Payroll salary setup.
 */
public without sharing class PWChrono_EmployeePromotionController {
  public static final String STATUS_DRAFT = 'Draft';
  public static final String STATUS_SUBMITTED = 'Submitted';
  public static final String STATUS_APPROVED = 'Approved';
  public static final String STATUS_CANCELLED = 'Cancelled';

  private static final String CLASS_NAME = 'PWChrono_EmployeePromotionController';
  private static final String NOT_FOUND_MESSAGE = 'Promotion record not found.';
  private static final String SELF_MESSAGE = 'You cannot manage a promotion for yourself. Ask another HR user to do this.';
  private static final Integer LOOKUP_LIMIT = 1000;
  private static final Integer MAX_DETAIL_LINES = 100;

  /** Tests set this to fail an approval after the employee was updated. */
  @TestVisible
  private static Boolean simulateFailureAfterApply = false;

  private static final Set<String> ALL_STATUSES = new Set<String>{
    STATUS_DRAFT,
    STATUS_SUBMITTED,
    STATUS_APPROVED,
    STATUS_CANCELLED
  };

  private static final Set<String> TERMINAL_STATUSES = new Set<String>{
    STATUS_APPROVED,
    STATUS_CANCELLED
  };

  private static final Set<String> DELETABLE_STATUSES = new Set<String>{
    STATUS_DRAFT,
    STATUS_CANCELLED
  };

  private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = new Map<String, Set<String>>{
    STATUS_DRAFT => new Set<String>{ STATUS_SUBMITTED, STATUS_CANCELLED },
    STATUS_SUBMITTED => new Set<String>{
      STATUS_DRAFT,
      STATUS_APPROVED,
      STATUS_CANCELLED
    }
  };

  /**
   * Fields a client may set when creating or editing a promotion. The employee
   * name and current department, designation and reporting manager are taken
   * from the employee record instead.
   */
  private static final List<Schema.SObjectField> EDITABLE_FIELDS = new List<Schema.SObjectField>{
    PWChrono_Employee_Promotion__c.Employee__c,
    PWChrono_Employee_Promotion__c.Company__c,
    PWChrono_Employee_Promotion__c.Promotion_Date__c,
    PWChrono_Employee_Promotion__c.New_Designation__c,
    PWChrono_Employee_Promotion__c.New_Department__c,
    PWChrono_Employee_Promotion__c.Current_Grade__c,
    PWChrono_Employee_Promotion__c.New_Grade__c,
    PWChrono_Employee_Promotion__c.Current_Branch__c,
    PWChrono_Employee_Promotion__c.New_Branch__c,
    PWChrono_Employee_Promotion__c.New_Reports_To__c,
    PWChrono_Employee_Promotion__c.Current_Salary__c,
    PWChrono_Employee_Promotion__c.New_Salary__c,
    PWChrono_Employee_Promotion__c.Promotion_Details__c
  };

  private static final String PROMOTION_FIELDS =
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

  private class SimulatedFailureException extends Exception {
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Caller access
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Tells the screen whether the caller is an administrator, so
   *              it shows the same actions the server allows.
   * @return Map with portalUserId (Id) and isAdmin (Boolean)
   */
  @AuraEnabled
  public static Map<String, Object> getAccessInfo(
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      return new Map<String, Object>{
        'portalUserId' => actorId,
        'isAdmin' => PWChrono_AccessController.isAdmin(actorId)
      };
    } catch (Exception ex) {
      throw toHandled(ex, 'getAccessInfo', 'Unable to load your access.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Promotion list
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns promotions, newest first. Administrators see all
   *              promotions; other users see promotions for employees in
   *              their access scope.
   * @param statusFilter A status value, or 'All' / blank for every status
   */
  @AuraEnabled
  public static List<PWChrono_Employee_Promotion__c> getPromotions(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      Set<Id> scope = getEmployeeScope(actorId);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;

      List<String> filters = new List<String>();
      if (scope != null) {
        filters.add('Employee__c IN :scope');
      }
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        filters.add('Status__c = :statusFilter');
      }
      String query = PROMOTION_FIELDS;
      if (!filters.isEmpty()) {
        query += ' WHERE ' + String.join(filters, ' AND ');
      }
      query += ' ORDER BY Promotion_Date__c DESC NULLS LAST, CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (Exception ex) {
      throw toHandled(ex, 'getPromotions', 'Unable to load promotions.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single promotion with detail lines
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a single promotion the caller is allowed to see.
   */
  @AuraEnabled
  public static PWChrono_Employee_Promotion__c getPromotionById(
    String promotionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      return getVisiblePromotion(promotionId, getEmployeeScope(actorId));
    } catch (Exception ex) {
      throw toHandled(ex, 'getPromotionById', 'Unable to load the promotion.');
    }
  }

  /**
   * @description Returns the detail lines of a promotion the caller is
   *              allowed to see.
   */
  @AuraEnabled
  public static List<PWChrono_Promotion_Detail__c> getPromotionDetails(
    String promotionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      PWChrono_Employee_Promotion__c promotion = getVisiblePromotion(
        promotionId,
        getEmployeeScope(actorId)
      );
      return [
        SELECT
          Id,
          Name,
          Property__c,
          Current_Value__c,
          New_Value__c,
          Promotion__c
        FROM PWChrono_Promotion_Detail__c
        WHERE Promotion__c = :promotion.Id
        ORDER BY CreatedDate ASC, Name ASC
        LIMIT 200
      ];
    } catch (Exception ex) {
      throw toHandled(
        ex,
        'getPromotionDetails',
        'Unable to load the promotion details.'
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update) with detail lines
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Creates or edits a promotion and, when detail lines are
   *              supplied, replaces its detail lines. Only editable fields are
   *              copied from the client; the status cannot be set here (new
   *              promotions start as Draft). Approved and Cancelled promotions
   *              cannot be edited, and Submitted promotions can only be edited
   *              by an administrator. The employee name and current
   *              assignment are refreshed from the employee record.
   * @param promotionJson JSON object with the promotion's editable fields
   *                      (and Id when editing)
   * @param detailsJson   JSON array of detail lines (Property__c,
   *                      Current_Value__c, New_Value__c). Blank leaves the
   *                      existing lines unchanged; '[]' removes them all.
   * @return Id of the saved promotion
   */
  @AuraEnabled
  public static String savePromotion(
    String promotionJson,
    String detailsJson,
    String portalUserId,
    String sessionToken
  ) {
    Savepoint sp;
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      Boolean admin = PWChrono_AccessController.isAdmin(actorId);
      Set<Id> scope = admin
        ? null
        : PWChrono_AccessController.getVisibleEmployeeIds(actorId);
      if (String.isBlank(promotionJson)) {
        throw handled('Promotion details are required.');
      }
      Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(
        promotionJson
      );

      PWChrono_Employee_Promotion__c promotion = new PWChrono_Employee_Promotion__c(
        Id = readRecordId(raw)
      );
      copyEditableFields(raw, promotion);

      PWChrono_Employee_Promotion__c existing;
      if (promotion.Id == null) {
        promotion.Status__c = STATUS_DRAFT;
      } else {
        existing = lockPromotion(promotion.Id);
        requireEditable(existing, actorId, admin, scope);
      }

      Id employeeId = (Id) valueAfterSave(
        raw,
        promotion,
        existing,
        PWChrono_Employee_Promotion__c.Employee__c
      );
      if (employeeId == null) {
        throw handled('Employee is required.');
      }
      Portal_Users__c employee = requireActiveEmployee(employeeId);
      if (!isInScope(scope, employeeId)) {
        throw handled(
          'You can only manage promotions for employees within your access scope.'
        );
      }
      if (employeeId == actorId) {
        throw handled(SELF_MESSAGE);
      }
      Id newReportsToId = (Id) valueAfterSave(
        raw,
        promotion,
        existing,
        PWChrono_Employee_Promotion__c.New_Reports_To__c
      );
      if (newReportsToId == employeeId) {
        throw handled('An employee cannot report to themselves.');
      }
      Object promotionDate = valueAfterSave(
        raw,
        promotion,
        existing,
        PWChrono_Employee_Promotion__c.Promotion_Date__c
      );
      if (promotionDate == null) {
        throw handled('Promotion Date is required.');
      }
      if (
        isNegative(promotion.Current_Salary__c) ||
        isNegative(promotion.New_Salary__c)
      ) {
        throw handled('Salary amounts cannot be negative.');
      }

      promotion.Employee__c = employeeId;
      applyEmployeeSnapshot(promotion, employee);

      List<PWChrono_Promotion_Detail__c> detailLines = parseDetailLines(
        detailsJson
      );

      sp = Database.setSavepoint();
      upsert promotion; // NOPMD - guest runtime; access enforced above
      replaceDetailLines(promotion.Id, detailLines);
      return promotion.Id;
    } catch (Exception ex) {
      rollback(sp);
      throw toHandled(ex, 'savePromotion', 'Unable to save the promotion.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (administrators only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Moves a promotion to a new status. Allowed transitions:
   *              Draft to Submitted or Cancelled; Submitted to Draft, Approved
   *              or Cancelled. Approved and Cancelled are final. Approving
   *              records the employee's current assignment on the promotion,
   *              then applies the new department, designation and reporting
   *              manager to the employee; a promotion without a date, or dated
   *              in the future, cannot be approved. Administrators only, and
   *              never for their own promotion.
   */
  @AuraEnabled
  public static void updatePromotionStatus(
    String promotionId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    Savepoint sp;
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      if (!PWChrono_AccessController.isAdmin(actorId)) {
        throw handled('Only HR administrators can change a promotion status.');
      }
      PWChrono_Employee_Promotion__c promotion = lockPromotion(
        toPromotionId(promotionId)
      );
      if (promotion.Employee__c == actorId) {
        throw handled(SELF_MESSAGE);
      }
      requireAllowedTransition(statusOf(promotion), newStatus);

      sp = Database.setSavepoint();
      if (newStatus == STATUS_APPROVED) {
        approve(promotion);
      }
      promotion.Status__c = newStatus;
      update promotion; // NOPMD - guest runtime; access enforced above
    } catch (Exception ex) {
      rollback(sp);
      throw toHandled(
        ex,
        'updatePromotionStatus',
        'Unable to update the promotion status.'
      );
    }
  }

  /** Applies an approved promotion to the employee. Caller holds a savepoint. */
  private static void approve(PWChrono_Employee_Promotion__c promotion) {
    if (promotion.Promotion_Date__c == null) {
      throw handled('Set the promotion date before approving this promotion.');
    }
    PWChrono_EmployeeLifecycleService.requireEffectiveDate(
      promotion.Promotion_Date__c,
      'This promotion'
    );
    Portal_Users__c employee = findEmployee(promotion.Employee__c);
    if (employee != null) {
      applyEmployeeSnapshot(promotion, employee);
    }
    PWChrono_EmployeeLifecycleService.applyAssignmentChange(
      promotion.Employee__c,
      promotion.New_Department__c,
      promotion.New_Designation__c,
      promotion.New_Reports_To__c
    );
    if (simulateFailureAfterApply) {
      throw new SimulatedFailureException(
        'Simulated failure after the employee was updated.'
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (administrators only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Deletes a Draft or Cancelled promotion and its detail lines.
   *              Administrators only, and never their own promotion.
   */
  @AuraEnabled
  public static void deletePromotion(
    String promotionId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      if (!PWChrono_AccessController.isAdmin(actorId)) {
        throw handled('Only HR administrators can delete promotions.');
      }
      PWChrono_Employee_Promotion__c promotion = lockPromotion(
        toPromotionId(promotionId)
      );
      if (promotion.Employee__c == actorId) {
        throw handled(SELF_MESSAGE);
      }
      String status = statusOf(promotion);
      if (!DELETABLE_STATUSES.contains(status)) {
        throw handled(
          'Only Draft or Cancelled promotions can be deleted. This promotion is ' +
            status +
            '.'
        );
      }
      delete promotion; // NOPMD - guest runtime; access enforced above
    } catch (Exception ex) {
      throw toHandled(ex, 'deletePromotion', 'Unable to delete the promotion.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  /** @description Returns active designations for dropdowns. */
  @AuraEnabled
  public static List<PWChrono_Designation__c> getActiveDesignations(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      return [
        SELECT Id, Name
        FROM PWChrono_Designation__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :LOOKUP_LIMIT
      ];
    } catch (Exception ex) {
      throw toHandled(
        ex,
        'getActiveDesignations',
        'Unable to load designations.'
      );
    }
  }

  /** @description Returns active departments for dropdowns. */
  @AuraEnabled
  public static List<PWChrono_Department__c> getActiveDepartments(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      return [
        SELECT Id, Name
        FROM PWChrono_Department__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :LOOKUP_LIMIT
      ];
    } catch (Exception ex) {
      throw toHandled(
        ex,
        'getActiveDepartments',
        'Unable to load departments.'
      );
    }
  }

  /**
   * @description Returns active employees for the employee and reporting
   *              manager dropdowns, with their current assignment so the form
   *              can show the "current" values.
   */
  @AuraEnabled
  public static List<Portal_Users__c> getActiveEmployees(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      return [
        SELECT
          Id,
          Name,
          Department__c,
          Designation__c,
          Reports_To__c,
          Reports_To__r.Name
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :LOOKUP_LIMIT
      ];
    } catch (Exception ex) {
      throw toHandled(ex, 'getActiveEmployees', 'Unable to load employees.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Access helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Id requireAccess(String portalUserId, String sessionToken) {
    Id actorId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    PWChrono_AccessController.requireFeature(
      actorId,
      PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE
    );
    return actorId;
  }

  /**
   * @return null for administrators (no restriction), otherwise the employee
   *         Ids the actor may see and manage.
   */
  private static Set<Id> getEmployeeScope(Id actorId) {
    return PWChrono_AccessController.isAdmin(actorId)
      ? null
      : PWChrono_AccessController.getVisibleEmployeeIds(actorId);
  }

  private static Boolean isInScope(Set<Id> scope, Id employeeId) {
    return scope == null || (employeeId != null && scope.contains(employeeId));
  }

  /** Rejects edits the caller may not make to an existing promotion. */
  private static void requireEditable(
    PWChrono_Employee_Promotion__c existing,
    Id actorId,
    Boolean admin,
    Set<Id> scope
  ) {
    if (!isInScope(scope, existing.Employee__c)) {
      throw handled(NOT_FOUND_MESSAGE);
    }
    if (existing.Employee__c == actorId) {
      throw handled(SELF_MESSAGE);
    }
    String status = statusOf(existing);
    if (TERMINAL_STATUSES.contains(status)) {
      throw handled(status + ' promotions cannot be edited.');
    }
    if (status == STATUS_SUBMITTED && !admin) {
      throw handled(
        'This promotion has been submitted for approval. Only an HR administrator can change it now.'
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Record helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static PWChrono_Employee_Promotion__c getVisiblePromotion(
    String promotionId,
    Set<Id> scope
  ) {
    Id recordId = toPromotionId(promotionId);
    List<PWChrono_Employee_Promotion__c> records = Database.query(
      PROMOTION_FIELDS + ' WHERE Id = :recordId LIMIT 1'
    );
    if (records.isEmpty() || !isInScope(scope, records[0].Employee__c)) {
      throw handled(NOT_FOUND_MESSAGE);
    }
    return records[0];
  }

  private static PWChrono_Employee_Promotion__c lockPromotion(Id recordId) {
    List<PWChrono_Employee_Promotion__c> records = [
      SELECT
        Id,
        Status__c,
        Employee__c,
        Promotion_Date__c,
        New_Department__c,
        New_Designation__c,
        New_Reports_To__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :recordId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw handled(NOT_FOUND_MESSAGE);
    }
    return records[0];
  }

  private static String statusOf(PWChrono_Employee_Promotion__c promotion) {
    return String.isBlank(promotion.Status__c)
      ? STATUS_DRAFT
      : promotion.Status__c;
  }

  /** The value a field will have after the save: from the client, else as stored. */
  private static Object valueAfterSave(
    Map<String, Object> raw,
    PWChrono_Employee_Promotion__c promotion,
    PWChrono_Employee_Promotion__c existing,
    Schema.SObjectField field
  ) {
    if (raw.containsKey(field.getDescribe().getName()) || existing == null) {
      return promotion.get(field);
    }
    return existing.get(field);
  }

  private static Id toPromotionId(String value) {
    Id recordId;
    try {
      recordId = String.isBlank(value) ? null : Id.valueOf(value.trim());
    } catch (Exception e) {
      recordId = null;
    }
    if (
      recordId == null ||
      recordId.getSObjectType() != PWChrono_Employee_Promotion__c.SObjectType
    ) {
      throw handled(NOT_FOUND_MESSAGE);
    }
    return recordId;
  }

  private static Id readRecordId(Map<String, Object> raw) {
    Object value = raw.get('Id');
    if (value == null || String.isBlank(String.valueOf(value))) {
      return null;
    }
    return toPromotionId(String.valueOf(value));
  }

  private static Portal_Users__c findEmployee(Id employeeId) {
    List<Portal_Users__c> employees = [
      SELECT
        Id,
        Name,
        Is_Active__c,
        Department__c,
        Designation__c,
        Reports_To__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    return employees.isEmpty() ? null : employees[0];
  }

  private static Portal_Users__c requireActiveEmployee(Id employeeId) {
    Portal_Users__c employee = findEmployee(employeeId);
    if (employee == null || employee.Is_Active__c != true) {
      throw handled('The selected employee must be an active employee.');
    }
    return employee;
  }

  /**
   * Copies the employee's name and current department, designation and
   * reporting manager onto the promotion.
   */
  private static void applyEmployeeSnapshot(
    PWChrono_Employee_Promotion__c promotion,
    Portal_Users__c employee
  ) {
    promotion.Employee_Name__c = employee.Name;
    promotion.Current_Reports_To__c = employee.Reports_To__c;
    promotion.Current_Department__c = null;
    promotion.Current_Designation__c = null;
    if (String.isNotBlank(employee.Department__c)) {
      for (PWChrono_Department__c department : [
        SELECT Id
        FROM PWChrono_Department__c
        WHERE Name = :employee.Department__c
        ORDER BY Is_Active__c DESC, CreatedDate ASC
        LIMIT 1
      ]) {
        promotion.Current_Department__c = department.Id;
      }
    }
    if (String.isNotBlank(employee.Designation__c)) {
      for (PWChrono_Designation__c designation : [
        SELECT Id
        FROM PWChrono_Designation__c
        WHERE Name = :employee.Designation__c
        ORDER BY Is_Active__c DESC, CreatedDate ASC
        LIMIT 1
      ]) {
        promotion.Current_Designation__c = designation.Id;
      }
    }
  }

  /** Copies only the whitelisted fields from client input (no mass assignment). */
  private static void copyEditableFields(
    Map<String, Object> raw,
    PWChrono_Employee_Promotion__c target
  ) {
    for (Schema.SObjectField field : EDITABLE_FIELDS) {
      Schema.DescribeFieldResult describe = field.getDescribe();
      if (raw.containsKey(describe.getName())) {
        target.put(field, toFieldValue(describe, raw.get(describe.getName())));
      }
    }
  }

  private static Object toFieldValue(
    Schema.DescribeFieldResult describe,
    Object value
  ) {
    String text = value == null ? null : String.valueOf(value).trim();
    if (String.isBlank(text)) {
      return null;
    }
    Object converted;
    try {
      switch on describe.getType() {
        when REFERENCE {
          Id referenceId = Id.valueOf(text);
          converted = describe.getReferenceTo()
              .contains(referenceId.getSObjectType())
            ? referenceId
            : null;
        }
        when DATE {
          converted = Date.valueOf(text);
        }
        when CURRENCY, DOUBLE, PERCENT {
          converted = Decimal.valueOf(text);
        }
        when else {
          converted = text;
        }
      }
    } catch (Exception e) {
      converted = null;
    }
    if (converted == null) {
      throw handled('Invalid value for ' + describe.getLabel() + '.');
    }
    return converted;
  }

  private static Boolean isNegative(Decimal value) {
    return value != null && value < 0;
  }

  private static List<PWChrono_Promotion_Detail__c> parseDetailLines(
    String detailsJson
  ) {
    if (String.isBlank(detailsJson)) {
      return null;
    }
    List<PWChrono_Promotion_Detail__c> lines = new List<PWChrono_Promotion_Detail__c>();
    for (Object item : (List<Object>) JSON.deserializeUntyped(detailsJson)) {
      Map<String, Object> line = (Map<String, Object>) item;
      PWChrono_Promotion_Detail__c detail = new PWChrono_Promotion_Detail__c(
        Property__c = readText(line, 'Property__c'),
        Current_Value__c = readText(line, 'Current_Value__c'),
        New_Value__c = readText(line, 'New_Value__c')
      );
      if (
        detail.Property__c == null &&
        detail.Current_Value__c == null &&
        detail.New_Value__c == null
      ) {
        continue;
      }
      lines.add(detail);
    }
    if (lines.size() > MAX_DETAIL_LINES) {
      throw handled(
        'A promotion can have at most ' + MAX_DETAIL_LINES + ' detail lines.'
      );
    }
    return lines;
  }

  private static String readText(Map<String, Object> source, String key) {
    Object value = source == null ? null : source.get(key);
    String text = value == null ? null : String.valueOf(value).trim();
    return String.isBlank(text) ? null : text;
  }

  /** Replaces the detail lines; a null list leaves the existing lines as-is. */
  private static void replaceDetailLines(
    Id promotionId,
    List<PWChrono_Promotion_Detail__c> lines
  ) {
    if (lines == null) {
      return;
    }
    List<PWChrono_Promotion_Detail__c> existing = [
      SELECT Id
      FROM PWChrono_Promotion_Detail__c
      WHERE Promotion__c = :promotionId
    ];
    if (!existing.isEmpty()) {
      delete existing; // NOPMD - guest runtime; access enforced by caller
    }
    for (PWChrono_Promotion_Detail__c line : lines) {
      line.Promotion__c = promotionId;
    }
    if (!lines.isEmpty()) {
      insert lines; // NOPMD - guest runtime; access enforced by caller
    }
  }

  private static void requireAllowedTransition(
    String currentStatus,
    String newStatus
  ) {
    if (String.isBlank(newStatus) || !ALL_STATUSES.contains(newStatus)) {
      throw handled('Choose a valid promotion status.');
    }
    if (TERMINAL_STATUSES.contains(currentStatus)) {
      throw handled(
        'This promotion is ' +
          currentStatus +
          ' and its status can no longer be changed.'
      );
    }
    if (currentStatus == newStatus) {
      throw handled('This promotion is already ' + currentStatus + '.');
    }
    Set<String> allowed = ALLOWED_TRANSITIONS.get(currentStatus);
    if (allowed == null || !allowed.contains(newStatus)) {
      String message =
        'A ' +
        currentStatus +
        ' promotion cannot be moved to ' +
        newStatus +
        '.';
      if (currentStatus == STATUS_DRAFT && newStatus == STATUS_APPROVED) {
        message += ' Submit it for approval first.';
      }
      throw handled(message);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static void rollback(Savepoint sp) {
    if (sp != null) {
      Database.rollback(sp);
    }
  }

  private static AuraHandledException toHandled(
    Exception ex,
    String methodName,
    String fallbackMessage
  ) {
    if (ex instanceof AuraHandledException) {
      return (AuraHandledException) ex;
    }
    if (ex instanceof PWChrono_EmployeeLifecycleService.LifecycleException) {
      return handled(ex.getMessage());
    }
    PWChrono_Logger.error(CLASS_NAME + '.' + methodName, ex);
    if (ex instanceof DmlException) {
      return handled(((DmlException) ex).getDmlMessage(0));
    }
    return handled(fallbackMessage);
  }

  private static AuraHandledException handled(String message) {
    AuraHandledException ahe = new AuraHandledException(message);
    ahe.setMessage(message);
    return ahe;
  }
}