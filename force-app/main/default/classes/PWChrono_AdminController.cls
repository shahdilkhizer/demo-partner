/**
 * @description Controller for Admin Settings Panel LWC
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.ExcessiveClassLength,PMD.CognitiveComplexity,PMD.ExcessivePublicCount')
public inherited sharing class PWChrono_AdminController {
  // --- Guest portal authorization helpers (Admin Settings) ---
  // The portal runs in Guest runtime with a server-issued session token.
  // For admin/config endpoints we require a verified portal session AND
  // that the caller has the Admin Settings feature.
  private static void requireSalesforceInternalUser() {
    // Admin Settings panel methods without (portalUserId, sessionToken)
    // must never be callable from Guest runtime.
    if (!PWChrono_AccessController.isSalesforceInternalUser()) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  private static void requireAdminSettingsAccessForGuest(
    String callerPortalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }

    Id verifiedPortalUserId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      callerPortalUserId,
      sessionToken
    );

    Portal_Users__c caller = [
      SELECT Id, Access_Features__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];

    if (!hasFeature(caller.Access_Features__c, 'Admin Settings')) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  private static Boolean hasFeature(String accessFeatures, String featureName) {
    if (String.isBlank(accessFeatures) || String.isBlank(featureName)) {
      return false;
    }

    // Split on semicolons and trim whitespace.
    for (String part : accessFeatures.split('\\s*;\\s*')) {
      if (part == featureName) {
        return true;
      }
    }
    return false;
  }

  public class ChartPoint {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Integer value;

    @SuppressWarnings('PMD.EmptyStatementBlock')
    public ChartPoint() {
      // Default constructor
    }
    public ChartPoint(String label, Integer value) {
      this.label = label;
      this.value = value;
    }
  }

  public class EmployeeStatusOverview {
    @AuraEnabled
    public Integer total;
    @AuraEnabled
    public Integer fulltime;
    @AuraEnabled
    public Integer contract;
    @AuraEnabled
    public Integer probation;
    @AuraEnabled
    public Integer wfh;
  }

  public class AttendanceOverview {
    @AuraEnabled
    public Date day;
    @AuraEnabled
    public Integer present;
    @AuraEnabled
    public Integer late;
    @AuraEnabled
    public Integer permission;
    @AuraEnabled
    public Integer absent;
    @AuraEnabled
    public Integer total;
  }

  public class TimelineItem implements Comparable {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String detail;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime timestamp;

    public Integer compareTo(Object other) {
      TimelineItem o = (TimelineItem) other;
      if (timestamp == null && o.timestamp == null) {
        return 0;
      }
      if (timestamp == null) {
        return 1;
      }
      if (o.timestamp == null) {
        return -1;
      }
      if (timestamp.getTime() == o.timestamp.getTime()) {
        return 0;
      }
      return timestamp.getTime() > o.timestamp.getTime() ? -1 : 1;
    }
  }

  public class AdminDashboardDTO {
    @AuraEnabled
    public String userName;
    @AuraEnabled
    public Integer totalEmployees;
    @AuraEnabled
    public String employeeTrend;
    @AuraEnabled
    public Integer onLeaveToday;
    @AuraEnabled
    public String leaveTrend;
    @AuraEnabled
    public Integer pendingRequests;
    @AuraEnabled
    public String requestTrend;
    @AuraEnabled
    public Integer totalProjects;
    @AuraEnabled
    public String projectTrend;
    @AuraEnabled
    public Integer pendingApprovals;
    @AuraEnabled
    public Integer overdueApprovals;
    @AuraEnabled
    public Integer approvedThisWeek;
    @AuraEnabled
    public Integer totalInvoices;
    @AuraEnabled
    public String invoiceTrend;
    @AuraEnabled
    public Integer completedTasks;
    @AuraEnabled
    public String taskTrend;
    @AuraEnabled
    public Integer attendanceRate;
    @AuraEnabled
    public String attendanceTrend;
    @AuraEnabled
    public Integer activeEmployees;
    @AuraEnabled
    public String activeTrend;
  }

  /**
   * @description Get Admin Dashboard Statistics
   * @return Map of statistics
   */
  @AuraEnabled(cacheable=true)
  public static AdminDashboardDTO getAdminDashboardStats(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getAdminDashboardStatsCore();
  }

  private static AdminDashboardDTO getAdminDashboardStatsCore() {
    AdminDashboardDTO data = new AdminDashboardDTO();

    try {
      // Welcome Banner Data
      data.userName = UserInfo.getName();
      Integer pendingLeaves = [
        SELECT COUNT()
        FROM Leave__c
        WHERE Status__c = 'Submitted'
      ];
      Integer pendingAttendance = [
        SELECT COUNT()
        FROM PWChrono_Attendance_Request__c
        WHERE Status__c = 'Submitted'
      ];
      data.pendingApprovals = pendingLeaves + pendingAttendance;

      Date threeDaysAgo = Date.today().addDays(-3);
      data.overdueApprovals = [
        SELECT COUNT()
        FROM Leave__c
        WHERE Status__c = 'Submitted' AND CreatedDate < :threeDaysAgo
      ];

      Date startOfWeek = Date.today().toStartOfWeek();
      data.approvedThisWeek = [
        SELECT COUNT()
        FROM Leave__c
        WHERE Status__c = 'Approved' AND LastModifiedDate >= :startOfWeek
      ];

      // Stat Card Data
      data.totalEmployees = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
      ];

      // Calculate Employee Trend (Growth over last 30 days)
      Integer newEmployeesLast30Days = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE AND CreatedDate = LAST_N_DAYS:30
      ];
      Integer previousEmployees = data.totalEmployees - newEmployeesLast30Days;
      data.employeeTrend = calculateTrendPercentage(
        data.totalEmployees,
        previousEmployees
      );

      data.onLeaveToday = [
        SELECT COUNT()
        FROM Leave__c
        WHERE
          From_Date__c <= TODAY
          AND To_Date__c >= TODAY
          AND Status__c = 'Approved'
      ];

      // Calculate Leave Trend (On Leave Today vs Yesterday)
      Integer onLeaveYesterday = [
        SELECT COUNT()
        FROM Leave__c
        WHERE
          From_Date__c <= YESTERDAY
          AND To_Date__c >= YESTERDAY
          AND Status__c = 'Approved'
      ];
      data.leaveTrend = calculateTrendPercentage(
        data.onLeaveToday,
        onLeaveYesterday
      );

      data.pendingRequests = data.pendingApprovals; // Reuse pending count

      // Calculate Request Trend (Volume of new requests this week vs last week)
      Integer requestsLast7Days =
        [
          SELECT COUNT()
          FROM Leave__c
          WHERE CreatedDate = LAST_N_DAYS:7
        ] +
        [
          SELECT COUNT()
          FROM PWChrono_Attendance_Request__c
          WHERE CreatedDate = LAST_N_DAYS:7
        ];
      Integer requestsPrevious7Days =
        [
          SELECT COUNT()
          FROM Leave__c
          WHERE CreatedDate < LAST_N_DAYS:7 AND CreatedDate >= LAST_N_DAYS:14
        ] +
        [
          SELECT COUNT()
          FROM PWChrono_Attendance_Request__c
          WHERE CreatedDate < LAST_N_DAYS:7 AND CreatedDate >= LAST_N_DAYS:14
        ];
      data.requestTrend = calculateTrendPercentage(
        requestsLast7Days,
        requestsPrevious7Days
      );

      data.totalProjects = [
        SELECT COUNT()
        FROM PWChrono_Project__c
        WHERE Status__c = 'Active'
      ];

      // Calculate Project Trend (Active Projects Growth last 30 days)
      Integer newProjectsLast30Days = [
        SELECT COUNT()
        FROM PWChrono_Project__c
        WHERE Status__c = 'Active' AND CreatedDate = LAST_N_DAYS:30
      ];
      Integer previousProjects = data.totalProjects - newProjectsLast30Days;
      data.projectTrend = calculateTrendPercentage(
        data.totalProjects,
        previousProjects
      );

      // Total Invoices
      data.totalInvoices = [SELECT COUNT() FROM PWChrono_Invoice__c];
      Integer newInvoicesLast30Days = [
        SELECT COUNT()
        FROM PWChrono_Invoice__c
        WHERE CreatedDate = LAST_N_DAYS:30
      ];
      Integer previousInvoices = data.totalInvoices - newInvoicesLast30Days;
      data.invoiceTrend = calculateTrendPercentage(
        data.totalInvoices,
        previousInvoices
      );

      // Completed Tasks
      data.completedTasks = [
        SELECT COUNT()
        FROM PWChrono_Onboarding_Task__c
        WHERE Status__c = 'Completed'
      ];
      Integer completedTasksLast7Days = [
        SELECT COUNT()
        FROM PWChrono_Onboarding_Task__c
        WHERE Status__c = 'Completed' AND LastModifiedDate = LAST_N_DAYS:7
      ];
      Integer completedTasksPrevious7Days = [
        SELECT COUNT()
        FROM PWChrono_Onboarding_Task__c
        WHERE
          Status__c = 'Completed'
          AND LastModifiedDate < LAST_N_DAYS:7
          AND LastModifiedDate >= LAST_N_DAYS:14
      ];
      data.taskTrend = calculateTrendPercentage(
        completedTasksLast7Days,
        completedTasksPrevious7Days
      );

      // Attendance Rate (percentage of employees who are active)
      Integer totalActive = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
      ];
      Integer approvedLeaves = [
        SELECT COUNT()
        FROM Leave__c
        WHERE
          Status__c = 'Approved'
          AND From_Date__c <= TODAY
          AND To_Date__c >= TODAY
      ];
      Integer attendingToday = totalActive - approvedLeaves;
      data.attendanceRate = totalActive > 0
        ? (attendingToday * 100 / totalActive)
        : 0;
      Integer attendanceYesterday = totalActive > 0
        ? ((totalActive -
          [
            SELECT COUNT()
            FROM Leave__c
            WHERE
              Status__c = 'Approved'
              AND From_Date__c <= YESTERDAY
              AND To_Date__c >= YESTERDAY
          ]) *
          100 /
          totalActive)
        : 0;
      data.attendanceTrend = calculateTrendPercentage(
        data.attendanceRate,
        attendanceYesterday
      );

      // Active Employees (Employees currently not on leave)
      data.activeEmployees = attendingToday;
      data.activeTrend = calculateTrendPercentage(
        attendingToday,
        (totalActive -
        [
          SELECT COUNT()
          FROM Leave__c
          WHERE
            Status__c = 'Approved'
            AND From_Date__c <= YESTERDAY
            AND To_Date__c >= YESTERDAY
        ])
      );
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching admin stats.');
    }

    return data;
  }

  private static String calculateTrendPercentage(
    Integer current,
    Integer previous
  ) {
    if (previous == 0) {
      return (current > 0) ? '+100%' : '0%';
    }
    Decimal change = ((Decimal) (current - previous) / previous) * 100;
    return (change >= 0 ? '+' : '') + change.setScale(1) + '%';
  }

  /**
   * @description Employee status summary derived from Portal_Users__c.
   * @note The underlying Portal_Users__c schema in this repo does not have explicit Fulltime/Contract/WFH flags,
   *       so this uses available fields to provide a consistent breakdown:
   *       - total: active portal users
   *       - probation: active users where Is_New__c = true
   *       - fulltime: active users with Role__c = 'Employee' and not new
   *       - contract: active users with Role__c = 'Manager'
   *       - wfh: remainder (active - fulltime - probation - contract)
   */
  @AuraEnabled(cacheable=true)
  public static EmployeeStatusOverview getEmployeeStatusOverview(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getEmployeeStatusOverviewCore();
  }

  private static EmployeeStatusOverview getEmployeeStatusOverviewCore() {
    try {
      Integer totalActive = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
      ];

      Integer probation = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE AND Is_New__c = TRUE
      ];

      Integer fulltime = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE
          Is_Active__c = TRUE
          AND Role__c = :PWChrono_Constants.ROLE_EMPLOYEE
          AND (Is_New__c = FALSE
          OR Is_New__c = NULL)
      ];

      Integer contract = [
        SELECT COUNT()
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE AND Role__c = :PWChrono_Constants.ROLE_MANAGER
      ];

      Integer wfh = totalActive - fulltime - probation - contract;
      if (wfh < 0) {
        wfh = 0;
      }

      EmployeeStatusOverview res = new EmployeeStatusOverview();
      res.total = totalActive;
      res.fulltime = fulltime;
      res.contract = contract;
      res.probation = probation;
      res.wfh = wfh;
      return res;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException(
        'Error fetching employee status overview.'
      );
    }
  }

  /**
   * @description Attendance overview derived from PWChrono_Attendance_Request__c.
   * @note The available schema provides Status__c only; we map statuses to the dashboard buckets:
   *       - Approved => Present
   *       - Submitted => Late
   *       - Draft => Permission
   *       - Rejected => Absent
   */
  @AuraEnabled(cacheable=true)
  public static AttendanceOverview getAttendanceOverview(
    Date forDate,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getAttendanceOverviewCore(forDate);
  }

  private static AttendanceOverview getAttendanceOverviewCore(Date forDate) {
    Date target = (forDate == null) ? Date.today() : forDate;
    try {
      Map<String, Integer> counts = new Map<String, Integer>{
        PWChrono_Constants.STATUS_APPROVED => 0,
        PWChrono_Constants.STATUS_SUBMITTED => 0,
        PWChrono_Constants.STATUS_DRAFT => 0,
        PWChrono_Constants.STATUS_REJECTED => 0
      };

      for (AggregateResult ar : [
        SELECT Status__c st, COUNT(Id) cnt
        FROM PWChrono_Attendance_Request__c
        WHERE Attendance_Date__c = :target
        GROUP BY Status__c
      ]) {
        String st = (String) ar.get('st');
        Integer cnt = (Integer) ar.get('cnt');
        if (st == null) {
          continue;
        }
        counts.put(
          st,
          (counts.containsKey(st) ? counts.get(st) : 0) +
          (cnt == null ? 0 : cnt)
        );
      }

      AttendanceOverview res = new AttendanceOverview();
      res.day = target;
      res.present = counts.get(PWChrono_Constants.STATUS_APPROVED);
      res.late = counts.get(PWChrono_Constants.STATUS_SUBMITTED);
      res.permission = counts.get(PWChrono_Constants.STATUS_DRAFT);
      res.absent = counts.get(PWChrono_Constants.STATUS_REJECTED);
      res.total = (res.present + res.late + res.permission + res.absent);

      // If no data for target date, find the most recent date with attendance data
      if (res.total == 0) {
        List<AggregateResult> mostRecent = [
          SELECT Attendance_Date__c latestDate
          FROM PWChrono_Attendance_Request__c
          WHERE Attendance_Date__c < :target
          GROUP BY Attendance_Date__c
          ORDER BY Attendance_Date__c DESC
          LIMIT 1
        ];

        if (!mostRecent.isEmpty()) {
          Date fallbackDate = (Date) mostRecent[0].get('latestDate');

          for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) cnt
            FROM PWChrono_Attendance_Request__c
            WHERE Attendance_Date__c = :fallbackDate
            GROUP BY Status__c
          ]) {
            String st = (String) ar.get('st');
            Integer cnt = (Integer) ar.get('cnt');
            if (st == null) {
              continue;
            }
            counts.put(
              st,
              (counts.containsKey(st) ? counts.get(st) : 0) +
              (cnt == null ? 0 : cnt)
            );
          }

          res.day = fallbackDate;
          res.present = counts.get(PWChrono_Constants.STATUS_APPROVED);
          res.late = counts.get(PWChrono_Constants.STATUS_SUBMITTED);
          res.permission = counts.get(PWChrono_Constants.STATUS_DRAFT);
          res.absent = counts.get(PWChrono_Constants.STATUS_REJECTED);
          res.total = (res.present + res.late + res.permission + res.absent);
        }
      }

      return res;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching attendance overview.');
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Attendance_Request__c> getRecentAttendanceRequests(
    String portalUserId,
    String sessionToken,
    Integer limitSize
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getRecentAttendanceRequestsCore(limitSize);
  }

  private static List<PWChrono_Attendance_Request__c> getRecentAttendanceRequestsCore(
    Integer limitSize
  ) {
    Integer size = (limitSize == null || limitSize < 1) ? 5 : limitSize;
    size = Math.min(size, 50);

    try {
      return [
        SELECT
          Id,
          Name,
          Status__c,
          Attendance_Date__c,
          From_Time__c,
          To_Time__c,
          Employee__r.Name,
          Employee__r.Designation__c,
          Employee__r.Department__c,
          Employee__r.Photo_Url__c,
          CreatedDate
        FROM PWChrono_Attendance_Request__c
        ORDER BY CreatedDate DESC
        LIMIT :size
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException(
        'Error fetching recent attendance requests.'
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<TimelineItem> getAdminTimeline(Integer limitSize) {
    Integer size = (limitSize == null || limitSize < 1) ? 8 : limitSize;
    size = Math.min(size, 50);

    List<TimelineItem> items = new List<TimelineItem>();

    try {
      List<PWChrono_Attendance_Request__c> attendance = [
        SELECT
          Id,
          Name,
          Status__c,
          Attendance_Date__c,
          From_Time__c,
          To_Time__c,
          Employee__r.Name,
          CreatedDate
        FROM PWChrono_Attendance_Request__c
        ORDER BY CreatedDate DESC
        LIMIT :size
      ];

      for (PWChrono_Attendance_Request__c a : attendance) {
        TimelineItem item = new TimelineItem();
        item.id = a.Id;
        item.category = 'Attendance';
        item.status = a.Status__c;
        item.timestamp = a.CreatedDate;

        String empName = (a.Employee__r == null)
          ? 'Employee'
          : a.Employee__r.Name;
        item.title = empName + ' attendance request';

        String datePart = (a.Attendance_Date__c == null)
          ? ''
          : String.valueOf(a.Attendance_Date__c);
        item.detail = datePart;
        items.add(item);
      }

      List<Leave__c> leaves = [
        SELECT
          Id,
          Name,
          Status__c,
          From_Date__c,
          To_Date__c,
          Employees__r.Name,
          Leave_Type__r.Name,
          CreatedDate
        FROM Leave__c
        ORDER BY CreatedDate DESC
        LIMIT :size
      ];

      for (Leave__c l : leaves) {
        TimelineItem item = new TimelineItem();
        item.id = l.Id;
        item.category = 'Leave';
        item.status = l.Status__c;
        item.timestamp = l.CreatedDate;

        String empName = (l.Employees__r == null)
          ? 'Employee'
          : l.Employees__r.Name;
        String leaveType = (l.Leave_Type__r == null)
          ? 'Leave'
          : l.Leave_Type__r.Name;
        item.title = empName + ' ' + leaveType;

        String rangePart = '';
        if (l.From_Date__c != null) {
          rangePart += String.valueOf(l.From_Date__c);
        }
        if (l.To_Date__c != null) {
          rangePart +=
            (rangePart == '' ? '' : ' → ') + String.valueOf(l.To_Date__c);
        }
        item.detail = rangePart;
        items.add(item);
      }

      items.sort();
      if (items.size() > size) {
        List<TimelineItem> trimmed = new List<TimelineItem>();
        for (Integer i = 0; i < size; i++) {
          trimmed.add(items[i]);
        }
        items = trimmed;
      }
      return items;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching admin timeline.');
    }
  }

  /**
   * @description Get Feature Settings (Org Default)
   * @return PWChrono_Feature_Settings__c record
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Feature_Settings__c getFeatureSettings(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getFeatureSettingsCore();
  }

  private static PWChrono_Feature_Settings__c getFeatureSettingsCore() {
    return PWChrono_Feature_Settings__c.getOrgDefaults();
  }

  /**
   * @description Save Feature Settings
   * @param settings The settings record to save
   * @return Updated settings
   */
  @AuraEnabled
  public static PWChrono_Feature_Settings__c saveFeatureSettings(
    PWChrono_Feature_Settings__c settings,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return saveFeatureSettingsCore(settings);
  }

  private static PWChrono_Feature_Settings__c saveFeatureSettingsCore(
    PWChrono_Feature_Settings__c settings
  ) {
    try {
      upsert settings;
      return settings;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error saving feature settings.'
      );
      ahe.setMessage('Error saving feature settings.');
      throw ahe;
    }
  }

  /**
   * @description Get Global Settings (Custom Metadata)
   * @return PWChrono_Settings__mdt record
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Settings__mdt getGlobalSettings(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getGlobalSettingsCore();
  }

  private static PWChrono_Settings__mdt getGlobalSettingsCore() {
    try {
      // Fetch the first record found, assuming single configuration record
      List<PWChrono_Settings__mdt> settings = [
        SELECT
          Id,
          DeveloperName,
          MasterLabel,
          Currency_Code__c,
          Default_Grace_Period_Minutes__c,
          Leave_Year_Start_Month__c,
          Max_Consecutive_Leave_Days__c,
          Probation_Period_Days__c,
          Standard_Working_Hours__c,
          Time_Zone__c,
          Weekend_Day_1__c,
          Weekend_Day_2__c,
          Working_Days_Per_Week__c
        FROM PWChrono_Settings__mdt
        LIMIT 1
      ];
      return settings.isEmpty() ? null : settings[0];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching global settings.'
      );
      ahe.setMessage('Error fetching global settings.');
      throw ahe;
    }
  }

  /**
   * @description Update Global Settings (Custom Metadata)
   * Note: This enqueues a deployment. The UI will not update immediately.
   * @param metadataName DeveloperName of the record
   * @param label MasterLabel
   * @param fieldData Map of field API names to values
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void updateGlobalSettings(
    String metadataName,
    String label,
    Map<String, Object> fieldData,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    updateGlobalSettingsCore(metadataName, label, fieldData);
  }

  private static void updateGlobalSettingsCore(
    String metadataName,
    String label,
    Map<String, Object> fieldData
  ) {
    try {
      Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
      customMetadata.fullName = 'PWChrono_Settings__mdt.' + metadataName;
      customMetadata.label = label;

      for (String fieldName : fieldData.keySet()) {
        Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
        customField.field = fieldName;
        customField.value = fieldData.get(fieldName);
        customMetadata.values.add(customField);
      }

      Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
      mdContainer.addMetadata(customMetadata);

      // Enqueue deployment
      // Note: In a real scenario, we might want a callback, but for LWC simple save we'll fire and forget
      // or return a job ID. For simplicity here, we just enqueue.
      if (!Test.isRunningTest()) {
        Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
      }
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error updating global settings.'
      );
      ahe.setMessage('Error updating global settings.');
      throw ahe;
    }
  }

  /**
   * @description Search for Portal Users
   * @param searchTerm Name or Email to search for
   * @return List of Portal Users
   */
  @AuraEnabled(cacheable=false)
  public static List<Portal_Users__c> searchPortalUsers(
    String searchTerm,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return searchPortalUsersCore(searchTerm);
  }

  private static List<Portal_Users__c> searchPortalUsersCore(
    String searchTerm
  ) {
    String key = '%' + String.escapeSingleQuotes(searchTerm) + '%';
    // Note: Leading wildcard in LIKE causes non-selective query
    // This is acceptable for admin search with LIMIT 20
    return [
      SELECT Id, Name, Email__c, Role__c, Access_Features__c, User__r.Name
      FROM Portal_Users__c
      WHERE Name LIKE :key OR Email__c LIKE :key OR User__r.Name LIKE :key
      LIMIT 20
    ];
  }

  /**
   * @description Update Portal User Access
   * @param portalUserId Id of the Portal User record
   * @param role New Role
   * @param features List of features to enable
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void updatePortalUserAccess(
    Id portalUserId,
    String role,
    List<String> features,
    String callerPortalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(callerPortalUserId, sessionToken);
    updatePortalUserAccessCore(portalUserId, role, features);
  }

  private static void updatePortalUserAccessCore(
    Id portalUserId,
    String role,
    List<String> features
  ) {
    try {
      Portal_Users__c user = new Portal_Users__c(Id = portalUserId);
      user.Role__c = role;
      if (features != null && !features.isEmpty()) {
        user.Access_Features__c = String.join(features, ';');
      } else {
        user.Access_Features__c = null;
      }
      update user;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error updating user access.'
      );
      ahe.setMessage('Error updating user access.');
      throw ahe;
    }
  }

  /**
   * @description Get Job Applicants for Dashboard
   * @return List of Job Applicants
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Applicant__c> getJobApplicants(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getJobApplicantsCore();
  }

  private static List<PWChrono_Job_Applicant__c> getJobApplicantsCore() {
    try {
      return [
        SELECT
          Id,
          Name,
          Experience_Years__c,
          Status__c,
          Job_Opening__r.Designation__r.Name
        FROM PWChrono_Job_Applicant__c
        ORDER BY CreatedDate DESC
        LIMIT 5
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching job applicants.');
    }
  }

  /**
   * @description Get Employees for Dashboard
   * @return List of Portal Users
   */
  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getEmployees() {
    requireSalesforceInternalUser();
    return getEmployeesCore(5, 0);
  }

  /**
   * @description Parameterized employees getter for widgets.
   * @note Kept separate from getEmployees() so existing @wire(getEmployees) usages won't break.
   */
  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getEmployeesPaged(
    Integer limitSize,
    Integer offsetSize
  ) {
    requireSalesforceInternalUser();
    Integer safeLimit = (limitSize == null || limitSize <= 0) ? 5 : limitSize;
    if (safeLimit > 200) {
      safeLimit = 200;
    }
    Integer safeOffset = (offsetSize == null ||
      offsetSize < 0)
      ? 0
      : offsetSize;
    return getEmployeesCore(safeLimit, safeOffset);
  }

  private static List<Portal_Users__c> getEmployeesCore(
    Integer limitSize,
    Integer offsetSize
  ) {
    try {
      return [
        SELECT Id, Name, Designation__c, Department__c, Photo_Url__c
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT :limitSize
        OFFSET :offsetSize
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching employees.');
    }
  }

  /**
   * @description Get Todo Tasks for Dashboard
   * @return List of Onboarding Tasks
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Onboarding_Task__c> getTodoTasks(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getTodoTasksCore(6, 0);
  }

  /**
   * @description Parameterized todo tasks getter for widgets.
   */
  @AuraEnabled(cacheable=true)
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static List<PWChrono_Onboarding_Task__c> getTodoTasksPaged(
    String portalUserId,
    String sessionToken,
    Integer limitSize,
    Integer offsetSize
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    Integer safeLimit = (limitSize == null || limitSize <= 0) ? 6 : limitSize;
    if (safeLimit > 200) {
      safeLimit = 200;
    }
    Integer safeOffset = (offsetSize == null ||
      offsetSize < 0)
      ? 0
      : offsetSize;
    return getTodoTasksCore(safeLimit, safeOffset);
  }

  private static List<PWChrono_Onboarding_Task__c> getTodoTasksCore(
    Integer limitSize,
    Integer offsetSize
  ) {
    try {
      return [
        SELECT Id, Name, Status__c, Description__c
        FROM PWChrono_Onboarding_Task__c
        ORDER BY CreatedDate DESC
        LIMIT :limitSize
        OFFSET :offsetSize
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching todo tasks.');
    }
  }

  /**
   * @description Get Schedules from Event objects
   * @return List of Events
   */
  @AuraEnabled(cacheable=true)
  public static List<Event> getSchedules(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getSchedulesCore(10, 0);
  }

  /**
   * @description Parameterized schedules getter for widgets.
   */
  @AuraEnabled(cacheable=true)
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static List<Event> getSchedulesPaged(
    String portalUserId,
    String sessionToken,
    Integer limitSize,
    Integer offsetSize
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    Integer safeLimit = (limitSize == null || limitSize <= 0) ? 10 : limitSize;
    if (safeLimit > 200) {
      safeLimit = 200;
    }
    Integer safeOffset = (offsetSize == null ||
      offsetSize < 0)
      ? 0
      : offsetSize;
    return getSchedulesCore(safeLimit, safeOffset);
  }

  private static List<Event> getSchedulesCore(
    Integer limitSize,
    Integer offsetSize
  ) {
    try {
      return [
        SELECT Id, Subject, StartDateTime, EndDateTime, Description, Location
        FROM Event
        WHERE StartDateTime >= TODAY
        ORDER BY StartDateTime ASC
        LIMIT :limitSize
        OFFSET :offsetSize
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching schedules.');
    }
  }

  /**
   * @description Get Recent Activities across multiple objects
   * @return List of TimelineItem wrapper objects
   */
  @AuraEnabled(cacheable=true)
  public static List<TimelineItem> getRecentActivities(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getRecentActivitiesCore();
  }

  private static List<TimelineItem> getRecentActivitiesCore() {
    List<TimelineItem> activities = new List<TimelineItem>();

    try {
      // Get recent attendance requests
      for (PWChrono_Attendance_Request__c att : [
        SELECT Id, Name, Status__c, CreatedDate, CreatedBy.Name
        FROM PWChrono_Attendance_Request__c
        ORDER BY CreatedDate DESC
        LIMIT 3
      ]) {
        TimelineItem item = new TimelineItem();
        item.id = att.Id;
        item.category = 'Attendance';
        item.title = att.CreatedBy.Name;
        item.detail = 'Submitted Attendance Request';
        item.status = att.Status__c;
        item.timestamp = att.CreatedDate;
        activities.add(item);
      }

      // Get recent leave requests
      for (Leave__c leave : [
        SELECT Id, Name, Status__c, CreatedDate, CreatedBy.Name
        FROM Leave__c
        ORDER BY CreatedDate DESC
        LIMIT 3
      ]) {
        TimelineItem item = new TimelineItem();
        item.id = leave.Id;
        item.category = 'Leave';
        item.title = leave.CreatedBy.Name;
        item.detail = 'Requested Leave';
        item.status = leave.Status__c;
        item.timestamp = leave.CreatedDate;
        activities.add(item);
      }

      // Sort all activities by timestamp descending
      activities.sort();

      // Return top 8 activities
      List<TimelineItem> topActivities = new List<TimelineItem>();
      for (Integer i = 0; i < Math.min(8, activities.size()); i++) {
        topActivities.add(activities[i]);
      }

      return topActivities;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching recent activities.');
    }
  }

  /**
   * @description Get Birthdays from Contacts linked to Portal Users
   * @return List of Contacts with upcoming birthdays
   */
  @AuraEnabled(cacheable=true)
  public static List<Contact> getBirthdays() {
    try {
      Date today = Date.today();
      Integer currentMonth = today.month();
      Integer currentDay = today.day();

      return [
        SELECT Id, Name, Birthdate, Title
        FROM Contact
        WHERE
          Id IN (
            SELECT Contact__c
            FROM Portal_Users__c
            WHERE Contact__c != NULL
          )
          AND Birthdate != NULL
        ORDER BY Birthdate ASC
        LIMIT 10
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching birthdays.');
    }
  }

  /**
   * @description Get Projects (PWChrono_Project__c) for Dashboard
   * @return List of PWChrono_Project__c
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Project__c> getProjects(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getProjectsCore();
  }

  private static List<PWChrono_Project__c> getProjectsCore() {
    try {
      return [
        SELECT
          Id,
          Name,
          Account__c,
          Account__r.Name,
          Status__c,
          Priority__c,
          Start_Date__c,
          End_Date__c,
          Description__c,
          Amount__c,
          Team_Size__c,
          Hours_Logged__c,
          Total_Hours__c,
          Project_Logo_ContentVersion_Id__c,
          Project_Members__c,
          Project_Leader__c,
          Project_Manager_Name__c,
          Project_Tags__c,
          CreatedBy.Name
        FROM PWChrono_Project__c
        ORDER BY CreatedDate DESC
        LIMIT 20
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching projects.');
    }
  }

  /**
   * @description Get Accounts used as Clients for Projects
   * @return List of Account (Id, Name)
   */
  @AuraEnabled(cacheable=true)
  public static List<Account> getProjectClients(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    try {
      return [
        SELECT Id, Name
        FROM Account
        WHERE Name != NULL
        ORDER BY Name
        LIMIT 200
      ];
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error fetching clients: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Get Invoices for Dashboard
   * @return List of Invoices
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Invoice__c> getInvoices() {
    try {
      return [
        SELECT
          Id,
          Name,
          Description__c,
          Account__r.Name,
          Amount__c,
          Status__c,
          Invoice_Date__c
        FROM PWChrono_Invoice__c
        ORDER BY Invoice_Date__c DESC
        LIMIT 5
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching invoices.');
    }
  }

  /**
   * @description Get Recent Leave Requests
   * @return List of Leave Requests
   */
  @AuraEnabled(cacheable=true)
  public static List<Leave__c> getLeaveRequests() {
    try {
      return [
        SELECT
          Id,
          Name,
          Employees__r.Name,
          Leave_Type__r.Name,
          From_Date__c,
          To_Date__c,
          Status__c,
          Total_Days__c
        FROM Leave__c
        WHERE Status__c IN ('Submitted', 'Draft')
        ORDER BY CreatedDate DESC
        LIMIT 8
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching leave requests.');
    }
  }

  /**
   * @description Get Upcoming Events
   * @return List of generic Events
   */
  @AuraEnabled(cacheable=true)
  public static List<Event> getHolidays() {
    try {
      return [
        SELECT Id, Subject, StartDateTime, EndDateTime, Description, Type
        FROM Event
        WHERE StartDateTime >= TODAY
        ORDER BY StartDateTime ASC
        LIMIT 6
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching holidays.');
    }
  }

  /**
   * @description Get Recent Hires (New Employees)
   * @return List of recently created Portal Users
   */
  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getRecentHires(
    String portalUserId,
    String sessionToken,
    Integer limitSize
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getRecentHiresCore(limitSize);
  }

  private static List<Portal_Users__c> getRecentHiresCore(Integer limitSize) {
    Integer size = (limitSize == null || limitSize < 1) ? 5 : limitSize;
    size = Math.min(size, 50);

    try {
      return [
        SELECT
          Id,
          Name,
          Email__c,
          Designation__c,
          Department__c,
          Photo_Url__c,
          CreatedDate
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY CreatedDate DESC
        LIMIT :size
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching recent hires.');
    }
  }

  /**
   * @description Get Payroll Summary
   * @return Payroll stats wrapper
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getPayrollSummary() {
    try {
      Date thisMonth = Date.today().toStartOfMonth();

      AggregateResult[] results = [
        SELECT
          COUNT(Id) totalSlips,
          SUM(Net_Pay__c) totalPayout,
          AVG(Net_Pay__c) avgSalary
        FROM PWChrono_Salary_Slip__c
        WHERE Payroll_Period__c >= :thisMonth
      ];

      Map<String, Object> summary = new Map<String, Object>();
      if (!results.isEmpty()) {
        summary.put(
          'totalSlips',
          results[0].get('totalSlips') != null
            ? (Integer) results[0].get('totalSlips')
            : 0
        );
        summary.put(
          'totalPayout',
          results[0].get('totalPayout') != null
            ? (Decimal) results[0].get('totalPayout')
            : 0
        );
        summary.put(
          'avgSalary',
          results[0].get('avgSalary') != null
            ? (Decimal) results[0].get('avgSalary')
            : 0
        );
      } else {
        summary.put('totalSlips', 0);
        summary.put('totalPayout', 0);
        summary.put('avgSalary', 0);
      }

      return summary;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching payroll summary.');
    }
  }

  /**
   * @description Employees by department chart data.
   * @return List of { label, value } points, sorted by count desc.
   */
  @AuraEnabled(cacheable=true)
  public static List<ChartPoint> getEmployeesByDepartment(
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getEmployeesByDepartmentCore();
  }

  private static List<ChartPoint> getEmployeesByDepartmentCore() {
    try {
      List<ChartPoint> out = new List<ChartPoint>();

      for (AggregateResult ar : [
        SELECT Department__c dept, COUNT(Id) cnt
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        GROUP BY Department__c
        ORDER BY COUNT(Id) DESC
        LIMIT 10
      ]) {
        String dept = (String) ar.get('dept');
        Integer cnt = (Integer) ar.get('cnt');
        out.add(
          new ChartPoint(
            (dept == null ? 'Unassigned' : dept),
            (cnt == null ? 0 : cnt)
          )
        );
      }

      return out;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching employees by department.');
    }
  }

  /**
   * @description Monthly sales overview chart data (sum of Opportunity Amount by month).
   * @param year Optional calendar year (defaults to current year).
   * @return 12 points (Jan..Dec) with values in $k.
   */
  @AuraEnabled(cacheable=true)
  public static List<ChartPoint> getSalesOverview(
    Integer year,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return getSalesOverviewCore(year);
  }

  private static List<ChartPoint> getSalesOverviewCore(Integer year) {
    Integer y = (year == null) ? Date.today().year() : year;
    Date startDate = Date.newInstance(y, 1, 1);
    Date endDate = Date.newInstance(y, 12, 31);

    try {
      Map<Integer, Decimal> monthToAmount = new Map<Integer, Decimal>();
      for (AggregateResult ar : [
        SELECT CALENDAR_MONTH(End_Date__c) m, SUM(Amount__c) amt
        FROM PWChrono_Project__c
        WHERE
          End_Date__c >= :startDate
          AND End_Date__c <= :endDate
          AND Amount__c != NULL
          AND Status__c != 'Inactive'
        GROUP BY CALENDAR_MONTH(End_Date__c)
      ]) {
        Integer m = (Integer) ar.get('m');
        Decimal amt = (Decimal) ar.get('amt');
        if (m == null) {
          continue;
        }
        monthToAmount.put(m, (amt == null ? 0 : amt));
      }

      List<String> labels = new List<String>{
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      };

      List<ChartPoint> points = new List<ChartPoint>();
      for (Integer i = 1; i <= 12; i++) {
        Decimal total = monthToAmount.containsKey(i) ? monthToAmount.get(i) : 0;
        Integer asK = (total == null)
          ? 0
          : Integer.valueOf(Math.round(total / 1000));
        points.add(new ChartPoint(labels[i - 1], asK));
      }
      return points;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching sales overview.');
    }
  }

  /**
   * @description Get Task Statistics for Dashboard Chart
   * @return List of ChartPoint (Status -> Count)
   */
  @AuraEnabled(cacheable=true)
  public static List<ChartPoint> getTaskStatistics() {
    try {
      List<ChartPoint> stats = new List<ChartPoint>();
      Map<String, Integer> counts = new Map<String, Integer>();

      for (AggregateResult ar : [
        SELECT Status__c st, COUNT(Id) cnt
        FROM PWChrono_Onboarding_Task__c
        GROUP BY Status__c
      ]) {
        String st = (String) ar.get('st');
        Integer cnt = (Integer) ar.get('cnt');
        if (st != null) {
          counts.put(st, cnt == null ? 0 : cnt);
        }
      }

      for (String key : counts.keySet()) {
        stats.add(new ChartPoint(key, counts.get(key)));
      }

      return stats;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new AuraHandledException('Error fetching task statistics.');
    }
  }

  /**
   * @description Save Project (PWChrono_Project__c)
   * @param projectData Map of field values
   * @return Id of the saved project
   */
  @AuraEnabled
  public static Id saveProject(
    Map<String, Object> projectData,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    return saveProjectCore(projectData);
  }

  @SuppressWarnings('PMD.NcssMethodCount')
  private static Id saveProjectCore(Map<String, Object> projectData) {
    try {
      PWChrono_Project__c proj = new PWChrono_Project__c();

      if (projectData.containsKey('Id')) {
        proj.Id = (Id) projectData.get('Id');
      }

      if (projectData.containsKey('Name')) {
        proj.Name = (String) projectData.get('Name');
      }

      if (projectData.containsKey('Account__c')) {
        Object acct = projectData.get('Account__c');
        proj.Account__c = (acct == null ||
          String.valueOf(acct).trim() == '')
          ? null
          : Id.valueOf(String.valueOf(acct));
      }

      if (projectData.containsKey('Status__c')) {
        proj.Status__c = (String) projectData.get('Status__c');
      } else if (proj.Id == null) {
        proj.Status__c = 'Active'; // Default
      }

      if (projectData.containsKey('Priority__c')) {
        proj.Priority__c = (String) projectData.get('Priority__c');
      }

      if (projectData.containsKey('End_Date__c')) {
        String dateStr = (String) projectData.get('End_Date__c');
        if (dateStr != null) {
          proj.End_Date__c = Date.valueOf(dateStr);
        }
      }

      if (projectData.containsKey('Start_Date__c')) {
        String dateStr = (String) projectData.get('Start_Date__c');
        if (dateStr != null) {
          proj.Start_Date__c = Date.valueOf(dateStr);
        }
      }

      if (projectData.containsKey('Description__c')) {
        proj.Description__c = (String) projectData.get('Description__c');
      }

      if (projectData.containsKey('Amount__c')) {
        Object amt = projectData.get('Amount__c');
        if (amt != null) {
          proj.Amount__c = Decimal.valueOf(String.valueOf(amt));
        }
      }

      if (projectData.containsKey('Total_Hours__c')) {
        Object total = projectData.get('Total_Hours__c');
        if (total != null && String.valueOf(total).trim() != '') {
          proj.Total_Hours__c = Decimal.valueOf(String.valueOf(total));
        }
      }

      if (projectData.containsKey('Team_Size__c')) {
        Object teamSize = projectData.get('Team_Size__c');
        if (teamSize != null && String.valueOf(teamSize).trim() != '') {
          proj.Team_Size__c = Decimal.valueOf(String.valueOf(teamSize));
        }
      }

      if (projectData.containsKey('Hours_Logged__c')) {
        Object hrs = projectData.get('Hours_Logged__c');
        if (hrs != null && String.valueOf(hrs).trim() != '') {
          proj.Hours_Logged__c = Decimal.valueOf(String.valueOf(hrs));
        }
      }

      // SmartHR parity fields
      // NOTE: We accept both the newer API names (Project_*) and the older keys that
      // were used in earlier iterations (Team_Leader__c, etc.), but we only write to
      // the new fields to avoid compile/runtime issues in orgs where the old fields
      // were deleted.
      String membersVal = (String) (projectData.containsKey(
          'Project_Members__c'
        )
        ? projectData.get('Project_Members__c')
        : projectData.get('Team_Members__c'));
      if (membersVal != null) {
        proj.Project_Members__c = membersVal;
      }

      String leaderVal = (String) (projectData.containsKey('Project_Leader__c')
        ? projectData.get('Project_Leader__c')
        : projectData.get('Team_Leader__c'));
      if (leaderVal != null) {
        proj.Project_Leader__c = leaderVal;
      }

      String pmVal = (String) (projectData.containsKey(
          'Project_Manager_Name__c'
        )
        ? projectData.get('Project_Manager_Name__c')
        : projectData.get('Project_Manager__c'));
      if (pmVal != null) {
        proj.Project_Manager_Name__c = pmVal;
      }

      String tagsVal = (String) (projectData.containsKey('Project_Tags__c')
        ? projectData.get('Project_Tags__c')
        : projectData.get('Tags__c'));
      if (tagsVal != null) {
        proj.Project_Tags__c = tagsVal;
      }

      String logoVal = (String) (projectData.containsKey(
          'Project_Logo_ContentVersion_Id__c'
        )
        ? projectData.get('Project_Logo_ContentVersion_Id__c')
        : projectData.get('Logo_ContentVersion_Id__c'));
      if (logoVal != null) {
        proj.Project_Logo_ContentVersion_Id__c = logoVal;
      }

      upsert proj;
      return proj.Id;
    } catch (Exception e) {
      throw new AuraHandledException('Error saving project: ' + e.getMessage());
    }
  }

  /**
   * @description Upload a logo file for a project and link it as a Salesforce File.
   * @return The created ContentVersion Id
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static Id uploadProjectLogo(
    Id projectId,
    String fileName,
    String base64Data,
    String contentType,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    if (projectId == null) {
      throw new AuraHandledException('Project Id is required.');
    }
    if (String.isBlank(fileName) || String.isBlank(base64Data)) {
      throw new AuraHandledException('File name and data are required.');
    }

    try {
      // Ensure project exists (and caller can at least see it).
      PWChrono_Project__c proj = [
        SELECT Id
        FROM PWChrono_Project__c
        WHERE Id = :projectId
        LIMIT 1
      ];

      ContentVersion cv = new ContentVersion();
      cv.Title = fileName;
      cv.PathOnClient = '/' + fileName;
      cv.VersionData = EncodingUtil.base64Decode(base64Data);
      insert cv;

      cv = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
      ];

      ContentDocumentLink cdl = new ContentDocumentLink(
        ContentDocumentId = cv.ContentDocumentId,
        LinkedEntityId = proj.Id,
        ShareType = 'V',
        Visibility = 'AllUsers'
      );
      insert cdl;

      // Store latest uploaded logo version id for easy rendering.
      update new PWChrono_Project__c(
        Id = proj.Id,
        Project_Logo_ContentVersion_Id__c = (String) cv.Id
      );

      return cv.Id;
    } catch (Exception e) {
      throw new AuraHandledException('Error uploading logo: ' + e.getMessage());
    }
  }

  /**
   * @description Delete Project (PWChrono_Project__c)
   * @param projectId Id of the project to delete
   */
  @AuraEnabled
  public static void deleteProject(
    Id projectId,
    String portalUserId,
    String sessionToken
  ) {
    requireAdminSettingsAccessForGuest(portalUserId, sessionToken);
    deleteProjectCore(projectId);
  }

  private static void deleteProjectCore(Id projectId) {
    try {
      delete [SELECT Id FROM PWChrono_Project__c WHERE Id = :projectId];
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error deleting project: ' + e.getMessage()
      );
    }
  }
}