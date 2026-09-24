/**
 * @description Server API for the Full and Final Settlement portal module:
 *              settlements and their payable and receivable lines.
 *
 *              Runs without sharing because portal requests execute as the
 *              Experience Cloud site guest user and settlement records use a
 *              private external sharing model, so with-sharing queries would
 *              return nothing for the guest. Authorization is enforced in code
 *              instead: every @AuraEnabled method verifies the portal session
 *              token and requires the Employee Lifecycle feature. Status
 *              changes and deletes additionally require an administrator.
 *              Settlement totals are always calculated here from the lines;
 *              waived lines are excluded from the totals.
 */
public without sharing class PWChrono_FullFinalSettlementController {
  public static final String STATUS_DRAFT = 'Draft';
  public static final String STATUS_SUBMITTED = 'Submitted';
  public static final String STATUS_PAID = 'Paid';
  public static final String STATUS_CANCELLED = 'Cancelled';

  public static final String LINE_PENDING = 'Pending';
  public static final String LINE_WAIVED = 'Waived';

  private static final Set<String> SETTLEMENT_STATUSES = new Set<String>{
    STATUS_DRAFT,
    STATUS_SUBMITTED,
    STATUS_PAID,
    STATUS_CANCELLED
  };
  private static final Set<String> EDITABLE_STATUSES = new Set<String>{
    STATUS_DRAFT,
    STATUS_SUBMITTED
  };
  private static final Set<String> DELETABLE_STATUSES = new Set<String>{
    STATUS_DRAFT,
    STATUS_CANCELLED
  };
  private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = new Map<String, Set<String>>{
    STATUS_DRAFT => new Set<String>{ STATUS_SUBMITTED, STATUS_CANCELLED },
    STATUS_SUBMITTED => new Set<String>{ STATUS_PAID, STATUS_CANCELLED }
  };
  private static final Set<String> PAYABLE_STATUSES = new Set<String>{
    LINE_PENDING,
    'Paid',
    LINE_WAIVED
  };
  private static final Set<String> RECEIVABLE_STATUSES = new Set<String>{
    LINE_PENDING,
    'Recovered',
    LINE_WAIVED
  };

  /** Fields a client may set on a settlement. Status and totals are server-owned. */
  private static final List<String> EDITABLE_FIELDS = new List<String>{
    'Employee__c',
    'Employee_Name__c',
    'Company__c',
    'Department__c',
    'Designation__c',
    'Separation__c',
    'Date_of_Joining__c',
    'Relieving_Date__c'
  };
  private static final Set<String> ID_FIELDS = new Set<String>{
    'Employee__c',
    'Department__c',
    'Designation__c',
    'Separation__c'
  };
  private static final Set<String> DATE_FIELDS = new Set<String>{
    'Date_of_Joining__c',
    'Relieving_Date__c'
  };

  private static final String SETTLEMENT_SELECT =
    'SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Name__c,' +
    ' Company__c, Department__c, Department__r.Name, Designation__c,' +
    ' Designation__r.Name, Separation__c, Separation__r.Name,' +
    ' Separation__r.Status__c, Date_of_Joining__c, Relieving_Date__c,' +
    ' Status__c, Total_Payable__c, Total_Receivable__c, Net_Payable__c' +
    ' FROM PWChrono_Full_Final_Settlement__c';

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns settlements, newest first, optionally filtered by
   *              status.
   */
  @AuraEnabled
  public static List<PWChrono_Full_Final_Settlement__c> getSettlements(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      String query = SETTLEMENT_SELECT;
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        query += ' WHERE Status__c = :statusFilter';
      }
      query += ' ORDER BY CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (Exception e) {
      throw toAuraException('getSettlements', 'Unable to load settlements.', e);
    }
  }

  /**
   * @description Returns a single settlement by Id.
   */
  @AuraEnabled
  public static PWChrono_Full_Final_Settlement__c getSettlementById(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Id recordId = toId(settlementId);
      List<PWChrono_Full_Final_Settlement__c> records = Database.query(
        SETTLEMENT_SELECT + ' WHERE Id = :recordId LIMIT 1'
      );
      if (records.isEmpty()) {
        throw handled('Settlement not found.');
      }
      return records[0];
    } catch (Exception e) {
      throw toAuraException(
        'getSettlementById',
        'Unable to load the settlement.',
        e
      );
    }
  }

  /** @description Returns the payable lines of a settlement. */
  @AuraEnabled
  public static List<PWChrono_Settlement_Payable__c> getPayables(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Id recordId = toId(settlementId);
      return [
        SELECT
          Id,
          Name,
          Settlement__c,
          Component__c,
          Reference_Document__c,
          Account__c,
          Amount__c,
          Status__c
        FROM PWChrono_Settlement_Payable__c
        WHERE Settlement__c = :recordId
        ORDER BY CreatedDate ASC
      ];
    } catch (Exception e) {
      throw toAuraException('getPayables', 'Unable to load payable items.', e);
    }
  }

  /** @description Returns the receivable lines of a settlement. */
  @AuraEnabled
  public static List<PWChrono_Settlement_Receivable__c> getReceivables(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Id recordId = toId(settlementId);
      return [
        SELECT
          Id,
          Name,
          Settlement__c,
          Component__c,
          Reference_Document__c,
          Account__c,
          Amount__c,
          Status__c
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :recordId
        ORDER BY CreatedDate ASC
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getReceivables',
        'Unable to load receivable items.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (upsert parent + replace lines)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Creates or updates a settlement and replaces its lines.
   *              - Status is never taken from the client: new settlements
   *                start as Draft; status changes use updateSettlementStatus.
   *              - Paid and cancelled settlements cannot be edited.
   *              - A new settlement linked to a separation takes blank
   *                employee, relieving date, department and designation values
   *                from the separation; a separation can have only one
   *                settlement that is not cancelled.
   *              - payablesJson / receivablesJson null keeps the existing
   *                lines; a JSON array replaces them. Totals are recalculated
   *                from the lines on every save.
   * @return Id of the saved settlement
   */
  @AuraEnabled
  public static String saveSettlement(
    String settlementJson,
    String payablesJson,
    String receivablesJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Map<String, Object> payload = parseObject(settlementJson);
      List<PWChrono_Settlement_Payable__c> payables = String.isBlank(
          payablesJson
        )
        ? null
        : buildPayables(parseList(payablesJson));
      List<PWChrono_Settlement_Receivable__c> receivables = String.isBlank(
          receivablesJson
        )
        ? null
        : buildReceivables(parseList(receivablesJson));

      Id recordId = readId(payload, 'Id', 'settlement');
      PWChrono_Full_Final_Settlement__c existing = recordId == null
        ? null
        : loadSettlement(recordId);
      if (existing != null && !EDITABLE_STATUSES.contains(existing.Status__c)) {
        throw handled(
          'This settlement is ' +
            existing.Status__c.toLowerCase() +
            ' and can no longer be edited.'
        );
      }

      PWChrono_Full_Final_Settlement__c merged = existing == null
        ? new PWChrono_Full_Final_Settlement__c()
        : existing.clone(true, true, false, false);
      applyFields(merged, payload);

      Boolean separationChanged =
        merged.Separation__c != null &&
        (existing == null ||
        merged.Separation__c != existing.Separation__c);
      if (merged.Separation__c != null) {
        applySeparationRules(
          merged,
          recordId,
          existing == null,
          separationChanged
        );
      }
      if (merged.Employee__c == null) {
        throw handled('Select the employee for this settlement.');
      }
      applyEmployeeDefaults(merged, existing == null);

      PWChrono_Full_Final_Settlement__c record = new PWChrono_Full_Final_Settlement__c(
        Id = recordId
      );
      for (String fieldName : EDITABLE_FIELDS) {
        record.put(fieldName, merged.get(fieldName));
      }
      if (recordId == null) {
        record.Status__c = STATUS_DRAFT;
      }
      record.Total_Payable__c = payables != null
        ? sumPayables(payables)
        : sumExistingPayables(recordId);
      record.Total_Receivable__c = receivables != null
        ? sumReceivables(receivables)
        : sumExistingReceivables(recordId);
      record.Net_Payable__c =
        record.Total_Payable__c - record.Total_Receivable__c;

      Savepoint sp = Database.setSavepoint();
      try {
        upsert record;
        if (payables != null) {
          replacePayables(record.Id, payables, recordId == null);
        }
        if (receivables != null) {
          replaceReceivables(record.Id, receivables, recordId == null);
        }
      } catch (Exception e) {
        Database.rollback(sp);
        throw e;
      }
      return record.Id;
    } catch (Exception e) {
      throw toAuraException(
        'saveSettlement',
        'Unable to save the settlement.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow (administrators)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Moves a settlement through its workflow. Administrators only.
   *              Allowed: Draft to Submitted; Submitted to Paid; Draft or
   *              Submitted to Cancelled.
   */
  @AuraEnabled
  public static void updateSettlementStatus(
    String settlementId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(
        actorId,
        'Only HR administrators can change the status of a settlement.'
      );
      if (!SETTLEMENT_STATUSES.contains(newStatus)) {
        throw handled('Choose a valid settlement status.');
      }
      PWChrono_Full_Final_Settlement__c settlement = loadSettlement(
        toId(settlementId)
      );
      Set<String> allowed = ALLOWED_TRANSITIONS.get(settlement.Status__c);
      if (allowed == null || !allowed.contains(newStatus)) {
        throw handled(
          'A ' +
            settlement.Status__c.toLowerCase() +
            ' settlement cannot be moved to ' +
            newStatus +
            '.'
        );
      }
      update new PWChrono_Full_Final_Settlement__c(
        Id = settlement.Id,
        Status__c = newStatus
      );
    } catch (Exception e) {
      throw toAuraException(
        'updateSettlementStatus',
        'Unable to update the settlement status.',
        e
      );
    }
  }

  /**
   * @description Deletes a draft or cancelled settlement and its lines.
   *              Administrators only.
   */
  @AuraEnabled
  public static void deleteSettlement(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(actorId, 'Only HR administrators can delete settlements.');
      PWChrono_Full_Final_Settlement__c settlement = loadSettlement(
        toId(settlementId)
      );
      if (!DELETABLE_STATUSES.contains(settlement.Status__c)) {
        throw handled('Only draft or cancelled settlements can be deleted.');
      }
      delete new PWChrono_Full_Final_Settlement__c(Id = settlement.Id);
    } catch (Exception e) {
      throw toAuraException(
        'deleteSettlement',
        'Unable to delete the settlement.',
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

  /**
   * @description Returns employees who can be settled: every active employee
   *              plus departing employees with a separation that is not
   *              cancelled (they are usually inactive by settlement time).
   */
  @AuraEnabled
  public static List<Portal_Users__c> getActiveEmployees(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Set<Id> departingEmployeeIds = new Set<Id>();
      for (PWChrono_Employee_Separation__c separation : [
        SELECT Employee__c
        FROM PWChrono_Employee_Separation__c
        WHERE
          Status__c != 'Cancelled'
          AND Employee__c != NULL
          AND Employee__r.Is_Active__c = FALSE
        LIMIT 1000
      ]) {
        departingEmployeeIds.add(separation.Employee__c);
      }
      return [
        SELECT Id, Name, Is_Active__c, Date_of_Joining__c
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE OR Id IN :departingEmployeeIds
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

  /**
   * @description Returns separations that are not cancelled, with the values
   *              a new settlement takes from its separation.
   */
  @AuraEnabled
  public static List<PWChrono_Employee_Separation__c> getActiveSeparations(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      return [
        SELECT
          Id,
          Name,
          Status__c,
          Employee__c,
          Employee__r.Name,
          Employee_Name__c,
          Company__c,
          Department__c,
          Designation__c,
          Relieving_Date__c
        FROM PWChrono_Employee_Separation__c
        WHERE Status__c != 'Cancelled'
        ORDER BY CreatedDate DESC
        LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
      ];
    } catch (Exception e) {
      throw toAuraException(
        'getActiveSeparations',
        'Unable to load separations.',
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
   * Loads a settlement for a write and locks its row, so the status checked
   * here cannot change before this transaction's DML (including the line
   * replacement) commits.
   */
  private static PWChrono_Full_Final_Settlement__c loadSettlement(
    Id settlementId
  ) {
    List<PWChrono_Full_Final_Settlement__c> records = [
      SELECT
        Id,
        Status__c,
        Employee__c,
        Employee_Name__c,
        Company__c,
        Department__c,
        Designation__c,
        Separation__c,
        Date_of_Joining__c,
        Relieving_Date__c
      FROM PWChrono_Full_Final_Settlement__c
      WHERE Id = :settlementId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw handled('Settlement not found.');
    }
    if (String.isBlank(records[0].Status__c)) {
      records[0].Status__c = STATUS_DRAFT;
    }
    return records[0];
  }

  private static void applySeparationRules(
    PWChrono_Full_Final_Settlement__c settlement,
    Id settlementId,
    Boolean isNew,
    Boolean separationChanged
  ) {
    List<PWChrono_Employee_Separation__c> separations = [
      SELECT
        Id,
        Name,
        Status__c,
        Employee__c,
        Employee_Name__c,
        Company__c,
        Department__c,
        Designation__c,
        Relieving_Date__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :settlement.Separation__c
      LIMIT 1
    ];
    if (separations.isEmpty()) {
      throw handled('The linked separation was not found.');
    }
    PWChrono_Employee_Separation__c separation = separations[0];

    if (separationChanged) {
      if (separation.Status__c == 'Cancelled') {
        throw handled(
          'Separation ' +
            separation.Name +
            ' is cancelled and cannot be settled.'
        );
      }
      List<PWChrono_Full_Final_Settlement__c> others = [
        SELECT Name
        FROM PWChrono_Full_Final_Settlement__c
        WHERE
          Separation__c = :separation.Id
          AND Status__c != :STATUS_CANCELLED
          AND Id != :settlementId
        LIMIT 1
      ];
      if (!others.isEmpty()) {
        throw handled(
          'Separation ' +
            separation.Name +
            ' already has settlement ' +
            others[0].Name +
            '.'
        );
      }
    }

    if (isNew) {
      if (settlement.Employee__c == null) {
        settlement.Employee__c = separation.Employee__c;
      }
      if (settlement.Relieving_Date__c == null) {
        settlement.Relieving_Date__c = separation.Relieving_Date__c;
      }
      if (settlement.Department__c == null) {
        settlement.Department__c = separation.Department__c;
      }
      if (settlement.Designation__c == null) {
        settlement.Designation__c = separation.Designation__c;
      }
      if (String.isBlank(settlement.Company__c)) {
        settlement.Company__c = separation.Company__c;
      }
      if (
        String.isBlank(settlement.Employee_Name__c) &&
        settlement.Employee__c == separation.Employee__c
      ) {
        settlement.Employee_Name__c = separation.Employee_Name__c;
      }
    }
    if (
      separation.Employee__c != null &&
      settlement.Employee__c != separation.Employee__c
    ) {
      throw handled(
        'The selected employee does not match separation ' +
          separation.Name +
          '.'
      );
    }
  }

  private static void applyEmployeeDefaults(
    PWChrono_Full_Final_Settlement__c settlement,
    Boolean isNew
  ) {
    List<Portal_Users__c> employees = [
      SELECT Id, Name, Date_of_Joining__c
      FROM Portal_Users__c
      WHERE Id = :settlement.Employee__c
      LIMIT 1
    ];
    if (employees.isEmpty()) {
      throw handled('The selected employee was not found.');
    }
    if (String.isBlank(settlement.Employee_Name__c)) {
      settlement.Employee_Name__c = employees[0].Name;
    }
    if (isNew && settlement.Date_of_Joining__c == null) {
      settlement.Date_of_Joining__c = employees[0].Date_of_Joining__c;
    }
  }

  private static List<PWChrono_Settlement_Payable__c> buildPayables(
    List<Object> rows
  ) {
    List<PWChrono_Settlement_Payable__c> lines = new List<PWChrono_Settlement_Payable__c>();
    for (Object rawRow : rows) {
      Map<String, Object> row = asLine(rawRow);
      PWChrono_Settlement_Payable__c line = new PWChrono_Settlement_Payable__c();
      line.Component__c = readString(row, 'Component__c');
      line.Reference_Document__c = readString(row, 'Reference_Document__c');
      line.Account__c = readString(row, 'Account__c');
      line.Amount__c = readAmount(row);
      line.Status__c = readLineStatus(row, PAYABLE_STATUSES);
      line.Name = lineName(row, line.Component__c, 'Payable Item');
      lines.add(line);
    }
    return lines;
  }

  private static List<PWChrono_Settlement_Receivable__c> buildReceivables(
    List<Object> rows
  ) {
    List<PWChrono_Settlement_Receivable__c> lines = new List<PWChrono_Settlement_Receivable__c>();
    for (Object rawRow : rows) {
      Map<String, Object> row = asLine(rawRow);
      PWChrono_Settlement_Receivable__c line = new PWChrono_Settlement_Receivable__c();
      line.Component__c = readString(row, 'Component__c');
      line.Reference_Document__c = readString(row, 'Reference_Document__c');
      line.Account__c = readString(row, 'Account__c');
      line.Amount__c = readAmount(row);
      line.Status__c = readLineStatus(row, RECEIVABLE_STATUSES);
      line.Name = lineName(row, line.Component__c, 'Receivable Item');
      lines.add(line);
    }
    return lines;
  }

  private static Decimal sumPayables(
    List<PWChrono_Settlement_Payable__c> lines
  ) {
    Decimal total = 0;
    for (PWChrono_Settlement_Payable__c line : lines) {
      if (line.Status__c != LINE_WAIVED) {
        total += line.Amount__c;
      }
    }
    return total;
  }

  private static Decimal sumReceivables(
    List<PWChrono_Settlement_Receivable__c> lines
  ) {
    Decimal total = 0;
    for (PWChrono_Settlement_Receivable__c line : lines) {
      if (line.Status__c != LINE_WAIVED) {
        total += line.Amount__c;
      }
    }
    return total;
  }

  private static Decimal sumExistingPayables(Id settlementId) {
    if (settlementId == null) {
      return 0;
    }
    return sumPayables(
      [
        SELECT Amount__c, Status__c
        FROM PWChrono_Settlement_Payable__c
        WHERE Settlement__c = :settlementId AND Amount__c != NULL
      ]
    );
  }

  private static Decimal sumExistingReceivables(Id settlementId) {
    if (settlementId == null) {
      return 0;
    }
    return sumReceivables(
      [
        SELECT Amount__c, Status__c
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :settlementId AND Amount__c != NULL
      ]
    );
  }

  private static void replacePayables(
    Id settlementId,
    List<PWChrono_Settlement_Payable__c> lines,
    Boolean isNew
  ) {
    if (!isNew) {
      delete [
        SELECT Id
        FROM PWChrono_Settlement_Payable__c
        WHERE Settlement__c = :settlementId
      ];
    }
    for (PWChrono_Settlement_Payable__c line : lines) {
      line.Settlement__c = settlementId;
    }
    if (!lines.isEmpty()) {
      insert lines;
    }
  }

  private static void replaceReceivables(
    Id settlementId,
    List<PWChrono_Settlement_Receivable__c> lines,
    Boolean isNew
  ) {
    if (!isNew) {
      delete [
        SELECT Id
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :settlementId
      ];
    }
    for (PWChrono_Settlement_Receivable__c line : lines) {
      line.Settlement__c = settlementId;
    }
    if (!lines.isEmpty()) {
      insert lines;
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
      throw handled('The settlement line data is not valid.');
    }
    return (List<Object>) parsed;
  }

  private static Map<String, Object> asLine(Object rawRow) {
    if (!(rawRow instanceof Map<String, Object>)) {
      throw handled('The settlement line data is not valid.');
    }
    return (Map<String, Object>) rawRow;
  }

  /** Copies only whitelisted fields that are present in the payload. */
  private static void applyFields(
    PWChrono_Full_Final_Settlement__c target,
    Map<String, Object> payload
  ) {
    for (String fieldName : EDITABLE_FIELDS) {
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

  private static Decimal readAmount(Map<String, Object> row) {
    String text = readString(row, 'Amount__c');
    Decimal amount;
    try {
      amount = text == null ? 0 : Decimal.valueOf(text.trim());
    } catch (Exception e) {
      throw handled('Enter each line amount as a number.');
    }
    if (amount < 0) {
      throw handled('Line amounts cannot be negative.');
    }
    return amount.setScale(2, RoundingMode.HALF_UP);
  }

  private static String readLineStatus(
    Map<String, Object> row,
    Set<String> allowed
  ) {
    String status = readString(row, 'Status__c');
    status = status == null ? LINE_PENDING : status;
    if (!allowed.contains(status)) {
      throw handled('Line status "' + status + '" is not valid.');
    }
    return status;
  }

  private static String lineName(
    Map<String, Object> row,
    String component,
    String fallback
  ) {
    String name = readString(row, 'Name');
    if (name == null) {
      name = component == null ? fallback : component;
    }
    return name.trim().left(80);
  }

  private static Id toId(String value) {
    if (String.isBlank(value)) {
      throw handled('A settlement is required.');
    }
    try {
      return Id.valueOf(value.trim());
    } catch (Exception e) {
      throw handled('The settlement reference is not valid.');
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
    PWChrono_Logger.error(
      'PWChrono_FullFinalSettlementController.' + operation,
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