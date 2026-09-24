/**
 * @description Server API for the Probation Management portal page
 *              (LWC pwchronoProbationManagement).
 *
 *              Declared without sharing because portal requests run as the
 *              Experience Cloud site guest user, and PWChrono_Probation__c and
 *              Portal_Users__c use a private external sharing model: queries
 *              with sharing would return nothing for the guest. Authorization
 *              is therefore enforced explicitly in every method:
 *              - the OTP portal session is verified
 *                (PWChrono_GuestSession.requireVerifiedPortalUserId);
 *              - the caller must hold the Employee Lifecycle feature;
 *              - status changes and deletion also require an administrator
 *                (HR Admin or System Administrator);
 *              - a non-administrator can never create or edit their own
 *                probation, and can only add to the review notes, never
 *                rewrite them.
 *              The client can never set Status__c through saveProbation; status
 *              only moves through updateProbationStatus transitions. Edits
 *              carry the record version the client loaded and are rejected
 *              when the record changed in the meantime.
 */
public without sharing class PWChrono_ProbationController {
  public static final String STATUS_PENDING = 'Pending';
  public static final String STATUS_IN_REVIEW = 'In Review';
  public static final String STATUS_EXTENDED = 'Extended';
  public static final String STATUS_COMPLETED = 'Completed';
  public static final String STATUS_FAILED = 'Failed';

  public static final Set<String> OPEN_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_IN_REVIEW,
    STATUS_EXTENDED
  };

  @TestVisible
  private static final Integer FALLBACK_PROBATION_DAYS = 90;
  @TestVisible
  private static final String SELF_MANAGE_MESSAGE = 'You cannot manage your own probation. Ask an HR administrator to make this change.';
  @TestVisible
  private static final String CONFLICT_MESSAGE = 'This probation was changed by someone else. Reopen it to see the latest details and try again.';
  private static final String NOTE_LABEL = 'Note';
  private static final String SETTINGS_RECORD = 'Default_Organization_Settings';
  private static final Integer NOTES_MAX_LENGTH = 5000;
  private static final Integer MAX_ROWS = 2000;
  private static final String PROBATION_QUERY =
    'SELECT Id, Name, SystemModstamp, Employee__c, Employee__r.Name, ' +
    'Employee__r.Designation__c, Employee__r.Department__c, ' +
    'Employee__r.Contact__r.Department, Employee__r.Photo_Url__c, ' +
    'Employee__r.Date_of_Joining__c, Reviewer__c, Reviewer__r.Name, ' +
    'Reviewer__r.Photo_Url__c, Start_Date__c, End_Date__c, ' +
    'Original_End_Date__c, Confirmation_Date__c, Status__c, Review_Notes__c ' +
    'FROM PWChrono_Probation__c';

  /**
   * Maximum rows returned by getProbations. Open probations are always loaded
   * first; closed ones fill the remaining rows, most recent first.
   */
  @TestVisible
  private static Integer recordLimit = MAX_ROWS;

  private class ProbationException extends Exception {
  }

  /** Values of one saveProbation request, with the verified caller. */
  private class ProbationInput {
    public Id employeeId;
    public Date startDate;
    public Date endDate;
    public Id reviewerId;
    public String notes;
    public String recordVersion;
    public Id actorId;
    public Boolean actorIsAdmin;
  }

  /** Orders rows by end date (soonest first, blanks last), then number. */
  private class EndDateOrder implements Comparator<ProbationRecord> {
    public Integer compare(ProbationRecord left, ProbationRecord right) {
      if (left.endDate != right.endDate) {
        if (left.endDate == null) {
          return 1;
        }
        if (right.endDate == null) {
          return -1;
        }
        return left.endDate < right.endDate ? -1 : 1;
      }
      String leftNumber = left.probationNumber == null
        ? ''
        : left.probationNumber;
      String rightNumber = right.probationNumber == null
        ? ''
        : right.probationNumber;
      return leftNumber.compareTo(rightNumber);
    }
  }

  /** @description Row returned to the Probation Management table. */
  public class ProbationRecord {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String probationNumber;
    @AuraEnabled
    public Id employeeId;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public String designation;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public String photoUrl;
    @AuraEnabled
    public Date dateOfJoining;
    @AuraEnabled
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public Date originalEndDate;
    @AuraEnabled
    public Id reviewerId;
    @AuraEnabled
    public String reviewerName;
    @AuraEnabled
    public String reviewerPhotoUrl;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String notes;
    @AuraEnabled
    public Date confirmationDate;
    /** Days until the end date for open probations (negative when overdue). */
    @AuraEnabled
    public Integer daysRemaining;
    /**
     * Fingerprint of the open record as loaded; saveProbation needs it back
     * to detect concurrent changes. Null for closed records.
     */
    @AuraEnabled
    public String recordVersion;
  }

  /** @description Active employee offered in the employee and reviewer pickers. */
  public class EmployeeOption {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String designation;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public Date dateOfJoining;
    @AuraEnabled
    public Id reportsToId;
  }

  /** @description Picker data and defaults for the Add and Edit forms. */
  public class ProbationOptions {
    @AuraEnabled
    public List<EmployeeOption> employees = new List<EmployeeOption>();
    @AuraEnabled
    public Integer defaultProbationDays;
    /** Server-resolved administrator flag; the UI uses it to show status actions. */
    @AuraEnabled
    public Boolean isAdmin;
  }

  /**
   * @description Returns probation records, soonest end date first. Every
   *              open probation is included; closed ones fill the remaining
   *              rows (up to 2000 in total), most recent first. Requires a
   *              verified session and the Employee Lifecycle feature.
   */
  @AuraEnabled
  public static List<ProbationRecord> getProbations(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireAccess(portalUserId, sessionToken);
      List<ProbationRecord> rows = new List<ProbationRecord>();
      for (PWChrono_Probation__c probation : queryProbationList()) {
        rows.add(toRecord(probation));
      }
      rows.sort(new EndDateOrder());
      return rows;
    } catch (Exception e) {
      throw toHandled(e, 'Unable to load probation records.');
    }
  }

  /**
   * @description Returns active employees for the pickers, the default
   *              probation length (PWChrono_Settings__mdt, fallback 90 days)
   *              and whether the caller is an administrator. Requires a
   *              verified session and the Employee Lifecycle feature.
   */
  @AuraEnabled
  public static ProbationOptions getProbationOptions(
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      ProbationOptions options = new ProbationOptions();
      options.defaultProbationDays = getDefaultProbationDays();
      options.isAdmin = PWChrono_AccessController.isAdmin(actorId);
      for (Portal_Users__c employee : [
        SELECT
          Id,
          Name,
          Designation__c,
          Department__c,
          Contact__r.Department,
          Date_of_Joining__c,
          Reports_To__c
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :MAX_ROWS
      ]) {
        EmployeeOption option = new EmployeeOption();
        option.id = employee.Id;
        option.name = employee.Name;
        option.designation = employee.Designation__c;
        option.department = resolveDepartment(employee);
        option.dateOfJoining = employee.Date_of_Joining__c;
        option.reportsToId = employee.Reports_To__c;
        options.employees.add(option);
      }
      return options;
    } catch (Exception e) {
      throw toHandled(e, 'Unable to load probation options.');
    }
  }

  /**
   * @description Creates a probation (probationId blank) or edits an open one.
   *              Requires a verified session and the Employee Lifecycle
   *              feature. A non-administrator can never create or edit their
   *              own probation.
   *              Create: the employee must be active with no open probation;
   *              the reviewer defaults to the employee's reporting manager; the
   *              status is always Pending; notes are the initial review notes.
   *              Edit: only Pending, In Review or Extended records, and only
   *              when recordVersion matches the stored record (otherwise
   *              someone changed it after the client loaded it). Blank dates
   *              and null notes leave those values unchanged; a blank reviewer
   *              clears the reviewer. The first end date is kept in
   *              Original_End_Date__c. Administrators' notes replace the review
   *              notes; anyone else's notes are appended as a dated entry.
   */
  @AuraEnabled
  public static ProbationRecord saveProbation(
    String probationId,
    String employeeId,
    Date startDate,
    Date endDate,
    String reviewerId,
    String notes,
    String recordVersion,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      Boolean actorIsAdmin = PWChrono_AccessController.isAdmin(actorId);
      Id recordId = String.isBlank(probationId)
        ? null
        : toId(probationId, 'probation');
      ProbationInput input = new ProbationInput();
      input.employeeId = toId(employeeId, 'employee');
      input.startDate = startDate;
      input.endDate = endDate;
      input.reviewerId = toId(reviewerId, 'reviewer');
      input.notes = notes;
      input.recordVersion = recordVersion;
      input.actorId = actorId;
      input.actorIsAdmin = actorIsAdmin;
      Id savedId = recordId == null
        ? createProbation(input)
        : editProbation(recordId, input);
      return toRecord(queryProbationsByIds(new Set<Id>{ savedId })[0]);
    } catch (Exception e) {
      throw toHandled(e, 'Unable to save the probation record.');
    }
  }

  /**
   * @description Moves a probation to a new stage. Administrators only.
   *              Allowed: Pending to In Review; any open stage to Extended
   *              (new end date later than the current one), Completed (sets
   *              the confirmation date to today) or Failed. Completed and
   *              Failed are final. Notes, when given, are appended to the
   *              review notes as an entry naming the status, date and author.
   */
  @AuraEnabled
  public static ProbationRecord updateProbationStatus(
    String probationId,
    String newStatus,
    Date newEndDate,
    String notes,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      requireAdmin(actorId, 'change probation status');
      PWChrono_Probation__c probation = getForUpdate(
        toId(probationId, 'probation')
      );
      applyTransition(probation, newStatus, newEndDate);
      String note = normalizeNotes(notes);
      if (note != null) {
        probation.Review_Notes__c = appendNote(
          probation.Review_Notes__c,
          newStatus,
          note,
          actorId
        );
      }
      update probation;
      return toRecord(queryProbationsByIds(new Set<Id>{ probation.Id })[0]);
    } catch (Exception e) {
      throw toHandled(e, 'Unable to update the probation status.');
    }
  }

  /**
   * @description Deletes Pending or In Review probations. Administrators only.
   *              All-or-nothing: if any selected record is Extended, Completed
   *              or Failed nothing is deleted and the blocked records are named.
   * @return Number of deleted records
   */
  @AuraEnabled
  public static Integer deleteProbations(
    List<String> probationIds,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireAccess(portalUserId, sessionToken);
      requireAdmin(actorId, 'delete probation records');
      Set<Id> ids = new Set<Id>();
      if (probationIds != null) {
        for (String value : probationIds) {
          if (String.isNotBlank(value)) {
            ids.add(toId(value, 'probation'));
          }
        }
      }
      if (ids.isEmpty()) {
        throw new ProbationException(
          'Select at least one probation record to delete.'
        );
      }

      List<PWChrono_Probation__c> records = [
        SELECT Id, Name, Status__c, Employee__r.Name
        FROM PWChrono_Probation__c
        WHERE Id IN :ids
        FOR UPDATE
      ];
      if (records.size() != ids.size()) {
        throw new ProbationException(
          'One or more selected probation records no longer exist. Refresh the page and try again.'
        );
      }
      List<String> blocked = new List<String>();
      for (PWChrono_Probation__c probation : records) {
        if (
          probation.Status__c != STATUS_PENDING &&
          probation.Status__c != STATUS_IN_REVIEW
        ) {
          blocked.add(describe(probation) + ' (' + probation.Status__c + ')');
        }
      }
      if (!blocked.isEmpty()) {
        blocked.sort();
        throw new ProbationException(
          'Only pending or in-review probations can be deleted. Blocked: ' +
            String.join(blocked, ', ') +
            '.'
        );
      }
      delete records;
      return records.size();
    } catch (Exception e) {
      throw toHandled(e, 'Unable to delete the probation records.');
    }
  }

  /**
   * @description Ids of active employees with an open probation (Pending,
   *              In Review or Extended). Used by the admin dashboard's
   *              employee status overview. Not exposed to clients: the caller
   *              must already have authorized the request. Runs without
   *              sharing so the result is complete in the guest runtime.
   */
  public static Set<Id> getEmployeeIdsOnOpenProbation() {
    Set<Id> employeeIds = new Set<Id>();
    for (PWChrono_Probation__c probation : [
      SELECT Employee__c
      FROM PWChrono_Probation__c
      WHERE
        Employee__c != NULL
        AND Employee__r.Is_Active__c = TRUE
        AND Status__c IN :OPEN_STATUSES
    ]) {
      employeeIds.add(probation.Employee__c);
    }
    return employeeIds;
  }

  // ---------------------------------------------------------------------------
  // Create / edit
  // ---------------------------------------------------------------------------

  private static Id createProbation(ProbationInput input) {
    Id employeeId = input.employeeId;
    if (employeeId == null) {
      throw new ProbationException('Select an employee.');
    }
    if (!input.actorIsAdmin && employeeId == input.actorId) {
      throw new ProbationException(SELF_MANAGE_MESSAGE);
    }
    // Lock the employee so concurrent creates for the same person run one
    // after the other and the open-probation check below stays reliable.
    List<Portal_Users__c> employees = [
      SELECT Id, Name, Is_Active__c, Reports_To__c, Reports_To__r.Is_Active__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
      FOR UPDATE
    ];
    if (employees.isEmpty()) {
      throw new ProbationException('Employee was not found.');
    }
    Portal_Users__c employee = employees[0];
    if (employee.Is_Active__c != true) {
      throw new ProbationException(
        'A probation can only be created for an active employee.'
      );
    }

    List<PWChrono_Probation__c> openRecords = [
      SELECT Name, Status__c
      FROM PWChrono_Probation__c
      WHERE Employee__c = :employeeId AND Status__c IN :OPEN_STATUSES
      LIMIT 1
    ];
    if (!openRecords.isEmpty()) {
      throw new ProbationException(
        employee.Name +
          ' already has an open probation (' +
          openRecords[0].Name +
          ', ' +
          openRecords[0].Status__c +
          '). Complete or close it before starting a new one.'
      );
    }

    validateDates(input.startDate, input.endDate);

    Id effectiveReviewerId = input.reviewerId;
    if (effectiveReviewerId == null) {
      // Default to the reporting manager when that manager can review.
      if (
        employee.Reports_To__c != null &&
        employee.Reports_To__c != employee.Id &&
        employee.Reports_To__r.Is_Active__c == true
      ) {
        effectiveReviewerId = employee.Reports_To__c;
      }
    } else {
      validateReviewer(effectiveReviewerId, employee.Id);
    }

    PWChrono_Probation__c probation = new PWChrono_Probation__c(
      Employee__c = employee.Id,
      Start_Date__c = input.startDate,
      End_Date__c = input.endDate,
      Reviewer__c = effectiveReviewerId,
      Status__c = STATUS_PENDING,
      Review_Notes__c = normalizeNotes(input.notes)
    );
    insert probation;
    return probation.Id;
  }

  private static Id editProbation(Id probationId, ProbationInput input) {
    PWChrono_Probation__c probation = getForUpdate(probationId);
    if (!input.actorIsAdmin && probation.Employee__c == input.actorId) {
      throw new ProbationException(SELF_MANAGE_MESSAGE);
    }
    if (!OPEN_STATUSES.contains(probation.Status__c)) {
      throw new ProbationException(
        describe(probation) +
          ' is ' +
          probation.Status__c +
          ' and can no longer be edited.'
      );
    }
    if (
      String.isBlank(input.recordVersion) ||
      input.recordVersion != versionOf(probation)
    ) {
      throw new ProbationException(CONFLICT_MESSAGE);
    }
    if (input.employeeId != null && input.employeeId != probation.Employee__c) {
      throw new ProbationException(
        'The employee on a probation record cannot be changed.'
      );
    }

    Date newStart = input.startDate == null
      ? probation.Start_Date__c
      : input.startDate;
    Date newEnd = input.endDate == null ? probation.End_Date__c : input.endDate;
    validateDates(newStart, newEnd);

    if (
      newEnd != probation.End_Date__c &&
      probation.Original_End_Date__c == null &&
      probation.End_Date__c != null
    ) {
      probation.Original_End_Date__c = probation.End_Date__c;
    }
    probation.Start_Date__c = newStart;
    probation.End_Date__c = newEnd;

    if (input.reviewerId != probation.Reviewer__c) {
      if (input.reviewerId != null) {
        validateReviewer(input.reviewerId, probation.Employee__c);
      }
      probation.Reviewer__c = input.reviewerId;
    }
    applyEditNotes(probation, input);
    update probation;
    return probation.Id;
  }

  /**
   * Administrators may rewrite the review notes (blank clears them). Anyone
   * else can only add a dated entry, so decision history cannot be removed.
   */
  private static void applyEditNotes(
    PWChrono_Probation__c probation,
    ProbationInput input
  ) {
    if (input.notes == null) {
      return;
    }
    if (input.actorIsAdmin) {
      probation.Review_Notes__c = normalizeNotes(input.notes);
      return;
    }
    String note = normalizeNotes(input.notes);
    if (note != null) {
      probation.Review_Notes__c = appendNote(
        probation.Review_Notes__c,
        NOTE_LABEL,
        note,
        input.actorId
      );
    }
  }

  private static void validateDates(Date startDate, Date endDate) {
    if (startDate == null || endDate == null) {
      throw new ProbationException(
        'Probation start and end dates are required.'
      );
    }
    if (endDate < startDate) {
      throw new ProbationException(
        'The probation end date cannot be before the start date.'
      );
    }
  }

  private static void validateReviewer(Id reviewerId, Id employeeId) {
    if (reviewerId == employeeId) {
      throw new ProbationException(
        'An employee cannot review their own probation.'
      );
    }
    List<Portal_Users__c> reviewers = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Id = :reviewerId AND Is_Active__c = TRUE
      LIMIT 1
    ];
    if (reviewers.isEmpty()) {
      throw new ProbationException('The reviewer must be an active employee.');
    }
  }

  // ---------------------------------------------------------------------------
  // Status transitions
  // ---------------------------------------------------------------------------

  private static void applyTransition(
    PWChrono_Probation__c probation,
    String newStatus,
    Date newEndDate
  ) {
    String current = probation.Status__c;
    if (!OPEN_STATUSES.contains(current)) {
      throw new ProbationException(
        describe(probation) +
          ' is already ' +
          current +
          ' and cannot be changed.'
      );
    }

    if (newStatus == STATUS_IN_REVIEW) {
      if (current != STATUS_PENDING) {
        throw new ProbationException(
          'Only a pending probation can be moved to review.'
        );
      }
    } else if (newStatus == STATUS_EXTENDED) {
      if (newEndDate == null) {
        throw new ProbationException(
          'Enter the new end date to extend the probation.'
        );
      }
      if (
        probation.End_Date__c != null &&
        newEndDate <= probation.End_Date__c
      ) {
        throw new ProbationException(
          'The new end date must be later than the current end date (' +
            probation.End_Date__c.format() +
            ').'
        );
      }
      if (probation.Original_End_Date__c == null) {
        probation.Original_End_Date__c = probation.End_Date__c;
      }
      probation.End_Date__c = newEndDate;
    } else if (newStatus == STATUS_COMPLETED) {
      probation.Confirmation_Date__c = Date.today();
    } else if (newStatus != STATUS_FAILED) {
      throw new ProbationException(
        'Choose a valid probation status: In Review, Extended, Completed or Failed.'
      );
    }
    probation.Status__c = newStatus;
  }

  private static String appendNote(
    String existing,
    String label,
    String note,
    Id authorId
  ) {
    String author = authorName(authorId);
    String entry =
      label +
      ' (' +
      Date.today().format() +
      (author == null ? '' : ', ' + author) +
      '): ' +
      note;
    String combined = String.isBlank(existing)
      ? entry
      : existing + '\n\n' + entry;
    // Keep the most recent notes when the history outgrows the field.
    return combined.length() > NOTES_MAX_LENGTH
      ? combined.right(NOTES_MAX_LENGTH)
      : combined;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  private static void requireAdmin(Id actorId, String action) {
    if (!PWChrono_AccessController.isAdmin(actorId)) {
      throw new ProbationException(
        'Only HR administrators can ' + action + '.'
      );
    }
  }

  private static String authorName(Id authorId) {
    if (authorId == null) {
      return null;
    }
    List<Portal_Users__c> authors = [
      SELECT Name
      FROM Portal_Users__c
      WHERE Id = :authorId
      LIMIT 1
    ];
    return authors.isEmpty() ? null : blankToNull(authors[0].Name);
  }

  private static List<PWChrono_Probation__c> queryProbationsByIds(Set<Id> ids) {
    return Database.query(PROBATION_QUERY + ' WHERE Id IN :ids');
  }

  /**
   * Open probations first (all of them, up to the row limit), then the most
   * recently ending closed ones in the remaining rows, so a long history can
   * never push open records out of the list.
   */
  private static List<PWChrono_Probation__c> queryProbationList() {
    Set<String> openStatuses = OPEN_STATUSES;
    Integer openLimit = recordLimit;
    List<PWChrono_Probation__c> records = Database.query(
      PROBATION_QUERY +
        ' WHERE Status__c IN :openStatuses' +
        ' ORDER BY End_Date__c ASC NULLS LAST, Name ASC LIMIT :openLimit'
    );
    Integer closedLimit = recordLimit - records.size();
    if (closedLimit > 0) {
      records.addAll(
        (List<PWChrono_Probation__c>) Database.query(
          PROBATION_QUERY +
            ' WHERE Status__c NOT IN :openStatuses' +
            ' ORDER BY End_Date__c DESC NULLS LAST, Name DESC LIMIT :closedLimit'
        )
      );
    }
    return records;
  }

  private static PWChrono_Probation__c getForUpdate(Id probationId) {
    if (probationId == null) {
      throw new ProbationException('A probation record is required.');
    }
    List<PWChrono_Probation__c> records = [
      SELECT
        Id,
        Name,
        SystemModstamp,
        Employee__c,
        Employee__r.Name,
        Reviewer__c,
        Start_Date__c,
        End_Date__c,
        Original_End_Date__c,
        Confirmation_Date__c,
        Status__c,
        Review_Notes__c
      FROM PWChrono_Probation__c
      WHERE Id = :probationId
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty()) {
      throw new ProbationException('Probation record was not found.');
    }
    return records[0];
  }

  private static ProbationRecord toRecord(PWChrono_Probation__c probation) {
    ProbationRecord row = new ProbationRecord();
    row.id = probation.Id;
    row.probationNumber = probation.Name;
    row.employeeId = probation.Employee__c;
    row.status = probation.Status__c;
    row.startDate = probation.Start_Date__c;
    row.endDate = probation.End_Date__c;
    row.originalEndDate = probation.Original_End_Date__c;
    row.confirmationDate = probation.Confirmation_Date__c;
    row.notes = probation.Review_Notes__c;
    row.reviewerId = probation.Reviewer__c;

    Portal_Users__c employee = probation.Employee__r;
    if (employee != null) {
      row.employeeName = employee.Name;
      row.designation = employee.Designation__c;
      row.department = resolveDepartment(employee);
      row.photoUrl = blankToNull(employee.Photo_Url__c);
      row.dateOfJoining = employee.Date_of_Joining__c;
    }
    Portal_Users__c reviewer = probation.Reviewer__r;
    if (reviewer != null) {
      row.reviewerName = reviewer.Name;
      row.reviewerPhotoUrl = blankToNull(reviewer.Photo_Url__c);
    }
    if (
      OPEN_STATUSES.contains(probation.Status__c) &&
      probation.End_Date__c != null
    ) {
      row.daysRemaining = Date.today().daysBetween(probation.End_Date__c);
    }
    if (OPEN_STATUSES.contains(probation.Status__c)) {
      row.recordVersion = versionOf(probation);
    }
    return row;
  }

  /**
   * Fingerprint of the stored record: its system timestamp plus every field an
   * edit or decision changes. It differs whenever anyone saved the record
   * after the client loaded it, even within the same second.
   */
  @TestVisible
  private static String versionOf(PWChrono_Probation__c probation) {
    List<String> parts = new List<String>{
      probation.SystemModstamp == null
        ? ''
        : String.valueOf(probation.SystemModstamp.getTime()),
      textOf(probation.Employee__c),
      textOf(probation.Reviewer__c),
      textOf(probation.Start_Date__c),
      textOf(probation.End_Date__c),
      textOf(probation.Original_End_Date__c),
      textOf(probation.Confirmation_Date__c),
      textOf(probation.Status__c),
      textOf(probation.Review_Notes__c)
    };
    Blob digest = Crypto.generateDigest(
      'SHA-256',
      Blob.valueOf(String.join(parts, '|'))
    );
    return EncodingUtil.convertToHex(digest);
  }

  private static String textOf(Object value) {
    return value == null ? '' : String.valueOf(value);
  }

  private static String resolveDepartment(Portal_Users__c employee) {
    if (String.isNotBlank(employee.Department__c)) {
      return employee.Department__c;
    }
    return blankToNull(employee.Contact__r?.Department);
  }

  @TestVisible
  private static Integer getDefaultProbationDays() {
    PWChrono_Settings__mdt settings = PWChrono_Settings__mdt.getInstance(
      SETTINGS_RECORD
    );
    if (
      settings != null &&
      settings.Probation_Period_Days__c != null &&
      settings.Probation_Period_Days__c > 0
    ) {
      return settings.Probation_Period_Days__c.intValue();
    }
    return FALLBACK_PROBATION_DAYS;
  }

  private static String normalizeNotes(String notes) {
    if (String.isBlank(notes)) {
      return null;
    }
    String trimmed = notes.trim();
    if (trimmed.length() > NOTES_MAX_LENGTH) {
      throw new ProbationException(
        'Notes cannot be longer than ' + NOTES_MAX_LENGTH + ' characters.'
      );
    }
    return trimmed;
  }

  private static String describe(PWChrono_Probation__c probation) {
    String employeeName = probation.Employee__r?.Name;
    return String.isBlank(employeeName)
      ? probation.Name
      : probation.Name + ' - ' + employeeName;
  }

  private static String blankToNull(String value) {
    return String.isBlank(value) ? null : value;
  }

  private static Id toId(String value, String label) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      return Id.valueOf(value);
    } catch (Exception e) {
      throw new ProbationException('The selected ' + label + ' is not valid.');
    }
  }

  private static AuraHandledException toHandled(
    Exception e,
    String fallbackMessage
  ) {
    String message;
    if (e instanceof AuraHandledException) {
      return (AuraHandledException) e;
    } else if (e instanceof ProbationException) {
      message = e.getMessage();
    } else if (e instanceof DmlException) {
      message = ((DmlException) e).getDmlMessage(0);
    } else {
      PWChrono_Logger.error(fallbackMessage, e);
      message = fallbackMessage + ' Please try again.';
    }
    AuraHandledException handled = new AuraHandledException(message);
    handled.setMessage(message);
    return handled;
  }
}