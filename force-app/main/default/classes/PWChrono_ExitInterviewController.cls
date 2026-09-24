/**
 * @description Server API for the Exit Interview portal module.
 *
 *              Runs without sharing because portal requests execute as the
 *              Experience Cloud site guest user and exit interview records use
 *              a private external sharing model, so with-sharing queries would
 *              return nothing for the guest. Authorization is enforced in code
 *              instead: every @AuraEnabled method verifies the portal session
 *              token and requires the Employee Lifecycle feature. Status
 *              changes and deletes additionally require an administrator.
 */
public without sharing class PWChrono_ExitInterviewController {
  public static final String STATUS_PENDING = 'Pending';
  public static final String STATUS_SCHEDULED = 'Scheduled';
  public static final String STATUS_COMPLETED = 'Completed';
  public static final String STATUS_SKIPPED = 'Skipped';

  private static final Set<String> INTERVIEW_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_SCHEDULED,
    STATUS_COMPLETED,
    STATUS_SKIPPED
  };
  private static final Set<String> EDITABLE_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_SCHEDULED
  };
  private static final Set<String> DELETABLE_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_SKIPPED
  };
  private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = new Map<String, Set<String>>{
    STATUS_PENDING => new Set<String>{
      STATUS_SCHEDULED,
      STATUS_COMPLETED,
      STATUS_SKIPPED
    },
    STATUS_SCHEDULED => new Set<String>{ STATUS_COMPLETED, STATUS_SKIPPED }
  };

  /** Fields a client may set on an exit interview. Status is never client-set. */
  private static final List<String> EDITABLE_FIELDS = new List<String>{
    'Employee__c',
    'Employee_Name__c',
    'Department__c',
    'Designation__c',
    'Separation__c',
    'Interviewer__c',
    'Interview_Date__c',
    'Exit_Questionnaire__c',
    'Employee_Feedback__c',
    'Final_Remarks__c',
    'Rating__c'
  };
  private static final Set<String> ID_FIELDS = new Set<String>{
    'Employee__c',
    'Department__c',
    'Designation__c',
    'Separation__c',
    'Interviewer__c'
  };

  private static final String INTERVIEW_SELECT =
    'SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Name__c,' +
    ' Department__c, Department__r.Name, Designation__c, Designation__r.Name,' +
    ' Separation__c, Separation__r.Name, Separation__r.Status__c,' +
    ' Interviewer__c, Interviewer__r.Name, Interview_Date__c,' +
    ' Exit_Questionnaire__c, Employee_Feedback__c, Final_Remarks__c,' +
    ' Rating__c, Status__c' +
    ' FROM PWChrono_Exit_Interview__c';

  // ─────────────────────────────────────────────────────────────────────────
  // Interview list and detail
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns exit interviews, most recent interview date first,
   *              optionally filtered by status.
   */
  @AuraEnabled
  public static List<PWChrono_Exit_Interview__c> getInterviews(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      String query = INTERVIEW_SELECT;
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        query += ' WHERE Status__c = :statusFilter';
      }
      query += ' ORDER BY Interview_Date__c DESC NULLS LAST, CreatedDate DESC LIMIT :queryLimit';
      return Database.query(query);
    } catch (Exception e) {
      throw toAuraException(
        'getInterviews',
        'Unable to load exit interviews.',
        e
      );
    }
  }

  /**
   * @description Returns a single exit interview by Id.
   */
  @AuraEnabled
  public static PWChrono_Exit_Interview__c getInterviewById(
    String interviewId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Id recordId = toId(interviewId);
      List<PWChrono_Exit_Interview__c> results = Database.query(
        INTERVIEW_SELECT + ' WHERE Id = :recordId LIMIT 1'
      );
      if (results.isEmpty()) {
        throw handled('Exit interview not found.');
      }
      return results[0];
    } catch (Exception e) {
      throw toAuraException(
        'getInterviewById',
        'Unable to load the exit interview.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save (insert / update)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Creates or updates an exit interview. New interviews start as
   *              Pending and status changes use updateInterviewStatus.
   *              Completed or skipped interviews cannot be edited. When a
   *              separation is linked, blank employee, department and
   *              designation values are taken from the separation.
   * @return Id of the saved interview
   */
  @AuraEnabled
  public static String saveInterview(
    String interviewJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Map<String, Object> payload = parseObject(interviewJson);
      Id recordId = readId(payload, 'Id', 'exit interview');
      PWChrono_Exit_Interview__c existing = recordId == null
        ? null
        : loadInterview(recordId);
      if (existing != null && !EDITABLE_STATUSES.contains(existing.Status__c)) {
        throw handled(
          'This exit interview is ' +
            existing.Status__c.toLowerCase() +
            ' and can no longer be edited.'
        );
      }

      PWChrono_Exit_Interview__c merged = existing == null
        ? new PWChrono_Exit_Interview__c()
        : existing.clone(true, true, false, false);
      applyFields(merged, payload);

      Boolean separationChanged =
        merged.Separation__c != null &&
        (existing == null ||
        merged.Separation__c != existing.Separation__c);
      if (merged.Separation__c != null) {
        applySeparationDefaults(merged, separationChanged);
      }
      if (merged.Employee__c == null) {
        throw handled('Select the employee for this exit interview.');
      }
      if (
        merged.Interviewer__c != null &&
        (existing == null ||
        merged.Interviewer__c != existing.Interviewer__c)
      ) {
        requireActiveInterviewer(merged.Interviewer__c);
      }
      if (
        merged.Rating__c != null &&
        (merged.Rating__c < 1 ||
        merged.Rating__c > 5 ||
        Math.floor(merged.Rating__c) != merged.Rating__c)
      ) {
        throw handled('Rating must be a whole number from 1 to 5.');
      }
      if (String.isBlank(merged.Employee_Name__c)) {
        merged.Employee_Name__c = getEmployeeName(merged.Employee__c);
      }

      PWChrono_Exit_Interview__c record = new PWChrono_Exit_Interview__c(
        Id = recordId
      );
      for (String fieldName : EDITABLE_FIELDS) {
        record.put(fieldName, merged.get(fieldName));
      }
      if (recordId == null) {
        record.Status__c = STATUS_PENDING;
      }
      upsert record;
      return record.Id;
    } catch (Exception e) {
      throw toAuraException(
        'saveInterview',
        'Unable to save the exit interview.',
        e
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow (administrators)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Moves an exit interview through its workflow. Administrators
   *              only. Allowed: Pending to Scheduled; Pending or Scheduled to
   *              Completed or Skipped. Scheduling requires an interview date.
   */
  @AuraEnabled
  public static void updateInterviewStatus(
    String interviewId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(
        actorId,
        'Only HR administrators can change the status of an exit interview.'
      );
      if (!INTERVIEW_STATUSES.contains(newStatus)) {
        throw handled('Choose a valid exit interview status.');
      }
      PWChrono_Exit_Interview__c interview = loadInterview(toId(interviewId));
      Set<String> allowed = ALLOWED_TRANSITIONS.get(interview.Status__c);
      if (allowed == null || !allowed.contains(newStatus)) {
        throw handled(
          'A ' +
            interview.Status__c.toLowerCase() +
            ' exit interview cannot be moved to ' +
            newStatus +
            '.'
        );
      }
      if (
        newStatus == STATUS_SCHEDULED &&
        interview.Interview_Date__c == null
      ) {
        throw handled('Set an interview date before scheduling the interview.');
      }
      update new PWChrono_Exit_Interview__c(
        Id = interview.Id,
        Status__c = newStatus
      );
    } catch (Exception e) {
      throw toAuraException(
        'updateInterviewStatus',
        'Unable to update the exit interview status.',
        e
      );
    }
  }

  /**
   * @description Deletes a pending or skipped exit interview. Administrators
   *              only.
   */
  @AuraEnabled
  public static void deleteInterview(
    String interviewId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      requireAdmin(
        actorId,
        'Only HR administrators can delete exit interviews.'
      );
      PWChrono_Exit_Interview__c interview = loadInterview(toId(interviewId));
      if (!DELETABLE_STATUSES.contains(interview.Status__c)) {
        throw handled(
          'Only pending or skipped exit interviews can be deleted.'
        );
      }
      delete new PWChrono_Exit_Interview__c(Id = interview.Id);
    } catch (Exception e) {
      throw toAuraException(
        'deleteInterview',
        'Unable to delete the exit interview.',
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
   * @description Returns employees for the employee and interviewer
   *              dropdowns: every active employee plus departing employees
   *              who already have an open or completed separation (they may be
   *              inactive when the interview is recorded). Is_Active__c lets
   *              the portal offer only active people as interviewers.
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
        SELECT Id, Name, Is_Active__c
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
   * @description Returns separations that are not cancelled, for linking an
   *              exit interview to a separation.
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
          Department__c,
          Designation__c
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
   * Loads an exit interview for a write and locks its row, so the status
   * checked here cannot change before this transaction's DML commits.
   */
  private static PWChrono_Exit_Interview__c loadInterview(Id interviewId) {
    List<PWChrono_Exit_Interview__c> records = [
      SELECT
        Id,
        Status__c,
        Employee__c,
        Employee_Name__c,
        Department__c,
        Designation__c,
        Separation__c,
        Interviewer__c,
        Interview_Date__c,
        Exit_Questionnaire__c,
        Employee_Feedback__c,
        Final_Remarks__c,
        Rating__c
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :interviewId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw handled('Exit interview not found.');
    }
    if (String.isBlank(records[0].Status__c)) {
      records[0].Status__c = STATUS_PENDING;
    }
    return records[0];
  }

  private static void applySeparationDefaults(
    PWChrono_Exit_Interview__c interview,
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
        Designation__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :interview.Separation__c
      LIMIT 1
    ];
    if (separations.isEmpty()) {
      throw handled('The linked separation was not found.');
    }
    PWChrono_Employee_Separation__c separation = separations[0];
    if (separationChanged && separation.Status__c == 'Cancelled') {
      throw handled(
        'Separation ' +
          separation.Name +
          ' is cancelled and cannot be linked to an exit interview.'
      );
    }
    if (interview.Employee__c == null) {
      interview.Employee__c = separation.Employee__c;
      interview.Employee_Name__c = separation.Employee_Name__c;
    } else if (
      separation.Employee__c != null &&
      interview.Employee__c != separation.Employee__c
    ) {
      throw handled(
        'The selected employee does not match separation ' +
          separation.Name +
          '.'
      );
    }
    if (interview.Department__c == null) {
      interview.Department__c = separation.Department__c;
    }
    if (interview.Designation__c == null) {
      interview.Designation__c = separation.Designation__c;
    }
  }

  private static void requireActiveInterviewer(Id interviewerId) {
    List<Portal_Users__c> interviewers = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Id = :interviewerId AND Is_Active__c = TRUE
      LIMIT 1
    ];
    if (interviewers.isEmpty()) {
      throw handled('The interviewer must be an active employee.');
    }
  }

  private static String getEmployeeName(Id employeeId) {
    List<Portal_Users__c> employees = [
      SELECT Name
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    if (employees.isEmpty()) {
      throw handled('The selected employee was not found.');
    }
    return employees[0].Name;
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

  /** Copies only whitelisted fields that are present in the payload. */
  private static void applyFields(
    PWChrono_Exit_Interview__c target,
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
      } else if (fieldName == 'Interview_Date__c') {
        target.put(fieldName, readDate(payload, fieldName));
      } else if (fieldName == 'Rating__c') {
        target.put(fieldName, readDecimal(payload, fieldName));
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

  private static Decimal readDecimal(Map<String, Object> source, String key) {
    String text = readString(source, key);
    if (text == null) {
      return null;
    }
    try {
      return Decimal.valueOf(text.trim());
    } catch (Exception e) {
      throw handled('Rating must be a whole number from 1 to 5.');
    }
  }

  private static Id toId(String value) {
    if (String.isBlank(value)) {
      throw handled('An exit interview is required.');
    }
    try {
      return Id.valueOf(value.trim());
    } catch (Exception e) {
      throw handled('The exit interview reference is not valid.');
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
    PWChrono_Logger.error('PWChrono_ExitInterviewController.' + operation, e);
    if (e instanceof DmlException) {
      return handled(((DmlException) e).getDmlMessage(0));
    }
    if (e instanceof JSONException) {
      return handled('The request data is not valid.');
    }
    return handled(fallbackMessage);
  }
}