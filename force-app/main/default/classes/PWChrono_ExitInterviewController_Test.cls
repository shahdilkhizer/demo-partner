@isTest
private class PWChrono_ExitInterviewController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Portal_Users__c employee = new Portal_Users__c(
        Name = 'Test Employee',
        Email__c = 'emp@test.com',
        Role__c = 'Employee',
        Is_Active__c = true
      );
      insert employee;

      Portal_Users__c hrAdmin = new Portal_Users__c(
        Name = 'HR Admin',
        Email__c = 'hr@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
        Is_Active__c = true
      );
      insert hrAdmin;

      Portal_Users__c interviewer = new Portal_Users__c(
        Name = 'Interviewer User',
        Email__c = 'interviewer@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
        Is_Active__c = true
      );
      insert interviewer;

      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Developer',
        Is_Active__c = true
      );
      insert desig;

      PWChrono_Employee_Separation__c sep = new PWChrono_Employee_Separation__c(
        Employee__c = employee.Id,
        Employee_Name__c = employee.Name,
        Company__c = 'PWChrono Corp',
        Department__c = dept.Id,
        Designation__c = desig.Id,
        Resignation_Letter_Date__c = Date.today(),
        Relieving_Date__c = Date.today().addDays(30),
        Status__c = 'Pending'
      );
      insert sep;

      PWChrono_Exit_Interview__c interview = new PWChrono_Exit_Interview__c(
        Employee__c = employee.Id,
        Employee_Name__c = employee.Name,
        Department__c = dept.Id,
        Designation__c = desig.Id,
        Separation__c = sep.Id,
        Interviewer__c = hrAdmin.Id,
        Interview_Date__c = Date.today(),
        Status__c = 'Pending',
        Rating__c = 4,
        Exit_Questionnaire__c = 'Why are you leaving?',
        Employee_Feedback__c = 'Great company.',
        Final_Remarks__c = 'Smooth transition.'
      );
      insert interview;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getInterviews
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetInterviews_AllAsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Exit_Interview__c> results = PWChrono_ExitInterviewController.getInterviews(
      'All',
      hr.Id,
      ''
    );
    Test.stopTest();
    Assert.isTrue(results.size() >= 1, 'HR should see all interviews');
  }

  @isTest
  static void testGetInterviews_OwnAsEmployee() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Exit_Interview__c> results = PWChrono_ExitInterviewController.getInterviews(
      'All',
      emp.Id,
      ''
    );
    Test.stopTest();
    for (PWChrono_Exit_Interview__c r : results) {
      Assert.areEqual(
        emp.Id,
        r.Employee__c,
        'Employee should only see own interviews'
      );
    }
  }

  @isTest
  static void testGetInterviews_FilterByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Exit_Interview__c> results = PWChrono_ExitInterviewController.getInterviews(
      'Pending',
      hr.Id,
      ''
    );
    Test.stopTest();
    for (PWChrono_Exit_Interview__c r : results) {
      Assert.areEqual(
        'Pending',
        r.Status__c,
        'All returned records should be Pending'
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getInterviewById
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetInterviewById() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Exit_Interview__c existing = [
      SELECT Id
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Exit_Interview__c result = PWChrono_ExitInterviewController.getInterviewById(
      existing.Id,
      hr.Id,
      ''
    );
    Test.stopTest();
    Assert.areEqual(
      existing.Id,
      result.Id,
      'Should return the requested interview'
    );
  }

  @isTest
  static void testGetInterviewById_NotFound() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Boolean threw = false;
    Test.startTest();
    try {
      PWChrono_ExitInterviewController.getInterviewById(
        'a0000000000000ZAAQ',
        hr.Id,
        ''
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    Assert.isTrue(
      threw,
      'Should throw AuraHandledException for missing record'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveInterview — insert
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSaveInterview_Insert() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Department__c dept = [
      SELECT Id
      FROM PWChrono_Department__c
      LIMIT 1
    ];
    PWChrono_Designation__c desig = [
      SELECT Id
      FROM PWChrono_Designation__c
      LIMIT 1
    ];

    Map<String, Object> payload = new Map<String, Object>{
      'Employee__c' => emp.Id,
      'Employee_Name__c' => 'Test Employee',
      'Department__c' => dept.Id,
      'Designation__c' => desig.Id,
      'Interviewer__c' => hr.Id,
      'Interview_Date__c' => String.valueOf(Date.today()),
      'Status__c' => 'Scheduled',
      'Rating__c' => 3,
      'Exit_Questionnaire__c' => 'New questionnaire',
      'Employee_Feedback__c' => 'New feedback',
      'Final_Remarks__c' => 'New remarks'
    };

    Test.startTest();
    String newId = PWChrono_ExitInterviewController.saveInterview(
      JSON.serialize(payload),
      hr.Id,
      ''
    );
    Test.stopTest();

    Assert.isNotNull(newId, 'Should return the new record Id');
    PWChrono_Exit_Interview__c created = [
      SELECT Status__c, Rating__c
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :newId
      LIMIT 1
    ];
    Assert.areEqual('Scheduled', created.Status__c);
    Assert.areEqual(3, created.Rating__c.intValue());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveInterview — update
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSaveInterview_Update() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Exit_Interview__c existing = [
      SELECT Id
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];

    Map<String, Object> payload = new Map<String, Object>{
      'Id' => existing.Id,
      'Final_Remarks__c' => 'Updated remarks',
      'Status__c' => 'Completed',
      'Rating__c' => 5
    };

    Test.startTest();
    String updatedId = PWChrono_ExitInterviewController.saveInterview(
      JSON.serialize(payload),
      hr.Id,
      ''
    );
    Test.stopTest();

    Assert.areEqual(existing.Id, updatedId);
    PWChrono_Exit_Interview__c updated = [
      SELECT Status__c, Rating__c, Final_Remarks__c
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :existing.Id
      LIMIT 1
    ];
    Assert.areEqual('Completed', updated.Status__c);
    Assert.areEqual(5, updated.Rating__c.intValue());
    Assert.areEqual('Updated remarks', updated.Final_Remarks__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // updateInterviewStatus
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testUpdateInterviewStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Exit_Interview__c existing = [
      SELECT Id
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_ExitInterviewController.updateInterviewStatus(
      existing.Id,
      'Scheduled',
      hr.Id,
      ''
    );
    Test.stopTest();
    PWChrono_Exit_Interview__c updated = [
      SELECT Status__c
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :existing.Id
      LIMIT 1
    ];
    Assert.areEqual('Scheduled', updated.Status__c);
  }

  @isTest
  static void testUpdateInterviewStatus_NotHR() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Exit_Interview__c existing = [
      SELECT Id
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];
    Boolean threw = false;
    Test.startTest();
    try {
      PWChrono_ExitInterviewController.updateInterviewStatus(
        existing.Id,
        'Completed',
        emp.Id,
        ''
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    Assert.isTrue(threw, 'Non-HR user should not be able to update status');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // deleteInterview
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testDeleteInterview() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Exit_Interview__c existing = [
      SELECT Id
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_ExitInterviewController.deleteInterview(existing.Id, hr.Id, '');
    Test.stopTest();
    List<PWChrono_Exit_Interview__c> remaining = [
      SELECT Id
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :existing.Id
      LIMIT 1
    ];
    Assert.areEqual(0, remaining.size(), 'Record should be deleted');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetActiveDesignations() {
    Test.startTest();
    List<PWChrono_Designation__c> results = PWChrono_ExitInterviewController.getActiveDesignations();
    Test.stopTest();
    Assert.isTrue(
      results.size() >= 1,
      'Should return at least one designation'
    );
  }

  @isTest
  static void testGetActiveDepartments() {
    Test.startTest();
    List<PWChrono_Department__c> results = PWChrono_ExitInterviewController.getActiveDepartments();
    Test.stopTest();
    Assert.isTrue(results.size() >= 1, 'Should return at least one department');
  }

  @isTest
  static void testGetActiveEmployees() {
    Test.startTest();
    List<Portal_Users__c> results = PWChrono_ExitInterviewController.getActiveEmployees();
    Test.stopTest();
    Assert.isTrue(results.size() >= 1, 'Should return active portal users');
  }

  @isTest
  static void testGetActiveSeparations() {
    Test.startTest();
    List<PWChrono_Employee_Separation__c> results = PWChrono_ExitInterviewController.getActiveSeparations();
    Test.stopTest();
    Assert.isTrue(results.size() >= 1, 'Should return active separations');
  }

  @isTest
  static void testGetInterviews_GuestHrSession() {
    Portal_Users__c hr = [
      SELECT Id, Session_Token__c, Session_Expires_At__c
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_exit_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Exit_Interview__c> results =
        PWChrono_ExitInterviewController.getInterviews(
          'All',
          String.valueOf(hr.Id),
          'guest_exit_token'
        );
      Test.stopTest();
      Assert.isTrue(results.size() >= 1, 'Guest HR should see interview records.');
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testDeleteInterview_NonPendingThrows() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Exit_Interview__c interview = [
      SELECT Id, Status__c
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];
    interview.Status__c = 'Completed';
    update interview;

    Test.startTest();
    try {
      PWChrono_ExitInterviewController.deleteInterview(
        String.valueOf(interview.Id),
        String.valueOf(hr.Id),
        null
      );
      System.assert(false, 'Only pending exit interviews should be deletable.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @isTest
  static void testMalformedPayloadAndDeleteNotFoundThrow() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'HR Admin'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_ExitInterviewController.saveInterview('{bad json', hr.Id, '');
      System.assert(false, 'Malformed exit interview JSON should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_ExitInterviewController.deleteInterview(
        '001000000000000AAA',
        hr.Id,
        ''
      );
      System.assert(false, 'Deleting a missing exit interview should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }
}