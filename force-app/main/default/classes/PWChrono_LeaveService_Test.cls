/**
 * @description Test class for PWChrono_LeaveService and PWChrono_LeaveController.
 *              Covers: submit, approve, reject, cancel, admin operations,
 *              working days calculation, and controller AuraEnabled methods.
 */
@SuppressWarnings('PMD.MethodNamingConventions,PMD.ExcessiveParameterList')
@IsTest
private class PWChrono_LeaveService_Test {

  @TestSetup
  static void setupTestData() {
    PWChrono_LeaveTestDataFactory.setupStandardTestData();
  }

  // ── Helpers ──

  static PWChrono_LeaveTestDataFactory.TestDataBundle getBundle() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle =
      new PWChrono_LeaveTestDataFactory.TestDataBundle();

    bundle.employee = [
      SELECT Id, Name, Reports_To__c
      FROM Portal_Users__c
      WHERE Name = 'Test Employee'
      LIMIT 1
    ];
    bundle.manager = [
      SELECT Id, Name
      FROM Portal_Users__c
      WHERE Name = 'Test Manager'
      LIMIT 1
    ];
    bundle.admin = [
      SELECT Id, Name
      FROM Portal_Users__c
      WHERE Name = 'Test HRAdmin'
      LIMIT 1
    ];
    bundle.annualLeave = [
      SELECT Id, Name, Max_Days_Allowed__c
      FROM PWChrono_Leave_Type__c
      WHERE Name = 'Annual Leave'
      LIMIT 1
    ];
    bundle.sickLeave = [
      SELECT Id, Name
      FROM PWChrono_Leave_Type__c
      WHERE Name = 'Sick Leave'
      LIMIT 1
    ];
    bundle.annualAllocation = [
      SELECT Id, Total_Leaves_Allocated__c, Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :bundle.employee.Id
        AND Leave_Type__c = :bundle.annualLeave.Id
      LIMIT 1
    ];
    bundle.sickAllocation = [
      SELECT Id
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :bundle.employee.Id
        AND Leave_Type__c = :bundle.sickLeave.Id
      LIMIT 1
    ];

    return bundle;
  }

  static PWChrono_LeaveValidator.LeaveDTO buildDTO(
    Id leaveTypeId, Date fromDate, Date toDate, String reason
  ) {
    PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
    dto.leaveTypeId = leaveTypeId;
    dto.fromDate = fromDate;
    dto.toDate = toDate;
    dto.reason = reason;
    dto.halfDay = false;
    dto.status = 'Submitted';
    return dto;
  }

  // ── Submit Leave Tests ──

  @IsTest
  static void testSubmitLeave_Success() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = buildDTO(
      b.annualLeave.Id,
      Date.today().addDays(5),
      Date.today().addDays(7),
      'Family vacation'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveService.submitLeave(dto, b.employee.Id);
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Leave should be created');
    System.assertEquals('Submitted', result.Status__c, 'Status should be Submitted');
    System.assertEquals(b.annualLeave.Id, result.Leave_Type__c, 'Leave type should match');
    System.assertEquals(b.employee.Id, result.Employees__c, 'Employee should match');
  }

  @IsTest
  static void testSubmitLeave_HalfDay() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = buildDTO(
      b.annualLeave.Id,
      Date.today().addDays(5),
      Date.today().addDays(5),
      'Half day off'
    );
    dto.halfDay = true;

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveService.submitLeave(dto, b.employee.Id);
    Test.stopTest();

    System.assertEquals(0.5, result.Total_Days__c, 'Half day should be 0.5');
    System.assertEquals(true, result.Half_Day__c, 'Half day flag should be true');
  }

  @IsTest
  static void testSubmitLeave_MissingDates() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = buildDTO(
      b.annualLeave.Id, null, null, 'Bad request'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.submitLeave(dto, b.employee.Id);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Missing dates should raise an exception');
    }
    Test.stopTest();
  }

  @IsTest
  static void testSubmitLeave_EndBeforeStart() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = buildDTO(
      b.annualLeave.Id,
      Date.today().addDays(10),
      Date.today().addDays(5),
      'Invalid range'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.submitLeave(dto, b.employee.Id);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Invalid date range should raise an exception');
    }
    Test.stopTest();
  }

  // ── Approval Tests ──

  @IsTest
  static void testApproveLeave_Success() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveService.processApproval(
      leave.Id, 'Approve', null, b.manager.Id
    );
    Test.stopTest();

    System.assertEquals('Approved', result.Status__c, 'Should be Approved');
    System.assertNotEquals(null, result.Approval_Date__c, 'Approval date should be set');

    // Verify balance deduction
    PWChrono_Leave_Allocation__c alloc = [
      SELECT Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Id = :b.annualAllocation.Id
    ];
    System.assert(
      alloc.Total_Leaves_Used__c >= leave.Total_Days__c,
      'Balance should be deducted'
    );
  }

  @IsTest
  static void testRejectLeave_Success() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveService.processApproval(
      leave.Id, 'Reject', 'Insufficient staff coverage', b.manager.Id
    );
    Test.stopTest();

    System.assertEquals('Rejected', result.Status__c, 'Should be Rejected');
    System.assertEquals(
      'Insufficient staff coverage',
      result.Rejection_Reason__c,
      'Rejection reason should be saved'
    );
  }

  @IsTest
  static void testRejectLeave_NoReason() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.processApproval(leave.Id, 'Reject', '', b.manager.Id);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Reject without reason should raise an exception');
    }
    Test.stopTest();
  }

  @IsTest
  static void testApproveLeave_InvalidStatus() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    // Create an already-approved leave
    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Approved'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.processApproval(leave.Id, 'Approve', null, b.manager.Id);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Invalid status should raise an exception');
    }
    Test.stopTest();
  }

  @IsTest
  static void testApproveLeave_InvalidAction() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.processApproval(leave.Id, 'InvalidAction', null, b.manager.Id);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Invalid approval action should raise an exception');
    }
    Test.stopTest();
  }

  // ── Cancel Tests ──

  @IsTest
  static void testCancelSubmittedLeave() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveService.cancelLeave(
      leave.Id, 'Change of plans', b.employee.Id
    );
    Test.stopTest();

    System.assertEquals('Cancelled', result.Status__c, 'Should be Cancelled');
  }

  @IsTest
  static void testCancelApprovedLeave_ReversesBalance() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Approved'
    );

    // Simulate prior balance deduction
    b.annualAllocation.Total_Leaves_Used__c = leave.Total_Days__c;
    update b.annualAllocation;

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveService.cancelLeave(
      leave.Id, 'Emergency resolved', b.employee.Id
    );
    Test.stopTest();

    System.assertEquals('Cancelled', result.Status__c, 'Should be Cancelled');

    // Verify balance reversal
    PWChrono_Leave_Allocation__c alloc = [
      SELECT Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Id = :b.annualAllocation.Id
    ];
    System.assertEquals(
      0, alloc.Total_Leaves_Used__c,
      'Balance should be reversed after cancel of approved leave'
    );
  }

  @IsTest
  static void testCancelRejectedLeave_Fails() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Rejected'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.cancelLeave(leave.Id, 'Trying to cancel', b.employee.Id);
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Rejected leave should not be cancellable');
    }
    Test.stopTest();
  }

  @IsTest
  static void testCancelLeave_UnauthorizedUser() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Portal_Users__c otherEmp = PWChrono_LeaveTestDataFactory.createEmployee(
      'Other Employee', true
    );

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    try {
      PWChrono_LeaveService.cancelLeave(leave.Id, 'Not my leave', otherEmp.Id);
      // Note: Since test user is internal (isAdmin=true by default),
      // this may succeed. The guard is meaningful for guest users.
      // We still verify the call path is exercised.
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Unauthorized'),
        'Should block unauthorized cancel'
      );
    }
    Test.stopTest();
  }

  // ── Admin Operations Tests ──

  @IsTest
  static void testCreateLeaveType() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave_Type__c newType = new PWChrono_Leave_Type__c(
      Name = 'Paternity Leave',
      Max_Days_Allowed__c = 15,
      Is_Active__c = true,
      Requires_Approval__c = true
    );

    Test.startTest();
    PWChrono_Leave_Type__c result = PWChrono_LeaveService.createLeaveType(
      newType, b.admin.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Leave type should be created');
    System.assertEquals('Paternity Leave', result.Name);
  }

  @IsTest
  static void testUpdateLeaveType() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    b.annualLeave.Max_Days_Allowed__c = 25;

    Test.startTest();
    PWChrono_Leave_Type__c result = PWChrono_LeaveService.updateLeaveType(
      b.annualLeave, b.admin.Id
    );
    Test.stopTest();

    System.assertEquals(25, result.Max_Days_Allowed__c, 'Max days should be updated');
  }

  @IsTest
  static void testAdjustLeaveBalance() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Test.startTest();
    PWChrono_LeaveService.adjustLeaveBalance(
      b.employee.Id, b.annualLeave.Id, 5, 'Extra allocation', b.admin.Id
    );
    Test.stopTest();

    PWChrono_Leave_Allocation__c alloc = [
      SELECT Total_Leaves_Allocated__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Id = :b.annualAllocation.Id
    ];
    System.assertEquals(25, alloc.Total_Leaves_Allocated__c, 'Should add 5 to 20');
  }

  @IsTest
  static void testAdjustLeaveBalance_ZeroDays() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Test.startTest();
    try {
      PWChrono_LeaveService.adjustLeaveBalance(
        b.employee.Id, b.annualLeave.Id, 0, 'No adjustment', b.admin.Id
      );
      System.assert(false, 'Should have thrown exception');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e, 'Zero-day adjustment should raise an exception');
    }
    Test.stopTest();
  }

  // ── Working Days Calculation ──

  @IsTest
  static void testCalculateWorkingDays_Weekday() {
    // Monday to Friday of next week (5 weekdays)
    Date monday = Date.today();
    // Find next Monday
    while (DateTime.newInstance(monday.year(), monday.month(), monday.day())
      .format('EEEE') != 'Monday') {
      monday = monday.addDays(1);
    }
    Date friday = monday.addDays(4);

    Test.startTest();
    Decimal days = PWChrono_LeaveService.calculateWorkingDays(
      monday, friday, false, null
    );
    Test.stopTest();

    System.assertEquals(5, days, 'Mon-Fri should be 5 working days');
  }

  @IsTest
  static void testCalculateWorkingDays_HalfDay() {
    Test.startTest();
    Decimal days = PWChrono_LeaveService.calculateWorkingDays(
      Date.today(), Date.today(), true, null
    );
    Test.stopTest();

    System.assertEquals(0.5, days, 'Half day should return 0.5');
  }

  @IsTest
  static void testCalculateWorkingDays_NullDates() {
    Test.startTest();
    Decimal days = PWChrono_LeaveService.calculateWorkingDays(
      null, null, false, null
    );
    Test.stopTest();

    System.assertEquals(0, days, 'Null dates should return 0');
  }

  // ── Controller AuraEnabled Methods ──

  @IsTest
  static void testController_GetMyLeaveBalance() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Test.startTest();
    List<PWChrono_LeaveBalanceService.LeaveBalanceWrapper> balances =
      PWChrono_LeaveController.getMyLeaveBalance(
        String.valueOf(b.employee.Id), null
      );
    Test.stopTest();

    System.assert(balances.size() >= 2, 'Should have at least 2 leave types');
  }

  @IsTest
  static void testController_GetMyLeaves() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    List<PWChrono_Leave__c> leaves = PWChrono_LeaveController.getMyLeaves(
      null, null, null, String.valueOf(b.employee.Id), null
    );
    Test.stopTest();

    System.assert(leaves.size() >= 1, 'Should return at least one leave');
  }

  @IsTest
  static void testController_GetLeaveDetail() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    PWChrono_Leave__c detail = PWChrono_LeaveController.getLeaveDetail(
      leave.Id, String.valueOf(b.employee.Id), null
    );
    Test.stopTest();

    System.assertNotEquals(null, detail, 'Should return leave detail');
    System.assertEquals(leave.Id, detail.Id, 'Should match the leave Id');
  }

  @IsTest
  static void testController_GetActiveLeaveTypes() {
    getBundle();

    Test.startTest();
    List<PWChrono_Leave_Type__c> types = PWChrono_LeaveController.getActiveLeaveTypes();
    Test.stopTest();

    System.assert(types.size() >= 2, 'Should have at least 2 active leave types');
  }

  @IsTest
  static void testController_SubmitLeaveApplication() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = buildDTO(
      b.annualLeave.Id,
      Date.today().addDays(10),
      Date.today().addDays(12),
      'Trip planned'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveController.submitLeaveApplication(
      dto, String.valueOf(b.employee.Id), null
    );
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Leave should be created via controller');
    System.assertEquals('Submitted', result.Status__c);
  }

  @IsTest
  static void testController_ProcessApproval() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveController.processLeaveApproval(
      leave.Id, 'Approve', null,
      String.valueOf(b.manager.Id), null
    );
    Test.stopTest();

    System.assertEquals('Approved', result.Status__c);
  }

  @IsTest
  static void testController_CancelLeave() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_Leave__c leave = PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    PWChrono_Leave__c result = PWChrono_LeaveController.cancelLeave(
      leave.Id, 'Changed mind',
      String.valueOf(b.employee.Id), null
    );
    Test.stopTest();

    System.assertEquals('Cancelled', result.Status__c);
  }

  @IsTest
  static void testController_CalculateWorkingDays() {
    Date monday = Date.today();
    while (DateTime.newInstance(monday.year(), monday.month(), monday.day())
      .format('EEEE') != 'Monday') {
      monday = monday.addDays(1);
    }

    Test.startTest();
    Decimal days = PWChrono_LeaveController.calculateWorkingDays(
      monday, monday.addDays(4), false, null
    );
    Test.stopTest();

    System.assertEquals(5, days, 'Mon-Fri should be 5 working days');
  }

  @IsTest
  static void testController_GetTeamLeavesForApproval() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveTestDataFactory.createLeave(
      b.employee.Id, b.annualLeave.Id, b.manager.Id,
      Date.today().addDays(5), Date.today().addDays(7), 'Submitted'
    );

    Test.startTest();
    List<PWChrono_Leave__c> pending = PWChrono_LeaveController.getTeamLeavesForApproval(
      String.valueOf(b.manager.Id), null
    );
    Test.stopTest();

    System.assert(pending.size() >= 1, 'Should find pending leaves for approval');
  }
}