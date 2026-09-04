@IsTest
private class PWChrono_LeaveController_Test {

  @TestSetup
  static void setupTestData() {
    PWChrono_LeaveTestDataFactory.setupStandardTestData();
  }

  private static PWChrono_LeaveTestDataFactory.TestDataBundle getBundle() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle =
      new PWChrono_LeaveTestDataFactory.TestDataBundle();
    bundle.employee = [
      SELECT Id, Reports_To__c FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    bundle.manager = [
      SELECT Id FROM Portal_Users__c WHERE Name = 'Test Manager' LIMIT 1
    ];
    bundle.admin = [
      SELECT Id FROM Portal_Users__c WHERE Name = 'Test HRAdmin' LIMIT 1
    ];
    bundle.annualLeave = [
      SELECT Id FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];
    return bundle;
  }

  @IsTest
  static void testSubmitApproveAndLedgerHistory() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
    dto.leaveTypeId = bundle.annualLeave.Id;
    dto.fromDate = Date.today().addDays(5);
    dto.toDate = Date.today().addDays(7);
    dto.reason = 'Controller test';
    dto.halfDay = false;

    Test.startTest();
    Leave__c createdLeave = PWChrono_LeaveController.submitLeaveApplication(
      dto,
      String.valueOf(bundle.employee.Id),
      null
    );
    Leave__c approvedLeave = PWChrono_LeaveController.processLeaveApproval(
      createdLeave.Id,
      'Approve',
      'Looks good',
      String.valueOf(bundle.manager.Id),
      null
    );
    List<PWChrono_LeaveLedgerService.LedgerEntryDTO> ledgerEntries =
      PWChrono_LeaveController.getLeaveLedgerHistory(
        createdLeave.Id,
        String.valueOf(bundle.employee.Id),
        null
      );
    Test.stopTest();

    System.assertEquals('Approved', approvedLeave.Status__c);
    System.assertEquals(1, ledgerEntries.size(), 'Approval should create a ledger entry.');
    System.assertEquals('Used', ledgerEntries[0].transactionType);
  }

  @IsTest
  static void testAddCommentAndRetrieveComments() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    Leave__c leaveRecord = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(2),
      Date.today().addDays(2),
      'Submitted'
    );

    Test.startTest();
    PWChrono_RequestCommentService.RequestCommentDTO newComment =
      PWChrono_LeaveController.addLeaveComment(
        leaveRecord.Id,
        'Please approve quickly.',
        String.valueOf(bundle.employee.Id),
        null
      );
    List<PWChrono_RequestCommentService.RequestCommentDTO> comments =
      PWChrono_LeaveController.getLeaveComments(
        leaveRecord.Id,
        String.valueOf(bundle.employee.Id),
        null
      );
    Test.stopTest();

    System.assertNotEquals(null, newComment.commentId);
    System.assertEquals(1, comments.size());
    System.assertEquals('Please approve quickly.', comments[0].text);
  }

  @IsTest
  static void testUploadLeaveFileAndRetrieveFiles() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    Leave__c leaveRecord = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(3),
      Date.today().addDays(3),
      'Submitted'
    );

    Test.startTest();
    PWChrono_RequestAttachmentService.FileDescriptorDTO uploadedFile =
      PWChrono_LeaveController.uploadLeaveFile(
        leaveRecord.Id,
        'medical-note.txt',
        EncodingUtil.base64Encode(Blob.valueOf('hello')),
        String.valueOf(bundle.employee.Id),
        null
      );
    List<PWChrono_RequestAttachmentService.FileDescriptorDTO> files =
      PWChrono_LeaveController.getLeaveFiles(
        leaveRecord.Id,
        String.valueOf(bundle.employee.Id),
        null
      );
    Test.stopTest();

    System.assertNotEquals(null, uploadedFile.contentDocumentId);
    System.assertEquals(1, files.size());
    System.assertEquals('medical-note.txt', files[0].name);

    Leave__c refreshedLeave = [
      SELECT Certificate_Uploaded__c
      FROM Leave__c
      WHERE Id = :leaveRecord.Id
      LIMIT 1
    ];
    System.assertEquals(true, refreshedLeave.Certificate_Uploaded__c);
  }

  @IsTest
  static void testReadOperationsReturnEmployeeAndManagerData() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    Leave__c submittedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(4),
      Date.today().addDays(5),
      'Submitted'
    );
    Leave__c approvedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(7),
      Date.today().addDays(8),
      'Approved'
    );
    PWChrono_Holiday_List__c holidayList = new PWChrono_Holiday_List__c(
      Name = 'National Holidays',
      Is_Active__c = true
    );
    insert holidayList;
    insert new PWChrono_Holiday__c(
      Name = 'National Day',
      Holiday_Date__c = Date.today().addDays(7),
      Holiday_List__c = holidayList.Id
    );

    Test.startTest();
    List<PWChrono_LeaveBalanceService.LeaveBalanceWrapper> balances =
      PWChrono_LeaveController.getMyLeaveBalance(String.valueOf(bundle.employee.Id), null);
    List<Leave__c> myLeaves = PWChrono_LeaveController.getMyLeaves(
      'All',
      null,
      null,
      String.valueOf(bundle.employee.Id),
      null
    );
    Leave__c detail = PWChrono_LeaveController.getLeaveDetail(
      submittedLeave.Id,
      String.valueOf(bundle.employee.Id),
      null
    );
    List<Leave__c> teamPending = PWChrono_LeaveController.getTeamLeavesForApproval(
      String.valueOf(bundle.manager.Id),
      null
    );
    List<Leave__c> teamLeaves = PWChrono_LeaveController.getTeamLeaves(
      'Submitted',
      null,
      null,
      String.valueOf(bundle.manager.Id),
      null
    );
    List<Leave__c> calendarRows = PWChrono_LeaveController.getLeaveCalendarData(
      Date.today().addDays(6),
      Date.today().addDays(9),
      String.valueOf(bundle.employee.Id),
      null
    );
    List<PWChrono_Holiday__c> holidays = PWChrono_LeaveController.getHolidays(
      Date.today().addDays(6),
      Date.today().addDays(9)
    );
    List<PWChrono_Leave_Type__c> leaveTypes = PWChrono_LeaveController.getActiveLeaveTypes(
      false
    );
    Decimal days = PWChrono_LeaveController.calculateWorkingDays(
      Date.today().addDays(10),
      Date.today().addDays(11),
      false,
      bundle.annualLeave.Id
    );
    Test.stopTest();

    System.assert(!balances.isEmpty(), 'Leave balance should be returned.');
    System.assert(myLeaves.size() >= 2, 'Employee should see created leave records.');
    System.assertEquals(submittedLeave.Id, detail.Id);
    System.assert(teamPending.size() >= 1, 'Manager queue should include submitted leave.');
    System.assert(teamLeaves.size() >= 1, 'Manager history should include submitted leave.');
    System.assertEquals(approvedLeave.Id, calendarRows[0].Id);
    System.assertEquals(1, holidays.size());
    System.assert(leaveTypes.size() >= 1, 'Active leave types should be returned.');
    System.assert(days > 0, 'Working days calculation should be positive.');
  }

  @IsTest
  static void testGetActiveLeaveTypes_NoArgAndLeaveDetailNotFound() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c outsider = PWChrono_TestDataFactory.createPortalUser(
      'Leave Outsider',
      'leave-outsider@example.com',
      'Employee'
    );
    outsider.Session_Token__c = 'leave_outsider_token';
    outsider.Session_Expires_At__c = System.now().addHours(1);
    update outsider;
    Leave__c submittedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(14),
      Date.today().addDays(14),
      'Submitted'
    );

    Test.startTest();
    List<PWChrono_Leave_Type__c> leaveTypes = PWChrono_LeaveController.getActiveLeaveTypes();
    try {
      PWChrono_LeaveController.getLeaveDetail(
        'a0B000000000001AAA',
        String.valueOf(bundle.employee.Id),
        null
      );
      System.assert(false, 'Missing leave should throw.');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().length() > 0);
    }
    PWChrono_GuestSession.testNowOverride = System.now();
    try {
      System.runAs(guestUser) {
        try {
          PWChrono_LeaveController.getLeaveDetail(
            submittedLeave.Id,
            String.valueOf(outsider.Id),
            'leave_outsider_token'
          );
          System.assert(false, 'Unauthorized employee should not be able to read another leave.');
        } catch (AuraHandledException e) {
          System.assertNotEquals(null, e.getMessage());
        }
      }
    } finally {
      PWChrono_GuestSession.testNowOverride = null;
    }
    Test.stopTest();

    System.assert(leaveTypes.size() >= 1, 'No-arg leave type lookup should work.');
  }

  @IsTest
  static void testAdminOperationsAndLegacySave() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    PWChrono_Leave_Type__c newType = new PWChrono_Leave_Type__c(
      Name = 'Bereavement Leave',
      Max_Days_Allowed__c = 5,
      Is_Active__c = true,
      Requires_Approval__c = true,
      Allow_Half_Day__c = true
    );

    Test.startTest();
    PWChrono_Leave_Type__c createdType = PWChrono_LeaveController.createLeaveType(
      newType,
      String.valueOf(bundle.admin.Id),
      null
    );
    createdType.Max_Days_Allowed__c = 7;
    PWChrono_Leave_Type__c updatedType = PWChrono_LeaveController.updateLeaveType(
      createdType,
      String.valueOf(bundle.admin.Id),
      null
    );
    PWChrono_LeaveController.adjustLeaveBalance(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      2,
      'Adjustment for testing',
      String.valueOf(bundle.admin.Id),
      null
    );
    Leave__c savedLeave = PWChrono_LeaveController.saveLeaveApplication(
      new Leave__c(
        Leave_Type__c = bundle.annualLeave.Id,
        From_Date__c = Date.today().addDays(12),
        To_Date__c = Date.today().addDays(13),
        Half_Day__c = false,
        Reason__c = 'Legacy save coverage',
        Status__c = 'Submitted'
      ),
      String.valueOf(bundle.employee.Id),
      null
    );
    Test.stopTest();

    PWChrono_Leave_Allocation__c allocation = [
      SELECT Total_Leaves_Allocated__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :bundle.employee.Id AND Leave_Type__c = :bundle.annualLeave.Id
      LIMIT 1
    ];
    System.assertNotEquals(null, createdType.Id);
    System.assertEquals(7, updatedType.Max_Days_Allowed__c);
    System.assertEquals(22, allocation.Total_Leaves_Allocated__c);
    System.assertNotEquals(null, savedLeave.Id);
  }

  @IsTest
  static void testCancelLeave() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    Leave__c submittedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(9),
      Date.today().addDays(10),
      'Submitted'
    );

    Test.startTest();
    Leave__c cancelled = PWChrono_LeaveController.cancelLeave(
      submittedLeave.Id,
      'Plans changed',
      String.valueOf(bundle.employee.Id),
      null
    );
    Test.stopTest();

    System.assertEquals('Cancelled', cancelled.Status__c);
  }

  @IsTest
  static void testAdditionalCoverageForAdminAndAttachmentGuards() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle = getBundle();
    User orphanUser = PWChrono_TestDataFactory.createTestUser('Leave Orphan');
    Leave__c submittedLeave = PWChrono_LeaveTestDataFactory.createLeave(
      bundle.employee.Id,
      bundle.annualLeave.Id,
      bundle.manager.Id,
      Date.today().addDays(15),
      Date.today().addDays(16),
      'Submitted'
    );
    PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
    dto.leaveTypeId = bundle.annualLeave.Id;
    dto.fromDate = Date.today().addDays(17);
    dto.toDate = Date.today().addDays(18);
    dto.reason = 'No employee context';
    dto.halfDay = false;

    List<PWChrono_Leave_Type__c> leaveTypesIncludingInactive =
      PWChrono_LeaveController.getActiveLeaveTypes(true);

    System.runAs(orphanUser) {
      Test.startTest();
      try {
        PWChrono_LeaveController.getMyLeaveBalance(null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getMyLeaves('All', null, null, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getTeamLeavesForApproval(null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getLeaveCalendarData(
          Date.today(),
          Date.today().addDays(1),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.submitLeaveApplication(dto, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getTeamLeaves('All', null, null, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.cancelLeave(submittedLeave.Id, 'No access', null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.processLeaveApproval(
          submittedLeave.Id,
          'Approve',
          'No access',
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.createLeaveType(
          new PWChrono_Leave_Type__c(Name = 'Orphan User Type'),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.adjustLeaveBalance(
          bundle.employee.Id,
          bundle.annualLeave.Id,
          1,
          'No access',
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.saveLeaveApplication(
          new Leave__c(
            Leave_Type__c = bundle.annualLeave.Id,
            From_Date__c = Date.today().addDays(20),
            To_Date__c = Date.today().addDays(20),
            Reason__c = 'No employee context',
            Status__c = 'Submitted'
          ),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getLeaveComments(submittedLeave.Id, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getLeaveFiles(submittedLeave.Id, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.getLeaveLedgerHistory(submittedLeave.Id, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.uploadLeaveFile(
          submittedLeave.Id,
          'no-context.txt',
          EncodingUtil.base64Encode(Blob.valueOf('no employee context')),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_LeaveController.updateLeaveType(
          new PWChrono_Leave_Type__c(
            Id = bundle.annualLeave.Id,
            Name = 'Annual Leave'
          ),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    }

    System.assert(
      leaveTypesIncludingInactive.size() >= 1,
      'The includeInactive leave type lookup should return test leave types.'
    );
  }
}