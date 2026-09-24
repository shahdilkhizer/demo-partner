@isTest
private class PWChrono_ExitInterviewController_Test {
  private static final String EMPLOYEE_EMAIL = 'emp@test.com';
  private static final String OTHER_EMAIL = 'other@test.com';
  private static final String HR_ADMIN_EMAIL = 'hr@test.com';
  private static final String HR_MANAGER_EMAIL = 'hr.manager@test.com';

  @testSetup
  static void setup() {
    Portal_User_Profile__c hrManagerProfile = new Portal_User_Profile__c(
      Profile_Type__c = 'HR Manager',
      Is_Active__c = true
    );
    insert hrManagerProfile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = hrManagerProfile.Id,
      Feature_Key__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Feature_Label__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Is_Enabled__c = true
    );

    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Test Employee',
      Email__c = EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true
    );
    Portal_Users__c other = new Portal_Users__c(
      Name = 'Other Employee',
      Email__c = OTHER_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true
    );
    Portal_Users__c hrAdmin = new Portal_Users__c(
      Name = 'HR Admin',
      Email__c = HR_ADMIN_EMAIL,
      Role__c = PWChrono_AccessController.ROLE_HR_ADMIN,
      Is_Active__c = true
    );
    Portal_Users__c hrManager = new Portal_Users__c(
      Name = 'HR Manager',
      Email__c = HR_MANAGER_EMAIL,
      Role__c = PWChrono_AccessController.ROLE_HR_MANAGER,
      Portal_User_Profile__c = hrManagerProfile.Id,
      Is_Active__c = true
    );
    insert new List<Portal_Users__c>{ employee, other, hrAdmin, hrManager };

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

    insert new PWChrono_Exit_Interview__c(
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
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Id userId(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  private static PWChrono_Exit_Interview__c getInterview() {
    return [
      SELECT
        Id,
        Status__c,
        Rating__c,
        Final_Remarks__c,
        Employee__c,
        Department__c,
        Designation__c,
        Interview_Date__c
      FROM PWChrono_Exit_Interview__c
      LIMIT 1
    ];
  }

  private static PWChrono_Employee_Separation__c getSeparation() {
    return [
      SELECT Id, Employee__c, Department__c, Designation__c
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
  }

  private static void setStatus(Id interviewId, String status) {
    update new PWChrono_Exit_Interview__c(Id = interviewId, Status__c = status);
  }

  private static String saveError(Map<String, Object> payload, Id actorId) {
    try {
      PWChrono_ExitInterviewController.saveInterview(
        JSON.serialize(payload),
        actorId,
        null
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('saveInterview should have failed.');
    return null;
  }

  private static String statusError(Id interviewId, String status, Id actorId) {
    try {
      PWChrono_ExitInterviewController.updateInterviewStatus(
        interviewId,
        status,
        actorId,
        null
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('updateInterviewStatus should have failed.');
    return null;
  }

  private static String deleteError(String interviewId, Id actorId) {
    try {
      PWChrono_ExitInterviewController.deleteInterview(
        interviewId,
        actorId,
        null
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('deleteInterview should have failed.');
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reads and access
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void getInterviewsReturnsAllAndFiltersByStatus() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    List<PWChrono_Exit_Interview__c> all = PWChrono_ExitInterviewController.getInterviews(
      'All',
      hrId,
      ''
    );
    List<PWChrono_Exit_Interview__c> pending = PWChrono_ExitInterviewController.getInterviews(
      'Pending',
      userId(HR_MANAGER_EMAIL),
      ''
    );
    List<PWChrono_Exit_Interview__c> completed = PWChrono_ExitInterviewController.getInterviews(
      'Completed',
      hrId,
      ''
    );
    Test.stopTest();
    Assert.areEqual(1, all.size());
    Assert.areEqual('HR Admin', all[0].Interviewer__r.Name);
    Assert.areEqual(1, pending.size());
    Assert.areEqual(0, completed.size());
  }

  @isTest
  static void userWithoutFeatureIsDenied() {
    Id employeeId = userId(EMPLOYEE_EMAIL);
    Integer denied = 0;
    Test.startTest();
    try {
      PWChrono_ExitInterviewController.getInterviews('All', employeeId, '');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Employee Lifecycle'));
      denied++;
    }
    try {
      PWChrono_ExitInterviewController.getInterviewById(
        getInterview().Id,
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_ExitInterviewController.saveInterview(
        JSON.serialize(new Map<String, Object>{ 'Employee__c' => employeeId }),
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_ExitInterviewController.getActiveDesignations(employeeId, '');
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_ExitInterviewController.getActiveDepartments(employeeId, '');
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_ExitInterviewController.getActiveEmployees(employeeId, '');
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_ExitInterviewController.getActiveSeparations(employeeId, '');
    } catch (AuraHandledException e) {
      denied++;
    }
    Test.stopTest();
    Assert.areEqual(7, denied);
  }

  @isTest
  static void getInterviewByIdHandlesFoundMissingAndInvalid() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    PWChrono_Exit_Interview__c existing = getInterview();
    String missing;
    String invalid;
    Test.startTest();
    PWChrono_Exit_Interview__c result = PWChrono_ExitInterviewController.getInterviewById(
      existing.Id,
      hrId,
      ''
    );
    try {
      PWChrono_ExitInterviewController.getInterviewById(
        'a0000000000000ZAAQ',
        hrId,
        ''
      );
    } catch (AuraHandledException e) {
      missing = e.getMessage();
    }
    try {
      PWChrono_ExitInterviewController.getInterviewById('', hrId, '');
    } catch (AuraHandledException e) {
      invalid = e.getMessage();
    }
    Test.stopTest();
    Assert.areEqual(existing.Id, result.Id);
    Assert.areEqual('Exit interview not found.', missing);
    Assert.areEqual('An exit interview is required.', invalid);
  }

  @isTest
  static void guestSessionIsVerified() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = :HR_ADMIN_EMAIL
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_exit_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    String denied;
    try {
      Test.startTest();
      List<PWChrono_Exit_Interview__c> results = PWChrono_ExitInterviewController.getInterviews(
        'All',
        String.valueOf(hr.Id),
        'guest_exit_token'
      );
      try {
        PWChrono_ExitInterviewController.getInterviews(
          'All',
          String.valueOf(hr.Id),
          null
        );
      } catch (AuraHandledException e) {
        denied = e.getMessage();
      }
      Test.stopTest();
      Assert.areEqual(1, results.size());
      Assert.isTrue(denied.startsWith('Session invalid'), denied);
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void saveInsertStartsPendingAndDefaultsFromSeparation() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    Map<String, Object> payload = new Map<String, Object>{
      'Separation__c' => sep.Id,
      'Interviewer__c' => userId(HR_MANAGER_EMAIL),
      'Interview_Date__c' => String.valueOf(Date.today().addDays(2)),
      'Status__c' => 'Completed',
      'Rating__c' => '3',
      'Exit_Questionnaire__c' => 'New questionnaire',
      'OwnerId' => userId(HR_ADMIN_EMAIL)
    };

    Test.startTest();
    String newId = PWChrono_ExitInterviewController.saveInterview(
      JSON.serialize(payload),
      userId(HR_MANAGER_EMAIL),
      ''
    );
    Test.stopTest();

    PWChrono_Exit_Interview__c created = [
      SELECT
        Status__c,
        Rating__c,
        Employee__c,
        Employee_Name__c,
        Department__c,
        Designation__c
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :newId
    ];
    Assert.areEqual('Pending', created.Status__c, 'Status is server-owned.');
    Assert.areEqual(3, created.Rating__c.intValue());
    Assert.areEqual(sep.Employee__c, created.Employee__c);
    Assert.areEqual('Test Employee', created.Employee_Name__c);
    Assert.areEqual(sep.Department__c, created.Department__c);
    Assert.areEqual(sep.Designation__c, created.Designation__c);
  }

  @isTest
  static void saveInsertWithoutSeparationUsesEmployeeName() {
    Map<String, Object> payload = new Map<String, Object>{
      'Employee__c' => userId(OTHER_EMAIL),
      'Interview_Date__c' => String.valueOf(Date.today()),
      'Rating__c' => ''
    };
    Test.startTest();
    String newId = PWChrono_ExitInterviewController.saveInterview(
      JSON.serialize(payload),
      userId(HR_ADMIN_EMAIL),
      ''
    );
    Test.stopTest();
    PWChrono_Exit_Interview__c created = [
      SELECT Employee_Name__c, Rating__c, Status__c
      FROM PWChrono_Exit_Interview__c
      WHERE Id = :newId
    ];
    Assert.areEqual('Other Employee', created.Employee_Name__c);
    Assert.isNull(created.Rating__c);
    Assert.areEqual('Pending', created.Status__c);
  }

  @isTest
  static void saveUpdateKeepsStatusAndUpdatesFields() {
    PWChrono_Exit_Interview__c existing = getInterview();
    Map<String, Object> payload = new Map<String, Object>{
      'Id' => existing.Id,
      'Final_Remarks__c' => 'Updated remarks',
      'Status__c' => 'Completed',
      'Rating__c' => 5
    };

    Test.startTest();
    String updatedId = PWChrono_ExitInterviewController.saveInterview(
      JSON.serialize(payload),
      userId(HR_ADMIN_EMAIL),
      ''
    );
    Test.stopTest();

    Assert.areEqual(existing.Id, updatedId);
    PWChrono_Exit_Interview__c updated = getInterview();
    Assert.areEqual('Pending', updated.Status__c, 'Save cannot set status.');
    Assert.areEqual(5, updated.Rating__c.intValue());
    Assert.areEqual('Updated remarks', updated.Final_Remarks__c);
    Assert.areEqual(existing.Employee__c, updated.Employee__c);
  }

  @isTest
  static void saveValidatesInput() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    PWChrono_Exit_Interview__c existing = getInterview();
    PWChrono_Employee_Separation__c sep = getSeparation();

    Portal_Users__c inactive = new Portal_Users__c(
      Name = 'Former Interviewer',
      Email__c = 'former@test.com',
      Role__c = 'Employee',
      Is_Active__c = false
    );
    insert inactive;

    Test.startTest();
    String noEmployee = saveError(
      new Map<String, Object>{ 'Interview_Date__c' => '2026-01-01' },
      hrId
    );
    String badRating = saveError(
      new Map<String, Object>{ 'Id' => existing.Id, 'Rating__c' => 7 },
      hrId
    );
    String fractionalRating = saveError(
      new Map<String, Object>{ 'Id' => existing.Id, 'Rating__c' => 2.5 },
      hrId
    );
    String textRating = saveError(
      new Map<String, Object>{ 'Id' => existing.Id, 'Rating__c' => 'great' },
      hrId
    );
    String mismatch = saveError(
      new Map<String, Object>{
        'Employee__c' => userId(OTHER_EMAIL),
        'Separation__c' => sep.Id
      },
      hrId
    );
    String inactiveInterviewer = saveError(
      new Map<String, Object>{
        'Id' => existing.Id,
        'Interviewer__c' => inactive.Id
      },
      hrId
    );
    String badDate = saveError(
      new Map<String, Object>{
        'Id' => existing.Id,
        'Interview_Date__c' => 'soon'
      },
      hrId
    );
    String badId = saveError(
      new Map<String, Object>{ 'Id' => existing.Id, 'Employee__c' => 'nope' },
      hrId
    );
    String unknownEmployee = saveError(
      new Map<String, Object>{ 'Employee__c' => existing.Id },
      hrId
    );
    String missingSeparation = saveError(
      new Map<String, Object>{
        'Employee__c' => userId(EMPLOYEE_EMAIL),
        'Separation__c' => existing.Id
      },
      hrId
    );
    Test.stopTest();

    Assert.isTrue(noEmployee.contains('Select the employee'), noEmployee);
    Assert.isTrue(badRating.contains('1 to 5'), badRating);
    Assert.isTrue(fractionalRating.contains('1 to 5'), fractionalRating);
    Assert.isTrue(textRating.contains('1 to 5'), textRating);
    Assert.isTrue(mismatch.contains('does not match'), mismatch);
    Assert.isTrue(
      inactiveInterviewer.contains('active employee'),
      inactiveInterviewer
    );
    Assert.isTrue(badDate.contains('YYYY-MM-DD'), badDate);
    Assert.isTrue(badId.contains('not valid'), badId);
    Assert.isTrue(unknownEmployee.contains('not found'), unknownEmployee);
    Assert.isTrue(missingSeparation.contains('not found'), missingSeparation);
  }

  @isTest
  static void saveRejectsCancelledSeparationAndTerminalInterviews() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    PWChrono_Employee_Separation__c sep = getSeparation();
    update new PWChrono_Employee_Separation__c(
      Id = sep.Id,
      Status__c = 'Cancelled'
    );
    PWChrono_Exit_Interview__c existing = getInterview();

    Test.startTest();
    String cancelled = saveError(
      new Map<String, Object>{
        'Employee__c' => sep.Employee__c,
        'Separation__c' => sep.Id
      },
      hrId
    );
    setStatus(existing.Id, 'Completed');
    String completed = saveError(
      new Map<String, Object>{ 'Id' => existing.Id, 'Final_Remarks__c' => 'X' },
      hrId
    );
    setStatus(existing.Id, 'Skipped');
    String skipped = saveError(
      new Map<String, Object>{ 'Id' => existing.Id, 'Final_Remarks__c' => 'X' },
      hrId
    );
    Test.stopTest();

    Assert.isTrue(cancelled.contains('cancelled'), cancelled);
    Assert.isTrue(completed.contains('can no longer be edited'), completed);
    Assert.isTrue(skipped.contains('can no longer be edited'), skipped);
    Assert.areEqual(
      'Smooth transition.',
      [
        SELECT Final_Remarks__c
        FROM PWChrono_Exit_Interview__c
        WHERE Id = :existing.Id
      ]
      .Final_Remarks__c
    );
  }

  @isTest
  static void malformedPayloadsAreRejected() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    String malformed;
    String notObject;
    String blank;
    Test.startTest();
    try {
      PWChrono_ExitInterviewController.saveInterview('{bad json', hrId, '');
    } catch (AuraHandledException e) {
      malformed = e.getMessage();
    }
    try {
      PWChrono_ExitInterviewController.saveInterview('[]', hrId, '');
    } catch (AuraHandledException e) {
      notObject = e.getMessage();
    }
    try {
      PWChrono_ExitInterviewController.saveInterview('', hrId, '');
    } catch (AuraHandledException e) {
      blank = e.getMessage();
    }
    Test.stopTest();
    Assert.areEqual('The request data is not valid.', malformed);
    Assert.areEqual('The request data is not valid.', notObject);
    Assert.areEqual('The request data is missing.', blank);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminSchedulesThenCompletesInterview() {
    Id interviewId = getInterview().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    PWChrono_ExitInterviewController.updateInterviewStatus(
      interviewId,
      'Scheduled',
      hrId,
      ''
    );
    String afterSchedule = getInterview().Status__c;
    PWChrono_ExitInterviewController.updateInterviewStatus(
      interviewId,
      'Completed',
      hrId,
      ''
    );
    Test.stopTest();
    Assert.areEqual('Scheduled', afterSchedule);
    Assert.areEqual('Completed', getInterview().Status__c);
  }

  @isTest
  static void adminSkipsPendingInterview() {
    Id interviewId = getInterview().Id;
    Test.startTest();
    PWChrono_ExitInterviewController.updateInterviewStatus(
      interviewId,
      'Skipped',
      userId(HR_ADMIN_EMAIL),
      ''
    );
    Test.stopTest();
    Assert.areEqual('Skipped', getInterview().Status__c);
  }

  @isTest
  static void invalidTransitionsAreRejected() {
    Id interviewId = getInterview().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    String unknown = statusError(interviewId, 'Archived', hrId);
    String same = statusError(interviewId, 'Pending', hrId);
    update new PWChrono_Exit_Interview__c(
      Id = interviewId,
      Interview_Date__c = null
    );
    String noDate = statusError(interviewId, 'Scheduled', hrId);
    setStatus(interviewId, 'Scheduled');
    String backToPending = statusError(interviewId, 'Pending', hrId);
    setStatus(interviewId, 'Completed');
    String fromCompleted = statusError(interviewId, 'Skipped', hrId);
    setStatus(interviewId, 'Skipped');
    String fromSkipped = statusError(interviewId, 'Completed', hrId);
    Test.stopTest();
    Assert.isTrue(unknown.contains('valid exit interview status'), unknown);
    Assert.isTrue(same.contains('cannot be moved'), same);
    Assert.isTrue(noDate.contains('interview date'), noDate);
    Assert.isTrue(backToPending.contains('scheduled exit interview'));
    Assert.isTrue(fromCompleted.contains('completed exit interview'));
    Assert.isTrue(fromSkipped.contains('skipped exit interview'));
  }

  @isTest
  static void nonAdminCannotChangeStatusOrDelete() {
    Id interviewId = getInterview().Id;
    Id managerId = userId(HR_MANAGER_EMAIL);
    Test.startTest();
    String statusMessage = statusError(interviewId, 'Scheduled', managerId);
    String deleteMessage = deleteError(interviewId, managerId);
    Test.stopTest();
    Assert.isTrue(statusMessage.contains('HR administrators'), statusMessage);
    Assert.isTrue(deleteMessage.contains('HR administrators'), deleteMessage);
    Assert.areEqual('Pending', getInterview().Status__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void deleteAllowsPendingAndSkippedOnly() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    PWChrono_Exit_Interview__c existing = getInterview();
    PWChrono_Exit_Interview__c second = existing.clone(false, true);
    second.Status__c = 'Skipped';
    insert second;

    Test.startTest();
    PWChrono_ExitInterviewController.deleteInterview(existing.Id, hrId, '');
    PWChrono_ExitInterviewController.deleteInterview(second.Id, hrId, '');
    PWChrono_Exit_Interview__c third = existing.clone(false, true);
    third.Status__c = 'Scheduled';
    insert third;
    String scheduled = deleteError(third.Id, hrId);
    setStatus(third.Id, 'Completed');
    String completed = deleteError(third.Id, hrId);
    String missing = deleteError('a0000000000000ZAAQ', hrId);
    String invalid = deleteError('bad-id', hrId);
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM PWChrono_Exit_Interview__c],
      'Only the completed interview should remain.'
    );
    Assert.isTrue(scheduled.contains('pending or skipped'), scheduled);
    Assert.isTrue(completed.contains('pending or skipped'), completed);
    Assert.areEqual('Exit interview not found.', missing);
    Assert.isTrue(invalid.contains('not valid'), invalid);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void lookupHelpersReturnActiveRecords() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Portal_Users__c employee = [
      SELECT Id, Is_Active__c
      FROM Portal_Users__c
      WHERE Email__c = :EMPLOYEE_EMAIL
    ];
    employee.Is_Active__c = false;
    update employee;

    Test.startTest();
    List<PWChrono_Designation__c> designations = PWChrono_ExitInterviewController.getActiveDesignations(
      hrId,
      ''
    );
    List<PWChrono_Department__c> departments = PWChrono_ExitInterviewController.getActiveDepartments(
      hrId,
      ''
    );
    List<Portal_Users__c> employees = PWChrono_ExitInterviewController.getActiveEmployees(
      hrId,
      ''
    );
    List<PWChrono_Employee_Separation__c> separations = PWChrono_ExitInterviewController.getActiveSeparations(
      hrId,
      ''
    );
    Test.stopTest();

    Assert.areEqual(1, designations.size());
    Assert.areEqual(1, departments.size());
    Assert.areEqual(
      4,
      employees.size(),
      'Departing employees stay selectable after deactivation.'
    );
    Assert.areEqual(1, separations.size());
  }
}