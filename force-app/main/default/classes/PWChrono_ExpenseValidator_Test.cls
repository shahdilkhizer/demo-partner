/**
 * @description Tests for PWChrono_ExpenseValidator.
 *              Covers: validate, validateNotFuture, validateItemType, computeTotal.
 */
@IsTest
private class PWChrono_ExpenseValidator_Test {

  // ─────────────────────── validate ─────────────────────────────────────────

  @IsTest
  static void testValidate_validDTO_returnsNoErrors() {
    PWChrono_ExpenseTestDataFactory.TestDataBundle bundle =
      PWChrono_ExpenseTestDataFactory.setupStandardTestData();

    PWChrono_ExpenseValidator.ExpenseClaimDTO dto =
      PWChrono_ExpenseTestDataFactory.buildClaimDTO(null, Date.today().addDays(-5));

    Test.startTest();
    List<String> errors = PWChrono_ExpenseValidator.validate(dto, bundle.employee.Id);
    Test.stopTest();

    System.assert(errors.isEmpty(), 'Valid DTO should produce no errors: ' + errors);
  }

  @IsTest
  static void testValidate_nullDTO_returnsError() {
    Portal_Users__c emp = new Portal_Users__c(Name='E', Is_Active__c=true, Role__c='Employee',
      Date_Of_Joining__c=Date.today().addYears(-1));
    insert emp;

    Test.startTest();
    List<String> errors = PWChrono_ExpenseValidator.validate(null, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'Null DTO should produce at least one error');
  }

  @IsTest
  static void testValidate_noItems_returnsError() {
    Portal_Users__c emp = new Portal_Users__c(Name='E', Is_Active__c=true, Role__c='Employee',
      Date_Of_Joining__c=Date.today().addYears(-1));
    insert emp;

    PWChrono_ExpenseValidator.ExpenseClaimDTO dto =
      PWChrono_ExpenseTestDataFactory.buildClaimDTO(null, Date.today().addDays(-5));
    dto.items = new List<PWChrono_ExpenseValidator.ExpenseItemDTO>();

    Test.startTest();
    List<String> errors = PWChrono_ExpenseValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'No items should produce an error');
  }

  @IsTest
  static void testValidate_missingDescription_returnsError() {
    Portal_Users__c emp = new Portal_Users__c(Name='E', Is_Active__c=true, Role__c='Employee',
      Date_Of_Joining__c=Date.today().addYears(-1));
    insert emp;

    PWChrono_ExpenseValidator.ExpenseClaimDTO dto =
      PWChrono_ExpenseTestDataFactory.buildClaimDTO(null, Date.today().addDays(-5));
    dto.description = null;

    Test.startTest();
    List<String> errors = PWChrono_ExpenseValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'Missing description should produce an error');
  }

  @IsTest
  static void testValidate_futureClaimDate_returnsError() {
    Portal_Users__c emp = new Portal_Users__c(Name='E', Is_Active__c=true, Role__c='Employee',
      Date_Of_Joining__c=Date.today().addYears(-1));
    insert emp;

    PWChrono_ExpenseValidator.ExpenseClaimDTO dto =
      PWChrono_ExpenseTestDataFactory.buildClaimDTO(null, Date.today().addDays(5));

    Test.startTest();
    List<String> errors = PWChrono_ExpenseValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'Future claim date should produce an error');
  }

  @IsTest
  static void testValidate_exceedsBackdatedLimit_returnsError() {
    Portal_Users__c emp = new Portal_Users__c(Name='E', Is_Active__c=true, Role__c='Employee',
      Date_Of_Joining__c=Date.today().addYears(-1));
    insert emp;

    PWChrono_ExpenseValidator.ExpenseClaimDTO dto =
      PWChrono_ExpenseTestDataFactory.buildClaimDTO(null, Date.today().addDays(-100));

    Test.startTest();
    List<String> errors = PWChrono_ExpenseValidator.validate(dto, emp.Id);
    Test.stopTest();

    System.assert(!errors.isEmpty(), 'Backdated > 90 days should produce an error');
  }

  // ─────────────────────── validateNotFuture ────────────────────────────────

  @IsTest
  static void testValidateNotFuture_today_returnsNull() {
    Test.startTest();
    String error = PWChrono_ExpenseValidator.validateNotFuture(Date.today());
    Test.stopTest();
    System.assertEquals(null, error, 'Today should be valid');
  }

  @IsTest
  static void testValidateNotFuture_past_returnsNull() {
    Test.startTest();
    String error = PWChrono_ExpenseValidator.validateNotFuture(Date.today().addDays(-1));
    Test.stopTest();
    System.assertEquals(null, error, 'Past date should be valid');
  }

  @IsTest
  static void testValidateNotFuture_future_returnsError() {
    Test.startTest();
    String error = PWChrono_ExpenseValidator.validateNotFuture(Date.today().addDays(1));
    Test.stopTest();
    System.assertNotEquals(null, error, 'Future date should return an error');
  }

  // ─────────────────────── validateItemType ─────────────────────────────────

  @IsTest
  static void testValidateItemType_valid_returnsNull() {
    List<String> validTypes = new List<String>{
      'Travel','Food','Lodging','Communication','Training','Entertainment','Other'
    };
    Test.startTest();
    for (String t : validTypes) {
      String error = PWChrono_ExpenseValidator.validateItemType(t);
      System.assertEquals(null, error, t + ' should be a valid type');
    }
    Test.stopTest();
  }

  @IsTest
  static void testValidateItemType_invalid_returnsError() {
    Test.startTest();
    String error = PWChrono_ExpenseValidator.validateItemType('CryptoFund');
    Test.stopTest();
    System.assertNotEquals(null, error, 'Invalid type should return an error');
  }

  @IsTest
  static void testValidateItemType_blank_returnsError() {
    Test.startTest();
    String error = PWChrono_ExpenseValidator.validateItemType('');
    Test.stopTest();
    System.assertNotEquals(null, error, 'Blank type should return an error');
  }

  // ─────────────────────── computeTotal ─────────────────────────────────────

  @IsTest
  static void testComputeTotal_multipleItems_sumsCorrectly() {
    List<PWChrono_ExpenseValidator.ExpenseItemDTO> items =
      PWChrono_ExpenseTestDataFactory.buildItemDTOs(Date.today().addDays(-1));

    Test.startTest();
    Decimal total = PWChrono_ExpenseValidator.computeTotal(items);
    Test.stopTest();

    System.assertEquals(165.00, total, 'Total should be 45.00 + 120.00 = 165.00');
  }

  @IsTest
  static void testComputeTotal_emptyList_returnsZero() {
    Test.startTest();
    Decimal total = PWChrono_ExpenseValidator.computeTotal(
      new List<PWChrono_ExpenseValidator.ExpenseItemDTO>()
    );
    Test.stopTest();
    System.assertEquals(0, total, 'Empty list should return 0');
  }

  @IsTest
  static void testComputeTotal_nullList_returnsZero() {
    Test.startTest();
    Decimal total = PWChrono_ExpenseValidator.computeTotal(null);
    Test.stopTest();
    System.assertEquals(0, total, 'Null list should return 0');
  }
}