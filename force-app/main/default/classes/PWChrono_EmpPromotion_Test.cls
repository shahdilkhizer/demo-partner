/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
private class PWChrono_EmpPromotion_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Portal_Users__c employee = new Portal_Users__c(
        Name = 'Test Employee',
        Email__c = 'emp@test.com',
        Role__c = 'Employee',
        Is_Active__c = true
      );
      insert employee;

      Portal_Users__c hrAdmin = new Portal_Users__c(
        Name = 'HR Admin',
        Email__c = 'hr@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
        Is_Active__c = true
      );
      insert hrAdmin;

      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c currentDesig = new PWChrono_Designation__c(
        Name = 'Junior Developer',
        Is_Active__c = true
      );
      PWChrono_Designation__c newDesig = new PWChrono_Designation__c(
        Name = 'Senior Developer',
        Is_Active__c = true
      );
      insert new List<PWChrono_Designation__c>{ currentDesig, newDesig };

      PWChrono_Employee_Promotion__c promo = new PWChrono_Employee_Promotion__c(
        Employee__c = employee.Id,
        Employee_Name__c = employee.Name,
        Company__c = 'PWChrono Corp',
        Promotion_Date__c = Date.today(),
        Current_Designation__c = currentDesig.Id,
        New_Designation__c = newDesig.Id,
        Current_Department__c = dept.Id,
        New_Department__c = dept.Id,
        Current_Grade__c = 'L2',
        New_Grade__c = 'L3',
        Current_Branch__c = 'HQ',
        New_Branch__c = 'HQ',
        Current_Salary__c = 60000,
        New_Salary__c = 75000,
        Status__c = 'Draft'
      );
      insert promo;

      PWChrono_Promotion_Detail__c detail = new PWChrono_Promotion_Detail__c(
        Promotion__c = promo.Id,
        Property__c = 'Designation',
        Current_Value__c = 'Junior Developer',
        New_Value__c = 'Senior Developer'
      );
      insert detail;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getPromotions
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetPromotions_AllAsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Promotion__c> results = PWChrono_EmployeePromotionController.getPromotions(
      'All',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'HR admin should see all promotions'
    );
  }

  @isTest
  static void testGetPromotions_OwnAsEmployee() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Promotion__c> results = PWChrono_EmployeePromotionController.getPromotions(
      'All',
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'Employee should see their own promotion'
    );
  }

  @isTest
  static void testGetPromotions_FilterByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Promotion__c> draft = PWChrono_EmployeePromotionController.getPromotions(
      'Draft',
      hr.Id,
      null
    );
    List<PWChrono_Employee_Promotion__c> approved = PWChrono_EmployeePromotionController.getPromotions(
      'Approved',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, draft.size());
    System.assertEquals(0, approved.size());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getPromotionById
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetPromotionById() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promo = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Employee_Promotion__c result = PWChrono_EmployeePromotionController.getPromotionById(
      promo.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals('PWChrono Corp', result.Company__c);
  }

  @isTest
  static void testGetPromotionById_NotFound() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeePromotionController.getPromotionById(
        'a0C000000000001AAA',
        hr.Id,
        null
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Should throw AuraHandledException when not found');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getPromotionDetails
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetPromotionDetails() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promo = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Promotion_Detail__c> details = PWChrono_EmployeePromotionController.getPromotionDetails(
      promo.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, details.size());
    System.assertEquals('Designation', details[0].Property__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // savePromotion
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSavePromotion_Insert() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Department__c dept = [
      SELECT Id
      FROM PWChrono_Department__c
      LIMIT 1
    ];
    Map<String, Object> promoMap = new Map<String, Object>{
      'Employee__c' => emp.Id,
      'Employee_Name__c' => 'Test Employee',
      'Promotion_Date__c' => String.valueOf(Date.today()),
      'Company__c' => 'Test Corp',
      'Status__c' => 'Draft'
    };
    List<Map<String, Object>> details = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Property__c' => 'Department',
        'Current_Value__c' => 'Engineering',
        'New_Value__c' => 'Product'
      }
    };
    Test.startTest();
    String newId = PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(promoMap),
      JSON.serialize(details),
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertNotEquals(null, newId);
    List<PWChrono_Promotion_Detail__c> saved = [
      SELECT Id
      FROM PWChrono_Promotion_Detail__c
      WHERE Promotion__c = :newId
    ];
    System.assertEquals(1, saved.size(), 'Detail line should be inserted');
  }

  @isTest
  static void testSavePromotion_Update() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promo = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    Map<String, Object> promoMap = new Map<String, Object>{
      'Id' => promo.Id,
      'Company__c' => 'Updated Corp'
    };
    Test.startTest();
    String savedId = PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(promoMap),
      '[]',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(promo.Id, savedId);
    PWChrono_Employee_Promotion__c updated = [
      SELECT Company__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :promo.Id
    ];
    System.assertEquals('Updated Corp', updated.Company__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // updatePromotionStatus
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testUpdatePromotionStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promo = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promo.Id,
      'Approved',
      hr.Id,
      null
    );
    Test.stopTest();
    PWChrono_Employee_Promotion__c updated = [
      SELECT Status__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :promo.Id
    ];
    System.assertEquals('Approved', updated.Status__c);
  }

  @isTest
  static void testUpdatePromotionStatus_NotHR() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promo = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeePromotionController.updatePromotionStatus(
        promo.Id,
        'Approved',
        emp.Id,
        null
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Non-HR should not be able to update status');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // deletePromotion
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testDeletePromotion() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promo = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeePromotionController.deletePromotion(promo.Id, hr.Id, null);
    Test.stopTest();
    List<PWChrono_Employee_Promotion__c> remaining = [
      SELECT Id
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :promo.Id
    ];
    System.assertEquals(0, remaining.size(), 'Record should be deleted');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetActiveDesignations() {
    Test.startTest();
    List<PWChrono_Designation__c> results = PWChrono_EmployeePromotionController.getActiveDesignations();
    Test.stopTest();
    System.assert(results.size() >= 2);
  }

  @isTest
  static void testGetActiveDepartments() {
    Test.startTest();
    List<PWChrono_Department__c> results = PWChrono_EmployeePromotionController.getActiveDepartments();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetActiveEmployees() {
    Test.startTest();
    List<Portal_Users__c> results = PWChrono_EmployeePromotionController.getActiveEmployees();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetPromotions_GuestHrSession() {
    Portal_Users__c hr = [
      SELECT Id, Session_Token__c, Session_Expires_At__c
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_promotion_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Employee_Promotion__c> results =
        PWChrono_EmployeePromotionController.getPromotions(
          'All',
          String.valueOf(hr.Id),
          'guest_promotion_token'
        );
      Test.stopTest();
      System.assertEquals(1, results.size());
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testDeletePromotion_NonDraftThrows() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Promotion__c promotion = [
      SELECT Id, Status__c
      FROM PWChrono_Employee_Promotion__c
      LIMIT 1
    ];
    promotion.Status__c = 'Approved';
    update promotion;

    Test.startTest();
    try {
      PWChrono_EmployeePromotionController.deletePromotion(
        String.valueOf(promotion.Id),
        String.valueOf(hr.Id),
        null
      );
      System.assert(false, 'Only draft promotion records should be deletable.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }
}