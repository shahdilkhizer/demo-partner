/**
 * @description Controller for PWChrono Reports Dashboard
 *              Provides aggregated data for various HR metrics
 * @author      PWChrono Team
 * @date        2025-12-31
 */
public inherited sharing class PWChrono_ReportsDashboardController {
  private static Boolean hasFeature(String accessFeatures, String featureName) {
    if (String.isBlank(accessFeatures) || String.isBlank(featureName)) {
      return false;
    }
    for (String part : accessFeatures.split(';')) {
      if (part != null && part.trim() == featureName) {
        return true;
      }
    }
    return false;
  }

  private static void requireReportsDashboardAccessForGuest(
    String portalUserId,
    String sessionToken
  ) {
    Id verifiedPortalUserId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );

    Portal_Users__c portalUser = [
      SELECT Id, Is_Active__c, Access_Features__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];

    if (portalUser == null || portalUser.Is_Active__c != true) {
      throw new AuraHandledException('Unauthorized.');
    }

    // Reports are org-wide aggregates. Require an explicit feature flag.
    if (
      !hasFeature(portalUser.Access_Features__c, 'Reports Dashboard') &&
      !hasFeature(portalUser.Access_Features__c, 'Admin Settings')
    ) {
      throw new AuraHandledException('Access denied.');
    }
  }

  /**
   * @description Wrapper class for dashboard summary data
   */
  public class DashboardSummary {
    @AuraEnabled
    public LeaveMetrics leaveMetrics { get; set; }
    @AuraEnabled
    public AttendanceMetrics attendanceMetrics { get; set; }
    @AuraEnabled
    public EmployeeMetrics employeeMetrics { get; set; }
    @AuraEnabled
    public PerformanceMetrics performanceMetrics { get; set; }
    @AuraEnabled
    public ExpenseMetrics expenseMetrics { get; set; }
    @AuraEnabled
    public TrainingMetrics trainingMetrics { get; set; }
    @AuraEnabled
    public RecruitmentMetrics recruitmentMetrics { get; set; }
  }

  public class LeaveMetrics {
    @AuraEnabled
    public Integer totalRequests { get; set; }
    @AuraEnabled
    public Integer pending { get; set; }
    @AuraEnabled
    public Integer approved { get; set; }
    @AuraEnabled
    public Integer rejected { get; set; }
    @AuraEnabled
    public List<LeaveByType> byType { get; set; }
  }

  public class LeaveByType {
    @AuraEnabled
    public String leaveType { get; set; }
    @AuraEnabled
    public Integer count { get; set; }
  }

  public class AttendanceMetrics {
    @AuraEnabled
    public Integer totalRecords { get; set; }
    @AuraEnabled
    public Integer onTime { get; set; }
    @AuraEnabled
    public Integer late { get; set; }
    @AuraEnabled
    public Integer absent { get; set; }
    @AuraEnabled
    public Decimal attendanceRate { get; set; }
  }

  public class EmployeeMetrics {
    @AuraEnabled
    public Integer totalEmployees { get; set; }
    @AuraEnabled
    public Integer activeEmployees { get; set; }
    @AuraEnabled
    public Integer inactiveEmployees { get; set; }
    @AuraEnabled
    public List<DepartmentBreakdown> byDepartment { get; set; }
  }

  public class DepartmentBreakdown {
    @AuraEnabled
    public String department { get; set; }
    @AuraEnabled
    public Integer count { get; set; }
  }

  public class PerformanceMetrics {
    @AuraEnabled
    public Integer totalGoals { get; set; }
    @AuraEnabled
    public Integer completed { get; set; }
    @AuraEnabled
    public Integer inProgress { get; set; }
    @AuraEnabled
    public Integer notStarted { get; set; }
    @AuraEnabled
    public Decimal avgProgress { get; set; }
  }

  public class ExpenseMetrics {
    @AuraEnabled
    public Integer totalClaims { get; set; }
    @AuraEnabled
    public Decimal totalAmount { get; set; }
    @AuraEnabled
    public Decimal approvedAmount { get; set; }
    @AuraEnabled
    public Decimal pendingAmount { get; set; }
  }

  public class TrainingMetrics {
    @AuraEnabled
    public Integer totalPrograms { get; set; }
    @AuraEnabled
    public Integer activePrograms { get; set; }
    @AuraEnabled
    public Integer completedPrograms { get; set; }
    @AuraEnabled
    public Integer upcomingPrograms { get; set; }
  }

  public class RecruitmentMetrics {
    @AuraEnabled
    public Integer totalOpenings { get; set; }
    @AuraEnabled
    public Integer activeOpenings { get; set; }
    @AuraEnabled
    public Integer closedOpenings { get; set; }
    @AuraEnabled
    public Integer totalApplicants { get; set; }
  }

  /**
   * @description Get complete dashboard summary with all metrics
   * @return DashboardSummary containing all HR metrics
   */
  @AuraEnabled(cacheable=true)
  public static DashboardSummary getDashboardSummary(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() == 'Guest') {
      requireReportsDashboardAccessForGuest(portalUserId, sessionToken);
    }
    return getDashboardSummaryCore();
  }

  private static DashboardSummary getDashboardSummaryCore() {
    DashboardSummary summary = new DashboardSummary();

    summary.leaveMetrics = getLeaveMetricsCore();
    summary.attendanceMetrics = getAttendanceMetricsCore();
    summary.employeeMetrics = getEmployeeMetricsCore();
    summary.performanceMetrics = getPerformanceMetricsCore();
    summary.expenseMetrics = getExpenseMetricsCore();
    summary.trainingMetrics = getTrainingMetricsCore();
    summary.recruitmentMetrics = getRecruitmentMetricsCore();

    return summary;
  }

  /**
   * @description Get leave request metrics
   */
  @AuraEnabled(cacheable=true)
  public static LeaveMetrics getLeaveMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getLeaveMetricsCore();
  }

  private static LeaveMetrics getLeaveMetricsCore() {
    LeaveMetrics metrics = new LeaveMetrics();
    metrics.byType = new List<LeaveByType>();

    // Get leave counts by status
    List<AggregateResult> statusCounts = [
      SELECT Status__c, COUNT(Id) cnt
      FROM PWChrono_Leave__c
      WHERE CreatedDate = THIS_FISCAL_YEAR
      GROUP BY Status__c
    ];

    metrics.totalRequests = 0;
    metrics.pending = 0;
    metrics.approved = 0;
    metrics.rejected = 0;

    for (AggregateResult ar : statusCounts) {
      String status = (String) ar.get('Status__c');
      Integer count = (Integer) ar.get('cnt');
      metrics.totalRequests += count;

      if (status == 'Pending' || status == 'Open') {
        metrics.pending += count;
      } else if (status == 'Approved') {
        metrics.approved += count;
      } else if (status == 'Rejected') {
        metrics.rejected += count;
      }
    }

    // Get leave counts by type
    List<AggregateResult> typeCounts = [
      SELECT Leave_Type__c, COUNT(Id) cnt
      FROM PWChrono_Leave__c
      WHERE CreatedDate = THIS_FISCAL_YEAR
      GROUP BY Leave_Type__c
      ORDER BY COUNT(Id) DESC
      LIMIT 5
    ];

    for (AggregateResult ar : typeCounts) {
      LeaveByType lbt = new LeaveByType();
      lbt.leaveType = (String) ar.get('Leave_Type__c');
      lbt.count = (Integer) ar.get('cnt');
      metrics.byType.add(lbt);
    }

    return metrics;
  }

  /**
   * @description Get attendance metrics
   */
  @AuraEnabled(cacheable=true)
  public static AttendanceMetrics getAttendanceMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getAttendanceMetricsCore();
  }

  private static AttendanceMetrics getAttendanceMetricsCore() {
    AttendanceMetrics metrics = new AttendanceMetrics();

    // Get attendance counts by status
    List<AggregateResult> statusCounts = [
      SELECT Status__c, COUNT(Id) cnt
      FROM PWChrono_Attendance_Request__c
      WHERE Attendance_Date__c = THIS_MONTH
      GROUP BY Status__c
    ];

    metrics.totalRecords = 0;
    metrics.onTime = 0;
    metrics.late = 0;
    metrics.absent = 0;

    for (AggregateResult ar : statusCounts) {
      String status = (String) ar.get('Status__c');
      Integer count = (Integer) ar.get('cnt');
      metrics.totalRecords += count;

      if (status == 'Approved' || status == 'On Time') {
        metrics.onTime += count;
      } else if (status == 'Late') {
        metrics.late += count;
      } else if (status == 'Absent') {
        metrics.absent += count;
      }
    }

    // Calculate attendance rate
    if (metrics.totalRecords > 0) {
      metrics.attendanceRate = ((Decimal) (metrics.onTime + metrics.late) /
        metrics.totalRecords *
        100)
        .setScale(1);
    } else {
      metrics.attendanceRate = 0;
    }

    return metrics;
  }

  /**
   * @description Get employee metrics
   */
  @AuraEnabled(cacheable=true)
  public static EmployeeMetrics getEmployeeMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getEmployeeMetricsCore();
  }

  private static EmployeeMetrics getEmployeeMetricsCore() {
    EmployeeMetrics metrics = new EmployeeMetrics();
    metrics.byDepartment = new List<DepartmentBreakdown>();

    // Get employee counts by active status
    List<AggregateResult> statusCounts = [
      SELECT Is_Active__c, COUNT(Id) cnt
      FROM Portal_Users__c
      GROUP BY Is_Active__c
    ];

    metrics.totalEmployees = 0;
    metrics.activeEmployees = 0;
    metrics.inactiveEmployees = 0;

    for (AggregateResult ar : statusCounts) {
      Boolean isActive = (Boolean) ar.get('Is_Active__c');
      Integer count = (Integer) ar.get('cnt');
      metrics.totalEmployees += count;

      if (isActive == true) {
        metrics.activeEmployees += count;
      } else {
        metrics.inactiveEmployees += count;
      }
    }

    // Get employee counts by department
    List<AggregateResult> deptCounts = [
      SELECT Department__c, COUNT(Id) cnt
      FROM Portal_Users__c
      WHERE Is_Active__c = TRUE
      GROUP BY Department__c
      ORDER BY COUNT(Id) DESC
      LIMIT 8
    ];

    for (AggregateResult ar : deptCounts) {
      DepartmentBreakdown db = new DepartmentBreakdown();
      db.department = (String) ar.get('Department__c');
      db.count = (Integer) ar.get('cnt');
      if (db.department != null) {
        metrics.byDepartment.add(db);
      }
    }

    return metrics;
  }

  /**
   * @description Get performance/goals metrics
   */
  @AuraEnabled(cacheable=true)
  public static PerformanceMetrics getPerformanceMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getPerformanceMetricsCore();
  }

  private static PerformanceMetrics getPerformanceMetricsCore() {
    PerformanceMetrics metrics = new PerformanceMetrics();

    // Get goal counts by status
    List<AggregateResult> statusCounts = [
      SELECT Status__c, COUNT(Id) cnt
      FROM PWChrono_Goal__c
      WHERE CreatedDate = THIS_FISCAL_YEAR
      GROUP BY Status__c
    ];

    metrics.totalGoals = 0;
    metrics.completed = 0;
    metrics.inProgress = 0;
    metrics.notStarted = 0;

    for (AggregateResult ar : statusCounts) {
      String status = (String) ar.get('Status__c');
      Integer count = (Integer) ar.get('cnt');
      metrics.totalGoals += count;

      if (status == 'Completed' || status == 'Achieved') {
        metrics.completed += count;
      } else if (status == 'In Progress') {
        metrics.inProgress += count;
      } else if (status == 'Not Started' || status == 'Open') {
        metrics.notStarted += count;
      }
    }

    // Calculate average progress
    List<AggregateResult> avgResult = [
      SELECT AVG(Progress__c) avgProg
      FROM PWChrono_Goal__c
      WHERE CreatedDate = THIS_FISCAL_YEAR
    ];

    if (!avgResult.isEmpty() && avgResult[0].get('avgProg') != null) {
      metrics.avgProgress = ((Decimal) avgResult[0].get('avgProg')).setScale(1);
    } else {
      metrics.avgProgress = 0;
    }

    return metrics;
  }

  /**
   * @description Get expense claim metrics
   */
  @AuraEnabled(cacheable=true)
  public static ExpenseMetrics getExpenseMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getExpenseMetricsCore();
  }

  private static ExpenseMetrics getExpenseMetricsCore() {
    ExpenseMetrics metrics = new ExpenseMetrics();

    // Get expense amounts by status
    List<AggregateResult> expenseCounts = [
      SELECT Status__c, COUNT(Id) cnt, SUM(Total_Amount__c) totalAmt
      FROM PWChrono_Expense_Claim__c
      WHERE CreatedDate = THIS_FISCAL_YEAR
      GROUP BY Status__c
    ];

    metrics.totalClaims = 0;
    metrics.totalAmount = 0;
    metrics.approvedAmount = 0;
    metrics.pendingAmount = 0;

    for (AggregateResult ar : expenseCounts) {
      String status = (String) ar.get('Status__c');
      Integer count = (Integer) ar.get('cnt');
      Decimal amount = ar.get('totalAmt') != null
        ? (Decimal) ar.get('totalAmt')
        : 0;

      metrics.totalClaims += count;
      metrics.totalAmount += amount;

      if (status == 'Approved') {
        metrics.approvedAmount += amount;
      } else if (status == 'Pending' || status == 'Submitted') {
        metrics.pendingAmount += amount;
      }
    }

    return metrics;
  }

  /**
   * @description Get training program metrics
   */
  @AuraEnabled(cacheable=true)
  public static TrainingMetrics getTrainingMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getTrainingMetricsCore();
  }

  private static TrainingMetrics getTrainingMetricsCore() {
    TrainingMetrics metrics = new TrainingMetrics();

    // Get training counts by active status
    List<AggregateResult> trainingCounts = [
      SELECT Is_Active__c, COUNT(Id) cnt
      FROM PWChrono_Training_Program__c
      GROUP BY Is_Active__c
    ];

    metrics.totalPrograms = 0;
    metrics.activePrograms = 0;
    metrics.completedPrograms = 0;
    metrics.upcomingPrograms = 0;

    for (AggregateResult ar : trainingCounts) {
      Boolean isActive = (Boolean) ar.get('Is_Active__c');
      Integer count = (Integer) ar.get('cnt');
      metrics.totalPrograms += count;

      if (isActive == true) {
        metrics.activePrograms += count;
      } else {
        metrics.completedPrograms += count;
      }
    }

    return metrics;
  }

  /**
   * @description Get recruitment metrics
   */
  @AuraEnabled(cacheable=true)
  public static RecruitmentMetrics getRecruitmentMetrics() {
    if (UserInfo.getUserType() == 'Guest') {
      throw new AuraHandledException('Unauthorized.');
    }
    return getRecruitmentMetricsCore();
  }

  private static RecruitmentMetrics getRecruitmentMetricsCore() {
    RecruitmentMetrics metrics = new RecruitmentMetrics();

    // Get job opening counts by status
    List<AggregateResult> openingCounts = [
      SELECT Status__c, COUNT(Id) cnt
      FROM PWChrono_Job_Opening__c
      GROUP BY Status__c
    ];

    metrics.totalOpenings = 0;
    metrics.activeOpenings = 0;
    metrics.closedOpenings = 0;

    for (AggregateResult ar : openingCounts) {
      String status = (String) ar.get('Status__c');
      Integer count = (Integer) ar.get('cnt');
      metrics.totalOpenings += count;

      if (status == 'Open' || status == 'Active') {
        metrics.activeOpenings += count;
      } else if (status == 'Closed' || status == 'Filled') {
        metrics.closedOpenings += count;
      }
    }

    // Get total applicants
    Integer applicantCount = [SELECT COUNT() FROM PWChrono_Job_Applicant__c];
    metrics.totalApplicants = applicantCount;

    return metrics;
  }
}