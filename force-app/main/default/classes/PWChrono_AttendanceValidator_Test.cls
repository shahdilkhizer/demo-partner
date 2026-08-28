/**
 * @description Tests for PWChrono_AttendanceValidator.
 */
@IsTest
private class PWChrono_AttendanceValidator_Test {

  @TestSetup
  static void setup() {
    PWChrono_AttendanceTestDataFactory.setupStandardTestData();
  }

  // ── DTO / time parsing ─────────────────────────────────────────────────

  @IsTest
  static void testParseTime_valid() {
    Time t = PWChrono_AttendanceValidator.parseTime('09:30');
    System.assertEquals(Time.newInstance(9, 30, 0, 0), t, 'Should parse HH:mm correctly');
  }

  @IsTest
  static void testParseTime_blank_returnsNull() {
    Time t = PWChrono_AttendanceValidator.parseTime('');
    System.assertEquals(null, t, 'Blank time should return null');
  }

  @IsTest
  static void testParseTime_malformed_returnsNull() {
    Time t = PWChrono_AttendanceValidator.parseTime('not-a-time');
    System.assertEquals(null, t, 'Malformed time should return null');
  }

  // ── validateNotFuture ─────────────────────────────────────────────────

  @IsTest
  static void testValidateNotFuture_future_returnsError() {
    String error = PWChrono_AttendanceValidator.validateNotFuture(Date.today().addDays(1));
    System.assertNotEquals(null, error, 'Future date should produce an error');
  }

  @IsTest
  static void testValidateNotFuture_today_returnsNull() {
    String error = PWChrono_AttendanceValidator.validateNotFuture(Date.today());
    System.assertEquals(null, error, 'Today should be valid');
  }

  @IsTest
  static void testValidateNotFuture_past_returnsNull() {
    String error = PWChrono_AttendanceValidator.validateNotFuture(Date.today().addDays(-5));
    System.assertEquals(null, error, 'Past date should be valid');
  }

  // ── validateCorrectionType ────────────────────────────────────────────

  @IsTest
  static void testValidateCorrectionType_blank_returnsError() {
    String error = PWChrono_AttendanceValidator.validateCorrectionType('');
    System.assertNotEquals(null, error, 'Blank type should fail');
  }

  @IsTest
  static void testValidateCorrectionType_invalid_returnsError() {
    String error = PWChrono_AttendanceValidator.validateCorrectionType('InvalidType');
    System.assertNotEquals(null, error, 'Invalid type should fail');
  }

  @IsTest
  static void testValidateCorrectionType_valid_returnsNull() {
    for (String ct : new List<String>{
      'Check-In Missing', 'Check-Out Missing', 'Both Missing', 'Wrong Time', 'Other'
    }) {
      String error = PWChrono_AttendanceValidator.validateCorrectionType(ct);
      System.assertEquals(null, error, ct + ' should be valid');
    }
  }

  // ── validateTimeLogic ─────────────────────────────────────────────────

  @IsTest
  static void testValidateTimeLogic_checkInAfterCheckOut_returnsError() {
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      new PWChrono_AttendanceValidator.AttendanceRequestDTO();
    dto.correctionType    = 'Wrong Time';
    dto.requestedCheckIn  = '18:00';
    dto.requestedCheckOut = '09:00';
    String error = PWChrono_AttendanceValidator.validateTimeLogic(dto);
    System.assertNotEquals(null, error, 'Check-in after check-out should fail');
  }

  @IsTest
  static void testValidateTimeLogic_checkInEqualsCheckOut_returnsError() {
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      new PWChrono_AttendanceValidator.AttendanceRequestDTO();
    dto.correctionType    = 'Wrong Time';
    dto.requestedCheckIn  = '09:00';
    dto.requestedCheckOut = '09:00';
    String error = PWChrono_AttendanceValidator.validateTimeLogic(dto);
    System.assertNotEquals(null, error, 'Equal times should fail');
  }

  @IsTest
  static void testValidateTimeLogic_missingRequiredCheckIn_returnsError() {
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      new PWChrono_AttendanceValidator.AttendanceRequestDTO();
    dto.correctionType   = 'Check-In Missing';
    dto.requestedCheckIn = '';
    String error = PWChrono_AttendanceValidator.validateTimeLogic(dto);
    System.assertNotEquals(null, error, 'Missing required check-in should fail');
  }

  @IsTest
  static void testValidateTimeLogic_validTimes_returnsNull() {
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      new PWChrono_AttendanceValidator.AttendanceRequestDTO();
    dto.correctionType    = 'Wrong Time';
    dto.requestedCheckIn  = '09:00';
    dto.requestedCheckOut = '18:00';
    String error = PWChrono_AttendanceValidator.validateTimeLogic(dto);
    System.assertEquals(null, error, 'Valid times should pass');
  }

  // ── validateNotOnApprovedLeave ────────────────────────────────────────

  @IsTest
  static void testNotOnApprovedLeave_noLeave_returnsNull() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    String error = PWChrono_AttendanceValidator.validateNotOnApprovedLeave(
      Date.today().addDays(-20), emp.Id
    );
    System.assertEquals(null, error, 'No leave should return null');
  }

  // ── Full validate() — happy path ──────────────────────────────────────

  @IsTest
  static void testValidate_valid_emptyErrors() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      PWChrono_AttendanceTestDataFactory.buildDTO(Date.today().addDays(-2), 'Wrong Time');

    Test.startTest();
    List<String> errors = PWChrono_AttendanceValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(errors.isEmpty(), 'Valid DTO should produce no errors: ' + String.join(errors, ', '));
  }

  // ── Full validate() — future date ─────────────────────────────────────

  @IsTest
  static void testValidate_futureDate_returnsError() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      PWChrono_AttendanceTestDataFactory.buildDTO(Date.today().addDays(5), 'Wrong Time');

    Test.startTest();
    List<String> errors = PWChrono_AttendanceValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'Future date should produce errors');
  }

  // ── Full validate() — backdated limit ────────────────────────────────

  @IsTest
  static void testValidate_tooOldDate_returnsError() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      PWChrono_AttendanceTestDataFactory.buildDTO(Date.today().addDays(-60), 'Wrong Time');

    Test.startTest();
    List<String> errors = PWChrono_AttendanceValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'Date older than backdate limit should fail');
  }
}