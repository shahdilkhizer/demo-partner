/**
 * @description Controller for the Employee Transfer module. Manages
 *              PWChrono_Employee_Transfer__c records and applies an approved
 *              transfer to the employee record.
 *
 *              Declared without sharing because portal requests run as the
 *              Experience Cloud site guest user and these objects use a private
 *              external sharing model, so with-sharing queries would return
 *              nothing. Authorization is enforced in code instead:
 *              - every @AuraEnabled method verifies the portal session token and
 *                requires the Employee Lifecycle feature;
 *              - status changes and deletes also require an administrator
 *                (HR Admin, System Administrator or System Admin);
 *              - non-administrators only see and edit transfers for employees
 *                inside their access scope, and only while they are Draft;
 *              - nobody can create, edit, change the status of or delete a
 *                transfer about themselves.
 *
 *              The employee name and the current department, designation and
 *              reporting manager are a snapshot of the employee record. The
 *              server takes it on every save and again at approval; values sent
 *              by the client for these fields are ignored.
 *
 *              Approving a transfer updates the employee's department,
 *              designation and reporting manager.
 */
public without sharing class PWChrono_EmployeeTransferController {
  public static final String STATUS_DRAFT = 'Draft';
  public static final String STATUS_SUBMITTED = 'Submitted';
  public static final String STATUS_APPROVED = 'Approved';
  public static final String STATUS_CANCELLED = 'Cancelled';

  private static final String CLASS_NAME = 'PWChrono_EmployeeTransferController';
  private static final String NOT_FOUND_MESSAGE = 'Transfer record not found.';
  private static final String SELF_MESSAGE = 'You cannot manage a transfer for yourself. Ask another HR user to do this.';
  private static final Integer LOOKUP_LIMIT = 1000;

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
   * Fields a client may set when creating or editing a transfer. The employee
   * name and current department, designation and reporting manager are taken
   * from the employee record instead.
   */
  private static final List<Schema.SObjectField> EDITABLE_FIELDS = new List<Schema.SObjectField>{
    PWChrono_Employee_Transfer__c.Employee__c,
    PWChrono_Employee_Transfer__c.Company__c,
    PWChrono_Employee_Transfer__c.Transfer_Date__c,
    PWChrono_Employee_Transfer__c.Current_Branch__c,
    PWChrono_Employee_Transfer__c.New_Branch__c,
    PWChrono_Employee_Transfer__c.New_Department__c,
    PWChrono_Employee_Transfer__c.New_Designation__c,
    PWChrono_Employee_Transfer__c.New_Reports_To__c,
    PWChrono_Employee_Transfer__c.Transfer_Details__c
  };

  private static final String TRANSFER_FIELDS =
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
  // Transfer list
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns transfers, newest first. Administrators see all
   *              transfers; other users see transfers for employees in their
   *              access scope.
   * @param statusFilter A status value, or 'All' / blank for every status
   */
  @AuraEnabled
  public static List<PWChrono_Employee_Transfer__c> getTransfers(
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
      String query = TRANSFER_FIELDS;
      if (!filters.isEmpty()) {
        query += ' WHERE ' + String.join(filters, ' AND ');
      }
      query += ' ORDER BY Transfer_Date__c DESC NULLS LAST, CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (Exception ex) {
      throw toHandled(ex, 'getTransfers', 'Unable to load transfers.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Single transfer
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns a single transfer the caller is allowed to see.
   */
  @AuraEnabled
  public static PWChrono_Employee_Transfer__c getTransferById(
    String transferId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      Id recordId = toTransferId(transferId);
      List<PWChrono_Employee_Transfer__c> records = Database.query(
        TRANSFER_FIELDS + ' WHERE Id = :recordId LIMIT 1'
      );
      if (
        records.isEmpty() ||
        !isInScope(getEmployeeScope(actorId), records[0].Employee__c)
      ) {
        throw handled(NOT_FOUND_MESSAGE);
      }
      return records[0];
    } catch (Exception ex) {
      throw toHandled(ex, 'getTransferById', 'Unable to load the transfer.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Creates or edits a transfer. Only editable fields are copied
   *              from the client; the status cannot be set here (new transfers
   *              start as Draft). Approved and Cancelled transfers cannot be
   *              edited, and Submitted transfers can only be edited by an
   *              administrator. The employee name and current assignment are
   *              refreshed from the employee record.
   * @param transferJson JSON object with the transfer's editable fields (and
   *                     Id when editing)
   * @return Id of the saved transfer
   */
  @AuraEnabled
  public static String saveTransfer(
    String transferJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      Boolean admin = PWChrono_AccessController.isAdmin(actorId);
      Set<Id> scope = admin
        ? null
        : PWChrono_AccessController.getVisibleEmployeeIds(actorId);
      if (String.isBlank(transferJson)) {
        throw handled('Transfer details are required.');
      }
      Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(
        transferJson
      );

      PWChrono_Employee_Transfer__c transfer = new PWChrono_Employee_Transfer__c(
        Id = readRecordId(raw)
      );
      copyEditableFields(raw, transfer);

      PWChrono_Employee_Transfer__c existing;
      if (transfer.Id == null) {
        transfer.Status__c = STATUS_DRAFT;
      } else {
        existing = lockTransfer(transfer.Id);
        requireEditable(existing, actorId, admin, scope);
      }

      Id employeeId = (Id) valueAfterSave(
        raw,
        transfer,
        existing,
        PWChrono_Employee_Transfer__c.Employee__c
      );
      if (employeeId == null) {
        throw handled('Employee is required.');
      }
      Portal_Users__c employee = requireActiveEmployee(employeeId);
      if (!isInScope(scope, employeeId)) {
        throw handled(
          'You can only manage transfers for employees within your access scope.'
        );
      }
      if (employeeId == actorId) {
        throw handled(SELF_MESSAGE);
      }
      Id newReportsToId = (Id) valueAfterSave(
        raw,
        transfer,
        existing,
        PWChrono_Employee_Transfer__c.New_Reports_To__c
      );
      if (newReportsToId == employeeId) {
        throw handled('An employee cannot report to themselves.');
      }
      Object transferDate = valueAfterSave(
        raw,
        transfer,
        existing,
        PWChrono_Employee_Transfer__c.Transfer_Date__c
      );
      if (transferDate == null) {
        throw handled('Transfer Date is required.');
      }

      transfer.Employee__c = employeeId;
      applyEmployeeSnapshot(transfer, employee);

      upsert transfer; // NOPMD - guest runtime; access enforced above
      return transfer.Id;
    } catch (Exception ex) {
      throw toHandled(ex, 'saveTransfer', 'Unable to save the transfer.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status update (administrators only)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Moves a transfer to a new status. Allowed transitions: Draft
   *              to Submitted or Cancelled; Submitted to Draft, Approved or
   *              Cancelled. Approved and Cancelled are final. Approving records
   *              the employee's current assignment on the transfer, then
   *              applies the new department, designation and reporting manager
   *              to the employee; a transfer without a date, or dated in the
   *              future, cannot be approved. Administrators only, and never
   *              for their own transfer.
   */
  @AuraEnabled
  public static void updateTransferStatus(
    String transferId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    Savepoint sp;
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      if (!PWChrono_AccessController.isAdmin(actorId)) {
        throw handled('Only HR administrators can change a transfer status.');
      }
      PWChrono_Employee_Transfer__c transfer = lockTransfer(
        toTransferId(transferId)
      );
      if (transfer.Employee__c == actorId) {
        throw handled(SELF_MESSAGE);
      }
      requireAllowedTransition(statusOf(transfer), newStatus);

      sp = Database.setSavepoint();
      if (newStatus == STATUS_APPROVED) {
        approve(transfer);
      }
      transfer.Status__c = newStatus;
      update transfer; // NOPMD - guest runtime; access enforced above
    } catch (Exception ex) {
      if (sp != null) {
        Database.rollback(sp);
      }
      throw toHandled(
        ex,
        'updateTransferStatus',
        'Unable to update the transfer status.'
      );
    }
  }

  /** Applies an approved transfer to the employee. Caller holds a savepoint. */
  private static void approve(PWChrono_Employee_Transfer__c transfer) {
    if (transfer.Transfer_Date__c == null) {
      throw handled('Set the transfer date before approving this transfer.');
    }
    PWChrono_EmployeeLifecycleService.requireEffectiveDate(
      transfer.Transfer_Date__c,
      'This transfer'
    );
    Portal_Users__c employee = findEmployee(transfer.Employee__c);
    if (employee != null) {
      applyEmployeeSnapshot(transfer, employee);
    }
    PWChrono_EmployeeLifecycleService.applyAssignmentChange(
      transfer.Employee__c,
      transfer.New_Department__c,
      transfer.New_Designation__c,
      transfer.New_Reports_To__c
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
   * @description Deletes a Draft or Cancelled transfer. Administrators only,
   *              and never their own transfer.
   */
  @AuraEnabled
  public static void deleteTransfer(
    String transferId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      if (!PWChrono_AccessController.isAdmin(actorId)) {
        throw handled('Only HR administrators can delete transfers.');
      }
      PWChrono_Employee_Transfer__c transfer = lockTransfer(
        toTransferId(transferId)
      );
      if (transfer.Employee__c == actorId) {
        throw handled(SELF_MESSAGE);
      }
      String status = statusOf(transfer);
      if (!DELETABLE_STATUSES.contains(status)) {
        throw handled(
          'Only Draft or Cancelled transfers can be deleted. This transfer is ' +
            status +
            '.'
        );
      }
      delete transfer; // NOPMD - guest runtime; access enforced above
    } catch (Exception ex) {
      throw toHandled(ex, 'deleteTransfer', 'Unable to delete the transfer.');
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

  /** Rejects edits the caller may not make to an existing transfer. */
  private static void requireEditable(
    PWChrono_Employee_Transfer__c existing,
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
      throw handled(status + ' transfers cannot be edited.');
    }
    if (status == STATUS_SUBMITTED && !admin) {
      throw handled(
        'This transfer has been submitted for approval. Only an HR administrator can change it now.'
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Record helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static PWChrono_Employee_Transfer__c lockTransfer(Id recordId) {
    List<PWChrono_Employee_Transfer__c> records = [
      SELECT
        Id,
        Status__c,
        Employee__c,
        Transfer_Date__c,
        New_Department__c,
        New_Designation__c,
        New_Reports_To__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :recordId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw handled(NOT_FOUND_MESSAGE);
    }
    return records[0];
  }

  private static String statusOf(PWChrono_Employee_Transfer__c transfer) {
    return String.isBlank(transfer.Status__c)
      ? STATUS_DRAFT
      : transfer.Status__c;
  }

  /** The value a field will have after the save: from the client, else as stored. */
  private static Object valueAfterSave(
    Map<String, Object> raw,
    PWChrono_Employee_Transfer__c transfer,
    PWChrono_Employee_Transfer__c existing,
    Schema.SObjectField field
  ) {
    if (raw.containsKey(field.getDescribe().getName()) || existing == null) {
      return transfer.get(field);
    }
    return existing.get(field);
  }

  private static Id toTransferId(String value) {
    Id recordId;
    try {
      recordId = String.isBlank(value) ? null : Id.valueOf(value.trim());
    } catch (Exception e) {
      recordId = null;
    }
    if (
      recordId == null ||
      recordId.getSObjectType() != PWChrono_Employee_Transfer__c.SObjectType
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
    return toTransferId(String.valueOf(value));
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
   * reporting manager onto the transfer.
   */
  private static void applyEmployeeSnapshot(
    PWChrono_Employee_Transfer__c transfer,
    Portal_Users__c employee
  ) {
    transfer.Employee_Name__c = employee.Name;
    transfer.Current_Reports_To__c = employee.Reports_To__c;
    transfer.Current_Department__c = null;
    transfer.Current_Designation__c = null;
    if (String.isNotBlank(employee.Department__c)) {
      for (PWChrono_Department__c department : [
        SELECT Id
        FROM PWChrono_Department__c
        WHERE Name = :employee.Department__c
        ORDER BY Is_Active__c DESC, CreatedDate ASC
        LIMIT 1
      ]) {
        transfer.Current_Department__c = department.Id;
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
        transfer.Current_Designation__c = designation.Id;
      }
    }
  }

  /** Copies only the whitelisted fields from client input (no mass assignment). */
  private static void copyEditableFields(
    Map<String, Object> raw,
    PWChrono_Employee_Transfer__c target
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

  private static void requireAllowedTransition(
    String currentStatus,
    String newStatus
  ) {
    if (String.isBlank(newStatus) || !ALL_STATUSES.contains(newStatus)) {
      throw handled('Choose a valid transfer status.');
    }
    if (TERMINAL_STATUSES.contains(currentStatus)) {
      throw handled(
        'This transfer is ' +
          currentStatus +
          ' and its status can no longer be changed.'
      );
    }
    if (currentStatus == newStatus) {
      throw handled('This transfer is already ' + currentStatus + '.');
    }
    Set<String> allowed = ALLOWED_TRANSITIONS.get(currentStatus);
    if (allowed == null || !allowed.contains(newStatus)) {
      String message =
        'A ' +
        currentStatus +
        ' transfer cannot be moved to ' +
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