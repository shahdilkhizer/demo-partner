/**
 * @description Test class for PWChrono_LeaveValidator and PWChrono_RequestValidator.
 *              Covers: DTO validation, status transitions, date ranges,
 *              active employee checks, and balance sufficiency.
 */
@SuppressWarnings('PMD.MethodNamingConventions')
@IsTest
private class PWChrono_LeaveValidator_Test {

  @TestSetup
  static void setupTestData() {
    PWChrono_LeaveTestDataFactory.setupStandardTestData();
  }

  static PWChrono_LeaveTestDataFactory.TestDataBundle getBundle() {
    PWChrono_LeaveTestDataFactory.TestDataBundle bundle =
      new PWChrono_LeaveTestDataFactory.TestDataBundle();
    bundle.employee = [
      SELECT Id, Name FROM Portal_Users__c WHERE Name = 'Test Employee' LIMIT 1
    ];
    bundle.annualLeave = [
      SELECT Id, Name, Max_Days_Allowed__c
      FROM PWChrono_Leave_Type__c WHERE Name = 'Annual Leave' LIMIT 1
    ];
    return bundle;
  }

  // ── RequestValidator Tests ──

  @IsTest
  static void testValidateActiveEmployee_Active() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Test.startTest();
    String error = PWChrono_RequestValidator.validateActiveEmployee(b.employee.Id);
    Test.stopTest();

    System.assertEquals(null, error, 'Active employee should pass validation');
  }

  @IsTest
  static void testValidateActiveEmployee_Inactive() {
    Portal_Users__c inactive = PWChrono_LeaveTestDataFactory.createEmployee(
      'Inactive User', false
    );

    Test.startTest();
    String error = PWChrono_RequestValidator.validateActiveEmployee(inactive.Id);
    Test.stopTest();

    System.assertNotEquals(null, error, 'Inactive employee should fail');
    System.assert(error.contains('active'), 'Error should mention active');
  }

  @IsTest
  static void testValidateActiveEmployee_Null() {
    Test.startTest();
    String error = PWChrono_RequestValidator.validateActiveEmployee(null);
    Test.stopTest();

    System.assertNotEquals(null, error, 'Null should fail');
    System.assert(error.contains('required'), 'Error should mention required');
  }

  @IsTest
  static void testValidateDateRange_Valid() {
    String error = PWChrono_RequestValidator.validateDateRange(
      Date.today(), Date.today().addDays(3)
    );
    System.assertEquals(null, error, 'Valid range should pass');
  }

  @IsTest
  static void testValidateDateRange_EndBeforeStart() {
    String error = PWChrono_RequestValidator.validateDateRange(
      Date.today().addDays(3), Date.today()
    );
    System.assertNotEquals(null, error, 'Invalid range should fail');
  }

  @IsTest
  static void testValidateDateRange_NullStart() {
    String error = PWChrono_RequestValidator.validateDateRange(null, Date.today());
    System.assertNotEquals(null, error, 'Null start should fail');
  }

  @IsTest
  static void testValidateDateRange_NullEnd() {
    String error = PWChrono_RequestValidator.validateDateRange(Date.today(), null);
    System.assertNotEquals(null, error, 'Null end should fail');
  }

  @IsTest
  static void testValidateBackdatedLimit_Valid() {
    String error = PWChrono_RequestValidator.validateBackdatedLimit(
      Date.today().addDays(-3), 7
    );
    System.assertEquals(null, error, 'Within limit should pass');
  }

  @IsTest
  static void testValidateBackdatedLimit_TooFarBack() {
    String error = PWChrono_RequestValidator.validateBackdatedLimit(
      Date.today().addDays(-30), 7
    );
    System.assertNotEquals(null, error, 'Beyond limit should fail');
  }

  @IsTest
  static void testValidateAdvanceLimit_Valid() {
    String error = PWChrono_RequestValidator.validateAdvanceLimit(
      Date.today().addDays(10), 30
    );
    System.assertEquals(null, error, 'Within limit should pass');
  }

  @IsTest
  static void testValidateAdvanceLimit_TooFarAhead() {
    String error = PWChrono_RequestValidator.validateAdvanceLimit(
      Date.today().addDays(60), 30
    );
    System.assertNotEquals(null, error, 'Beyond limit should fail');
  }

  // ── Status Transition Tests ──

  @IsTest
  static void testStatusTransitions() {
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Draft', 'Submitted'));
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Draft', 'Cancelled'));
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Submitted', 'Approved'));
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Submitted', 'Rejected'));
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Submitted', 'Cancelled'));
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Approved', 'Cancelled'));
    System.assertEquals(true,
      PWChrono_RequestValidator.isValidStatusTransition('Rejected', 'Draft'));

    // Invalid transitions
    System.assertEquals(false,
      PWChrono_RequestValidator.isValidStatusTransition('Cancelled', 'Submitted'));
    System.assertEquals(false,
      PWChrono_RequestValidator.isValidStatusTransition('Approved', 'Rejected'));
    System.assertEquals(false,
      PWChrono_RequestValidator.isValidStatusTransition('Rejected', 'Approved'));
    System.assertEquals(false,
      PWChrono_RequestValidator.isValidStatusTransition(null, 'Submitted'));
    System.assertEquals(false,
      PWChrono_RequestValidator.isValidStatusTransition('Submitted', null));
  }

  @IsTest
  static void testValidateStatusTransition_Error() {
    String error = PWChrono_RequestValidator.validateStatusTransition(
      'Cancelled', 'Submitted'
    );
    System.assertNotEquals(null, error, 'Invalid transition should return error');
    System.assert(error.contains('Invalid status transition'));
  }

  @IsTest
  static void testValidateStatusTransition_Valid() {
    String error = PWChrono_RequestValidator.validateStatusTransition(
      'Submitted', 'Approved'
    );
    System.assertEquals(null, error, 'Valid transition should return null');
  }

  // ── LeaveValidator.validate Tests ──

  @IsTest
  static void testValidateDTO_Valid() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
    dto.leaveTypeId = b.annualLeave.Id;
    dto.fromDate = Date.today().addDays(5);
    dto.toDate = Date.today().addDays(7);
    dto.totalDays = 3;
    dto.reason = 'Vacation';

    Test.startTest();
    List<String> errors = PWChrono_LeaveValidator.validate(dto, b.employee.Id);
    Test.stopTest();

    System.assertEquals(0, errors.size(),
      'Valid DTO should produce 0 errors. Got: ' + String.join(errors, ' | '));
  }

  @IsTest
  static void testValidateDTO_MissingLeaveType() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
    dto.fromDate = Date.today().addDays(5);
    dto.toDate = Date.today().addDays(7);
    dto.totalDays = 3;
    dto.reason = 'Vacation';

    Test.startTest();
    List<String> errors = PWChrono_LeaveValidator.validate(dto, b.employee.Id);
    Test.stopTest();

    System.assert(errors.size() > 0, 'Missing leave type should fail');
  }

  @IsTest
  static void testValidateDTO_MissingReason() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
    dto.leaveTypeId = b.annualLeave.Id;
    dto.fromDate = Date.today().addDays(5);
    dto.toDate = Date.today().addDays(7);
    dto.totalDays = 3;
    dto.reason = '';

    Test.startTest();
    List<String> errors = PWChrono_LeaveValidator.validate(dto, b.employee.Id);
    Test.stopTest();

    System.assert(errors.size() > 0, 'Missing reason should fail');
  }

  // ── EnforceDataAccess Tests ──

  @IsTest
  static void testEnforceDataAccess_OwnData() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Id result = PWChrono_RequestValidator.enforceDataAccess(
      b.employee.Id, b.employee.Id
    );
    System.assertEquals(b.employee.Id, result, 'Own data should return own Id');
  }

  @IsTest
  static void testEnforceDataAccess_NullTarget() {
    PWChrono_LeaveTestDataFactory.TestDataBundle b = getBundle();

    Id result = PWChrono_RequestValidator.enforceDataAccess(
      b.employee.Id, null
    );
    System.assertEquals(b.employee.Id, result, 'Null target should return own Id');
  }
}