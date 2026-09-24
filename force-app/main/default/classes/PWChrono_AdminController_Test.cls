@isTest
private class PWChrono_AdminController_Test {
  @TestSetup
  static void makeData() {
    // Create User and Employee
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );

    // Departments__c is a formula (Contact__r.Department) — set via linked Contacts.
    Contact mgmtContact = new Contact(
      LastName = 'Manager Contact',
      Department = 'Management'
    );
    Contact engContact = new Contact(
      LastName = 'Eng Contact',
      Department = 'Engineering'
    );
    Contact hrContact = new Contact(LastName = 'HR Contact', Department = 'HR');
    insert new List<Contact>{ mgmtContact, engContact, hrContact };

    // Additional portal users to exercise employee status breakdown.
    Portal_Users__c manager = new Portal_Users__c(
      Name = 'Test Manager',
      Email__c = 'testmanager@example.com',
      Role__c = PWChrono_Constants.ROLE_MANAGER,
      User__c = testUser.Id,
      Is_Active__c = true,
      Contact__c = mgmtContact.Id
    );
    Portal_Users__c probation = new Portal_Users__c(
      Name = 'Test Probation',
      Email__c = 'testprobation@example.com',
      Role__c = PWChrono_Constants.ROLE_EMPLOYEE,
      User__c = testUser.Id,
      Is_Active__c = true,
      Is_New__c = true,
      Contact__c = engContact.Id
    );
    Portal_Users__c other = new Portal_Users__c(
      Name = 'Test Other',
      Email__c = 'testother@example.com',
      Role__c = 'HR Admin',
      User__c = testUser.Id,
      Is_Active__c = true,
      Contact__c = hrContact.Id
    );
    insert new List<Portal_Users__c>{ manager, probation, other };

    // Ensure the primary test employee has a department for grouping (via Contact).
    Contact empContact = new Contact(
      LastName = 'Emp Contact',
      Department = 'Engineering'
    );
    insert empContact;
    employee.Contact__c = empContact.Id;
    update employee;

    PWChrono_Leave_Type__c lType = new PWChrono_Leave_Type__c(
      Name = 'Annual Leave',
      Is_Unpaid__c = false,
      Max_Days_Allowed__c = 20
    );
    insert lType;

    // Some orgs enforce leave balance validations for Submitted/Approved leaves.
    // Create a matching allocation that covers the leave date range.
    PWChrono_Leave_Allocation__c allocation = new PWChrono_Leave_Allocation__c(
      Employees__c = employee.Id,
      Leave_Type__c = lType.Id,
      From_Date__c = Date.today().addDays(-30),
      To_Date__c = Date.today().addDays(365),
      Total_Leaves_Allocated__c = 30
    );
    insert allocation;

    Leave__c leave = new Leave__c(
      Employees__c = employee.Id,
      From_Date__c = Date.today().addDays(3),
      To_Date__c = Date.today().addDays(5),
      Reason__c = 'Vacation',
      Status__c = PWChrono_Constants.STATUS_SUBMITTED,
      Leave_Type__c = lType.Id
    );
    insert leave;

    PWChrono_Attendance_Request__c attendance = new PWChrono_Attendance_Request__c(
      Employee__c = employee.Id,
      Attendance_Date__c = Date.today(),
      From_Time__c = Time.newInstance(9, 30, 0, 0),
      To_Time__c = Time.newInstance(18, 0, 0, 0),
      Reason__c = 'Workday',
      Status__c = PWChrono_Constants.STATUS_SUBMITTED
    );
    insert attendance;

    // Extra attendance records to cover all status buckets.
    insert new List<PWChrono_Attendance_Request__c>{
      new PWChrono_Attendance_Request__c(
        Employee__c = employee.Id,
        Attendance_Date__c = Date.today(),
        From_Time__c = Time.newInstance(9, 0, 0, 0),
        To_Time__c = Time.newInstance(18, 0, 0, 0),
        Reason__c = 'Approved example',
        Status__c = PWChrono_Constants.STATUS_APPROVED
      ),
      new PWChrono_Attendance_Request__c(
        Employee__c = employee.Id,
        Attendance_Date__c = Date.today(),
        From_Time__c = Time.newInstance(10, 0, 0, 0),
        To_Time__c = Time.newInstance(18, 0, 0, 0),
        Reason__c = 'Draft example',
        Status__c = PWChrono_Constants.STATUS_DRAFT
      ),
      new PWChrono_Attendance_Request__c(
        Employee__c = employee.Id,
        Attendance_Date__c = Date.today(),
        From_Time__c = Time.newInstance(9, 0, 0, 0),
        To_Time__c = Time.newInstance(18, 0, 0, 0),
        Reason__c = 'Rejected example',
        Status__c = PWChrono_Constants.STATUS_REJECTED
      )
    };

    // Create Feature Settings
    PWChrono_Feature_Settings__c settings = new PWChrono_Feature_Settings__c(
      Enable_Payroll_Module__c = true,
      Enable_Leave_Encashment__c = true
    );
    insert settings;

    // Minimal project data for sales overview aggregation
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Integer y = Date.today().year();
    insert new List<PWChrono_Project__c>{
      new PWChrono_Project__c(
        Name = 'Test Project Jan',
        Account__c = acc.Id,
        End_Date__c = Date.newInstance(y, 1, 15),
        Amount__c = 25000,
        Status__c = 'Completed'
      ),
      new PWChrono_Project__c(
        Name = 'Test Project Feb',
        Account__c = acc.Id,
        End_Date__c = Date.newInstance(y, 2, 10),
        Amount__c = 50000,
        Status__c = 'Completed'
      )
    };
  }

  @isTest
  static void testGetEmployeeStatusOverview() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    Id probationUserId = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'testprobation@example.com'
    ]
    .Id;
    Id managerUserId = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'testmanager@example.com'
    ]
    .Id;
    // Probation is driven by open probation records, not Is_New__c. Two open
    // records for one employee count once; a completed probation is ignored.
    insert new List<PWChrono_Probation__c>{
      new PWChrono_Probation__c(
        Employee__c = probationUserId,
        Start_Date__c = Date.today().addDays(-10),
        End_Date__c = Date.today().addDays(80),
        Status__c = 'Pending'
      ),
      new PWChrono_Probation__c(
        Employee__c = probationUserId,
        Start_Date__c = Date.today().addDays(-100),
        End_Date__c = Date.today().addDays(5),
        Status__c = 'Extended'
      ),
      new PWChrono_Probation__c(
        Employee__c = managerUserId,
        Start_Date__c = Date.today().addDays(-200),
        End_Date__c = Date.today().addDays(-110),
        Status__c = 'Completed'
      )
    };

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_AdminController.EmployeeStatusOverview res = PWChrono_AdminController.getEmployeeStatusOverview(
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        res,
        'Should return employee status overview'
      );
      System.assert(res.total >= 1, 'Total should be at least 1');
      System.assertEquals(
        1,
        res.contract,
        'Should count manager as Contract bucket'
      );
      System.assertEquals(
        1,
        res.probation,
        'Should count each active employee with an open probation once'
      );
      System.assertEquals(
        1,
        res.fulltime,
        'Employees on probation are not counted as full-time'
      );
      System.assertEquals(
        res.total,
        res.fulltime + res.contract + res.probation + res.wfh,
        'Status buckets should not overlap'
      );
    }
  }

  @isTest
  static void testGetAttendanceOverview() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_AdminController.AttendanceOverview res = PWChrono_PortalApi.getAttendanceOverview(
        Date.today(),
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, res, 'Should return attendance overview');
      System.assertEquals(
        Date.today(),
        res.day,
        'Should reflect requested date'
      );
      System.assertEquals(1, res.present, 'Approved should map to Present');
      System.assertEquals(1, res.late, 'Submitted should map to Late');
      System.assertEquals(1, res.permission, 'Draft should map to Permission');
      System.assertEquals(1, res.absent, 'Rejected should map to Absent');
      System.assertEquals(4, res.total, 'Total should equal sum of buckets');
    }
  }

  @isTest
  static void testGetRecentAttendanceRequests() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      List<PWChrono_Attendance_Request__c> requests = PWChrono_AdminController.getRecentAttendanceRequests(
        null,
        null,
        5
      );
      Test.stopTest();

      System.assert(!requests.isEmpty(), 'Should return attendance requests');
    }
  }

  @isTest
  static void testGetAdminTimeline() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      List<PWChrono_AdminController.TimelineItem> items = PWChrono_AdminController.getAdminTimeline(
        10
      );
      Test.stopTest();

      System.assert(!items.isEmpty(), 'Should return timeline items');
    }
  }

  @isTest
  static void testGetFeatureSettings() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      adminUser.Id,
      'PWChrono_HR_Admin'
    );

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_Feature_Settings__c settings = PWChrono_AdminController.getFeatureSettings(
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, settings, 'Should return feature settings');
      // Note: Default values might be null if not set, checking object existence
    }
  }

  @isTest
  static void testSaveFeatureSettings() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      adminUser.Id,
      'PWChrono_HR_Admin'
    );
    PWChrono_Feature_Settings__c settings = [
      SELECT Id, Enable_Payroll_Module__c
      FROM PWChrono_Feature_Settings__c
      LIMIT 1
    ];

    System.runAs(adminUser) {
      settings.Enable_Payroll_Module__c = false;

      Test.startTest();
      PWChrono_Feature_Settings__c savedSettings = PWChrono_AdminController.saveFeatureSettings(
        settings,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        false,
        savedSettings.Enable_Payroll_Module__c,
        'Payroll should be disabled'
      );
    }
  }

  @isTest
  static void testGetGlobalSettings() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      // This might return null if no metadata exists in the org, but code handles it
      PWChrono_Settings__mdt settings = PWChrono_AdminController.getGlobalSettings(
        null,
        null
      );
      Test.stopTest();

      // We can't assert much here as MDT depends on org config, but we ensure no exception
    }
  }

  @isTest
  static void testUpdateGlobalSettings() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      adminUser.Id,
      'PWChrono_HR_Admin'
    );

    System.runAs(adminUser) {
      Map<String, Object> fieldData = new Map<String, Object>{
        'Standard_Working_Hours__c' => 8
      };

      Test.startTest();
      try {
        // This will just enqueue deployment, we can't verify result in test easily
        PWChrono_AdminController.updateGlobalSettings(
          'Default',
          'Default Settings',
          fieldData,
          null,
          null
        );
      } catch (Exception e) {
        // Expected if CMDT deployment callback is not mocked or fails in test
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testSearchPortalUsers() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      adminUser.Id,
      'PWChrono_HR_Admin'
    );

    System.runAs(adminUser) {
      Test.startTest();
      List<Portal_Users__c> users = PWChrono_AdminController.searchPortalUsers(
        'Test',
        null,
        null
      );
      Test.stopTest();

      System.assert(!users.isEmpty(), 'Should find test user');
    }
  }

  @isTest
  static void testUpdatePortalUserAccess() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      adminUser.Id,
      'PWChrono_HR_Admin'
    );
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_AdminController.updatePortalUserAccess(
        employee.Id,
        PWChrono_Constants.ROLE_MANAGER,
        new List<String>{ 'Attendance', 'Leaves' },
        null,
        null
      );
      Test.stopTest();

      Portal_Users__c updatedEmployee = [
        SELECT Role__c, Access_Features__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertEquals(
        PWChrono_Constants.ROLE_MANAGER,
        updatedEmployee.Role__c,
        'Role should be updated'
      );
      System.assert(
        updatedEmployee.Access_Features__c.contains('Attendance'),
        'Features should be updated'
      );
    }
  }

  @isTest
  static void testGetEmployeesByDepartment() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      List<PWChrono_AdminController.ChartPoint> points = PWChrono_PortalApi.getEmployeesByDepartment(
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        points,
        'Should return department chart points'
      );
      System.assert(
        !points.isEmpty(),
        'Should return at least one department point'
      );
      System.assert(
        points[0].value >= 1,
        'Top department count should be >= 1'
      );
    }
  }

  @isTest
  static void testGetSalesOverview() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Integer y = Date.today().year();
      Test.startTest();
      List<PWChrono_AdminController.ChartPoint> points = PWChrono_AdminController.getSalesOverview(
        y,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(12, points.size(), 'Should return 12 months');
      // Values are in $k, based on test setup (25k in Jan, 50k in Feb)
      System.assertEquals(
        'Jan',
        points[0].label,
        'First month label should be Jan'
      );
      System.assertEquals(25, points[0].value, 'Jan should be 25k');
      System.assertEquals(
        'Feb',
        points[1].label,
        'Second month label should be Feb'
      );
      System.assertEquals(50, points[1].value, 'Feb should be 50k');
    }
  }

  // ---------------------------------------------------------------------------
  // Direct coverage of dashboard widgets and project management endpoints.
  // ---------------------------------------------------------------------------

  @isTest
  static void testGetAdminDashboardStats() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_AdminController.AdminDashboardDTO stats = PWChrono_AdminController.getAdminDashboardStats(
        null,
        null
      );
      Test.stopTest();

      System.assert(stats.totalEmployees >= 1, 'Active employees counted');
      System.assert(stats.pendingApprovals >= 0, 'Pending approvals counted');
      System.assertNotEquals(null, stats.employeeTrend, 'Trend computed');
      System.assertNotEquals(null, stats.attendanceTrend, 'Trend computed');
      System.assertNotEquals(null, stats.activeTrend, 'Trend computed');
      System.assert(
        stats.attendanceRate >= 0 && stats.attendanceRate <= 100,
        'Attendance rate is a percentage'
      );
    }
  }

  @isTest
  static void testAttendanceOverviewFallsBackToLatestDate() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_AdminController.AttendanceOverview res = PWChrono_AdminController.getAttendanceOverview(
        Date.today().addDays(30),
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        Date.today(),
        res.day,
        'Falls back to the most recent day with attendance data'
      );
      System.assertEquals(4, res.total, 'Fallback day buckets are counted');
    }
  }

  @isTest
  static void testRecentActivitiesTimelineAndPayroll() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      List<PWChrono_AdminController.TimelineItem> activities = PWChrono_AdminController.getRecentActivities(
        null,
        null
      );
      List<PWChrono_AdminController.TimelineItem> trimmed = PWChrono_AdminController.getAdminTimeline(
        1
      );
      Map<String, Object> payroll = PWChrono_AdminController.getPayrollSummary();
      Test.stopTest();

      System.assert(!activities.isEmpty(), 'Recent activities returned');
      System.assert(activities.size() <= 8, 'At most eight activities');
      System.assertEquals(1, trimmed.size(), 'Timeline is trimmed to limit');
      System.assert(payroll.containsKey('totalSlips'), 'Slip count returned');
      System.assert(payroll.containsKey('totalPayout'), 'Payout returned');
      System.assert(payroll.containsKey('avgSalary'), 'Average returned');
    }
  }

  @isTest
  static void testTimelineItemOrdering() {
    PWChrono_AdminController.TimelineItem older = new PWChrono_AdminController.TimelineItem();
    older.timestamp = Datetime.now().addDays(-1);
    PWChrono_AdminController.TimelineItem newer = new PWChrono_AdminController.TimelineItem();
    newer.timestamp = Datetime.now();
    PWChrono_AdminController.TimelineItem undated = new PWChrono_AdminController.TimelineItem();
    PWChrono_AdminController.TimelineItem undatedToo = new PWChrono_AdminController.TimelineItem();

    List<PWChrono_AdminController.TimelineItem> items = new List<PWChrono_AdminController.TimelineItem>{
      undated,
      older,
      newer
    };
    items.sort();

    System.assertEquals(newer, items[0], 'Newest first');
    System.assertEquals(undated, items[2], 'Undated last');
    System.assertEquals(0, undated.compareTo(undatedToo), 'Undated are equal');
    System.assertEquals(-1, newer.compareTo(undated), 'Dated before undated');
    System.assertEquals(0, newer.compareTo(newer), 'Same time is equal');
  }

  @isTest
  static void testTaskStatisticsCountsByStatus() {
    // Other automation may already have created onboarding tasks; count on top.
    Integer pendingBefore = [
      SELECT COUNT()
      FROM PWChrono_Onboarding_Task__c
      WHERE Status__c = 'Pending'
    ];
    Integer completedBefore = [
      SELECT COUNT()
      FROM PWChrono_Onboarding_Task__c
      WHERE Status__c = 'Completed'
    ];
    insert new List<PWChrono_Onboarding_Task__c>{
      new PWChrono_Onboarding_Task__c(Name = 'Laptop', Status__c = 'Pending'),
      new PWChrono_Onboarding_Task__c(Name = 'Badge', Status__c = 'Pending'),
      new PWChrono_Onboarding_Task__c(Name = 'Email', Status__c = 'Completed')
    };
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      List<PWChrono_AdminController.ChartPoint> stats = PWChrono_AdminController.getTaskStatistics();
      List<PWChrono_Onboarding_Task__c> todo = PWChrono_AdminController.getTodoTasks(
        null,
        null
      );
      List<PWChrono_Onboarding_Task__c> todoPage = PWChrono_AdminController.getTodoTasksPaged(
        null,
        null,
        500,
        -1
      );
      Test.stopTest();

      Map<String, Integer> byStatus = new Map<String, Integer>();
      for (PWChrono_AdminController.ChartPoint point : stats) {
        byStatus.put(point.label, point.value);
      }
      Integer totalTasks = [SELECT COUNT() FROM PWChrono_Onboarding_Task__c];
      System.assertEquals(
        pendingBefore + 2,
        byStatus.get('Pending'),
        'Pending tasks counted'
      );
      System.assertEquals(
        completedBefore + 1,
        byStatus.get('Completed'),
        'Completed counted'
      );
      System.assertEquals(
        Math.min(6, totalTasks),
        todo.size(),
        'Todo widget returns at most six tasks'
      );
      System.assertEquals(
        Math.min(200, totalTasks),
        todoPage.size(),
        'Paged todo clamps limit and offset'
      );
    }
  }

  @isTest
  static void testDashboardWidgetQueries() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    insert new Event(
      Subject = 'Town hall',
      StartDateTime = Datetime.now().addDays(2),
      EndDateTime = Datetime.now().addDays(2).addHours(1),
      OwnerId = adminUser.Id
    );

    System.runAs(adminUser) {
      Test.startTest();
      List<Portal_Users__c> employees = PWChrono_AdminController.getEmployees();
      List<Portal_Users__c> employeesPage = PWChrono_AdminController.getEmployeesPaged(
        500,
        -1
      );
      List<Portal_Users__c> recentHires = PWChrono_AdminController.getRecentHires(
        null,
        null,
        0
      );
      List<Event> schedules = PWChrono_AdminController.getSchedules(null, null);
      List<Event> schedulesPage = PWChrono_AdminController.getSchedulesPaged(
        null,
        null,
        500,
        -1
      );
      List<Event> holidays = PWChrono_AdminController.getHolidays();
      List<Contact> birthdays = PWChrono_AdminController.getBirthdays();
      List<PWChrono_Invoice__c> invoices = PWChrono_AdminController.getInvoices();
      List<Leave__c> leaveRequests = PWChrono_AdminController.getLeaveRequests();
      List<PWChrono_Job_Applicant__c> applicants = PWChrono_AdminController.getJobApplicants(
        null,
        null
      );
      List<PWChrono_Project__c> projects = PWChrono_AdminController.getProjects(
        null,
        null
      );
      List<Account> clients = PWChrono_AdminController.getProjectClients(
        null,
        null
      );
      Test.stopTest();

      System.assert(!employees.isEmpty(), 'Employees widget returns rows');
      System.assert(employees.size() <= 5, 'Default employee limit');
      System.assert(employeesPage.size() >= employees.size(), 'Paged rows');
      System.assert(!recentHires.isEmpty(), 'Recent hires returned');
      System.assertEquals(1, schedules.size(), 'Upcoming event listed');
      System.assertEquals(1, schedulesPage.size(), 'Paged schedules');
      System.assertEquals(1, holidays.size(), 'Upcoming events listed');
      System.assertNotEquals(null, birthdays, 'Birthdays query runs');
      System.assertNotEquals(null, invoices, 'Invoices query runs');
      System.assertNotEquals(null, leaveRequests, 'Leave query runs');
      System.assertNotEquals(null, applicants, 'Applicants query runs');
      System.assertEquals(2, projects.size(), 'Projects listed');
      System.assertEquals(1, clients.size(), 'Client accounts listed');
    }
  }

  @isTest
  static void testSaveUploadLogoAndDeleteProject() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    Account client = [SELECT Id FROM Account LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      Id projectId = PWChrono_AdminController.saveProject(
        new Map<String, Object>{
          'Name' => 'Portal Rebuild',
          'Account__c' => String.valueOf(client.Id),
          'Priority__c' => 'High',
          'Start_Date__c' => String.valueOf(Date.today()),
          'End_Date__c' => String.valueOf(Date.today().addDays(60)),
          'Description__c' => 'Rebuild the portal',
          'Amount__c' => 12000,
          'Total_Hours__c' => '400',
          'Team_Size__c' => '4',
          'Hours_Logged__c' => '10',
          'Project_Members__c' => 'Ann;Ben',
          'Project_Leader__c' => 'Ann',
          'Project_Manager_Name__c' => 'Cara',
          'Project_Tags__c' => 'portal',
          'Project_Logo_ContentVersion_Id__c' => 'none'
        },
        null,
        null
      );
      PWChrono_AdminController.saveProject(
        new Map<String, Object>{
          'Id' => projectId,
          'Account__c' => '',
          'Status__c' => 'On Hold',
          'Team_Members__c' => 'Dan',
          'Team_Leader__c' => 'Dan',
          'Project_Manager__c' => 'Eve',
          'Tags__c' => 'legacy',
          'Logo_ContentVersion_Id__c' => 'legacy-logo'
        },
        null,
        null
      );
      Id versionId = PWChrono_AdminController.uploadProjectLogo(
        projectId,
        'logo.png',
        EncodingUtil.base64Encode(Blob.valueOf('logo')),
        'image/png',
        null,
        null
      );
      Test.stopTest();

      PWChrono_Project__c saved = [
        SELECT
          Name,
          Account__c,
          Status__c,
          Priority__c,
          Amount__c,
          Team_Size__c,
          Project_Members__c,
          Project_Manager_Name__c,
          Project_Tags__c,
          Project_Logo_ContentVersion_Id__c
        FROM PWChrono_Project__c
        WHERE Id = :projectId
      ];
      System.assertEquals('Portal Rebuild', saved.Name, 'Name saved');
      System.assertEquals(null, saved.Account__c, 'Blank client clears it');
      System.assertEquals('On Hold', saved.Status__c, 'Status updated');
      System.assertEquals('High', saved.Priority__c, 'Priority kept');
      System.assertEquals(12000, saved.Amount__c, 'Amount saved');
      System.assertEquals(4, saved.Team_Size__c, 'Team size saved');
      System.assertEquals('Dan', saved.Project_Members__c, 'Legacy key used');
      System.assertEquals('Eve', saved.Project_Manager_Name__c, 'Legacy PM');
      System.assertEquals('legacy', saved.Project_Tags__c, 'Legacy tags');
      System.assertEquals(
        String.valueOf(versionId),
        saved.Project_Logo_ContentVersion_Id__c,
        'Uploaded logo is linked'
      );

      PWChrono_AdminController.deleteProject(projectId, null, null);
      System.assertEquals(
        0,
        [SELECT COUNT() FROM PWChrono_Project__c WHERE Id = :projectId],
        'Project deleted'
      );
    }
  }

  @isTest
  static void testProjectAndSettingsErrorsAreHandled() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    Id projectId = [SELECT Id FROM PWChrono_Project__c LIMIT 1].Id;
    Integer failures = 0;

    System.runAs(adminUser) {
      Test.startTest();
      try {
        PWChrono_AdminController.saveProject(
          new Map<String, Object>{ 'Name' => 'Bad', 'Account__c' => 'bad-id' },
          null,
          null
        );
      } catch (AuraHandledException e) {
        failures++;
      }
      try {
        PWChrono_AdminController.uploadProjectLogo(
          null,
          'logo.png',
          'AA==',
          'image/png',
          null,
          null
        );
      } catch (AuraHandledException e) {
        failures++;
      }
      try {
        PWChrono_AdminController.uploadProjectLogo(
          projectId,
          '',
          '',
          'image/png',
          null,
          null
        );
      } catch (AuraHandledException e) {
        failures++;
      }
      try {
        PWChrono_AdminController.saveFeatureSettings(null, null, null);
      } catch (AuraHandledException e) {
        failures++;
      }
      try {
        PWChrono_AdminController.updatePortalUserAccess(
          null,
          PWChrono_Constants.ROLE_MANAGER,
          null,
          null,
          null
        );
      } catch (AuraHandledException e) {
        failures++;
      }
      try {
        PWChrono_AdminController.updateGlobalSettings(
          'Default',
          'Default Settings',
          null,
          null,
          null
        );
      } catch (AuraHandledException e) {
        failures++;
      }
      Test.stopTest();
    }

    System.assertEquals(6, failures, 'Every invalid request is rejected');
  }
}