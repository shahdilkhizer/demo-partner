/**
 * @description Centralized SOQL queries for the Leave module.
 *              All leave-related reads go through this class for reusability and consistency.
 *              No DML — read-only.
 */
public inherited sharing class PWChrono_LeaveSelector {
  private static final Integer DEFAULT_LIMIT = PWChrono_Constants.DEFAULT_QUERY_LIMIT;

  // ── Leave Application Queries ──

  /**
   * @description Get a single leave record with all fields needed for detail view.
   */
  public static Leave__c getLeaveById(Id leaveId) {
    List<Leave__c> leaves = [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Employees__r.Reports_To__c,
        Employees__r.Departments__c,
        Leave_Type__c,
        Leave_Type__r.Name,
        From_Date__c,
        To_Date__c,
        Total_Days__c,
        Half_Day__c,
        Reason__c,
        Status__c,
        Approvers__c,
        Approvers__r.Name,
        Applied_Date__c,
        Approval_Date__c,
        Approver_Comments__c,
        Rejection_Reason__c,
        Leave_Allocation__c,
        Half_Day_Session__c,
        Certificate_Required__c,
        Certificate_Uploaded__c,
        Working_Days_Excluded__c,
        CreatedDate,
        LastModifiedDate
      FROM Leave__c
      WHERE Id = :leaveId
      LIMIT 1
    ];
    return leaves.isEmpty() ? null : leaves[0];
  }

  /**
   * @description Get leaves for an employee with optional filters.
   *              Uses bind variables — no SOQL injection.
   * @param employeeId Portal_Users__c Id
   * @param statusFilter Status filter string (null or 'All' for no filter)
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @param queryLimit Max records (defaults to DEFAULT_LIMIT)
   * @return Filtered list of leave records
   */
  @SuppressWarnings('PMD.ApexSOQLInjection,PMD.ExcessiveParameterList')
  public static List<Leave__c> getLeavesByEmployee(
    Id employeeId,
    String statusFilter,
    Date startDate,
    Date endDate,
    Integer queryLimit
  ) {
    Integer lim = queryLimit != null ? queryLimit : DEFAULT_LIMIT;

    String query =
      'SELECT Id, Name, Employees__c, Leave_Type__c, Leave_Type__r.Name, ' +
      'From_Date__c, To_Date__c, Total_Days__c, Half_Day__c, ' +
      'Reason__c, Status__c, Approvers__c, Approvers__r.Name, ' +
      'Applied_Date__c, CreatedDate ' +
      'FROM Leave__c ' +
      'WHERE Employees__c = :employeeId ';

    if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
      query += 'AND Status__c = :statusFilter ';
    }
    if (startDate != null) {
      query += 'AND From_Date__c >= :startDate ';
    }
    if (endDate != null) {
      query += 'AND To_Date__c <= :endDate ';
    }

    query += 'ORDER BY From_Date__c DESC LIMIT :lim';

    return Database.query(query);
  }

  /**
   * @description Get team pending leaves for manager approval.
   */
  public static List<Leave__c> getTeamPendingLeaves(Id managerId) {
    return [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Leave_Type__c,
        Leave_Type__r.Name,
        From_Date__c,
        To_Date__c,
        Total_Days__c,
        Half_Day__c,
        Reason__c,
        Status__c,
        CreatedDate
      FROM Leave__c
      WHERE
        Approvers__c = :managerId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
      ORDER BY CreatedDate DESC
      LIMIT :DEFAULT_LIMIT
    ];
  }

  /**
   * @description Get team leaves for approval workspace (all statuses).
   */
  @SuppressWarnings('PMD.ExcessiveParameterList,PMD.ApexSOQLInjection')
  public static List<Leave__c> getTeamLeaves(
    Id managerId,
    String statusFilter,
    Date startDate,
    Date endDate
  ) {
    String query =
      'SELECT Id, Name, Employees__c, Employees__r.Name, ' +
      'Leave_Type__c, Leave_Type__r.Name, ' +
      'From_Date__c, To_Date__c, Total_Days__c, ' +
      'Half_Day__c, Reason__c, Status__c, ' +
      'CreatedDate ' +
      'FROM Leave__c ' +
      'WHERE Approvers__c = :managerId ';

    if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
      query += 'AND Status__c = :statusFilter ';
    }
    if (startDate != null) {
      query += 'AND From_Date__c >= :startDate ';
    }
    if (endDate != null) {
      query += 'AND To_Date__c <= :endDate ';
    }

    Integer lim = DEFAULT_LIMIT;
    query += 'ORDER BY CreatedDate DESC LIMIT :lim';

    return Database.query(query);
  }

  // ── Calendar Queries ──

  /**
   * @description Get approved leaves in a date range for calendar display.
   *              Includes own leaves and team leaves (direct reports).
   */
  public static List<Leave__c> getLeaveCalendar(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    return [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Leave_Type__c,
        Leave_Type__r.Name,
        From_Date__c,
        To_Date__c,
        Total_Days__c,
        Half_Day__c,
        Status__c
      FROM Leave__c
      WHERE
        Status__c = :PWChrono_Constants.STATUS_APPROVED
        AND From_Date__c <= :endDate
        AND To_Date__c >= :startDate
        AND (Employees__c = :employeeId
        OR Employees__r.Reports_To__c = :employeeId)
      ORDER BY From_Date__c
    ];
  }

  /**
   * @description Find overlapping leaves for validation.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static List<Leave__c> getOverlappingLeaves(
    Id employeeId,
    Date fromDate,
    Date toDate,
    Id excludeLeaveId
  ) {
    String submitted = PWChrono_Constants.STATUS_SUBMITTED;
    String approved = PWChrono_Constants.STATUS_APPROVED;

    if (excludeLeaveId != null) {
      return [
        SELECT Id, Name, From_Date__c, To_Date__c, Status__c, Leave_Type__r.Name
        FROM Leave__c
        WHERE
          Employees__c = :employeeId
          AND Id != :excludeLeaveId
          AND (Status__c = :submitted
          OR Status__c = :approved)
          AND From_Date__c <= :toDate
          AND To_Date__c >= :fromDate
      ];
    }

    return [
      SELECT Id, Name, From_Date__c, To_Date__c, Status__c, Leave_Type__r.Name
      FROM Leave__c
      WHERE
        Employees__c = :employeeId
        AND (Status__c = :submitted
        OR Status__c = :approved)
        AND From_Date__c <= :toDate
        AND To_Date__c >= :fromDate
    ];
  }

  // ── Leave Type Queries ──

  /**
   * @description Get all active leave types.
   */
  public static List<PWChrono_Leave_Type__c> getActiveLeaveTypes() {
    return getActiveLeaveTypes(false);
  }

  public static List<PWChrono_Leave_Type__c> getActiveLeaveTypes(
    Boolean includeInactive
  ) {
    if (includeInactive == true) {
      return [
        SELECT
          Id,
          Name,
          Max_Days_Allowed__c,
          Is_Carry_Forward__c,
          Max_Carry_Forward_Days__c,
          Requires_Approval__c,
          Requires_Certificate__c,
          Is_Encashable__c,
          Is_Unpaid__c,
          Applicable_After_Days__c,
          Allow_Negative_Balance__c,
          Description__c,
          Is_Active__c,
          Allow_Half_Day__c,
          Min_Days_Per_Request__c,
          Max_Consecutive_Days__c,
          Include_Weekends__c,
          Include_Holidays__c,
          Color_Code__c,
          Sort_Order__c
        FROM PWChrono_Leave_Type__c
        ORDER BY Sort_Order__c ASC NULLS LAST, Name ASC
      ];
    }

    return [
      SELECT
        Id,
        Name,
        Max_Days_Allowed__c,
        Is_Carry_Forward__c,
        Max_Carry_Forward_Days__c,
        Requires_Approval__c,
        Requires_Certificate__c,
        Is_Encashable__c,
        Is_Unpaid__c,
        Applicable_After_Days__c,
        Allow_Negative_Balance__c,
        Description__c,
        Is_Active__c,
        Allow_Half_Day__c,
        Min_Days_Per_Request__c,
        Max_Consecutive_Days__c,
        Include_Weekends__c,
        Include_Holidays__c,
        Color_Code__c,
        Sort_Order__c
      FROM PWChrono_Leave_Type__c
      WHERE Is_Active__c = TRUE
      ORDER BY Sort_Order__c ASC NULLS LAST, Name ASC
    ];
  }

  /**
   * @description Get a single leave type by Id.
   */
  public static PWChrono_Leave_Type__c getLeaveTypeById(Id leaveTypeId) {
    List<PWChrono_Leave_Type__c> types = [
      SELECT
        Id,
        Name,
        Max_Days_Allowed__c,
        Is_Carry_Forward__c,
        Max_Carry_Forward_Days__c,
        Requires_Approval__c,
        Requires_Certificate__c,
        Is_Encashable__c,
        Is_Unpaid__c,
        Applicable_After_Days__c,
        Allow_Negative_Balance__c,
        Description__c,
        Is_Active__c,
        Allow_Half_Day__c,
        Min_Days_Per_Request__c,
        Max_Consecutive_Days__c,
        Include_Weekends__c,
        Include_Holidays__c,
        Color_Code__c,
        Sort_Order__c
      FROM PWChrono_Leave_Type__c
      WHERE Id = :leaveTypeId
      LIMIT 1
    ];
    return types.isEmpty() ? null : types[0];
  }

  // ── Holiday Queries ──

  /**
   * @description Get holidays in a date range from active holiday lists.
   */
  public static List<PWChrono_Holiday__c> getHolidaysInRange(
    Date startDate,
    Date endDate
  ) {
    return [
      SELECT
        Id,
        Name,
        Holiday_Date__c,
        Is_Weekly_Off__c,
        Holiday_List__c,
        Holiday_List__r.Name
      FROM PWChrono_Holiday__c
      WHERE
        Holiday_Date__c >= :startDate
        AND Holiday_Date__c <= :endDate
        AND Holiday_List__r.Is_Active__c = TRUE
      ORDER BY Holiday_Date__c
    ];
  }

  /**
   * @description Get holiday dates as a Set for working-day calculations.
   */
  public static Set<Date> getHolidayDateSet(Date startDate, Date endDate) {
    Set<Date> dates = new Set<Date>();
    for (PWChrono_Holiday__c h : getHolidaysInRange(startDate, endDate)) {
      dates.add(h.Holiday_Date__c);
    }
    return dates;
  }

  /**
   * @description Get blocked leave dates in a range, scoped to global or employee department rules.
   */
  public static Set<Date> getBlockedDateSet(
    Date startDate,
    Date endDate,
    Id employeeDepartmentId
  ) {
    Set<Date> blockedDates = new Set<Date>();
    List<PWChrono_Leave_Block_Date__c> blockedDateRecords;
    if (employeeDepartmentId == null) {
      blockedDateRecords = [
        SELECT Block_Date__c
        FROM PWChrono_Leave_Block_Date__c
        WHERE
          Is_Active__c = TRUE
          AND Allow_Exceptions__c = FALSE
          AND Block_Date__c >= :startDate
          AND Block_Date__c <= :endDate
          AND Department__c = NULL
      ];
    } else {
      blockedDateRecords = [
        SELECT Block_Date__c
        FROM PWChrono_Leave_Block_Date__c
        WHERE
          Is_Active__c = TRUE
          AND Allow_Exceptions__c = FALSE
          AND Block_Date__c >= :startDate
          AND Block_Date__c <= :endDate
          AND (Department__c = NULL
          OR Department__c = :employeeDepartmentId)
      ];
    }

    for (PWChrono_Leave_Block_Date__c blockDate : blockedDateRecords) {
      blockedDates.add(blockDate.Block_Date__c);
    }
    return blockedDates;
  }

  // ── Allocation Queries ──

  /**
   * @description Get allocations for an employee, optionally filtered by leave type.
   */
  public static List<PWChrono_Leave_Allocation__c> getAllocationsByEmployee(
    Id employeeId,
    Id leaveTypeId
  ) {
    if (leaveTypeId != null) {
      return [
        SELECT
          Id,
          Leave_Type__c,
          Leave_Type__r.Name,
          Total_Leaves_Allocated__c,
          Total_Leaves_Used__c,
          Total_Leaves_Encashed__c,
          Carry_Forwarded_Leaves__c,
          New_Leaves_Allocated__c,
          From_Date__c,
          To_Date__c
        FROM PWChrono_Leave_Allocation__c
        WHERE
          Employees__c = :employeeId
          AND Leave_Type__c = :leaveTypeId
          AND To_Date__c >= TODAY
        ORDER BY From_Date__c DESC
        LIMIT 1
      ];
    }

    return [
      SELECT
        Id,
        Leave_Type__c,
        Leave_Type__r.Name,
        Total_Leaves_Allocated__c,
        Total_Leaves_Used__c,
        Total_Leaves_Encashed__c,
        Carry_Forwarded_Leaves__c,
        New_Leaves_Allocated__c,
        From_Date__c,
        To_Date__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employeeId AND To_Date__c >= TODAY
      ORDER BY Leave_Type__r.Name
    ];
  }

  // ── Settings Queries ──

  private static PWChrono_Settings__mdt cachedSettings;

  /**
   * @description Get weekend configuration from custom metadata (cached).
   */
  public static PWChrono_Settings__mdt getWeekendSettings() {
    if (cachedSettings == null) {
      List<PWChrono_Settings__mdt> settingsList = [
        SELECT Weekend_Day_1__c, Weekend_Day_2__c
        FROM PWChrono_Settings__mdt
        LIMIT 1
      ];
      if (!settingsList.isEmpty()) {
        cachedSettings = settingsList[0];
      }
    }
    return cachedSettings;
  }

  /**
   * @description Get weekend day names (defaults to Saturday/Sunday).
   */
  public static List<String> getWeekendDays() {
    PWChrono_Settings__mdt settings = getWeekendSettings();
    String day1 = settings != null ? settings.Weekend_Day_1__c : 'Saturday';
    String day2 = settings != null ? settings.Weekend_Day_2__c : 'Sunday';
    return new List<String>{ day1, day2 };
  }

  /**
   * @description Get the employee's department for department-scoped block date checks.
   */
  public static Id getEmployeeDepartmentId(Id employeeId) {
    if (employeeId == null) {
      return null;
    }

    List<Portal_Users__c> employees = [
      SELECT Departments__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    return employees.isEmpty() ? null : employees[0].Departments__c;
  }

  /**
   * @description Check if salary has already been processed for any requested leave date.
   */
  public static Boolean hasPaidSalarySlipInRange(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    if (employeeId == null || startDate == null || endDate == null) {
      return false;
    }

    Integer paidSalarySlipCount = [
      SELECT COUNT()
      FROM PWChrono_Salary_Slip__c
      WHERE
        Employees__c = :employeeId
        AND Payroll_Period__c >= :startDate
        AND Payroll_Period__c <= :endDate
        AND Status__c = 'Paid'
    ];

    return paidSalarySlipCount > 0;
  }
}