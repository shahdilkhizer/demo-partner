/**
 * @description Tests for PWChrono_AttendanceSelector.
 *              Verifies every query method returns expected data
 *              using the standard test data factory.
 */
@IsTest
private class PWChrono_AttendanceSelector_Test {

  @TestSetup
  static void setup() {
    PWChrono_AttendanceTestDataFactory.setupStandardTestData();
  }

  // ─────────────────────── getRequestById ──────────────────────────────────

  @IsTest
  static void testGetRequestById_existingId_returnsRecord() {
    PWChrono_Attendance_Request__c req = [
      SELECT Id FROM PWChrono_Attendance_Request__c LIMIT 1
    ];

    Test.startTest();
    PWChrono_Attendance_Request__c result =
      PWChrono_AttendanceSelector.getRequestById(req.Id);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a record');
    System.assertEquals(req.Id, result.Id, 'Should return the correct record');
    System.assertNotEquals(null, result.Status__c, 'Status should be populated');
  }

  @IsTest
  static void testGetRequestById_bogusId_returnsNull() {
    Test.startTest();
    PWChrono_Attendance_Request__c result =
      PWChrono_AttendanceSelector.getRequestById('001000000000000AAA');
    Test.stopTest();

    System.assertEquals(null, result, 'Should return null for non-existent Id');
  }

  // ─────────────────────── getRequestsByEmployee ───────────────────────────

  @IsTest
  static void testGetRequestsByEmployee_noFilters_returnsAll() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getRequestsByEmployee(emp.Id, 'All', null, null);
    Test.stopTest();

    System.assert(result.size() >= 2, 'Should return all requests for employee');
  }

  @IsTest
  static void testGetRequestsByEmployee_statusFilter_returnsFiltered() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getRequestsByEmployee(emp.Id, 'Submitted', null, null);
    Test.stopTest();

    for (PWChrono_Attendance_Request__c req : result) {
      System.assertEquals('Submitted', req.Status__c, 'All returned records should be Submitted');
    }
  }

  @IsTest
  static void testGetRequestsByEmployee_dateRange_returnsFiltered() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    Date startDate = Date.today().addDays(-30);
    Date endDate   = Date.today();

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getRequestsByEmployee(emp.Id, null, startDate, endDate);
    Test.stopTest();

    for (PWChrono_Attendance_Request__c req : result) {
      System.assert(req.Attendance_Date__c >= startDate &&
                    req.Attendance_Date__c <= endDate,
                    'All records should be within the date range');
    }
  }

  // ─────────────────────── getRecentRequestsByEmployee ─────────────────────

  @IsTest
  static void testGetRecentRequestsByEmployee_returnsUpToFive() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getRecentRequestsByEmployee(emp.Id);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    System.assert(result.size() <= 5, 'Should return at most 5 records');
    System.assert(result.size() >= 1, 'Should return at least 1 record');
  }

  // ─────────────────────── getTeamRequestsForApproval ──────────────────────

  @IsTest
  static void testGetTeamRequestsForApproval_returnsSubmittedOnly() {
    Portal_Users__c mgr = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Manager' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getTeamRequestsForApproval(mgr.Id);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    for (PWChrono_Attendance_Request__c req : result) {
      System.assertEquals(
        PWChrono_Constants.STATUS_SUBMITTED,
        req.Status__c,
        'Only Submitted requests should appear in approvals queue'
      );
    }
  }

  // ─────────────────────── getTeamRequests ─────────────────────────────────

  @IsTest
  static void testGetTeamRequests_allStatuses_returnsAll() {
    Portal_Users__c mgr = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Manager' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getTeamRequests(mgr.Id, 'All');
    Test.stopTest();

    System.assert(result.size() >= 2, 'Should return at least 2 records (Submitted + Approved)');
  }

  @IsTest
  static void testGetTeamRequests_approvedFilter_returnsApprovedOnly() {
    Portal_Users__c mgr = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Manager' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getTeamRequests(mgr.Id, 'Approved');
    Test.stopTest();

    for (PWChrono_Attendance_Request__c req : result) {
      System.assertEquals('Approved', req.Status__c, 'All returned records should be Approved');
    }
  }

  // ─────────────────────── getActiveRequestsByEmployeeAndDate ──────────────

  @IsTest
  static void testGetActiveRequestsByEmployeeAndDate_existingDate_returnsRecord() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    PWChrono_Attendance_Request__c req = [
      SELECT Id, Attendance_Date__c
      FROM PWChrono_Attendance_Request__c
      WHERE Employees__c = :emp.Id AND Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getActiveRequestsByEmployeeAndDate(
        emp.Id, req.Attendance_Date__c, null
      );
    Test.stopTest();

    System.assert(result.size() >= 1, 'Should find the existing active request on that date');
  }

  @IsTest
  static void testGetActiveRequestsByEmployeeAndDate_withExcludeId_excludesRecord() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    PWChrono_Attendance_Request__c req = [
      SELECT Id, Attendance_Date__c
      FROM PWChrono_Attendance_Request__c
      WHERE Employees__c = :emp.Id AND Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getActiveRequestsByEmployeeAndDate(
        emp.Id, req.Attendance_Date__c, req.Id
      );
    Test.stopTest();

    for (PWChrono_Attendance_Request__c r : result) {
      System.assertNotEquals(req.Id, r.Id, 'Excluded Id should not appear in results');
    }
  }

  @IsTest
  static void testGetActiveRequestsByEmployeeAndDate_noRecord_returnsEmpty() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getActiveRequestsByEmployeeAndDate(
        emp.Id, Date.today().addDays(-90), null  // far past date unlikely to have test data
      );
    Test.stopTest();

    System.assertEquals(0, result.size(), 'Should return empty list for date with no requests');
  }

  // ─────────────────────── getApprovedLeaveCoveringDate ────────────────────

  @IsTest
  static void testGetApprovedLeaveCoveringDate_noLeave_returnsEmpty() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Leave__c> result =
      PWChrono_AttendanceSelector.getApprovedLeaveCoveringDate(emp.Id, Date.today().addDays(-10));
    Test.stopTest();

    // Standard test data does not create leave records, so result should be empty
    System.assertNotEquals(null, result, 'Should return a list (not null)');
    System.assertEquals(0, result.size(), 'No approved leave expected in standard test data');
  }

  // ─────────────────────── getRequestsInRange ─────────────────────────────

  @IsTest
  static void testGetRequestsInRange_fullMonth_returnsRequests() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    Date startDate = Date.today().addDays(-30);
    Date endDate   = Date.today();

    Test.startTest();
    List<PWChrono_Attendance_Request__c> result =
      PWChrono_AttendanceSelector.getRequestsInRange(emp.Id, startDate, endDate);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    System.assert(result.size() >= 1, 'Should return at least 1 request in range');
    for (PWChrono_Attendance_Request__c req : result) {
      System.assert(req.Attendance_Date__c >= startDate &&
                    req.Attendance_Date__c <= endDate,
                    'Each record date should be within requested range');
    }
  }

  // ─────────────────────── getShiftForDate ─────────────────────────────────

  @IsTest
  static void testGetShiftForDate_withAssignment_returnsShift() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    PWChrono_Shift_Assignment__c result =
      PWChrono_AttendanceSelector.getShiftForDate(emp.Id, Date.today());
    Test.stopTest();

    // Standard test data creates a shift assignment covering today
    System.assertNotEquals(null, result, 'Should return a shift assignment for today');
    System.assertNotEquals(null, result.Shift_Type__r, 'Shift type should be populated');
  }

  @IsTest
  static void testGetShiftForDate_noAssignment_returnsNull() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    PWChrono_Shift_Assignment__c result =
      PWChrono_AttendanceSelector.getShiftForDate(emp.Id, Date.today().addYears(10));
    Test.stopTest();

    System.assertEquals(null, result, 'Should return null for a date with no shift assignment');
  }

  // ─────────────────────── getMonthlyRequestCounts ─────────────────────────

  @IsTest
  static void testGetMonthlyRequestCounts_returnsCountMap() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    Date startDate = Date.today().addDays(-30);
    Date endDate   = Date.today();

    Test.startTest();
    Map<String, Integer> result =
      PWChrono_AttendanceSelector.getMonthlyRequestCounts(emp.Id, startDate, endDate);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a map');
    System.assert(result.containsKey('Submitted'), 'Map should have Submitted key');
    System.assert(result.containsKey('Approved'),  'Map should have Approved key');
    System.assert(result.containsKey('Rejected'),  'Map should have Rejected key');
    System.assert(result.containsKey('Cancelled'), 'Map should have Cancelled key');
    System.assert(result.get('Submitted') >= 1,    'Should have at least 1 Submitted request');
    System.assert(result.get('Approved')  >= 1,    'Should have at least 1 Approved request');
  }

  @IsTest
  static void testGetMonthlyRequestCounts_emptyRange_returnsZeros() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    Date startDate = Date.today().addDays(-200);
    Date endDate   = Date.today().addDays(-100);

    Test.startTest();
    Map<String, Integer> result =
      PWChrono_AttendanceSelector.getMonthlyRequestCounts(emp.Id, startDate, endDate);
    Test.stopTest();

    System.assertEquals(0, result.get('Submitted'), 'Should be 0 for empty range');
    System.assertEquals(0, result.get('Approved'),  'Should be 0 for empty range');
  }
}