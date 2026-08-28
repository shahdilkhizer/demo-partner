@IsTest
private class PWChrono_LeaveSelector_Test {

  @TestSetup
  static void setupTestData() {
    PWChrono_LeaveTestDataFactory.setupStandardTestData();
  }

  @IsTest
  static void testGetActiveLeaveTypes_IncludeInactive() {
    PWChrono_Leave_Type__c inactiveType = PWChrono_LeaveTestDataFactory.createLeaveType('Comp Off', 5);
    inactiveType.Is_Active__c = false;
    update inactiveType;

    Test.startTest();
    List<PWChrono_Leave_Type__c> activeOnly = PWChrono_LeaveSelector.getActiveLeaveTypes(false);
    List<PWChrono_Leave_Type__c> includeInactive = PWChrono_LeaveSelector.getActiveLeaveTypes(true);
    Test.stopTest();

    System.assertEquals(false, new Map<Id, PWChrono_Leave_Type__c>(activeOnly).containsKey(inactiveType.Id));
    System.assertEquals(true, new Map<Id, PWChrono_Leave_Type__c>(includeInactive).containsKey(inactiveType.Id));
  }

  @IsTest
  static void testBlockedDateAndPaidSalaryDetection() {
    Portal_Users__c employee = [
      SELECT Id FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    Date targetDate = Date.today().addDays(10);
    PWChrono_LeaveTestDataFactory.createBlockedDate(targetDate);
    PWChrono_LeaveTestDataFactory.createPaidSalarySlip(employee.Id, targetDate);

    Test.startTest();
    Set<Date> blockedDates = PWChrono_LeaveSelector.getBlockedDateSet(targetDate, targetDate, null);
    Boolean salaryProcessed = PWChrono_LeaveSelector.hasPaidSalarySlipInRange(
      employee.Id,
      targetDate,
      targetDate
    );
    Test.stopTest();

    System.assertEquals(true, blockedDates.contains(targetDate));
    System.assertEquals(true, salaryProcessed);
  }

  @IsTest
  static void testLeaveReadSelectors() {
    Portal_Users__c employee = [
      SELECT Id, Reports_To__c FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    PWChrono_Leave_Type__c leaveType = [
      SELECT Id FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];
    PWChrono_Leave__c submittedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      employee.Id,
      leaveType.Id,
      employee.Reports_To__c,
      Date.today().addDays(5),
      Date.today().addDays(6),
      'Submitted'
    );
    PWChrono_Leave__c approvedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      employee.Id,
      leaveType.Id,
      employee.Reports_To__c,
      Date.today().addDays(8),
      Date.today().addDays(9),
      'Approved'
    );

    Test.startTest();
    PWChrono_Leave__c byId = PWChrono_LeaveSelector.getLeaveById(submittedLeave.Id);
    List<PWChrono_Leave__c> byEmployee = PWChrono_LeaveSelector.getLeavesByEmployee(
      employee.Id,
      'All',
      null,
      null,
      null
    );
    List<PWChrono_Leave__c> pendingForManager = PWChrono_LeaveSelector.getTeamPendingLeaves(
      employee.Reports_To__c
    );
    List<PWChrono_Leave__c> managerHistory = PWChrono_LeaveSelector.getTeamLeaves(
      employee.Reports_To__c,
      'Submitted',
      null,
      null
    );
    List<PWChrono_Leave__c> calendarRows = PWChrono_LeaveSelector.getLeaveCalendar(
      employee.Id,
      Date.today().addDays(7),
      Date.today().addDays(10)
    );
    List<PWChrono_Leave__c> overlaps = PWChrono_LeaveSelector.getOverlappingLeaves(
      employee.Id,
      Date.today().addDays(8),
      Date.today().addDays(9),
      null
    );
    Test.stopTest();

    System.assertEquals(submittedLeave.Id, byId.Id);
    System.assert(byEmployee.size() >= 2, 'Employee list should include created leaves.');
    System.assertEquals(submittedLeave.Id, pendingForManager[0].Id);
    System.assert(managerHistory.size() >= 1, 'Manager history should return submitted leaves.');
    System.assertEquals(approvedLeave.Id, calendarRows[0].Id);
    System.assertEquals(approvedLeave.Id, overlaps[0].Id);
  }
}