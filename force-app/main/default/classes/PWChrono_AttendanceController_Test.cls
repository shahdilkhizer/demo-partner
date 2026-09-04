/**
 * @description Tests for PWChrono_AttendanceController.
 *              Covers new framework methods and legacy method delegation.
 */
@IsTest
private class PWChrono_AttendanceController_Test {
  @TestSetup
  static void setup() {
    PWChrono_AttendanceTestDataFactory.setupStandardTestData();
  }

  // ─────────────────────── getMyAttendanceRequestList ──────────────────────

  @IsTest
  static void testGetMyAttendanceRequestList_returnsRequests() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'Test Employee'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result = PWChrono_AttendanceController.getMyAttendanceRequestList(
      'All',
      null,
      null,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    System.assert(result.size() >= 2, 'Should have at least 2 test requests');
  }

  @IsTest
  static void testGetMyAttendanceRequestList_filteredByStatus() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result = PWChrono_AttendanceController.getMyAttendanceRequestList(
      'Submitted',
      null,
      null,
      emp.Id,
      null
    );
    Test.stopTest();

    for (PWChrono_Attendance_Request__c req : result) {
      System.assertEquals(
        'Submitted',
        req.Status__c,
        'All results should be Submitted'
      );
    }
  }

  // ─────────────────────── getAttendanceRequestDetail ──────────────────────

  @IsTest
  static void testGetAttendanceRequestDetail_owner_succeeds() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.getAttendanceRequestDetail(
      req.Id,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(req.Id, result.Id, 'Should return correct record');
  }

  @IsTest
  static void testGetAttendanceRequestDetail_notFound_throwsException() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceController.getAttendanceRequestDetail(
        '001000000000000AAA',
        emp.Id,
        null
      );
      System.assert(false, 'Should throw for missing record');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().length() > 0,
        'Should return a user-friendly error'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testGetAttendanceRequestDetail_unauthorized_throwsException() {
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c outsider = PWChrono_TestDataFactory.createPortalUser(
      'Attendance Outsider',
      'attendance-outsider@example.com',
      'Employee'
    );
    outsider.Session_Token__c = 'attendance_outsider_token';
    outsider.Session_Expires_At__c = System.now().addHours(1);
    update outsider;

    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'Test Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    PWChrono_GuestSession.testNowOverride = System.now();
    try {
      System.runAs(guestUser) {
        Test.startTest();
        try {
          PWChrono_AttendanceController.getAttendanceRequestDetail(
            req.Id,
            outsider.Id,
            'attendance_outsider_token'
          );
          System.assert(
            false,
            'Unauthorized employee should not be able to read another request.'
          );
        } catch (AuraHandledException e) {
          System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
      }
    } finally {
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  // ─────────────────────── submitAttendanceRequest ────────────────────────

  @IsTest
  static void testSubmitAttendanceRequest_succeeds() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto = PWChrono_AttendanceTestDataFactory.buildDTO(
      Date.today().addDays(-7),
      'Wrong Time'
    );

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.submitAttendanceRequest(
      dto,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertEquals('Submitted', result.Status__c, 'Should be Submitted');
  }

  // ─────────────────────── cancelAttendanceRequest ────────────────────────

  @IsTest
  static void testCancelAttendanceRequest_succeeds() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.cancelAttendanceRequest(
      req.Id,
      'Not needed',
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertEquals('Cancelled', result.Status__c, 'Should be Cancelled');
  }

  // ─────────────────────── getTeamAttendanceRequestsForApproval ────────────

  @IsTest
  static void testGetTeamAttendanceRequestsForApproval_returnsRequests() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result = PWChrono_AttendanceController.getTeamAttendanceRequestsForApproval(
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    for (PWChrono_Attendance_Request__c req : result) {
      System.assertEquals(
        'Submitted',
        req.Status__c,
        'Only submitted should appear in approvals queue'
      );
    }
  }

  @IsTest
  static void testGetTeamAttendanceRequests_returnsHistory() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result = PWChrono_AttendanceController.getTeamAttendanceRequests(
      'All',
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      result.size() >= 2,
      'Manager history should include submitted and approved requests.'
    );
  }

  // ─────────────────────── processAttendanceCorrectionApproval ────────────

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
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.processAttendanceCorrectionApproval(
      req.Id,
      'Approve',
      'LGTM',
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assertEquals('Approved', result.Status__c);
  }

  @IsTest
  static void testProcessAttendanceCorrectionApproval_reject_succeeds() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = new PWChrono_Attendance_Request__c(
      Employees__c = emp.Id,
      Approvers__c = mgr.Id,
      Attendance_Date__c = Date.today().addDays(-11),
      Correction_Type__c = 'Wrong Time',
      From_Time__c = Time.newInstance(10, 0, 0, 0),
      To_Time__c = Time.newInstance(17, 0, 0, 0),
      Reason__c = 'Reject through new method',
      Status__c = 'Submitted',
      Applied_Date__c = Date.today()
    );
    insert req;

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.processAttendanceCorrectionApproval(
      req.Id,
      'Reject',
      'Rejected in controller test',
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assertEquals('Rejected', result.Status__c);
  }

  // ─────────────────────── getAttendanceDashboardSummary ──────────────────

  @IsTest
  static void testGetAttendanceDashboardSummary_returnsData() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    Date startDate = Date.today().addDays(-30);
    Date endDate = Date.today();

    Test.startTest();
    PWChrono_AttendanceService.AttendanceDashboardDTO result = PWChrono_AttendanceController.getAttendanceDashboardSummary(
      startDate,
      endDate,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.recentRequests);
  }

  // ─────────────────────── getAttendanceTrackerData ────────────────────────

  @IsTest
  static void testGetAttendanceTrackerData_returnsData() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_AttendanceController.AttendanceDayWrapper> result = PWChrono_AttendanceController.getAttendanceTrackerData(
      Date.today().addDays(-7),
      Date.today(),
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(
      8,
      result.size(),
      'Should return 8 days (addDays -7 to today inclusive)'
    );
  }

  @IsTest
  static void testGetAttendanceTrackerDataForEmployee_adminCanViewSelectedEmployee() {
    Portal_Users__c admin = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'HR Admin'
      LIMIT 1
    ];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_AttendanceController.AttendanceDayWrapper> result = PWChrono_AttendanceController.getAttendanceTrackerDataForEmployee(
      Date.today().addDays(-2),
      Date.today(),
      employee.Id,
      admin.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(3, result.size());
    System.assertEquals('Test Employee', result[0].employeeName);
  }

  @IsTest
  static void testGetAttendanceTrackerDataForEmployee_rejectsInactiveTarget() {
    Portal_Users__c admin = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'HR Admin'
      LIMIT 1
    ];
    Portal_Users__c inactiveEmployee = PWChrono_AttendanceTestDataFactory.createEmployee(
      'Inactive Attendance Employee',
      false
    );

    Test.startTest();
    try {
      PWChrono_AttendanceController.getAttendanceTrackerDataForEmployee(
        Date.today(),
        Date.today(),
        inactiveEmployee.Id,
        admin.Id,
        null
      );
      System.assert(false, 'Inactive employees must not be available.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @IsTest
  static void testGetAttendanceAdminRows_listsEveryActiveEmployee() {
    Integer activeEmployeeCount = [
      SELECT COUNT()
      FROM Portal_Users__c
      WHERE Is_Active__c = TRUE
    ];
    Date attendanceDate = Date.today().addDays(-10);

    Test.startTest();
    List<PWChrono_AttendanceController.AttendanceAdminRow> rows = PWChrono_AttendanceController.getAttendanceAdminRows(
      attendanceDate,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(activeEmployeeCount, rows.size());
    Boolean foundEmployee = false;
    for (PWChrono_AttendanceController.AttendanceAdminRow row : rows) {
      if (row.employeeName == 'Test Employee') {
        foundEmployee = true;
        System.assertEquals(attendanceDate, row.attendanceDate);
        System.assertNotEquals(null, row.status);
      }
    }
    System.assert(
      foundEmployee,
      'The employee must appear in the admin table.'
    );
  }

  @IsTest
  static void testBuildTrackerData_coversStatusVariants() {
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
    PWChrono_Shift_Type__c shiftType = PWChrono_AttendanceTestDataFactory.createShiftType(
      'Coverage Shift',
      Time.newInstance(9, 0, 0, 0),
      Time.newInstance(18, 0, 0, 0)
    );

    Date saturday = Date.today().addDays(-7);
    while (
      DateTime.newInstance(saturday.year(), saturday.month(), saturday.day())
        .format('EEEE') != 'Saturday'
    ) {
      saturday = saturday.addDays(-1);
    }
    Date holidayDate = saturday.addDays(2);
    Date leaveDate = saturday.addDays(3);
    Date requestDate = saturday.addDays(4);
    Date futureDate = Date.today().addDays(2);

    PWChrono_AttendanceTestDataFactory.createShiftAssignment(
      emp.Id,
      shiftType.Id,
      saturday,
      futureDate
    );

    PWChrono_Leave_Type__c leaveType = PWChrono_TestDataFactory.createLeaveType(
      'Attendance Coverage Leave',
      5
    );
    insert new Leave__c(
      Employees__c = emp.Id,
      Leave_Type__c = leaveType.Id,
      Approvers__c = mgr.Id,
      From_Date__c = leaveDate,
      To_Date__c = leaveDate,
      Reason__c = 'Attendance tracker leave',
      Status__c = 'Approved'
    );

    PWChrono_Holiday_List__c holidayList = new PWChrono_Holiday_List__c(
      Name = 'Attendance Coverage Holidays',
      Is_Active__c = true
    );
    insert holidayList;
    insert new PWChrono_Holiday__c(
      Name = 'Attendance Coverage Holiday',
      Holiday_Date__c = holidayDate,
      Holiday_List__c = holidayList.Id
    );

    insert new PWChrono_Attendance_Request__c(
      Employees__c = emp.Id,
      Approvers__c = mgr.Id,
      Attendance_Date__c = requestDate,
      Correction_Type__c = 'Wrong Time',
      From_Time__c = Time.newInstance(10, 0, 0, 0),
      To_Time__c = Time.newInstance(17, 0, 0, 0),
      Reason__c = 'Late and early leave coverage',
      Status__c = 'Submitted',
      Applied_Date__c = Date.today()
    );

    Test.startTest();
    List<PWChrono_AttendanceController.AttendanceDayWrapper> rows = PWChrono_AttendanceController.buildTrackerData(
      emp.Id,
      saturday,
      futureDate
    );
    Test.stopTest();

    Map<Date, PWChrono_AttendanceController.AttendanceDayWrapper> rowsByDate = new Map<Date, PWChrono_AttendanceController.AttendanceDayWrapper>();
    for (PWChrono_AttendanceController.AttendanceDayWrapper row : rows) {
      rowsByDate.put(row.attendanceDate, row);
    }

    System.assertEquals('Weekend', rowsByDate.get(saturday).status);
    System.assertEquals('Holiday', rowsByDate.get(holidayDate).status);
    System.assertEquals('Leave', rowsByDate.get(leaveDate).status);
    System.assertEquals('Late', rowsByDate.get(requestDate).status);
    System.assertEquals(true, rowsByDate.get(requestDate).isEarlyLeave);
    System.assertEquals('Future', rowsByDate.get(futureDate).status);
  }

  // ─────────────────────── Legacy: saveAttendanceRequest ───────────────────

  @IsTest
  static void testSaveAttendanceRequest_legacy_succeeds() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = new PWChrono_Attendance_Request__c(
      Attendance_Date__c = Date.today().addDays(-8),
      Correction_Type__c = 'Check-Out Missing',
      Reason__c = 'Legacy test',
      Status__c = 'Submitted'
    );

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.saveAttendanceRequest(
      req,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result.Id);
    System.assertEquals(
      emp.Id,
      result.Employees__c,
      'Should enforce employee ownership'
    );
  }

  // ─────────────────────── getActiveShiftTypes ────────────────────────────

  @IsTest
  static void testGetActiveShiftTypes_returnsShifts() {
    Test.startTest();
    List<PWChrono_Shift_Type__c> result = PWChrono_AttendanceController.getActiveShiftTypes();
    Test.stopTest();

    System.assert(
      result.size() >= 1,
      'Should return at least the test shift type'
    );
  }

  @IsTest
  static void testGetAttendanceCommentsAndAddComment_workTogether() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_RequestCommentService.RequestCommentDTO created = PWChrono_AttendanceController.addAttendanceComment(
      req.Id,
      'Need approval quickly.',
      emp.Id,
      null
    );
    List<PWChrono_RequestCommentService.RequestCommentDTO> comments = PWChrono_AttendanceController.getAttendanceComments(
      req.Id,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, created.commentId);
    System.assert(
      comments.size() >= 1,
      'Comment thread should include the new comment.'
    );
  }

  @IsTest
  static void testAddAttendanceComment_blankThrows() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_AttendanceController.addAttendanceComment(
        req.Id,
        '',
        emp.Id,
        null
      );
      System.assert(false, 'Blank comments should be rejected.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @IsTest
  static void testGetAttendanceFilesAndUploadFile_workTogether() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_RequestAttachmentService.FileDescriptorDTO uploaded = PWChrono_AttendanceController.uploadAttendanceFile(
      req.Id,
      'attendance-proof.txt',
      EncodingUtil.base64Encode(Blob.valueOf('attendance proof')),
      'text/plain',
      emp.Id,
      null
    );
    List<PWChrono_RequestAttachmentService.FileDescriptorDTO> files = PWChrono_AttendanceController.getAttendanceFiles(
      req.Id,
      emp.Id,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, uploaded.contentDocumentId);
    System.assert(files.size() >= 1, 'Uploaded file should be retrievable.');
  }

  @IsTest
  static void testGetMyShiftAssignments_returnsAssignments() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Shift_Assignment__c> result = PWChrono_AttendanceController.getMyShiftAssignments(
      Date.today().addDays(-5),
      Date.today().addDays(5),
      emp.Id,
      null
    );
    Test.stopTest();

    System.assert(
      result.size() >= 1,
      'Employee should have a shift assignment.'
    );
  }

  @IsTest
  static void testGetTeamShiftAssignments_returnsAssignments() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Shift_Assignment__c> result = PWChrono_AttendanceController.getTeamShiftAssignments(
      Date.today().addDays(-5),
      Date.today().addDays(5),
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      result.size() >= 1,
      'Manager should see team shift assignments.'
    );
  }

  @IsTest
  static void testGetAllAttendanceAndLegacyListMethods() {
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
    Date targetDate = Date.today().addDays(-3);

    Test.startTest();
    List<PWChrono_Attendance_Request__c> allRows = PWChrono_AttendanceController.getAllAttendance(
      targetDate,
      null,
      null
    );
    List<PWChrono_Attendance_Request__c> mine = PWChrono_AttendanceController.getMyAttendanceRequests(
      'All',
      null,
      null,
      emp.Id,
      null
    );
    List<PWChrono_Attendance_Request__c> approvals = PWChrono_AttendanceController.getTeamAttendanceForApproval(
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      allRows.size() >= 1,
      'Admin list should include test attendance rows.'
    );
    System.assert(mine.size() >= 2, 'Legacy employee list should still work.');
    System.assert(
      approvals.size() >= 1,
      'Legacy approval queue should still work.'
    );
  }

  @IsTest
  static void testCreateAndUpdateShiftType_adminFlow() {
    PWChrono_Shift_Type__c shiftType = new PWChrono_Shift_Type__c(
      Name = 'Night Shift',
      Start_Time__c = Time.newInstance(22, 0, 0, 0),
      End_Time__c = Time.newInstance(6, 0, 0, 0),
      Working_Hours__c = 8,
      Grace_Period_Minutes__c = 10,
      Is_Active__c = true
    );

    Test.startTest();
    PWChrono_Shift_Type__c created = PWChrono_AttendanceController.createShiftType(
      shiftType,
      null,
      null
    );
    created.Grace_Period_Minutes__c = 20;
    PWChrono_Shift_Type__c updated = PWChrono_AttendanceController.updateShiftType(
      created,
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, created.Id);
    System.assertEquals(20, updated.Grace_Period_Minutes__c);
  }

  @IsTest
  static void testLegacyProcessAttendanceApproval_rejects() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = new PWChrono_Attendance_Request__c(
      Employees__c = emp.Id,
      Approvers__c = mgr.Id,
      Attendance_Date__c = Date.today().addDays(-6),
      Correction_Type__c = 'Wrong Time',
      From_Time__c = Time.newInstance(10, 0, 0, 0),
      To_Time__c = Time.newInstance(18, 0, 0, 0),
      Reason__c = 'Legacy reject',
      Status__c = 'Submitted',
      Applied_Date__c = Date.today()
    );
    insert req;

    Test.startTest();
    PWChrono_Attendance_Request__c result = PWChrono_AttendanceController.processAttendanceApproval(
      req.Id,
      'Reject',
      'Needs better evidence',
      mgr.Id,
      null
    );
    Test.stopTest();

    System.assertEquals('Rejected', result.Status__c);
  }

  @IsTest
  static void testAdminGuestAndNotFoundBranches() {
    User orphanUser = PWChrono_TestDataFactory.createTestUser(
      'Attendance Orphan'
    );
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'Test Employee'
      LIMIT 1
    ];
    PWChrono_Attendance_Request__c req = [
      SELECT Id
      FROM PWChrono_Attendance_Request__c
      WHERE Employees__c = :emp.Id
      LIMIT 1
    ];

    System.runAs(orphanUser) {
      Test.startTest();
      try {
        PWChrono_AttendanceController.getAttendanceDashboardSummary(
          Date.today().addDays(-7),
          Date.today(),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getMyAttendanceRequestList(
          'All',
          null,
          null,
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.submitAttendanceRequest(
          PWChrono_AttendanceTestDataFactory.buildDTO(
            Date.today().addDays(-2),
            'Wrong Time'
          ),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getTeamAttendanceRequestsForApproval(
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getTeamAttendanceRequests(
          'All',
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getAttendanceTrackerData(
          Date.today().addDays(-3),
          Date.today(),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getMyShiftAssignments(
          Date.today().addDays(-3),
          Date.today(),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.processAttendanceApproval(
          req.Id,
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
        PWChrono_AttendanceController.cancelAttendanceRequest(
          req.Id,
          'No access',
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.processAttendanceCorrectionApproval(
          req.Id,
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
        PWChrono_AttendanceController.getAttendanceComments(req.Id, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.addAttendanceComment(
          req.Id,
          'No access',
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getAttendanceFiles(req.Id, null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.uploadAttendanceFile(
          req.Id,
          'null-context.txt',
          EncodingUtil.base64Encode(Blob.valueOf('no employee context')),
          'text/plain',
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getTeamShiftAssignments(
          Date.today().addDays(-3),
          Date.today(),
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getMyAttendanceRequests(
          'All',
          null,
          null,
          null,
          null
        );
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.getTeamAttendanceForApproval(null, null);
        System.assert(false, 'Missing employee context should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_AttendanceController.saveAttendanceRequest(
          new PWChrono_Attendance_Request__c(
            Attendance_Date__c = Date.today().addDays(-1),
            Correction_Type__c = 'Wrong Time',
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
      Test.stopTest();
    }

    try {
      PWChrono_AttendanceController.getAttendanceComments(
        '001000000000000AAA',
        emp.Id,
        null
      );
      System.assert(false, 'Missing attendance request comments should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_AttendanceController.getAttendanceFiles(
        '001000000000000AAA',
        emp.Id,
        null
      );
      System.assert(false, 'Missing attendance request files should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_AttendanceController.uploadAttendanceFile(
        '001000000000000AAA',
        'missing.txt',
        EncodingUtil.base64Encode(Blob.valueOf('missing')),
        'text/plain',
        emp.Id,
        null
      );
      System.assert(
        false,
        'Uploading against a missing attendance request should throw.'
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_AttendanceController.addAttendanceComment(
        '001000000000000AAA',
        'Should fail',
        emp.Id,
        null
      );
      System.assert(
        false,
        'Adding comments to a missing attendance request should throw.'
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void testGuestAdminMethodsRejectNonAdminSession() {
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c guestEmployee = PWChrono_TestDataFactory.createPortalUser(
      'Attendance Guest Non Admin',
      'attendance-guest-non-admin@example.com',
      'Employee'
    );
    guestEmployee.Session_Token__c = 'attendance_guest_non_admin_token';
    guestEmployee.Session_Expires_At__c = System.now().addHours(1);
    guestEmployee.Session_Failed_Attempts__c = 0;
    guestEmployee.Session_Locked_Until__c = null;
    update guestEmployee;

    PWChrono_GuestSession.testNowOverride = System.now();
    try {
      System.runAs(guestUser) {
        Test.startTest();
        try {
          PWChrono_AttendanceController.getAllAttendance(
            Date.today().addDays(-3),
            guestEmployee.Id,
            'attendance_guest_non_admin_token'
          );
          System.assert(
            false,
            'Guest non-admin users should not access admin attendance views.'
          );
        } catch (AuraHandledException e) {
          System.assertNotEquals(null, e.getMessage());
        }

        try {
          PWChrono_AttendanceController.createShiftType(
            new PWChrono_Shift_Type__c(
              Name = 'Denied Guest Shift',
              Start_Time__c = Time.newInstance(8, 0, 0, 0),
              End_Time__c = Time.newInstance(16, 0, 0, 0),
              Working_Hours__c = 8,
              Grace_Period_Minutes__c = 5,
              Is_Active__c = true
            ),
            guestEmployee.Id,
            'attendance_guest_non_admin_token'
          );
          System.assert(
            false,
            'Guest non-admin users should not create shift types.'
          );
        } catch (AuraHandledException e) {
          System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
      }
    } finally {
      PWChrono_GuestSession.testNowOverride = null;
    }
  }
}