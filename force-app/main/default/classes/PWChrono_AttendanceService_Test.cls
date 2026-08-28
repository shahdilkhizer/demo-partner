/**
 * @description Tests for PWChrono_AttendanceService.
 *              Covers: submitRequest, processApproval, cancelRequest,
 *              getDashboardSummary, and error paths.
 */
@IsTest
private class PWChrono_AttendanceService_Test {
  @TestSetup
  static void setup() {
    PWChrono_AttendanceTestDataFactory.setupStandardTestData();
  }

  // ─────────────────────── submitRequest ────────────────────────────────────

  @IsTest
  static void testSubmitRequest_newRequest_succeeds() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto = PWChrono_AttendanceTestDataFactory.buildDTO(
      Date.today().addDays(-2),
      'Wrong Time'
    );

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceService.submitRequest(
      dto,
      emp.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Should return saved record');
    System.assertEquals(
      'Submitted',
      result.Status__c,
      'Status should be Submitted'
    );
    System.assertEquals(
      Date.today().addDays(-2),
      result.Attendance_Date__c,
      'Date should match'
    );
    System.assertEquals(
      'Wrong Time',
      result.Correction_Type__c,
      'Correction type should match'
    );
  }

  @IsTest
  static void testSubmitRequest_futureDate_throwsException() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto = PWChrono_AttendanceTestDataFactory.buildDTO(
      Date.today().addDays(1),
      'Wrong Time'
    );

    Test.startTest();
    try {
      PWChrono_AttendanceService.submitRequest(dto, emp.Id);
      System.assert(false, 'Should have thrown an exception for future date');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('future'),
        'Error should mention future: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testSubmitRequest_duplicateDate_throwsException() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];

    // Create an existing submitted request on the same date
    Date targetDate = Date.today().addDays(-5);
    PWChrono_AttendanceTestDataFactory.createAttendanceRequest(
      emp.Id,
      mgr.Id,
      targetDate,
      'Check-Out Missing',
      'Submitted'
    );

    PWChrono_AttendanceValidator.AttendanceRequestDTO dto = PWChrono_AttendanceTestDataFactory.buildDTO(
      targetDate,
      'Wrong Time'
    );

    Test.startTest();
    try {
      PWChrono_AttendanceService.submitRequest(dto, emp.Id);
      System.assert(false, 'Should have thrown for duplicate date');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().length() > 0,
        'Should have meaningful error'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testSubmitRequest_approverAutoAssigned() {
    Portal_Users__c emp = [
      SELECT Id, Reports_To__c
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto = PWChrono_AttendanceTestDataFactory.buildDTO(
      Date.today().addDays(-4),
      'Check-In Missing'
    );
    dto.requestedCheckOut = null;

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceService.submitRequest(
      dto,
      emp.Id
    );
    Test.stopTest();

    if (emp.Reports_To__c != null) {
      System.assertEquals(
        emp.Reports_To__c,
        result.Approvers__c,
        'Approver should be Reports_To'
      );
    }
  }

  // ─────────────────────── processApproval ─────────────────────────────────

  @IsTest
  static void testProcessApproval_approve_succeeds() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceService.processApproval(
      req.Id,
      'Approve',
      'Looks good.',
      mgr.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Approved',
      result.Status__c,
      'Status should be Approved'
    );
    System.assertNotEquals(
      null,
      result.Approval_Date__c,
      'Approval date should be set'
    );
    System.assertEquals(
      'Looks good.',
      result.Approver_Comments__c,
      'Comment should be persisted'
    );
  }

  @IsTest
  static void testProcessApproval_reject_requiresComments() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceService.processApproval(req.Id, 'Reject', '', mgr.Id);
      System.assert(false, 'Should have required rejection reason');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('required'),
        'Error should mention required: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testProcessApproval_reject_withReason_succeeds() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceService.processApproval(
      req.Id,
      'Reject',
      'Incorrect details.',
      mgr.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Rejected',
      result.Status__c,
      'Status should be Rejected'
    );
    System.assertEquals(
      'Incorrect details.',
      result.Rejection_Reason__c,
      'Rejection reason should be stored'
    );
  }

  @IsTest
  static void testProcessApproval_selfApproval_throwsException() {
    PWChrono_Attendance_Request__c req = [
      SELECT Id, Employees__c
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceService.processApproval(
        req.Id,
        'Approve',
        '',
        req.Employees__c
      );
      System.assert(false, 'Self-approval should be blocked');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().toLowerCase().contains('self'),
        'Should mention self-approval: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testProcessApproval_notApprover_throwsException() {
    Portal_Users__c other = PWChrono_AttendanceTestDataFactory.createEmployee(
      'Other Employee',
      true
    );
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceService.processApproval(
        req.Id,
        'Approve',
        '',
        other.Id
      );
      System.assert(false, 'Non-approver should be blocked');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().toLowerCase().contains('denied') ||
        e.getMessage().toLowerCase().contains('authorized'),
        'Should mention access denied: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testProcessApproval_alreadyApproved_throwsException() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Approved'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceService.processApproval(req.Id, 'Approve', '', mgr.Id);
      System.assert(
        false,
        'Already-approved request should not be processable'
      );
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Submitted') ||
        e.getMessage().contains('submitted'),
        'Error should mention submitted status requirement'
      );
    }
    Test.stopTest();
  }

  // ─────────────────────── cancelRequest ──────────────────────────────────

  @IsTest
  static void testCancelRequest_byOwner_succeeds() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceService.cancelRequest(
      req.Id,
      'No longer needed.',
      emp.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Cancelled',
      result.Status__c,
      'Status should be Cancelled'
    );
    System.assertNotEquals(
      null,
      result.Cancelled_Date__c,
      'Cancelled date should be set'
    );
    System.assertEquals(
      'No longer needed.',
      result.Cancelled_Reason__c,
      'Reason should be stored'
    );
  }

  @IsTest
  static void testCancelRequest_byNonOwner_throwsException() {
    Portal_Users__c other = PWChrono_AttendanceTestDataFactory.createEmployee(
      'Other Employee',
      true
    );

    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceService.cancelRequest(
        req.Id,
        'Cancel by other',
        other.Id
      );
      System.assert(false, 'Non-owner cancel should be blocked');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().toLowerCase().contains('unauthorized') ||
        e.getMessage().toLowerCase().contains('own'),
        'Should block non-owner: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testCancelRequest_alreadyApproved_followsStatusMachine() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Approved'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceService.cancelRequest(
      req.Id,
      'Want to cancel',
      emp.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Cancelled',
      result.Status__c,
      'Approved requests should follow the shared status machine.'
    );
  }

  // ─────────────────────── getDashboardSummary ────────────────────────────

  @IsTest
  static void testGetDashboardSummary_returnsData() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    Date startDate = Date.today().addDays(-Date.today().day() + 1); // first of month
    Date endDate = Date.today();

    Test.startTest();
    PWChrono_AttendanceService.AttendanceDashboardDTO dto = PWChrono_AttendanceService.getDashboardSummary(
      emp.Id,
      startDate,
      endDate
    );
    Test.stopTest();

    System.assertNotEquals(null, dto, 'Should return a DTO');
    System.assertNotEquals(
      null,
      dto.recentRequests,
      'recentRequests should not be null'
    );
  }
}