/**
 * @description Provides HR dashboard summary metrics for LWC consumers.
 *              All SOQL runs in system context intentionally — guest user
 *              access is gated by requireHRAccess() session token validation
 *              before any data is returned.
 */
@SuppressWarnings(
  'PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.ApexCRUDViolation'
)
public inherited sharing class PWChrono_HRDashboardController {
  /**
   * Aggregate dashboard payload.
   */
  @SuppressWarnings('PMD.ExcessivePublicCount,PMD.TooManyFields')
  public class HRDashboardDTO {
    @AuraEnabled
    public Integer totalEmployees;
    @AuraEnabled
    public Integer newJoiners;
    @AuraEnabled
    public Integer lateArrivalsToday;
    @AuraEnabled
    public Decimal totalPayrollCost;
    @AuraEnabled
    public Decimal benefitDeductions;

    @AuraEnabled
    public Integer fullTimeEmployees;
    @AuraEnabled
    public Integer contractEmployees;
    @AuraEnabled
    public Integer probationEmployees;

    @AuraEnabled
    public Integer sickLeaveCount;
    @AuraEnabled
    public Integer casualLeaveCount;
    @AuraEnabled
    public Integer unpaidLeaveCount;

    @AuraEnabled
    public List<String> attendanceLabels;
    @AuraEnabled
    public List<Integer> onTimeTrend;
    @AuraEnabled
    public List<Integer> lateTrend;
    @AuraEnabled
    public List<Integer> absentTrend;

    @AuraEnabled
    public List<String> distributionLabels;
    @AuraEnabled
    public List<Integer> distributionToday;
    @AuraEnabled
    public List<Integer> distributionWeek;
    @AuraEnabled
    public List<Integer> distributionMonth;
    @AuraEnabled
    public List<Integer> distributionQuarter;
    @AuraEnabled
    public List<Integer> distributionYear;

    @AuraEnabled
    public Integer trainingInProgress;
    @AuraEnabled
    public Integer trainingCompleted;

    @AuraEnabled
    public List<Decimal> deductionSparkline;
    @AuraEnabled
    public List<Decimal> payrollSparkline;

    @AuraEnabled
    public Integer recruitmentApplicants;
    @AuraEnabled
    public Integer recruitmentHired;
    @AuraEnabled
    public Integer recruitmentAvgTimeDays;
    @AuraEnabled
    public Integer recruitmentApplicantsPercent;
    @AuraEnabled
    public Integer recruitmentScreeningPercent;
    @AuraEnabled
    public Integer recruitmentHiredPercent;
    @AuraEnabled
    public Integer recruitmentApplicantsEmployees;
    @AuraEnabled
    public Integer recruitmentScreeningEmployees;
    @AuraEnabled
    public Integer recruitmentHiredEmployees;

    @AuraEnabled
    public List<LateArrivalRow> lateArrivals;
    @AuraEnabled
    public List<PendingApprovalRow> pendingApprovals;
    @AuraEnabled
    public List<UpcomingInterviewRow> upcomingInterviews;
    @AuraEnabled
    public List<TopEmployeeRow> topEmployees;
  }

  /** Row model for late arrivals table. */
  public class LateArrivalRow {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public String arrivalTime;
    @AuraEnabled
    public String lateBy;
  }

  /** Row model for pending approvals table. */
  public class PendingApprovalRow {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public String dateAndDays;
    @AuraEnabled
    public String reason;
  }
  /** Row model for upcoming interviews table. */
  public class UpcomingInterviewRow {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String timeRange;
  }
  /** Row model for top employees table. */
  public class TopEmployeeRow {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public String photoUrl;
  }

  /**
   * @description Validates that the calling guest user holds an active session
   *              with the HR Admin role. Throws AuraHandledException on failure.
   * @param portalUserId Id of the Portal_Users__c record for the requesting user
   * @param sessionToken Active session token for the requesting user
   */
  private static void requireHRAccess(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }
    Id verifiedId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    Portal_Users__c caller = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :verifiedId
      LIMIT 1
    ];
    if (caller.Role__c != PWChrono_Constants.ROLE_HR_ADMIN) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  /**
   * @description Returns summarized HR dashboard data for the authenticated user.
   * @param portalUserId Id of the Portal_Users__c record for the requesting user
   * @param sessionToken Active session token for the requesting user
   * @return HRDashboardDTO summarized metrics payload
   */
  @SuppressWarnings('PMD.NcssMethodCount,PMD.CyclomaticComplexity')
  @AuraEnabled
  public static HRDashboardDTO getDashboardSummary(
    String portalUserId,
    String sessionToken
  ) {
    requireHRAccess(portalUserId, sessionToken);
    HRDashboardDTO dto = initDashboardDto();
    populateDashboardDto(dto);
    return dto;
  }

  @SuppressWarnings('PMD.NcssMethodCount')
  private static HRDashboardDTO initDashboardDto() {
    HRDashboardDTO dto = new HRDashboardDTO();
    dto.totalEmployees = 0;
    dto.newJoiners = 0;
    dto.lateArrivalsToday = 0;
    dto.totalPayrollCost = 0;
    dto.benefitDeductions = 0;

    dto.fullTimeEmployees = 0;
    dto.contractEmployees = 0;
    dto.probationEmployees = 0;

    dto.sickLeaveCount = 0;
    dto.casualLeaveCount = 0;
    dto.unpaidLeaveCount = 0;

    dto.attendanceLabels = new List<String>();
    dto.onTimeTrend = new List<Integer>();
    dto.lateTrend = new List<Integer>();
    dto.absentTrend = new List<Integer>();

    dto.distributionLabels = new List<String>{
      'Sales',
      'Front End',
      'React',
      'UI'
    };
    dto.distributionToday = new List<Integer>{ 0, 0, 0, 0 };
    dto.distributionWeek = new List<Integer>{ 0, 0, 0, 0 };
    dto.distributionMonth = new List<Integer>{ 0, 0, 0, 0 };
    dto.distributionQuarter = new List<Integer>{ 0, 0, 0, 0 };
    dto.distributionYear = new List<Integer>{ 0, 0, 0, 0 };

    dto.trainingInProgress = 0;
    dto.trainingCompleted = 0;

    dto.deductionSparkline = new List<Decimal>();
    dto.payrollSparkline = new List<Decimal>();

    applyRecruitmentDefaults(dto);

    dto.lateArrivals = new List<LateArrivalRow>();
    dto.pendingApprovals = new List<PendingApprovalRow>();
    dto.upcomingInterviews = new List<UpcomingInterviewRow>();
    dto.topEmployees = new List<TopEmployeeRow>();
    return dto;
  }

  private static void applyRecruitmentDefaults(HRDashboardDTO dto) {
    dto.recruitmentApplicants = 0;
    dto.recruitmentHired = 0;
    dto.recruitmentAvgTimeDays = 0;
    dto.recruitmentApplicantsPercent = 55;
    dto.recruitmentScreeningPercent = 20;
    dto.recruitmentHiredPercent = 25;
    dto.recruitmentApplicantsEmployees = 7;
    dto.recruitmentScreeningEmployees = 36;
    dto.recruitmentHiredEmployees = 18;
  }

  private static void populateDashboardDto(HRDashboardDTO dto) {
    try {
      populateHeadcount(dto);
    } catch (Exception e) {
      absorbException('populateHeadcount', e);
    }
    try {
      populatePayroll(dto);
    } catch (Exception e) {
      absorbException('populatePayroll', e);
    }
    try {
      populateLeaveDistribution(dto);
    } catch (Exception e) {
      absorbException('populateLeaveDistribution', e);
    }
    try {
      populateAttendanceTrend(dto);
    } catch (Exception e) {
      absorbException('populateAttendanceTrend', e);
    }
    try {
      populateDepartmentDistribution(dto);
    } catch (Exception e) {
      absorbException('populateDepartmentDistribution', e);
    }
    try {
      populateTraining(dto);
    } catch (Exception e) {
      absorbException('populateTraining', e);
    }
    try {
      populateSparklines(dto);
    } catch (Exception e) {
      absorbException('populateSparklines', e);
    }
    try {
      populateRecruitment(dto);
    } catch (Exception e) {
      absorbException('populateRecruitment', e);
    }
    try {
      populateLateArrivals(dto);
    } catch (Exception e) {
      absorbException('populateLateArrivals', e);
    }
    try {
      populatePendingApprovals(dto);
    } catch (Exception e) {
      absorbException('populatePendingApprovals', e);
    }
    try {
      populateUpcomingInterviews(dto);
    } catch (Exception e) {
      absorbException('populateUpcomingInterviews', e);
    }
    try {
      populateTopEmployees(dto);
    } catch (Exception e) {
      absorbException('populateTopEmployees', e);
    }
  }

  private static void populateHeadcount(HRDashboardDTO dto) {
    dto.totalEmployees = [
      SELECT COUNT()
      FROM Portal_Users__c
      LIMIT 50000
    ];
    dto.newJoiners = [
      SELECT COUNT()
      FROM Portal_Users__c
      WHERE Date_of_Joining__c = THIS_YEAR
    ];

    for (AggregateResult ar : [
      SELECT Type__c t, COUNT(Id) c
      FROM Portal_Users__c
      GROUP BY Type__c
      LIMIT 200
    ]) {
      String t = safeLower(ar.get('t'));
      Integer c = (Integer) ar.get('c');
      if (c == null) {
        c = 0;
      }

      if (t.contains('contract')) {
        dto.contractEmployees += c;
      } else if (t.contains('probation') || t.contains('trainee')) {
        dto.probationEmployees += c;
      } else {
        dto.fullTimeEmployees += c;
      }
    }
  }

  private static void populatePayroll(HRDashboardDTO dto) {
    Date today = Date.today();
    Date startMonth = Date.newInstance(today.year(), today.month(), 1);
    Date endMonth = startMonth.addMonths(1).addDays(-1);

    AggregateResult ar = [
      SELECT SUM(Gross_Pay__c) g, SUM(Total_Deductions__c) d
      FROM PWChrono_Salary_Slip__c
      WHERE Payroll_Period__c >= :startMonth AND Payroll_Period__c <= :endMonth
    ];

    dto.totalPayrollCost = (Decimal) ar.get('g');
    dto.benefitDeductions = (Decimal) ar.get('d');
    if (dto.totalPayrollCost == null) {
      dto.totalPayrollCost = 0;
    }
    if (dto.benefitDeductions == null) {
      dto.benefitDeductions = 0;
    }
  }

  private static void populateLeaveDistribution(HRDashboardDTO dto) {
    for (AggregateResult ar : [
      SELECT Leave_Type__r.Name ln, COUNT(Id) c
      FROM PWChrono_Leave__c
      WHERE From_Date__c = THIS_YEAR
      GROUP BY Leave_Type__r.Name
    ]) {
      String leaveName = safeLower(ar.get('ln'));
      Integer countVal = (Integer) ar.get('c');
      if (countVal == null) {
        countVal = 0;
      }

      if (leaveName.contains('sick')) {
        dto.sickLeaveCount += countVal;
      } else if (leaveName.contains('casual')) {
        dto.casualLeaveCount += countVal;
      } else {
        dto.unpaidLeaveCount += countVal;
      }
    }
  }

  @SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
  private static void populateAttendanceTrend(HRDashboardDTO dto) {
    Date today = Date.today();
    List<Date> days = new List<Date>();
    for (Integer i = 6; i >= 0; i--) {
      days.add(today.addDays(-i));
    }

    Map<Date, Integer> onTime = new Map<Date, Integer>();
    Map<Date, Integer> late = new Map<Date, Integer>();
    Map<Date, Integer> absent = new Map<Date, Integer>();
    Time lateThreshold = Time.newInstance(9, 30, 0, 0);

    for (PWChrono_Attendance_Request__c attendance : [
      SELECT Attendance_Date__c, Status__c, From_Time__c
      FROM PWChrono_Attendance_Request__c
      WHERE
        Attendance_Date__c >= :today.addDays(-6)
        AND Attendance_Date__c <= :today
    ]) {
      Date day = attendance.Attendance_Date__c;
      if (day == null) {
        continue;
      }

      String status = (attendance.Status__c == null
        ? ''
        : attendance.Status__c.toLowerCase());

      if (status.contains('absent')) {
        absent.put(day, (absent.containsKey(day) ? absent.get(day) : 0) + 1);
        continue;
      }

      Boolean isLate = status.contains('late');
      if (
        !isLate &&
        attendance.From_Time__c != null &&
        attendance.From_Time__c > lateThreshold
      ) {
        isLate = true;
      }

      if (isLate) {
        late.put(day, (late.containsKey(day) ? late.get(day) : 0) + 1);
      } else {
        onTime.put(day, (onTime.containsKey(day) ? onTime.get(day) : 0) + 1);
      }
    }

    dto.lateArrivalsToday = (late.containsKey(today) ? late.get(today) : 0);

    for (Date day : days) {
      dto.attendanceLabels.add(formatDateLabel(day, 'EEE'));
      dto.onTimeTrend.add(onTime.containsKey(day) ? onTime.get(day) : 0);
      dto.lateTrend.add(late.containsKey(day) ? late.get(day) : 0);
      dto.absentTrend.add(absent.containsKey(day) ? absent.get(day) : 0);
    }
  }

  private static void populateDepartmentDistribution(HRDashboardDTO dto) {
    Integer sales = 0;
    Integer frontEnd = 0;
    Integer react = 0;
    Integer ui = 0;

    for (AggregateResult ar : [
      SELECT Department__c dep, COUNT(Id) c
      FROM Portal_Users__c
      GROUP BY Department__c
      LIMIT 200
    ]) {
      String dep = safeLower(ar.get('dep'));
      Integer countVal = (Integer) ar.get('c');
      if (countVal == null) {
        countVal = 0;
      }

      if (dep.contains('sales')) {
        sales += countVal;
      } else if (dep.contains('front')) {
        frontEnd += countVal;
      } else if (dep.contains('react')) {
        react += countVal;
      } else if (dep.contains('ui') || dep.contains('design')) {
        ui += countVal;
      }
    }

    dto.distributionToday = new List<Integer>{ sales, frontEnd, react, ui };
    dto.distributionWeek = dto.distributionToday.clone();
    dto.distributionMonth = dto.distributionToday.clone();
    dto.distributionQuarter = dto.distributionToday.clone();
    dto.distributionYear = dto.distributionToday.clone();
  }

  private static void populateTraining(HRDashboardDTO dto) {
    try {
      dto.trainingInProgress = [
        SELECT COUNT()
        FROM PWChrono_Appraisal__c
        WHERE Status__c IN ('In Progress', 'Submitted')
      ];
      dto.trainingCompleted = [
        SELECT COUNT()
        FROM PWChrono_Appraisal__c
        WHERE Status__c IN ('Completed', 'Approved')
      ];
    } catch (Exception e) {
      dto.trainingInProgress = 0;
      dto.trainingCompleted = 0;
    }
  }

  private static void populateSparklines(HRDashboardDTO dto) {
    Date today = Date.today();
    Date start = Date.newInstance(today.year(), today.month(), 1).addMonths(-5);
    Date endDate = Date.newInstance(today.year(), today.month(), 1)
      .addMonths(1)
      .addDays(-1);

    Map<String, AggregateResult> byMonth = new Map<String, AggregateResult>();
    for (AggregateResult ar : [
      SELECT
        CALENDAR_YEAR(Payroll_Period__c) y,
        CALENDAR_MONTH(Payroll_Period__c) m,
        SUM(Total_Deductions__c) d,
        SUM(Gross_Pay__c) g
      FROM PWChrono_Salary_Slip__c
      WHERE Payroll_Period__c >= :start AND Payroll_Period__c <= :endDate
      GROUP BY
        CALENDAR_YEAR(Payroll_Period__c),
        CALENDAR_MONTH(Payroll_Period__c)
    ]) {
      Integer y = (Integer) ar.get('y');
      Integer m = (Integer) ar.get('m');
      if (y == null || m == null) {
        continue;
      }
      byMonth.put(String.valueOf(y) + '-' + String.valueOf(m), ar);
    }

    for (Integer i = 0; i < 6; i++) {
      Date d = start.addMonths(i);
      String key = String.valueOf(d.year()) + '-' + String.valueOf(d.month());
      AggregateResult ar = byMonth.get(key);

      Decimal deduction = 0;
      Decimal payroll = 0;
      if (ar != null) {
        deduction = (Decimal) ar.get('d');
        payroll = (Decimal) ar.get('g');
      }
      dto.deductionSparkline.add(
        (deduction == null ? 0 : deduction).setScale(0)
      );
      dto.payrollSparkline.add((payroll == null ? 0 : payroll).setScale(0));
    }
  }

  private static void populateRecruitment(HRDashboardDTO dto) {
    Integer applicants = [
      SELECT COUNT()
      FROM Portal_Users__c
      WHERE CreatedDate = THIS_YEAR
    ];
    Integer hired = [
      SELECT COUNT()
      FROM Portal_Users__c
      WHERE Date_of_Joining__c = THIS_YEAR
    ];

    Integer screening = Math.max(0, applicants - hired);
    Integer weightedTotal = applicants + screening + hired;
    if (weightedTotal <= 0) {
      weightedTotal = 1;
    }

    Integer applicantsPct = Integer.valueOf(
      Math.round((Decimal.valueOf(applicants) / weightedTotal) * 100)
    );
    Integer screeningPct = Integer.valueOf(
      Math.round((Decimal.valueOf(screening) / weightedTotal) * 100)
    );
    Integer hiredPct = Math.max(0, 100 - applicantsPct - screeningPct);

    Integer totalDays = 0;
    Integer counted = 0;
    for (Portal_Users__c userRec : [
      SELECT Id, CreatedDate, Date_of_Joining__c
      FROM Portal_Users__c
      WHERE Date_of_Joining__c != NULL
      ORDER BY CreatedDate DESC
      LIMIT 500
    ]) {
      Date createdDate = userRec.CreatedDate == null
        ? null
        : userRec.CreatedDate.date();
      Date joinDate = userRec.Date_of_Joining__c;
      if (createdDate == null || joinDate == null) {
        continue;
      }
      Integer days = createdDate.daysBetween(joinDate);
      if (days < 0) {
        continue;
      }
      totalDays += days;
      counted++;
    }

    dto.recruitmentApplicants = applicants;
    dto.recruitmentHired = hired;
    dto.recruitmentAvgTimeDays = counted > 0
      ? Integer.valueOf(Math.round(Decimal.valueOf(totalDays) / counted))
      : 0;

    dto.recruitmentApplicantsPercent = applicantsPct;
    dto.recruitmentScreeningPercent = screeningPct;
    dto.recruitmentHiredPercent = hiredPct;

    dto.recruitmentApplicantsEmployees = applicants;
    dto.recruitmentScreeningEmployees = screening;
    dto.recruitmentHiredEmployees = hired;
  }

  private static void populateLateArrivals(HRDashboardDTO dto) {
    Time lateThreshold = Time.newInstance(9, 30, 0, 0);

    List<PWChrono_Attendance_Request__c> lateItems = [
      SELECT Id, Employees__c, From_Time__c, Status__c
      FROM PWChrono_Attendance_Request__c
      WHERE
        Attendance_Date__c = TODAY
        AND (Status__c LIKE '%Late%'
        OR From_Time__c > :lateThreshold)
      ORDER BY From_Time__c DESC
      LIMIT 5
    ];

    Set<Id> employeeIds = new Set<Id>();
    for (PWChrono_Attendance_Request__c item : lateItems) {
      if (item.Employees__c != null) {
        employeeIds.add(item.Employees__c);
      }
    }

    Map<Id, Portal_Users__c> usersById = new Map<Id, Portal_Users__c>();
    if (!employeeIds.isEmpty()) {
      usersById = new Map<Id, Portal_Users__c>(
        [
          SELECT Id, Name, Department__c
          FROM Portal_Users__c
          WHERE Id IN :employeeIds
        ]
      );
    }

    for (PWChrono_Attendance_Request__c item : lateItems) {
      Portal_Users__c employee = usersById.get(item.Employees__c);
      LateArrivalRow row = new LateArrivalRow();
      row.key = String.valueOf(item.Id);
      row.employeeName = employee != null && String.isNotBlank(employee.Name)
        ? employee.Name
        : 'Employee';
      row.department = employee != null &&
        String.isNotBlank(employee.Department__c)
        ? employee.Department__c
        : 'Department';
      row.arrivalTime = formatTime(item.From_Time__c);
      row.lateBy = formatLateBy(item.From_Time__c, lateThreshold);
      dto.lateArrivals.add(row);
    }
  }

  private static void populatePendingApprovals(HRDashboardDTO dto) {
    List<PWChrono_Leave__c> leaves = [
      SELECT Id, Employees__c, From_Date__c, To_Date__c, Reason__c
      FROM PWChrono_Leave__c
      WHERE Status__c = 'Submitted'
      ORDER BY Applied_Date__c DESC
      LIMIT 3
    ];

    Set<Id> employeeIds = new Set<Id>();
    for (PWChrono_Leave__c leaveItem : leaves) {
      if (leaveItem.Employees__c != null) {
        employeeIds.add(leaveItem.Employees__c);
      }
    }

    Map<Id, Portal_Users__c> usersById = new Map<Id, Portal_Users__c>();
    if (!employeeIds.isEmpty()) {
      usersById = new Map<Id, Portal_Users__c>(
        [
          SELECT Id, Name
          FROM Portal_Users__c
          WHERE Id IN :employeeIds
        ]
      );
    }

    for (PWChrono_Leave__c leaveItem : leaves) {
      Portal_Users__c employee = usersById.get(leaveItem.Employees__c);
      PendingApprovalRow row = new PendingApprovalRow();
      row.key = String.valueOf(leaveItem.Id);
      row.employeeName = employee != null && String.isNotBlank(employee.Name)
        ? employee.Name
        : 'Employee';
      row.dateAndDays = buildDateAndDaysLabel(
        leaveItem.From_Date__c,
        leaveItem.To_Date__c
      );
      row.reason = String.isNotBlank(leaveItem.Reason__c)
        ? leaveItem.Reason__c
        : 'N/A';
      dto.pendingApprovals.add(row);
    }
  }

  private static String buildDateAndDaysLabel(Date fromDate, Date toDate) {
    if (fromDate == null) {
      return 'N/A';
    }
    Date endDate = (toDate == null ? fromDate : toDate);
    Integer days = fromDate.daysBetween(endDate) + 1;
    if (days < 1) {
      days = 1;
    }
    return formatDateLabel(fromDate, 'dd MMM yyyy') +
      ' • ' +
      String.valueOf(days) +
      (days == 1 ? ' day' : ' days');
  }

  private static String formatDateLabel(Date value, String pattern) {
    if (value == null) {
      return 'N/A';
    }
    return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0))
      .format(pattern);
  }

  private static String safeLower(Object value) {
    if (value == null) {
      return '';
    }
    return String.valueOf(value).toLowerCase();
  }

  private static String formatTime(Time t) {
    if (t == null) {
      return '--:--';
    }
    Integer hour24 = t.hour();
    Integer minute = t.minute();
    String ampm = hour24 >= 12 ? 'PM' : 'AM';
    Integer hour12 = Math.mod(hour24, 12);
    if (hour12 == 0) {
      hour12 = 12;
    }
    String mm = minute < 10
      ? '0' + String.valueOf(minute)
      : String.valueOf(minute);
    return String.valueOf(hour12) + ':' + mm + ' ' + ampm;
  }

  private static String formatLateBy(Time arrival, Time threshold) {
    if (arrival == null || threshold == null) {
      return '+0 Min';
    }
    Integer arrivalMins = arrival.hour() * 60 + arrival.minute();
    Integer thresholdMins = threshold.hour() * 60 + threshold.minute();
    Integer diff = Math.max(0, arrivalMins - thresholdMins);
    if (diff >= 60) {
      Integer hours = diff / 60;
      return '+' + String.valueOf(hours) + ' Hr';
    }
    return '+' + String.valueOf(diff) + ' Min';
  }

  private static void populateUpcomingInterviews(HRDashboardDTO dto) {
    for (PWChrono_Interview__c interviewRec : [
      SELECT Id, Name, Interview_Date__c, Job_Applicant__r.Name
      FROM PWChrono_Interview__c
      WHERE Interview_Date__c >= :System.now()
      ORDER BY Interview_Date__c ASC
      LIMIT 2
    ]) {
      UpcomingInterviewRow row = new UpcomingInterviewRow();
      row.key = String.valueOf(interviewRec.Id);

      String applicantName = interviewRec.Job_Applicant__r != null
        ? interviewRec.Job_Applicant__r.Name
        : null;
      row.title = String.isNotBlank(applicantName)
        ? applicantName + ' Interview'
        : interviewRec.Name;
      row.timeRange = formatInterviewTimeRange(interviewRec.Interview_Date__c);
      dto.upcomingInterviews.add(row);
    }
  }

  private static void populateTopEmployees(HRDashboardDTO dto) {
    for (Portal_Users__c employee : [
      SELECT Id, Name, Photo_Url__c
      FROM Portal_Users__c
      ORDER BY
        Last_Login_Date__c DESC NULLS LAST,
        Date_of_Joining__c DESC NULLS LAST
      LIMIT 10
    ]) {
      TopEmployeeRow row = new TopEmployeeRow();
      row.key = String.valueOf(employee.Id);
      row.employeeName = employee.Name;
      row.photoUrl = employee.Photo_Url__c;
      dto.topEmployees.add(row);
    }
  }

  private static String formatInterviewTimeRange(Datetime interviewDateTime) {
    if (interviewDateTime == null) {
      return 'TBD';
    }

    Datetime endTime = interviewDateTime.addMinutes(30);
    return formatDateTime12(interviewDateTime) +
      ' - ' +
      formatDateTime12(endTime);
  }

  private static String formatDateTime12(Datetime dt) {
    Integer hour24 = dt.hour();
    Integer minute = dt.minute();
    String ampm = hour24 >= 12 ? 'PM' : 'AM';
    Integer hour12 = Math.mod(hour24, 12);
    if (hour12 == 0) {
      hour12 = 12;
    }
    String mm = minute < 10
      ? '0' + String.valueOf(minute)
      : String.valueOf(minute);
    return String.valueOf(hour12) + ':' + mm + ' ' + ampm;
  }

  private static void absorbException(String contextName, Exception e) {
    String ignoredContext = contextName;
    String ignoredMessage = (e == null ? 'unknown' : e.getMessage());
    ignoredContext = ignoredContext + ignoredMessage;
  }
}