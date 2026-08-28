/**
 * @description Controller for Employee Dashboard LWC Component
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_DashboardController {
  // -----------------------------
  // Public API
  // -----------------------------

  /**
   * @description Guest-safe dashboard summary (Experience/OTP runtime).
   *              - Guest users must supply portalUserId + sessionToken, validated server-side.
   *              - Authenticated Salesforce users can call with nulls.
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getDashboardSummaryForPortal(
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id targetEmployeeId = resolveCurrentEmployeeId(
        portalUserId,
        sessionToken
      );
      if (targetEmployeeId == null) {
        return buildEmptySummary();
      }

      return buildDashboardSummary(targetEmployeeId);
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching dashboard summary: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching dashboard summary: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Get dashboard summary data for current employee
   * @param employeeId Optional employee ID (Portal_Users__c). If null, uses current user's employee record.
   * @return Map containing dashboard metrics
   */
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getDashboardSummary() {
    try {
      String userType = UserInfo.getUserType();
      // This method is intended for authenticated Salesforce users.
      // In Guest runtime, use getDashboardSummaryForPortal().
      if (userType == 'Guest') {
        return buildEmptySummary();
      }

      Id currentUserId = UserInfo.getUserId();
      Id targetEmployeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);
      if (targetEmployeeId == null) {
        return buildEmptySummary();
      }

      return buildDashboardSummary(targetEmployeeId);
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching dashboard summary: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching dashboard summary: ' + e.getMessage());
      throw ahe;
    }
  }

  // -----------------------------
  // Core helpers
  // -----------------------------

  private static Id resolveCurrentEmployeeId(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      // Throws if invalid.
      return PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
    }

    Id currentUserId = UserInfo.getUserId();
    return PWChrono_Utils.getCurrentEmployeeId(currentUserId);
  }

  private static Map<String, Object> buildEmptySummary() {
    return new Map<String, Object>{
      'leaveBalance' => new List<Object>(),
      'pendingApprovals' => new Map<String, Object>{ 'total' => 0 },
      'upcomingShifts' => new List<Object>(),
      'recentSalarySlips' => new List<Object>(),
      'activeGoalsCount' => 0,
      'pendingAppraisalsCount' => 0,
      'todayAttendance' => null
    };
  }

  private static Map<String, Object> buildDashboardSummary(
    Id targetEmployeeId
  ) {
    Map<String, Object> summary = new Map<String, Object>();

    // Leave Balance Summary
    summary.put('leaveBalance', getLeaveBalanceSummary(targetEmployeeId));

    // Pending Approvals Count (if manager)
    summary.put('pendingApprovals', getPendingApprovalsCount(targetEmployeeId));

    // Upcoming Shifts (next 7 days)
    summary.put('upcomingShifts', getUpcomingShifts(targetEmployeeId));

    // Recent Salary Slips (last 3 months)
    summary.put('recentSalarySlips', getRecentSalarySlips(targetEmployeeId));

    // Active Goals Count
    summary.put('activeGoalsCount', getActiveGoalsCount(targetEmployeeId));

    // Pending Appraisals Count
    summary.put(
      'pendingAppraisalsCount',
      getPendingAppraisalsCount(targetEmployeeId)
    );

    // Today's Attendance
    summary.put('todayAttendance', getTodayAttendance(targetEmployeeId));

    return summary;
  }

  /**
   * @description Get leave balance summary
   */
  private static List<Map<String, Object>> getLeaveBalanceSummary(
    Id employeeId
  ) {
    List<Map<String, Object>> balances = new List<Map<String, Object>>();

    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT
        Id,
        Leave_Type__r.Name,
        Total_Leaves_Allocated__c,
        Total_Leaves_Used__c,
        Total_Leaves_Encashed__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employeeId AND To_Date__c >= TODAY
      ORDER BY Leave_Type__r.Name
    ];

    for (PWChrono_Leave_Allocation__c allocation : allocations) {
      Map<String, Object> balance = new Map<String, Object>();
      String leaveTypeName = (allocation.Leave_Type__r != null &&
        allocation.Leave_Type__r.Name != null)
        ? allocation.Leave_Type__r.Name
        : 'Unknown';

      Decimal allocated = allocation.Total_Leaves_Allocated__c != null
        ? allocation.Total_Leaves_Allocated__c
        : 0;
      Decimal used = allocation.Total_Leaves_Used__c != null
        ? allocation.Total_Leaves_Used__c
        : 0;
      Decimal encashed = allocation.Total_Leaves_Encashed__c != null
        ? allocation.Total_Leaves_Encashed__c
        : 0;
      Decimal available = allocated - used - encashed;

      balance.put('leaveType', leaveTypeName);
      balance.put('allocated', allocated);
      balance.put('used', used);
      balance.put('available', available);

      balances.add(balance);
    }

    return balances;
  }

  /**
   * @description Get pending approvals count for manager
   */
  private static Map<String, Integer> getPendingApprovalsCount(Id employeeId) {
    Map<String, Integer> counts = new Map<String, Integer>();

    // Pending leave approvals
    Integer pendingLeaves = [
      SELECT COUNT()
      FROM PWChrono_Leave__c
      WHERE
        Approvers__c = :employeeId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
    ];

    counts.put('leaves', pendingLeaves);

    // Pending attendance approvals
    Integer pendingAttendance = [
      SELECT COUNT()
      FROM PWChrono_Attendance_Request__c
      WHERE
        Approvers__c = :employeeId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
    ];

    counts.put('attendance', pendingAttendance);

    // Pending appraisal reviews
    Integer pendingAppraisals = [
      SELECT COUNT()
      FROM PWChrono_Appraisal__c
      WHERE
        Reviewers__c = :employeeId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
    ];

    counts.put('appraisals', pendingAppraisals);

    counts.put('total', pendingLeaves + pendingAttendance + pendingAppraisals);

    return counts;
  }

  /**
   * @description Get upcoming shifts
   */
  private static List<PWChrono_Shift_Assignment__c> getUpcomingShifts(
    Id employeeId
  ) {
    Date today = System.today();
    Date nextWeek = today.addDays(7);

    return [
      SELECT
        Id,
        Shift_Type__r.Name,
        Shift_Type__r.Start_Time__c,
        Shift_Type__r.End_Time__c,
        From_Date__c,
        To_Date__c
      FROM PWChrono_Shift_Assignment__c
      WHERE
        Employees__c = :employeeId
        AND From_Date__c <= :nextWeek
        AND To_Date__c >= :today
        AND Status__c = :PWChrono_Constants.STATUS_ACTIVE
      ORDER BY From_Date__c
      LIMIT 7
    ];
  }

  /**
   * @description Get recent salary slips
   */
  private static List<PWChrono_Salary_Slip__c> getRecentSalarySlips(
    Id employeeId
  ) {
    return [
      SELECT
        Id,
        Name,
        Payroll_Period__c,
        Gross_Pay__c,
        Total_Deductions__c,
        Net_Pay__c,
        Status__c
      FROM PWChrono_Salary_Slip__c
      WHERE Employees__c = :employeeId
      ORDER BY Payroll_Period__c DESC
      LIMIT 3
    ];
  }

  /**
   * @description Get active goals count
   */
  private static Integer getActiveGoalsCount(Id employeeId) {
    return [
      SELECT COUNT()
      FROM PWChrono_Goal__c
      WHERE
        Employees__c = :employeeId
        AND Status__c IN ('Not Started', 'In Progress')
    ];
  }

  /**
   * @description Get pending appraisals count
   */
  private static Integer getPendingAppraisalsCount(Id employeeId) {
    return [
      SELECT COUNT()
      FROM PWChrono_Appraisal__c
      WHERE
        Employees__c = :employeeId
        AND Status__c IN (:PWChrono_Constants.STATUS_DRAFT, 'In Progress')
    ];
  }

  /**
   * @description Get today's attendance details
   */
  private static Map<String, Object> getTodayAttendance(Id employeeId) {
    List<PWChrono_Attendance_Request__c> requests = [
      SELECT Id, From_Time__c, To_Time__c, Status__c, Attendance_Date__c
      FROM PWChrono_Attendance_Request__c
      WHERE Employees__c = :employeeId AND Attendance_Date__c = TODAY
      LIMIT 1
    ];

    if (!requests.isEmpty()) {
      PWChrono_Attendance_Request__c request = requests[0];
      return new Map<String, Object>{
        'checkIn' => request.From_Time__c,
        'checkOut' => request.To_Time__c,
        'status' => request.Status__c,
        'id' => request.Id
      };
    }
    return null;
  }
}