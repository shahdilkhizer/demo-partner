/**
 * @description Server side of the Notice Period Tracker in the Employee
 *              Lifecycle module. A resignation notice is the start of an
 *              employee separation, so the tracker reads and writes
 *              PWChrono_Employee_Separation__c instead of keeping its own
 *              records: notice start = Resignation_Letter_Date__c, last
 *              working day = Relieving_Date__c, reason =
 *              Reason_for_Leaving__c.
 *
 *              Runs without sharing because the portal calls this controller
 *              from the Experience Cloud site as the guest user, and the
 *              separation and employee objects use a private external sharing
 *              model: with-sharing queries would return nothing for the guest.
 *              Every method therefore verifies the portal session token and
 *              requires the Employee Lifecycle feature before reading or
 *              changing data; withdrawing notices additionally requires an
 *              administrator.
 *
 *              Separation rules enforced here (independently of the
 *              Separations screen): an employee has at most one open
 *              (Pending or In Process) separation, new separations start as
 *              Pending, and Completed or Cancelled separations are read-only.
 *              A legacy separation with a blank status is treated as Pending,
 *              as the Separations screen does.
 */
public without sharing class PWChrono_NoticePeriodController {
  public static final String STATUS_PENDING = 'Pending';
  public static final String STATUS_IN_PROCESS = 'In Process';
  public static final String STATUS_COMPLETED = 'Completed';
  public static final String STATUS_CANCELLED = 'Cancelled';

  public static final String NOTICE_ACTIVE = 'Active';
  public static final String NOTICE_CLOSING_SOON = 'Closing Soon';
  public static final String NOTICE_COMPLETED = 'Completed';

  /** A notice with this many days or fewer remaining is "Closing Soon". */
  public static final Integer CLOSING_SOON_DAYS = 7;

  private static final Set<String> OPEN_STATUSES = new Set<String>{
    STATUS_PENDING,
    STATUS_IN_PROCESS
  };
  private static final Integer MAX_ROWS = 2000;
  private static final Integer MAX_WITHDRAW = 200;
  private static final Integer REASON_MAX_LENGTH = 255;

  /** One notice period as shown in the tracker. */
  public class NoticeRecord {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String recordNumber;
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
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public Integer totalDays;
    @AuraEnabled
    public Integer completedDays;
    @AuraEnabled
    public Integer remainingDays;
    @AuraEnabled
    public Integer progressPercent;
    @AuraEnabled
    public String noticeStatus;
    @AuraEnabled
    public String separationStatus;
    @AuraEnabled
    public String reason;
    /** True while the separation is Pending or In Process. */
    @AuraEnabled
    public Boolean isOpen;
  }

  /** An active employee who can be given a notice period. */
  public class EmployeeOption {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String designation;
    @AuraEnabled
    public String department;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Queries
  // ───────────────────────────────────────────────────────────────────────

  /**
   * @description Returns every notice period that is not withdrawn
   *              (separations that are not Cancelled and have a notice start
   *              date or a last working day). Current notices (Active or
   *              Closing Soon) come first, soonest last working day first;
   *              finished notices follow, most recent last working day first.
   *              Open separations are always loaded before completed history,
   *              so the row limit can only ever cut off the oldest history.
   */
  @AuraEnabled
  public static List<NoticeRecord> getNoticeRecords(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Date today = Date.today();

      List<NoticeRecord> current = new List<NoticeRecord>();
      List<NoticeRecord> finished = new List<NoticeRecord>();
      for (PWChrono_Employee_Separation__c separation : [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee_Name__c,
          Employee__r.Name,
          Employee__r.Designation__c,
          Employee__r.Department__c,
          Employee__r.Photo_Url__c,
          Employee__r.Google_Picture_URL__c,
          Employee__r.Use_No_Profile_Picture__c,
          Employee__r.Contact__r.Department,
          Employee__r.Contact__r.Title,
          Department__r.Name,
          Designation__r.Name,
          Resignation_Letter_Date__c,
          Relieving_Date__c,
          Reason_for_Leaving__c,
          Status__c
        FROM PWChrono_Employee_Separation__c
        WHERE
          (Status__c IN :OPEN_STATUSES
          OR Status__c = NULL)
          AND (Resignation_Letter_Date__c != NULL
          OR Relieving_Date__c != NULL)
        ORDER BY
          Relieving_Date__c ASC NULLS LAST,
          Resignation_Letter_Date__c ASC NULLS LAST,
          Name ASC
        LIMIT :MAX_ROWS
      ]) {
        NoticeRecord notice = toNoticeRecord(separation, today);
        // An open separation whose last working day has passed is a
        // finished notice even though the separation is not closed yet.
        if (notice.noticeStatus == NOTICE_COMPLETED) {
          finished.add(notice);
        } else {
          current.add(notice);
        }
      }

      Integer historyLimit = MAX_ROWS - current.size() - finished.size();
      if (historyLimit > 0) {
        for (PWChrono_Employee_Separation__c separation : [
          SELECT
            Id,
            Name,
            Employee__c,
            Employee_Name__c,
            Employee__r.Name,
            Employee__r.Designation__c,
            Employee__r.Department__c,
            Employee__r.Photo_Url__c,
            Employee__r.Google_Picture_URL__c,
            Employee__r.Use_No_Profile_Picture__c,
            Employee__r.Contact__r.Department,
            Employee__r.Contact__r.Title,
            Department__r.Name,
            Designation__r.Name,
            Resignation_Letter_Date__c,
            Relieving_Date__c,
            Reason_for_Leaving__c,
            Status__c
          FROM PWChrono_Employee_Separation__c
          WHERE
            Status__c = :STATUS_COMPLETED
            AND (Resignation_Letter_Date__c != NULL
            OR Relieving_Date__c != NULL)
          ORDER BY
            Relieving_Date__c DESC NULLS LAST,
            Resignation_Letter_Date__c DESC NULLS LAST,
            Name ASC
          LIMIT :historyLimit
        ]) {
          finished.add(toNoticeRecord(separation, today));
        }
      }
      finished.sort(new MostRecentFirst());

      List<NoticeRecord> notices = new List<NoticeRecord>(current);
      notices.addAll(finished);
      return notices;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_NoticePeriodController.getNoticeRecords',
        e
      );
      throw userError('Notice periods could not be loaded. Please try again.');
    }
  }

  /**
   * @description Returns active employees who do not already have an open
   *              separation, i.e. the employees a new notice can be recorded
   *              for.
   */
  @AuraEnabled
  public static List<EmployeeOption> getNoticeOptions(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      Set<Id> employeesWithOpenSeparation = new Set<Id>();
      for (PWChrono_Employee_Separation__c separation : [
        SELECT Employee__c
        FROM PWChrono_Employee_Separation__c
        WHERE
          (Status__c IN :OPEN_STATUSES
          OR Status__c = NULL)
          AND Employee__c != NULL
      ]) {
        employeesWithOpenSeparation.add(separation.Employee__c);
      }

      List<EmployeeOption> options = new List<EmployeeOption>();
      for (Portal_Users__c employee : [
        SELECT
          Id,
          Name,
          Designation__c,
          Department__c,
          Contact__r.Title,
          Contact__r.Department
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE AND Id NOT IN :employeesWithOpenSeparation
        ORDER BY Name ASC
        LIMIT :MAX_ROWS
      ]) {
        EmployeeOption option = new EmployeeOption();
        option.id = employee.Id;
        option.name = employee.Name;
        option.designation = employeeDesignation(employee);
        option.department = employeeDepartment(employee);
        options.add(option);
      }
      return options;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_NoticePeriodController.getNoticeOptions',
        e
      );
      throw userError('Employees could not be loaded. Please try again.');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Changes
  // ───────────────────────────────────────────────────────────────────────

  /**
   * @description Records a new notice (noticeId null) by starting a Pending
   *              separation, or updates the dates and reason of an open one.
   *              Status and employee are never changed here.
   * @return Id of the separation that was created or updated
   */
  @AuraEnabled
  public static Id saveNotice(
    Id noticeId,
    Id employeeId,
    Date startDate,
    Date endDate,
    String reason,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireLifecycleAccess(portalUserId, sessionToken);
      validateDates(startDate, endDate);
      String cleanReason = cleanReason(reason);
      return noticeId == null
        ? createNotice(employeeId, startDate, endDate, cleanReason)
        : updateNotice(noticeId, employeeId, startDate, endDate, cleanReason);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (DmlException de) {
      PWChrono_Logger.error('PWChrono_NoticePeriodController.saveNotice', de);
      throw userError(de.getDmlMessage(0));
    } catch (Exception e) {
      PWChrono_Logger.error('PWChrono_NoticePeriodController.saveNotice', e);
      throw userError('The notice could not be saved. Please try again.');
    }
  }

  /**
   * @description Withdraws notices by cancelling their open separations.
   *              Administrators only. The whole request is rejected when any
   *              selected separation is already Completed; separations that
   *              are already Cancelled are left as they are.
   * @return Number of separations that were cancelled
   */
  @AuraEnabled
  public static Integer withdrawNotices(
    List<Id> noticeIds,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorId = requireLifecycleAccess(portalUserId, sessionToken);
      if (!PWChrono_AccessController.isAdmin(actorId)) {
        throw userError('Only HR administrators can withdraw notices.');
      }

      Set<Id> ids = new Set<Id>();
      if (noticeIds != null) {
        for (Id noticeId : noticeIds) {
          if (noticeId != null) {
            ids.add(noticeId);
          }
        }
      }
      if (ids.isEmpty()) {
        throw userError('Select at least one notice to withdraw.');
      }
      if (ids.size() > MAX_WITHDRAW) {
        throw userError(
          'Withdraw at most ' + MAX_WITHDRAW + ' notices at a time.'
        );
      }

      List<PWChrono_Employee_Separation__c> separations = [
        SELECT Id, Name, Status__c
        FROM PWChrono_Employee_Separation__c
        WHERE Id IN :ids
        FOR UPDATE
      ];
      if (separations.size() != ids.size()) {
        throw userError(
          'One or more notices were not found. Refresh the page and try again.'
        );
      }

      List<String> completed = new List<String>();
      List<PWChrono_Employee_Separation__c> toCancel = new List<PWChrono_Employee_Separation__c>();
      for (PWChrono_Employee_Separation__c separation : separations) {
        if (separation.Status__c == STATUS_COMPLETED) {
          completed.add(separation.Name);
        } else if (isOpenStatus(separation.Status__c)) {
          toCancel.add(
            new PWChrono_Employee_Separation__c(
              Id = separation.Id,
              Status__c = STATUS_CANCELLED
            )
          );
        }
      }
      if (!completed.isEmpty()) {
        completed.sort();
        throw userError(
          'Completed separations cannot be withdrawn: ' +
            String.join(completed, ', ') +
            '. Nothing was changed.'
        );
      }
      if (!toCancel.isEmpty()) {
        update toCancel;
      }
      return toCancel.size();
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (DmlException de) {
      PWChrono_Logger.error(
        'PWChrono_NoticePeriodController.withdrawNotices',
        de
      );
      throw userError(de.getDmlMessage(0));
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_NoticePeriodController.withdrawNotices',
        e
      );
      throw userError('The notices could not be withdrawn. Please try again.');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Save helpers
  // ───────────────────────────────────────────────────────────────────────

  private static Id createNotice(
    Id employeeId,
    Date startDate,
    Date endDate,
    String reason
  ) {
    if (employeeId == null) {
      throw userError('Select the employee who is serving notice.');
    }
    // Locking the employee serialises concurrent requests for the same
    // person, so two notices cannot both pass the open-separation check.
    List<Portal_Users__c> employees = [
      SELECT
        Id,
        Name,
        Is_Active__c,
        Designation__c,
        Department__c,
        Contact__r.Title,
        Contact__r.Department
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
      FOR UPDATE
    ];
    if (employees.isEmpty()) {
      throw userError('The selected employee was not found.');
    }
    Portal_Users__c employee = employees[0];
    if (employee.Is_Active__c != true) {
      throw userError(
        employee.Name +
        ' is inactive. Notices can be recorded only for active employees.'
      );
    }

    List<PWChrono_Employee_Separation__c> openSeparations = [
      SELECT Name
      FROM PWChrono_Employee_Separation__c
      WHERE
        Employee__c = :employee.Id
        AND (Status__c IN :OPEN_STATUSES
        OR Status__c = NULL)
      LIMIT 1
    ];
    if (!openSeparations.isEmpty()) {
      throw userError(
        employee.Name +
          ' already has an open separation (' +
          openSeparations[0].Name +
          '). Update that record instead of adding a new notice.'
      );
    }

    PWChrono_Employee_Separation__c separation = new PWChrono_Employee_Separation__c(
      Employee__c = employee.Id,
      Employee_Name__c = employee.Name,
      Resignation_Letter_Date__c = startDate,
      Relieving_Date__c = endDate,
      Reason_for_Leaving__c = reason,
      Status__c = STATUS_PENDING,
      Department__c = findActiveDepartmentId(employeeDepartment(employee)),
      Designation__c = findActiveDesignationId(employeeDesignation(employee))
    );
    insert separation;
    return separation.Id;
  }

  private static Id updateNotice(
    Id noticeId,
    Id employeeId,
    Date startDate,
    Date endDate,
    String reason
  ) {
    List<PWChrono_Employee_Separation__c> separations = [
      SELECT Id, Name, Employee__c, Status__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :noticeId
      LIMIT 1
      FOR UPDATE
    ];
    if (separations.isEmpty()) {
      throw userError(
        'The notice was not found. Refresh the page and try again.'
      );
    }
    PWChrono_Employee_Separation__c existing = separations[0];
    if (!isOpenStatus(existing.Status__c)) {
      throw userError(
        existing.Name +
          ' is ' +
          existing.Status__c.toLowerCase() +
          ' and can no longer be edited.'
      );
    }
    if (employeeId != null && employeeId != existing.Employee__c) {
      throw userError('The employee on a notice cannot be changed.');
    }

    update new PWChrono_Employee_Separation__c(
      Id = existing.Id,
      Resignation_Letter_Date__c = startDate,
      Relieving_Date__c = endDate,
      Reason_for_Leaving__c = reason
    );
    return existing.Id;
  }

  private static void validateDates(Date startDate, Date endDate) {
    if (startDate == null || endDate == null) {
      throw userError(
        'Enter both the notice start date and the last working day.'
      );
    }
    if (endDate < startDate) {
      throw userError(
        'The last working day cannot be before the notice start date.'
      );
    }
  }

  private static String cleanReason(String reason) {
    String trimmed = String.isBlank(reason) ? null : reason.trim();
    if (trimmed != null && trimmed.length() > REASON_MAX_LENGTH) {
      throw userError(
        'The reason must be ' + REASON_MAX_LENGTH + ' characters or fewer.'
      );
    }
    return trimmed;
  }

  private static Id findActiveDepartmentId(String name) {
    if (String.isBlank(name)) {
      return null;
    }
    List<PWChrono_Department__c> departments = [
      SELECT Id
      FROM PWChrono_Department__c
      WHERE Name = :name AND Is_Active__c = TRUE
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    return departments.isEmpty() ? null : departments[0].Id;
  }

  private static Id findActiveDesignationId(String name) {
    if (String.isBlank(name)) {
      return null;
    }
    List<PWChrono_Designation__c> designations = [
      SELECT Id
      FROM PWChrono_Designation__c
      WHERE Name = :name AND Is_Active__c = TRUE
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    return designations.isEmpty() ? null : designations[0].Id;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Mapping and day calculations
  // ───────────────────────────────────────────────────────────────────────

  private static NoticeRecord toNoticeRecord(
    PWChrono_Employee_Separation__c separation,
    Date today
  ) {
    Portal_Users__c employee = separation.Employee__r;
    NoticeRecord notice = new NoticeRecord();
    notice.id = separation.Id;
    notice.recordNumber = separation.Name;
    notice.employeeId = separation.Employee__c;
    notice.employeeName = employee != null && String.isNotBlank(employee.Name)
      ? employee.Name
      : separation.Employee_Name__c;
    notice.designation = separation.Designation__r != null
      ? separation.Designation__r.Name
      : employeeDesignation(employee);
    notice.department = separation.Department__r != null
      ? separation.Department__r.Name
      : employeeDepartment(employee);
    notice.photoUrl = employeePhoto(employee);
    notice.startDate = separation.Resignation_Letter_Date__c;
    notice.endDate = separation.Relieving_Date__c;
    notice.reason = separation.Reason_for_Leaving__c;
    notice.separationStatus = String.isBlank(separation.Status__c)
      ? STATUS_PENDING
      : separation.Status__c;
    notice.isOpen = isOpenStatus(separation.Status__c);
    applyDayCounts(notice, today);
    return notice;
  }

  /**
   * @description Pending and In Process separations are open. The status
   *              picklist defaults to Pending, so a legacy blank status is
   *              treated as Pending too.
   */
  private static Boolean isOpenStatus(String status) {
    return String.isBlank(status) || OPEN_STATUSES.contains(status);
  }

  /**
   * @description Orders finished notices by last working day, most recent
   *              first; then by notice start, most recent first; then by
   *              record number. Missing dates sort last.
   */
  @TestVisible
  private class MostRecentFirst implements Comparator<NoticeRecord> {
    public Integer compare(NoticeRecord a, NoticeRecord b) {
      Integer result = newestFirst(a.endDate, b.endDate);
      if (result == 0) {
        result = newestFirst(a.startDate, b.startDate);
      }
      if (result == 0) {
        String left = a.recordNumber == null ? '' : a.recordNumber;
        String right = b.recordNumber == null ? '' : b.recordNumber;
        result = left.compareTo(right);
      }
      return result;
    }

    private Integer newestFirst(Date left, Date right) {
      if (left == right) {
        return 0;
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return left > right ? -1 : 1;
    }
  }

  /**
   * @description Fills the day counts, progress and notice status. Values
   *              that cannot be known because a date is missing stay null.
   */
  @TestVisible
  private static void applyDayCounts(NoticeRecord notice, Date today) {
    Date startDate = notice.startDate;
    Date endDate = notice.endDate;

    if (startDate != null && endDate != null) {
      notice.totalDays = Math.max(0, startDate.daysBetween(endDate));
      notice.completedDays = Math.min(
        notice.totalDays,
        Math.max(0, startDate.daysBetween(today))
      );
    } else if (startDate != null) {
      notice.completedDays = Math.max(0, startDate.daysBetween(today));
    }
    if (endDate != null) {
      notice.remainingDays = Math.max(0, today.daysBetween(endDate));
    }

    Boolean separationCompleted = notice.separationStatus == STATUS_COMPLETED;
    Boolean pastEnd = endDate != null && today > endDate;

    if (separationCompleted || pastEnd) {
      notice.progressPercent = 100;
    } else if (notice.totalDays != null && notice.totalDays > 0) {
      // Integer arithmetic rounds half up without floating point drift.
      notice.progressPercent =
        (notice.completedDays * 100 + notice.totalDays / 2) / notice.totalDays;
    } else if (notice.totalDays != null) {
      // Notice starts and ends on the same day.
      notice.progressPercent = today >= startDate ? 100 : 0;
    } else {
      notice.progressPercent = 0;
    }

    if (separationCompleted || pastEnd) {
      notice.noticeStatus = NOTICE_COMPLETED;
    } else if (
      notice.remainingDays != null &&
      notice.remainingDays <= CLOSING_SOON_DAYS
    ) {
      notice.noticeStatus = NOTICE_CLOSING_SOON;
    } else {
      notice.noticeStatus = NOTICE_ACTIVE;
    }
  }

  private static String employeeDesignation(Portal_Users__c employee) {
    if (employee == null) {
      return null;
    }
    if (String.isNotBlank(employee.Designation__c)) {
      return employee.Designation__c;
    }
    return employee.Contact__r != null ? employee.Contact__r.Title : null;
  }

  private static String employeeDepartment(Portal_Users__c employee) {
    if (employee == null) {
      return null;
    }
    if (String.isNotBlank(employee.Department__c)) {
      return employee.Department__c;
    }
    return employee.Contact__r != null ? employee.Contact__r.Department : null;
  }

  private static String employeePhoto(Portal_Users__c employee) {
    if (employee == null || employee.Use_No_Profile_Picture__c == true) {
      return null;
    }
    if (String.isNotBlank(employee.Photo_Url__c)) {
      return employee.Photo_Url__c;
    }
    return String.isNotBlank(employee.Google_Picture_URL__c)
      ? employee.Google_Picture_URL__c
      : null;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Access and errors
  // ───────────────────────────────────────────────────────────────────────

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

  private static AuraHandledException userError(String message) {
    AuraHandledException ahe = new AuraHandledException(message);
    ahe.setMessage(message);
    return ahe;
  }
}