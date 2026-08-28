@IsTest
private class PWChrono_LeaveBalanceService_Test {

  @TestSetup
  static void setupTestData() {
    PWChrono_LeaveTestDataFactory.setupStandardTestData();
  }

  @IsTest
  static void testPendingRequestsIncludedInBalance() {
    Portal_Users__c employee = [
      SELECT Id, Reports_To__c FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    PWChrono_Leave_Type__c annualLeave = [
      SELECT Id FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];

    PWChrono_LeaveTestDataFactory.createLeave(
      employee.Id,
      annualLeave.Id,
      employee.Reports_To__c,
      Date.today().addDays(4),
      Date.today().addDays(5),
      'Submitted'
    );

    Test.startTest();
    PWChrono_LeaveBalanceService.LeaveBalanceWrapper balance =
      PWChrono_LeaveBalanceService.getBalanceForType(employee.Id, annualLeave.Id);
    Test.stopTest();

    System.assertEquals(2, balance.pendingRequests);
  }

  @IsTest
  static void testDeductAndReverseBalance() {
    Portal_Users__c employee = [
      SELECT Id FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    PWChrono_Leave_Type__c annualLeave = [
      SELECT Id FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];

    Test.startTest();
    PWChrono_LeaveBalanceService.deductBalance(employee.Id, annualLeave.Id, 3);
    PWChrono_LeaveBalanceService.reverseBalance(employee.Id, annualLeave.Id, 1);
    Test.stopTest();

    PWChrono_Leave_Allocation__c allocation = [
      SELECT Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employee.Id
        AND Leave_Type__c = :annualLeave.Id
      LIMIT 1
    ];
    System.assertEquals(2, allocation.Total_Leaves_Used__c);
  }
}