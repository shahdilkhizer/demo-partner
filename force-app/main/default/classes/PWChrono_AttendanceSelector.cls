/**
 * @description All SOQL for the Attendance module. No DML.
 *              Static methods only; queries use bind variables.
 *              Guest access is controlled by the calling portal session layer.
 */
public inherited sharing class PWChrono_AttendanceSelector {
  // ─────────────────────── Single record reads ─────────────────────────────

  /**
   * @description Fetches a full attendance request by Id.
   *              Includes related employee, approver, shift context.
   */
  public static PWChrono_Attendance_Request__c getRequestById(Id requestId) {
    List<PWChrono_Attendance_Request__c> results = [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Approvers__c,
        Approvers__r.Name,
        Attendance_Date__c,
        From_Time__c,
        To_Time__c,
        Actual_Check_In__c,
        Actual_Check_Out__c,
        Correction_Type__c,
        Reason__c,
        Status__c,
        Applied_Date__c,
        Approval_Date__c,
        Approver_Comments__c,
        Rejection_Reason__c,
        Cancelled_Date__c,
        Cancelled_Reason__c,
        Shift_Assignment__c,
        CreatedDate
      FROM PWChrono_Attendance_Request__c
      WHERE Id = :requestId
      LIMIT 1
    ];
    return results.isEmpty() ? null : results[0];
  }

  // ─────────────────────── Employee list reads ──────────────────────────────

  /**
   * @description Returns paginated attendance requests for an employee.
   *              Optionally filtered by status and date range.
   */
  @SuppressWarnings('PMD.ApexSOQLInjection')
  public static List<PWChrono_Attendance_Request__c> getRequestsByEmployee(
    Id employeeId,
    String statusFilter,
    Date startDate,
    Date endDate
  ) {
    Integer lim = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
    String query =
      'SELECT Id, Name, Employees__c, Employees__r.Name, ' +
      'Attendance_Date__c, ' +
      'From_Time__c, To_Time__c, Reason__c, Status__c, ' +
      'Approvers__c, Approvers__r.Name, CreatedDate ' +
      'FROM PWChrono_Attendance_Request__c ' +
      'WHERE Employees__c = :employeeId ';
    if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
      query += 'AND Status__c = :statusFilter ';
    }
    if (startDate != null) {
      query += 'AND Attendance_Date__c >= :startDate ';
    }
    if (endDate != null) {
      query += 'AND Attendance_Date__c <= :endDate ';
    }
    query += 'ORDER BY Attendance_Date__c DESC LIMIT :lim';
    return Database.query(query);
  }

  /**
   * @description Returns the 5 most recent requests for a dashboard summary.
   */
  public static List<PWChrono_Attendance_Request__c> getRecentRequestsByEmployee(
    Id employeeId
  ) {
    return [
      SELECT Id, Name, Attendance_Date__c, Status__c, Reason__c
      FROM PWChrono_Attendance_Request__c
      WHERE Employees__c = :employeeId
      ORDER BY CreatedDate DESC
      LIMIT 5
    ];
  }

  // ─────────────────────── Manager / approver reads ─────────────────────────

  /**
   * @description Returns submitted requests assigned to a manager.
   */
  public static List<PWChrono_Attendance_Request__c> getTeamRequestsForApproval(
    Id managerId
  ) {
    Integer lim = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
    return [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Attendance_Date__c,
        From_Time__c,
        To_Time__c,
        Reason__c,
        Status__c,
        CreatedDate
      FROM PWChrono_Attendance_Request__c
      WHERE
        Approvers__c = :managerId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
      ORDER BY CreatedDate ASC
      LIMIT :lim
    ];
  }

  /**
   * @description Returns all requests (any status) for a manager's team — for
   *              team attendance views beyond just pending approvals.
   */
  public static List<PWChrono_Attendance_Request__c> getTeamRequests(
    Id managerId,
    String statusFilter
  ) {
    Integer lim = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
    if (String.isBlank(statusFilter) || statusFilter == 'All') {
      return [
        SELECT
          Id,
          Name,
          Employees__c,
          Employees__r.Name,
          Attendance_Date__c,
          Status__c,
          Reason__c,
          CreatedDate
        FROM PWChrono_Attendance_Request__c
        WHERE Approvers__c = :managerId
        ORDER BY Attendance_Date__c DESC
        LIMIT :lim
      ];
    }
    return [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Attendance_Date__c,
        Status__c,
        Reason__c,
        CreatedDate
      FROM PWChrono_Attendance_Request__c
      WHERE Approvers__c = :managerId AND Status__c = :statusFilter
      ORDER BY Attendance_Date__c DESC
      LIMIT :lim
    ];
  }

  // ─────────────────────── Validation queries ───────────────────────────────

  /**
   * @description Returns active (Submitted or Approved) requests for an employee
   *              on a specific date.  Used for duplicate check. Excludes the
   *              request being edited (excluded when requestId is non-null).
   */
  public static List<PWChrono_Attendance_Request__c> getActiveRequestsByEmployeeAndDate(
    Id employeeId,
    Date attendanceDate,
    Id excludeRequestId
  ) {
    if (excludeRequestId != null) {
      return [
        SELECT Id, Status__c
        FROM PWChrono_Attendance_Request__c
        WHERE
          Employees__c = :employeeId
          AND Attendance_Date__c = :attendanceDate
          AND Status__c IN (
            :PWChrono_Constants.STATUS_SUBMITTED,
            :PWChrono_Constants.STATUS_APPROVED
          )
          AND Id != :excludeRequestId
        LIMIT 1
      ];
    }
    return [
      SELECT Id, Status__c
      FROM PWChrono_Attendance_Request__c
      WHERE
        Employees__c = :employeeId
        AND Attendance_Date__c = :attendanceDate
        AND Status__c IN (
          :PWChrono_Constants.STATUS_SUBMITTED,
          :PWChrono_Constants.STATUS_APPROVED
        )
      LIMIT 1
    ];
  }

  /**
   * @description Returns approved leaves that cover the given date for conflict detection.
   */
  public static List<PWChrono_Leave__c> getApprovedLeaveCoveringDate(
    Id employeeId,
    Date attendanceDate
  ) {
    return [
      SELECT Id, Leave_Type__r.Name
      FROM PWChrono_Leave__c
      WHERE
        Employees__c = :employeeId
        AND Status__c = :PWChrono_Constants.STATUS_APPROVED
        AND From_Date__c <= :attendanceDate
        AND To_Date__c >= :attendanceDate
      LIMIT 1
    ];
  }

  // ─────────────────────── Calendar / tracker reads ─────────────────────────

  /**
   * @description Returns all attendance requests for an employee within a date
   *              range.  Used to build the monthly calendar view.
   */
  public static List<PWChrono_Attendance_Request__c> getRequestsInRange(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    return [
      SELECT Id, Attendance_Date__c, From_Time__c, To_Time__c, Status__c
      FROM PWChrono_Attendance_Request__c
      WHERE
        Employees__c = :employeeId
        AND Attendance_Date__c >= :startDate
        AND Attendance_Date__c <= :endDate
      ORDER BY Attendance_Date__c ASC
    ];
  }

  // ─────────────────────── Shift context ────────────────────────────────────

  /**
   * @description Returns the shift assignment that covers a specific date.
   */
  public static PWChrono_Shift_Assignment__c getShiftForDate(
    Id employeeId,
    Date attendanceDate
  ) {
    List<PWChrono_Shift_Assignment__c> shifts = [
      SELECT
        Id,
        Shift_Type__c,
        Shift_Type__r.Name,
        Shift_Type__r.Start_Time__c,
        Shift_Type__r.End_Time__c,
        Shift_Type__r.Working_Hours__c,
        Shift_Type__r.Grace_Period_Minutes__c
      FROM PWChrono_Shift_Assignment__c
      WHERE
        Employees__c = :employeeId
        AND From_Date__c <= :attendanceDate
        AND To_Date__c >= :attendanceDate
      LIMIT 1
    ];
    return shifts.isEmpty() ? null : shifts[0];
  }

  // ─────────────────────── Monthly metrics ──────────────────────────────────

  /**
   * @description Returns request counts grouped by status for a given month.
   *              Used by the dashboard metrics section.
   */
  public static Map<String, Integer> getMonthlyRequestCounts(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    Map<String, Integer> counts = new Map<String, Integer>{
      'Submitted' => 0,
      'Approved' => 0,
      'Rejected' => 0,
      'Cancelled' => 0
    };
    AggregateResult[] aggs = [
      SELECT Status__c status, COUNT(Id) cnt
      FROM PWChrono_Attendance_Request__c
      WHERE
        Employees__c = :employeeId
        AND Attendance_Date__c >= :startDate
        AND Attendance_Date__c <= :endDate
      GROUP BY Status__c
    ];
    for (AggregateResult ar : aggs) {
      String s = (String) ar.get('status');
      if (counts.containsKey(s)) {
        counts.put(s, Integer.valueOf(ar.get('cnt')));
      }
    }
    return counts;
  }
}