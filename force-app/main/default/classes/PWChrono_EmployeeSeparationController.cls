/**
 * @description Server API for the Employee Separation portal module: the
 *              separation register, its exit checklist and employee exit
 *              records.
 *
 *              Runs without sharing because portal requests execute as the
 *              Experience Cloud site guest user and separation records use a
 *              private external sharing model, so with-sharing queries would
 *              return nothing for the guest. Authorization is enforced in code
 *              instead: every @AuraEnabled method verifies the portal session
 *              token and requires the Employee Lifecycle feature. Status
 *              changes, deletes, removing existing checklist items or changing
 *              whether they are required, and saving employee exit records
 *              additionally require an administrator. Completing a separation deactivates the employee
 *              and ends their portal access.
 */
public without sharing class PWChrono_EmployeeSeparationController {
  public static final String STATUS_PENDING = 'Pending';
  public static final String STATUS_IN_PROCESS = 'In Process';
  public static final String STATUS_COMPLETED = 'Completed';
  public static final String STATUS_CANCELLED = 'Cancelled';

  public static final String CHECKLIST_PENDING = 'Pending';
  public static final String CHECKLIST_IN_PROGRESS = 'In Progress';
  public static final String CHECKLIST_COMPLETED = 'Completed';

  private static final Set<String> SEPARATION_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_IN_PROCESS,
    STATUS_COMPLETED,
    STATUS_CANCELLED
  };
  private static final Set<String> OPEN_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_IN_PROCESS
  };
  private static final Set<String> DELETABLE_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_CANCELLED
  };
  private static final Set<String> CHECKLIST_STATUSES = new Set<String>{
    CHECKLIST_PENDING,
    CHECKLIST_IN_PROGRESS,
    CHECKLIST_COMPLETED
  };
  private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = new Map<String, Set<String>>{
    STATUS_PENDING => new Set<String>{
      STATUS_IN_PROCESS,
      STATUS_COMPLETED,
      STATUS_CANCELLED
    },
    STATUS_IN_PROCESS => new Set<String>{ STATUS_COMPLETED, STATUS_CANCELLED }
  };

  /** Fields a client may set on a separation. Status is never client-set. */
  private static final List<String> SEPARATION_EDITABLE_FIELDS = new List<String>{
    'Employee__c',
    'Employee_Name__c',
    'Company__c',
    'Department__c',
    'Designation__c',
    'Separation_Template__c',
    'Resignation_Letter_Date__c',
    'Relieving_Date__c',
    'Reason_for_Leaving__c'
  };
  private static final Set<String> ID_FIELDS = new Set<String>{
    'Employee__c',
    'Department__c',
    'Designation__c',
    'Separation_Template__c',
    'Separation__c'
  };
  private static final Set<String> DATE_FIELDS = new Set<String>{
    'Resignation_Letter_Date__c',
    'Relieving_Date__c',
    'Date_of_Joining__c',
    'Resignation_Date__c'
  };

  /**
   * Fields an administrator may set on an employee exit record. The record
   * carries exit interview, settlement and final decision statuses, so
   * saveExitRecord is restricted to administrators.
   */
  private static final List<String> EXIT_EDITABLE_FIELDS = new List<String>{
    'Employee__c',
    'Employee_Name__c',
    'Department__c',
    'Designation__c',
    'Separation__c',
    'Date_of_Joining__c',
    'Resignation_Date__c',
    'Relieving_Date__c',
    'Exit_Type__c',
    'Reason_for_Exit__c',
    'Exit_Interview_Status__c',
    'Full_and_Final_Status__c',
    'Final_Decision__c'
  };

  private static final String SEPARATION_SELECT =
    'SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Is_Active__c,' +
    ' Employee_Name__c, Company__c, Department__c, Department__r.Name,' +
    ' Designation__c, Designation__r.Name, Resignation_Letter_Date__c,' +
    ' Relieving_Date__c, Reason_for_Leaving__c, Status__c,' +
    ' Separation_Template__c, Separation_Template__r.Name,' +
    ' (SELECT Id, Status__c, Is_Required__c FROM Checklist_Items__r)' +
    ' FROM PWChrono_Employee_Separation__c';

  /**
   * Test seam: when true, completing a separation fails after the employee
   * has been deactivated, so tests can prove the deactivation is rolled back.
   */
  @TestVisible
  private static Boolean simulateCompletionFailure = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Separation register
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns separations, newest resignation first, optionally
   *              filtered by status. Each row carries its checklist items'
   *              status so the portal can show completion readiness.
   */
  @AuraEnabled
  public static List<PWChrono_Employee_Separation__c> getSeparations(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      String query = SEPARATION_SELECT;
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        query += ' WHERE Status__c = :statusFilter';
      }
      query += ' ORDER BY Resignation_Letter_Date__c DESC NULLS LAST, CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (Exception e) {
      throw toAuraException('getSeparations', 'Unable to load separations.', e);
    }
  }

  /**
   * @description Returns a single separation by Id.
   */
  @AuraEnabled
  public static PWChrono_Employee_Separation__c getSeparationById(
    String separationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Id recordId = toId(separationId, 'separation');
      List<PWChrono_Employee_Separation__c> records = Database.query(
        SEPARATION_SELECT + ' WHERE Id = :recordId LIMIT 1'
      );
      if (records.isEmpty()) {
        throw handled('Separation record not found.');
      }
      return records[0];
    } catch (Exception e) {
      throw toAuraException(
        'getSeparationById',
        'Unable to load the separation.',
        e
      );
    }
  }

  /**
   * @description Returns the exit checklist items of a separation.
   */
  @AuraEnabled
  public static List<PWChrono_Separation_Checklist__c> getChecklistItems(
    String separationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Id recordId = toId(separationId, 'separation');
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
        WHERE Separation__c = :recordId
        ORDER BY CreatedDate ASC, Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getChecklistItems',
        'Unable to load the exit checklist.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update) with checklist
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Creates or updates a separation.
   *              - Status is never taken from the client: new separations
   *                start as Pending; status changes use updateSeparationStatus.
   *              - Completed and cancelled separations cannot be edited.
   *              - The employee must be active and may have only one open
   *                (Pending or In Process) separation at a time.
   *              - checklistJson null leaves the checklist unchanged; a JSON
   *                array replaces it (rows with an Id are updated, rows without
   *                are added, missing rows are removed). A new separation with
   *                a template and no checklist rows gets its checklist
   *                generated from the template's activities.
   *              - Checklist item status is never taken from the client: new
   *                items start as Pending and progress is recorded with
   *                updateChecklistItemStatus. Only administrators can change
   *                whether an existing item is required or remove one.
   *              - The separation row is locked before its status is checked,
   *                so a save cannot race a status change.
   * @return Id of the saved separation
   */
  @AuraEnabled
  public static String saveSeparation(
    String separationJson,
    String checklistJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      Map<String, Object> payload = parseObject(separationJson);
      List<Object> checklistRows = String.isBlank(checklistJson)
        ? null
        : parseList(checklistJson);

      Id recordId = readId(payload, 'Id', 'separation');
      PWChrono_Employee_Separation__c existing = recordId == null
        ? null
        : loadSeparation(recordId);
      if (existing != null && !OPEN_STATUSES.contains(existing.Status__c)) {
        throw handled(
          'This separation is ' +
            existing.Status__c.toLowerCase() +
            ' and can no longer be edited.'
        );
      }

      PWChrono_Employee_Separation__c merged = existing == null
        ? new PWChrono_Employee_Separation__c()
        : existing.clone(true, true, false, false);
      applyFields(merged, payload, SEPARATION_EDITABLE_FIELDS);

      Boolean employeeChanged =
        existing == null ||
        merged.Employee__c != existing.Employee__c;
      if (merged.Employee__c == null) {
        throw handled('Select the employee who is leaving.');
      }
      if (employeeChanged) {
        Portal_Users__c employee = requireActiveEmployee(merged.Employee__c);
        requireNoOtherOpenSeparation(employee, recordId);
        if (String.isBlank(merged.Employee_Name__c) || existing != null) {
          merged.Employee_Name__c = employee.Name;
        }
      }
      if (
        merged.Resignation_Letter_Date__c != null &&
        merged.Relieving_Date__c != null &&
        merged.Relieving_Date__c < merged.Resignation_Letter_Date__c
      ) {
        throw handled(
          'The relieving date cannot be before the resignation letter date.'
        );
      }

      PWChrono_Employee_Separation__c record = new PWChrono_Employee_Separation__c(
        Id = recordId
      );
      for (String fieldName : SEPARATION_EDITABLE_FIELDS) {
        record.put(fieldName, merged.get(fieldName));
      }
      if (recordId == null) {
        record.Status__c = STATUS_PENDING;
      }

      Savepoint sp = Database.setSavepoint();
      try {
        upsert record;
        Boolean hasRows = checklistRows != null && !checklistRows.isEmpty();
        if (recordId == null && !hasRows) {
          PWChrono_EmployeeLifecycleService.createChecklistFromTemplate(
            record.Id,
            record.Separation_Template__c
          );
        } else if (checklistRows != null) {
          syncChecklist(record.Id, checklistRows, recordId == null, actorId);
        }
      } catch (Exception e) {
        Database.rollback(sp);
        throw e;
      }
      return record.Id;
    } catch (Exception e) {
      throw toAuraException(
        'saveSeparation',
        'Unable to save the separation.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow (administrators)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Moves a separation through its workflow. Administrators only.
   *              Allowed: Pending to In Process, Completed or Cancelled; In
   *              Process to Completed or Cancelled. Completing requires the
   *              relieving date to have arrived and every required checklist
   *              item to be completed, then deactivates the employee and ends
   *              their portal session in the same transaction.
   */
  @AuraEnabled
  public static void updateSeparationStatus(
    String separationId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(
        actorId,
        'Only HR administrators can change the status of a separation.'
      );
      if (!SEPARATION_STATUSES.contains(newStatus)) {
        throw handled('Choose a valid separation status.');
      }
      PWChrono_Employee_Separation__c separation = loadSeparation(
        toId(separationId, 'separation')
      );
      requireTransition(separation.Status__c, newStatus);

      Savepoint sp = Database.setSavepoint();
      try {
        if (newStatus == STATUS_COMPLETED) {
          PWChrono_EmployeeLifecycleService.requireEffectiveDate(
            separation.Relieving_Date__c,
            'This separation'
          );
          requireRequiredChecklistCompleted(separation.Id);
          PWChrono_EmployeeLifecycleService.deactivateEmployee(
            separation.Employee__c
          );
          if (simulateCompletionFailure) {
            throw handled('Simulated failure after deactivation.');
          }
        }
        update new PWChrono_Employee_Separation__c(
          Id = separation.Id,
          Status__c = newStatus
        );
      } catch (Exception e) {
        Database.rollback(sp);
        throw e;
      }
    } catch (Exception e) {
      throw toAuraException(
        'updateSeparationStatus',
        'Unable to update the separation status.',
        e
      );
    }
  }

  /**
   * @description Updates the status of one checklist item while its
   *              separation is still open. This is the only way checklist
   *              progress is recorded. The separation row is locked first so
   *              the change cannot race the separation's completion.
   */
  @AuraEnabled
  public static void updateChecklistItemStatus(
    String checklistItemId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      if (!CHECKLIST_STATUSES.contains(newStatus)) {
        throw handled('Choose a valid checklist status.');
      }
      Id itemId = toId(checklistItemId, 'checklist item');
      List<PWChrono_Separation_Checklist__c> items = [
        SELECT Id, Separation__c
        FROM PWChrono_Separation_Checklist__c
        WHERE Id = :itemId
        LIMIT 1
      ];
      if (items.isEmpty()) {
        throw handled('Checklist item not found.');
      }
      PWChrono_Employee_Separation__c separation = loadSeparation(
        items[0].Separation__c
      );
      if (!OPEN_STATUSES.contains(separation.Status__c)) {
        throw handled(
          'The checklist of a completed or cancelled separation cannot be changed.'
        );
      }
      update new PWChrono_Separation_Checklist__c(
        Id = itemId,
        Status__c = newStatus
      );
    } catch (Exception e) {
      throw toAuraException(
        'updateChecklistItemStatus',
        'Unable to update the checklist item.',
        e
      );
    }
  }

  /**
   * @description Deletes a pending or cancelled separation and its checklist.
   *              Administrators only.
   */
  @AuraEnabled
  public static void deleteSeparation(
    String separationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(actorId, 'Only HR administrators can delete separations.');
      PWChrono_Employee_Separation__c separation = loadSeparation(
        toId(separationId, 'separation')
      );
      if (!DELETABLE_STATUSES.contains(separation.Status__c)) {
        throw handled('Only pending or cancelled separations can be deleted.');
      }
      delete new PWChrono_Employee_Separation__c(Id = separation.Id);
    } catch (Exception e) {
      throw toAuraException(
        'deleteSeparation',
        'Unable to delete the separation.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Employee exit records
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns employee exit records, newest resignation first.
   */
  @AuraEnabled
  public static List<PWChrono_Employee_Exit__c> getExitRecords(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      return [
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
          Date_of_Joining__c,
          Resignation_Date__c,
          Relieving_Date__c,
          Exit_Type__c,
          Reason_for_Exit__c,
          Exit_Interview_Status__c,
          Full_and_Final_Status__c,
          Final_Decision__c,
          Separation__c
        FROM PWChrono_Employee_Exit__c
        ORDER BY Resignation_Date__c DESC NULLS LAST
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getExitRecords',
        'Unable to load exit records.',
        e
      );
    }
  }

  /**
   * @description Creates or updates an employee exit record. Administrators
   *              only, because the record carries the exit interview,
   *              settlement and final decision statuses. Only whitelisted
   *              fields are copied from the client. When a separation is
   *              linked, the employee must match it (a blank employee,
   *              department, designation and dates are taken from it) and a
   *              cancelled separation cannot be newly linked.
   * @return Id of the saved exit record
   */
  @AuraEnabled
  public static String saveExitRecord(
    String exitJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(
        actorId,
        'Only HR administrators can save employee exit records.'
      );
      Map<String, Object> payload = parseObject(exitJson);
      Id recordId = readId(payload, 'Id', 'exit record');
      PWChrono_Employee_Exit__c record = recordId == null
        ? new PWChrono_Employee_Exit__c()
        : loadExitRecord(recordId);
      Id previousSeparationId = record.Separation__c;
      applyFields(record, payload, EXIT_EDITABLE_FIELDS);
      if (record.Separation__c != null) {
        applyExitSeparationRules(
          record,
          recordId == null || record.Separation__c != previousSeparationId
        );
      }
      if (record.Employee__c == null) {
        throw handled('Select the employee for this exit record.');
      }
      upsert record;
      return record.Id;
    } catch (Exception e) {
      throw toAuraException(
        'saveExitRecord',
        'Unable to save the exit record.',
        e
      );
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
      requireLifecycleAccess(portalUserId, sessionToken);
      return [
        SELECT Id, Name
        FROM PWChrono_Designation__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getActiveDesignations',
        'Unable to load designations.',
        e
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
      requireLifecycleAccess(portalUserId, sessionToken);
      return [
        SELECT Id, Name
        FROM PWChrono_Department__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getActiveDepartments',
        'Unable to load departments.',
        e
      );
    }
  }

  /** @description Returns active employees for dropdowns. */
  @AuraEnabled
  public static List<Portal_Users__c> getActiveEmployees(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      return [
        SELECT Id, Name
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT 1000
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getActiveEmployees',
        'Unable to load employees.',
        e
      );
    }
  }

  /** @description Returns active separation templates for dropdowns. */
  @AuraEnabled
  public static List<PWChrono_Separation_Template__c> getActiveSeparationTemplates(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      return [
        SELECT Id, Name
        FROM PWChrono_Separation_Template__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getActiveSeparationTemplates',
        'Unable to load separation templates.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Authorization helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Id requireLifecycleAccess(
    String portalUserId,
    String sessionToken
  ) {
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

  private static void requireAdmin(Id actorId, String message) {
    if (!PWChrono_AccessController.isAdmin(actorId)) {
      throw handled(message);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Business rule helpers
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Loads a separation for a write and locks its row, so the status checked
   * here cannot change before this transaction's DML commits.
   */
  private static PWChrono_Employee_Separation__c loadSeparation(
    Id separationId
  ) {
    List<PWChrono_Employee_Separation__c> records = [
      SELECT
        Id,
        Name,
        Status__c,
        Employee__c,
        Employee_Name__c,
        Company__c,
        Department__c,
        Designation__c,
        Separation_Template__c,
        Resignation_Letter_Date__c,
        Relieving_Date__c,
        Reason_for_Leaving__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :separationId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw handled('Separation record not found.');
    }
    if (String.isBlank(records[0].Status__c)) {
      // The picklist defaults to Pending; treat legacy blank values the same.
      records[0].Status__c = STATUS_PENDING;
    }
    return records[0];
  }

  private static Portal_Users__c requireActiveEmployee(Id employeeId) {
    List<Portal_Users__c> employees = [
      SELECT Id, Name, Is_Active__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    if (employees.isEmpty()) {
      throw handled('The selected employee was not found.');
    }
    if (employees[0].Is_Active__c != true) {
      throw handled(
        employees[0].Name +
        ' is no longer active. Separations can only be raised for active employees.'
      );
    }
    return employees[0];
  }

  private static void requireNoOtherOpenSeparation(
    Portal_Users__c employee,
    Id currentSeparationId
  ) {
    List<PWChrono_Employee_Separation__c> openSeparations = [
      SELECT Id, Name, Status__c
      FROM PWChrono_Employee_Separation__c
      WHERE
        Employee__c = :employee.Id
        AND Status__c IN :OPEN_STATUSES
        AND Id != :currentSeparationId
      LIMIT 1
    ];
    if (!openSeparations.isEmpty()) {
      throw handled(
        employee.Name +
          ' already has an open separation (' +
          openSeparations[0].Name +
          ', ' +
          openSeparations[0].Status__c +
          '). Complete or cancel it before raising another.'
      );
    }
  }

  /** Loads an employee exit record for update and locks its row. */
  private static PWChrono_Employee_Exit__c loadExitRecord(Id exitId) {
    List<PWChrono_Employee_Exit__c> records = [
      SELECT
        Id,
        Employee__c,
        Employee_Name__c,
        Department__c,
        Designation__c,
        Separation__c,
        Date_of_Joining__c,
        Resignation_Date__c,
        Relieving_Date__c,
        Exit_Type__c,
        Reason_for_Exit__c,
        Exit_Interview_Status__c,
        Full_and_Final_Status__c,
        Final_Decision__c
      FROM PWChrono_Employee_Exit__c
      WHERE Id = :exitId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw handled('Exit record not found.');
    }
    return records[0];
  }

  /**
   * Keeps an exit record consistent with its separation: the employee must
   * match, blank values are taken from the separation and a cancelled
   * separation cannot be newly linked.
   */
  private static void applyExitSeparationRules(
    PWChrono_Employee_Exit__c exitRecord,
    Boolean separationChanged
  ) {
    List<PWChrono_Employee_Separation__c> separations = [
      SELECT
        Id,
        Name,
        Status__c,
        Employee__c,
        Employee_Name__c,
        Department__c,
        Designation__c,
        Resignation_Letter_Date__c,
        Relieving_Date__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :exitRecord.Separation__c
      LIMIT 1
    ];
    if (separations.isEmpty()) {
      throw handled('The linked separation was not found.');
    }
    PWChrono_Employee_Separation__c separation = separations[0];
    if (separationChanged && separation.Status__c == STATUS_CANCELLED) {
      throw handled(
        'Separation ' +
          separation.Name +
          ' is cancelled and cannot be linked to an exit record.'
      );
    }
    if (exitRecord.Employee__c == null) {
      exitRecord.Employee__c = separation.Employee__c;
    } else if (
      separation.Employee__c != null &&
      exitRecord.Employee__c != separation.Employee__c
    ) {
      throw handled(
        'The selected employee does not match separation ' +
          separation.Name +
          '.'
      );
    }
    if (
      String.isBlank(exitRecord.Employee_Name__c) &&
      exitRecord.Employee__c == separation.Employee__c
    ) {
      exitRecord.Employee_Name__c = separation.Employee_Name__c;
    }
    if (exitRecord.Department__c == null) {
      exitRecord.Department__c = separation.Department__c;
    }
    if (exitRecord.Designation__c == null) {
      exitRecord.Designation__c = separation.Designation__c;
    }
    if (exitRecord.Resignation_Date__c == null) {
      exitRecord.Resignation_Date__c = separation.Resignation_Letter_Date__c;
    }
    if (exitRecord.Relieving_Date__c == null) {
      exitRecord.Relieving_Date__c = separation.Relieving_Date__c;
    }
  }

  private static void requireTransition(
    String currentStatus,
    String newStatus
  ) {
    Set<String> allowed = ALLOWED_TRANSITIONS.get(currentStatus);
    if (allowed == null || !allowed.contains(newStatus)) {
      throw handled(
        'A ' +
          currentStatus.toLowerCase() +
          ' separation cannot be moved to ' +
          newStatus +
          '.'
      );
    }
  }

  private static void requireRequiredChecklistCompleted(Id separationId) {
    List<String> pending = new List<String>();
    for (PWChrono_Separation_Checklist__c item : [
      SELECT Name
      FROM PWChrono_Separation_Checklist__c
      WHERE
        Separation__c = :separationId
        AND Is_Required__c = TRUE
        AND (Status__c != :CHECKLIST_COMPLETED
        OR Status__c = NULL)
      ORDER BY Name ASC
    ]) {
      pending.add(item.Name);
    }
    if (!pending.isEmpty()) {
      throw handled(
        'Complete the required checklist items before completing this separation: ' +
          String.join(pending, ', ') +
          '.'
      );
    }
  }

  /**
   * Applies the client's checklist rows to a separation.
   * - Item status is server-owned: new items start as Pending and existing
   *   items keep their stored status (progress is recorded with
   *   updateChecklistItemStatus), so a stale form cannot undo it.
   * - Anyone with the feature may add items and edit an item's name,
   *   assignee and notes. Only administrators may change whether an existing
   *   item is required or remove an existing item, so the required-checklist
   *   rule on completion cannot be bypassed through save.
   */
  private static void syncChecklist(
    Id separationId,
    List<Object> rows,
    Boolean isNewSeparation,
    Id actorId
  ) {
    Map<Id, PWChrono_Separation_Checklist__c> existingItems = isNewSeparation
      ? new Map<Id, PWChrono_Separation_Checklist__c>()
      : new Map<Id, PWChrono_Separation_Checklist__c>(
          [
            SELECT Id, Name
            FROM PWChrono_Separation_Checklist__c
            WHERE Separation__c = :separationId
          ]
        );
    Boolean actorIsAdmin =
      !existingItems.isEmpty() && PWChrono_AccessController.isAdmin(actorId);

    List<PWChrono_Separation_Checklist__c> itemsToSave = new List<PWChrono_Separation_Checklist__c>();
    Set<Id> keptIds = new Set<Id>();
    for (Object rawRow : rows) {
      if (!(rawRow instanceof Map<String, Object>)) {
        throw handled('The checklist data is not valid.');
      }
      Map<String, Object> row = (Map<String, Object>) rawRow;
      Id itemId = readId(row, 'Id', 'checklist item');
      if (itemId != null && !existingItems.containsKey(itemId)) {
        throw handled('A checklist item does not belong to this separation.');
      }
      String name = readString(row, 'Name');
      if (String.isBlank(name)) {
        throw handled('Each checklist item needs an activity name.');
      }

      PWChrono_Separation_Checklist__c item;
      if (itemId == null) {
        item = new PWChrono_Separation_Checklist__c(
          Separation__c = separationId,
          Status__c = CHECKLIST_PENDING,
          Is_Required__c = readBoolean(row, 'Is_Required__c')
        );
      } else {
        item = new PWChrono_Separation_Checklist__c(Id = itemId);
        if (actorIsAdmin && row.containsKey('Is_Required__c')) {
          item.Is_Required__c = readBoolean(row, 'Is_Required__c');
        }
        keptIds.add(itemId);
      }
      item.Name = name.trim().left(80);
      if (row.containsKey('Assigned_To__c')) {
        item.Assigned_To__c = readId(
          row,
          'Assigned_To__c',
          'checklist assignee'
        );
      }
      if (row.containsKey('Notes__c')) {
        item.Notes__c = readString(row, 'Notes__c');
      }
      itemsToSave.add(item);
    }

    List<PWChrono_Separation_Checklist__c> itemsToDelete = new List<PWChrono_Separation_Checklist__c>();
    List<String> removedNames = new List<String>();
    for (
      PWChrono_Separation_Checklist__c existingItem : existingItems.values()
    ) {
      if (!keptIds.contains(existingItem.Id)) {
        itemsToDelete.add(
          new PWChrono_Separation_Checklist__c(Id = existingItem.Id)
        );
        removedNames.add(existingItem.Name);
      }
    }
    if (!itemsToDelete.isEmpty()) {
      if (!actorIsAdmin) {
        removedNames.sort();
        throw handled(
          'Only HR administrators can remove checklist items: ' +
            String.join(removedNames, ', ') +
            '.'
        );
      }
      delete itemsToDelete;
    }
    if (!itemsToSave.isEmpty()) {
      upsert itemsToSave;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Payload parsing helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Map<String, Object> parseObject(String jsonText) {
    if (String.isBlank(jsonText)) {
      throw handled('The request data is missing.');
    }
    Object parsed = JSON.deserializeUntyped(jsonText);
    if (!(parsed instanceof Map<String, Object>)) {
      throw handled('The request data is not valid.');
    }
    return (Map<String, Object>) parsed;
  }

  private static List<Object> parseList(String jsonText) {
    Object parsed = JSON.deserializeUntyped(jsonText);
    if (!(parsed instanceof List<Object>)) {
      throw handled('The checklist data is not valid.');
    }
    return (List<Object>) parsed;
  }

  /** Copies only the listed fields that are present in the payload. */
  private static void applyFields(
    SObject target,
    Map<String, Object> payload,
    List<String> fieldNames
  ) {
    for (String fieldName : fieldNames) {
      if (!payload.containsKey(fieldName)) {
        continue;
      }
      if (ID_FIELDS.contains(fieldName)) {
        target.put(
          fieldName,
          readId(
            payload,
            fieldName,
            fieldName.removeEnd('__c').replace('_', ' ').toLowerCase()
          )
        );
      } else if (DATE_FIELDS.contains(fieldName)) {
        target.put(fieldName, readDate(payload, fieldName));
      } else {
        target.put(fieldName, readString(payload, fieldName));
      }
    }
  }

  private static String readString(Map<String, Object> source, String key) {
    Object value = source.get(key);
    if (value == null) {
      return null;
    }
    String text = String.valueOf(value);
    return String.isBlank(text) ? null : text;
  }

  private static Id readId(
    Map<String, Object> source,
    String key,
    String label
  ) {
    String text = readString(source, key);
    if (text == null) {
      return null;
    }
    try {
      return Id.valueOf(text.trim());
    } catch (Exception e) {
      throw handled('The ' + label + ' reference is not valid.');
    }
  }

  private static Date readDate(Map<String, Object> source, String key) {
    String text = readString(source, key);
    if (text == null) {
      return null;
    }
    try {
      return Date.valueOf(text.trim().substringBefore('T'));
    } catch (Exception e) {
      throw handled('Enter dates in the format YYYY-MM-DD.');
    }
  }

  private static Boolean readBoolean(Map<String, Object> source, String key) {
    Object value = source.get(key);
    if (value instanceof Boolean) {
      return (Boolean) value;
    }
    return value != null && String.valueOf(value).equalsIgnoreCase('true');
  }

  private static Id toId(String value, String label) {
    if (String.isBlank(value)) {
      throw handled('A ' + label + ' is required.');
    }
    try {
      return Id.valueOf(value.trim());
    } catch (Exception e) {
      throw handled('The ' + label + ' reference is not valid.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error handling
  // ─────────────────────────────────────────────────────────────────────────

  private static AuraHandledException handled(String message) {
    AuraHandledException ahe = new AuraHandledException(message);
    ahe.setMessage(message);
    return ahe;
  }

  private static AuraHandledException toAuraException(
    String operation,
    String fallbackMessage,
    Exception e
  ) {
    if (e instanceof AuraHandledException) {
      return (AuraHandledException) e;
    }
    if (e instanceof PWChrono_EmployeeLifecycleService.LifecycleException) {
      return handled(e.getMessage());
    }
    PWChrono_Logger.error(
      'PWChrono_EmployeeSeparationController.' + operation,
      e
    );
    if (e instanceof DmlException) {
      return handled(((DmlException) e).getDmlMessage(0));
    }
    if (e instanceof JSONException) {
      return handled('The request data is not valid.');
    }
    return handled(fallbackMessage);
  }
}