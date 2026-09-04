@IsTest
private class PWChrono_LeaveLedgerService_Test {

  @TestSetup
  static void setupTestData() {
    PWChrono_LeaveTestDataFactory.setupStandardTestData();
  }

  @IsTest
  static void testRecordLeaveUsedCreatesLedgerEntry() {
    Portal_Users__c employee = [
      SELECT Id, Reports_To__c FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    PWChrono_Leave_Type__c annualLeave = [
      SELECT Id FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];
    Leave__c leaveRecord = PWChrono_LeaveTestDataFactory.createLeave(
      employee.Id,
      annualLeave.Id,
      employee.Reports_To__c,
      Date.today().addDays(6),
      Date.today().addDays(8),
      'Approved'
    );

    Test.startTest();
    PWChrono_LeaveBalanceService.deductBalance(employee.Id, annualLeave.Id, leaveRecord.Total_Days__c);
    PWChrono_LeaveLedgerService.recordLeaveUsed(leaveRecord, employee.Reports_To__c);
    Test.stopTest();

    List<PWChrono_LeaveLedgerService.LedgerEntryDTO> entries =
      PWChrono_LeaveLedgerService.getLedgerHistoryByLeave(leaveRecord.Id);

    System.assertEquals(1, entries.size());
    System.assertEquals('Used', entries[0].transactionType);
    System.assertEquals(-3, entries[0].days);
  }

  @IsTest
  static void testRecordAdjustmentCreatesLedgerEntry() {
    Portal_Users__c employee = [
      SELECT Id FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    Portal_Users__c admin = [
      SELECT Id FROM Portal_Users__c WHERE Name = 'Test HRAdmin' LIMIT 1
    ];
    PWChrono_Leave_Type__c annualLeave = [
      SELECT Id FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];

    Test.startTest();
    PWChrono_LeaveService.adjustLeaveBalance(employee.Id, annualLeave.Id, 2, 'Manual credit', admin.Id);
    Test.stopTest();

    List<PWChrono_LeaveLedgerService.LedgerEntryDTO> entries =
      PWChrono_LeaveLedgerService.getLedgerHistory(employee.Id, annualLeave.Id);

    System.assertEquals(false, entries.isEmpty());
    System.assertEquals('Adjustment', entries[0].transactionType);
  }
}