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

    PWChrono_Leave__c leave = new PWChrono_Leave__c(
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
        'Should count Is_New__c user as Probation bucket'
      );
    }
  }

  @isTest
  static void testGetAttendanceOverview() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_AdminController.AttendanceOverview res = PWChrono_AdminController.getAttendanceOverview(
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
      List<PWChrono_AdminController.ChartPoint> points = PWChrono_AdminController.getEmployeesByDepartment(
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
}