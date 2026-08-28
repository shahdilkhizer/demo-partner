/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
private class PWChrono_EmployeeReferralController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Product Manager',
        Is_Active__c = true
      );
      insert desig;

      Portal_Users__c employee = new Portal_Users__c(
        Name = 'Test Employee',
        Email__c = 'employee@test.com',
        Role__c = 'Employee'
      );
      insert employee;

      Portal_Users__c hrAdmin = new Portal_Users__c(
        Name = 'HR Admin User',
        Email__c = 'hradmin@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN
      );
      insert hrAdmin;

      PWChrono_Job_Applicant__c applicant = new PWChrono_Job_Applicant__c(
        Name = 'Jane Doe',
        Email__c = 'jane@test.com'
      );
      insert applicant;

      PWChrono_Employee_Referral__c referral = new PWChrono_Employee_Referral__c(
        Name = 'REF-001',
        Full_Name__c = 'Jane Doe',
        Email__c = 'jane@test.com',
        Mobile_Number__c = '+1-555-0100',
        For_Designation__c = desig.Id,
        Status__c = 'Pending',
        Current_Employee__c = employee.Id,
        Job_Applicant__c = applicant.Id,
        Is_Applicable_for_Referral_Bonus__c = true,
        Referral_Bonus_Amount__c = 1000,
        Referral_Bonus_Payment_Status__c = 'Pending'
      );
      insert referral;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getReferrals
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetReferrals_AllAsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Referral__c> results = PWChrono_EmployeeReferralController.getReferrals(
      'All',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'HR admin should see all referrals');
  }

  @isTest
  static void testGetReferrals_OwnAsEmployee() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'employee@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Referral__c> results = PWChrono_EmployeeReferralController.getReferrals(
      'All',
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'Employee should see their own referral'
    );
  }

  @isTest
  static void testGetReferrals_FilterByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Referral__c> pending = PWChrono_EmployeeReferralController.getReferrals(
      'Pending',
      hr.Id,
      null
    );
    List<PWChrono_Employee_Referral__c> selected = PWChrono_EmployeeReferralController.getReferrals(
      'Selected',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, pending.size(), 'Should find 1 pending referral');
    System.assertEquals(0, selected.size(), 'Should find 0 selected referrals');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getReferralById
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetReferralById() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Referral__c ref = [
      SELECT Id
      FROM PWChrono_Employee_Referral__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Employee_Referral__c result = PWChrono_EmployeeReferralController.getReferralById(
      ref.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals('Jane Doe', result.Full_Name__c);
  }

  @isTest
  static void testGetReferralById_NotFound() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeeReferralController.getReferralById(
        'a0C000000000001AAA',
        hr.Id,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Should throw when not found');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveReferral
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSaveReferral_Insert() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'employee@test.com'
      LIMIT 1
    ];
    PWChrono_Designation__c desig = [
      SELECT Id
      FROM PWChrono_Designation__c
      LIMIT 1
    ];
    Map<String, Object> refMap = new Map<String, Object>{
      'Name' => 'REF-NEW',
      'Full_Name__c' => 'Bob Smith',
      'Email__c' => 'bob@test.com',
      'For_Designation__c' => desig.Id,
      'Status__c' => 'Pending'
    };
    Test.startTest();
    String newId = PWChrono_EmployeeReferralController.saveReferral(
      JSON.serialize(refMap),
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertNotEquals(null, newId);
    PWChrono_Employee_Referral__c saved = [
      SELECT Current_Employee__c
      FROM PWChrono_Employee_Referral__c
      WHERE Id = :newId
      LIMIT 1
    ];
    System.assertEquals(
      emp.Id,
      saved.Current_Employee__c,
      'Employee should be stamped on insert'
    );
  }

  @isTest
  static void testSaveReferral_Update() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Referral__c ref = [
      SELECT Id
      FROM PWChrono_Employee_Referral__c
      LIMIT 1
    ];
    Map<String, Object> refMap = new Map<String, Object>{
      'Id' => ref.Id,
      'Additional_Information__c' => 'Updated note'
    };
    Test.startTest();
    String savedId = PWChrono_EmployeeReferralController.saveReferral(
      JSON.serialize(refMap),
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(ref.Id, savedId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // updateReferralStatus
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testUpdateReferralStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Referral__c ref = [
      SELECT Id
      FROM PWChrono_Employee_Referral__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeeReferralController.updateReferralStatus(
      ref.Id,
      'Selected',
      hr.Id,
      null
    );
    Test.stopTest();
    PWChrono_Employee_Referral__c updated = [
      SELECT Status__c
      FROM PWChrono_Employee_Referral__c
      WHERE Id = :ref.Id
      LIMIT 1
    ];
    System.assertEquals('Selected', updated.Status__c);
  }

  @isTest
  static void testUpdateReferralStatus_NotHR() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'employee@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Referral__c ref = [
      SELECT Id
      FROM PWChrono_Employee_Referral__c
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeeReferralController.updateReferralStatus(
        ref.Id,
        'Selected',
        emp.Id,
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Non-HR should not be able to update status');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // deleteReferral
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testDeleteReferral() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Referral__c ref = [
      SELECT Id
      FROM PWChrono_Employee_Referral__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeeReferralController.deleteReferral(ref.Id, hr.Id, null);
    Test.stopTest();
    List<PWChrono_Employee_Referral__c> remaining = [
      SELECT Id
      FROM PWChrono_Employee_Referral__c
      WHERE Id = :ref.Id
    ];
    System.assertEquals(0, remaining.size(), 'Record should be deleted');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetActiveDesignations() {
    Test.startTest();
    List<PWChrono_Designation__c> results = PWChrono_EmployeeReferralController.getActiveDesignations();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetJobApplicants() {
    Test.startTest();
    List<PWChrono_Job_Applicant__c> results = PWChrono_EmployeeReferralController.getJobApplicants();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetReferrals_GuestHrSession() {
    Portal_Users__c hr = [
      SELECT
        Id,
        Is_Active__c,
        Session_Token__c,
        Session_Expires_At__c,
        Session_Failed_Attempts__c,
        Session_Locked_Until__c
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    hr.Is_Active__c = true;
    hr.Session_Token__c = 'guest_referral_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    hr.Session_Failed_Attempts__c = 0;
    hr.Session_Locked_Until__c = null;
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_GuestSession.testNowOverride = System.now();
    try {
      Test.startTest();
      List<PWChrono_Employee_Referral__c> results =
        PWChrono_EmployeeReferralController.getReferrals(
          'All',
          String.valueOf(hr.Id),
          'guest_referral_token'
        );
      Test.stopTest();
      System.assertEquals(1, results.size(), 'Guest HR should see referral records.');
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testDeleteReferral_NonPendingThrows() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Referral__c referral = [
      SELECT Id, Status__c
      FROM PWChrono_Employee_Referral__c
      LIMIT 1
    ];
    referral.Status__c = 'Selected';
    update referral;

    Test.startTest();
    try {
      PWChrono_EmployeeReferralController.deleteReferral(
        String.valueOf(referral.Id),
        String.valueOf(hr.Id),
        null
      );
      System.assert(false, 'Only pending referrals should be deletable.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @isTest
  static void testSaveReferral_BlankPayloadRejected() {
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'employee@test.com'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_EmployeeReferralController.saveReferral(
        '',
        String.valueOf(employee.Id),
        null
      );
      System.assert(false, 'Blank referral payload should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @isTest
  static void testMalformedPayloadAndDeleteNotFoundThrow() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hradmin@test.com'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_EmployeeReferralController.saveReferral(
        '{bad json',
        hr.Id,
        null
      );
      System.assert(false, 'Malformed referral JSON should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_EmployeeReferralController.updateReferralStatus(
        '001000000000000AAA',
        'Selected',
        hr.Id,
        null
      );
      System.assert(false, 'Missing referral status update should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_EmployeeReferralController.deleteReferral(
        '001000000000000AAA',
        hr.Id,
        null
      );
      System.assert(false, 'Deleting a missing referral should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }
}