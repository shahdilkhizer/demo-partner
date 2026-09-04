@isTest
private class PWChrono_EmpDirectoryTest {
  @TestSetup
  static void setupTestData() {
    Account acc = new Account(Name = 'Test Corp');
    insert acc;

    Contact mgr = new Contact(
      FirstName = 'Manager',
      LastName = 'One',
      Title = 'Manager',
      Department = 'Finance',
      Email = 'mgr@test.com',
      Phone = '1234567890',
      AccountId = acc.Id
    );
    insert mgr;

    List<Contact> contacts = new List<Contact>();
    contacts.add(
      new Contact(
        FirstName = 'Alice',
        LastName = 'Developer',
        Title = 'Developer',
        Department = 'Engineering',
        Email = 'alice@test.com',
        Phone = '1112223333',
        Bank_Name__c = 'Test Bank',
        Account_Number__c = '123456789012',
        SWIFT_Code__c = 'TESTPKKA',
        Branch_Name_Code__c = 'Main Branch',
        Passport_No__c = 'AB1234567',
        Emergency_Contact_Name__c = 'Alice Emergency',
        Emergency_Contact_Number__c = '03001234567',
        Family_Member_Name__c = 'Alice Family',
        Laptop_Brand__c = 'Test Laptop',
        Model__c = 'Model One',
        ReportsToId = mgr.Id,
        AccountId = acc.Id
      )
    );
    contacts.add(
      new Contact(
        FirstName = 'Bob',
        LastName = 'Finance',
        Title = 'Finance',
        Department = 'Finance',
        Email = 'bob@test.com',
        Phone = '4445556666',
        ReportsToId = mgr.Id,
        AccountId = acc.Id
      )
    );
    insert contacts;
  }

  @isTest
  static void testGetEmployees_All() {
    Test.startTest();
    List<PWChrono_EmployeeDirectoryController.EmployeeWrapper> results = PWChrono_EmployeeDirectoryController.getEmployees(
      '',
      'All',
      'All',
      'Ascending',
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, results, 'Results should not be null');
    System.assert(results.size() >= 3, 'Should return at least 3 contacts');
  }

  @isTest
  static void testGetEmployees_WithFilters() {
    Test.startTest();
    List<PWChrono_EmployeeDirectoryController.EmployeeWrapper> filtered = PWChrono_EmployeeDirectoryController.getEmployees(
      'Alice',
      'Developer',
      'All',
      'Descending',
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, filtered, 'Results should not be null');
    System.assert(filtered.size() >= 1, 'Should find at least 1 developer');
    System.assertEquals('Alice Developer', filtered[0].name);
  }

  @isTest
  static void testGetEmployeeDirectoryMetrics() {
    Test.startTest();
    Map<String, Object> metrics = PWChrono_EmployeeDirectoryController.getEmployeeDirectoryMetrics(
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, metrics, 'Metrics map should not be null');
    System.assert(metrics.containsKey('total'), 'Should contain total count');
    System.assert(metrics.containsKey('active'), 'Should contain active count');
  }

  @isTest
  static void testGetEmployeeDesignations() {
    Test.startTest();
    List<String> designations = PWChrono_EmployeeDirectoryController.getEmployeeDesignations(
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      designations,
      'Designations should not be null'
    );
    System.assert(designations.size() > 0, 'Should return designations');
  }

  @isTest
  static void testGetEmployeeDetail() {
    Contact c = [SELECT Id FROM Contact WHERE FirstName = 'Alice' LIMIT 1];
    PWChrono_EmployeeDirectoryController.testCanViewAllSensitiveOverride = true;
    PWChrono_EmployeeDirectoryController.EmployeeWrapper detail;
    try {
      Test.startTest();
      detail = PWChrono_EmployeeDirectoryController.getEmployeeDetail(
        c.Id,
        null,
        null
      );
      Test.stopTest();
    } finally {
      PWChrono_EmployeeDirectoryController.testCanViewAllSensitiveOverride = null;
    }

    System.assertNotEquals(null, detail, 'Employee detail should not be null');
    System.assertEquals('Alice Developer', detail.name);
    System.assertEquals('Test Bank', detail.bankInfo.bankName);
    System.assertEquals('**** 9012', detail.bankInfo.maskedAccountNumber);
    System.assertEquals(
      false,
      JSON.serialize(detail).contains('123456789012'),
      'The full account number must never leave Apex.'
    );
    System.assertEquals('**** 4567', detail.personalInfo.passportNo);
    System.assertEquals(
      'Test Laptop - Model One',
      detail.assetInfo.displayText
    );
  }

  @isTest
  static void testNonPayrollUserCannotViewAnotherEmployeesSensitiveData() {
    Contact otherContact = [
      SELECT Id
      FROM Contact
      WHERE FirstName = 'Alice'
      LIMIT 1
    ];

    PWChrono_EmployeeDirectoryController.testCanViewAllSensitiveOverride = false;
    try {
      Test.startTest();
      PWChrono_EmployeeDirectoryController.EmployeeWrapper detail = PWChrono_EmployeeDirectoryController.getEmployeeDetail(
        otherContact.Id,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(false, detail.canViewSensitive);
      System.assertEquals(null, detail.bankInfo);
      System.assertEquals(null, detail.personalInfo);
      System.assertEquals(null, detail.emergencyContact);
      System.assertEquals(null, detail.familyInfo);
    } finally {
      PWChrono_EmployeeDirectoryController.testCanViewAllSensitiveOverride = null;
    }
  }

  @isTest
  static void testSaveAndDeleteEmployee() {
    Contact newContact = new Contact(
      FirstName = 'Charlie',
      LastName = 'Tester',
      Email = 'charlie@test.com',
      Title = 'QA Engineer'
    );

    Test.startTest();
    Contact saved = PWChrono_EmployeeDirectoryController.saveEmployee(
      newContact,
      null,
      null
    );
    System.assertNotEquals(null, saved.Id, 'Contact should be inserted');

    saved.LastName = 'Updated';
    PWChrono_EmployeeDirectoryController.saveEmployee(saved, null, null);

    PWChrono_EmployeeDirectoryController.deleteEmployee(saved.Id, null, null);
    Test.stopTest();

    List<Contact> check = [SELECT Id FROM Contact WHERE Id = :saved.Id];
    System.assertEquals(0, check.size(), 'Contact should be deleted');
  }

  @isTest
  static void testLegacyMethods() {
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    List<Contact> legacy = PWChrono_EmployeeDirectoryController.searchEmployees(
      'Alice',
      null,
      null
    );
    Boolean hasAccess = PWChrono_EmployeeDirectoryController.checkRecordAccess(
      c.Id,
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, legacy, 'Legacy search should return results');
    System.assertEquals(true, hasAccess, 'User should have access');
  }

  @isTest
  static void testGuestDirectoryAuthorizationAndSensitiveMasking() {
    Contact selfContact = [
      SELECT Id
      FROM Contact
      WHERE FirstName = 'Alice'
      LIMIT 1
    ];
    Contact otherContact = [
      SELECT Id
      FROM Contact
      WHERE FirstName = 'Bob'
      LIMIT 1
    ];
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    Portal_Object__c contactObject = new Portal_Object__c(
      Object_API_Name__c = 'Contact'
    );
    insert contactObject;
    insert new Portal_Object_Permission__c(
      Portal_User_Profile__c = profile.Id,
      Portal_Object__c = contactObject.Id,
      Can_View__c = true,
      Can_View_All__c = true,
      Can_Edit__c = false
    );
    Portal_Users__c portalUser = PWChrono_TestDataFactory.createPortalUser(
      'Directory Guest',
      'directory-guest@example.com',
      'Employee'
    );
    portalUser.Contact__c = selfContact.Id;
    portalUser.Portal_User_Profile__c = profile.Id;
    portalUser.Session_Token__c = 'directory_guest_token';
    portalUser.Session_Expires_At__c = System.now().addHours(1);
    Database.update(portalUser, AccessLevel.SYSTEM_MODE);

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_EmployeeDirectoryController.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      PWChrono_EmployeeDirectoryController.EmployeeWrapper selfDetail = PWChrono_EmployeeDirectoryController.getEmployeeDetail(
        selfContact.Id,
        String.valueOf(portalUser.Id),
        'directory_guest_token'
      );
      PWChrono_EmployeeDirectoryController.EmployeeWrapper otherDetail = PWChrono_EmployeeDirectoryController.getEmployeeDetail(
        otherContact.Id,
        String.valueOf(portalUser.Id),
        'directory_guest_token'
      );
      Test.stopTest();

      System.assertEquals(true, selfDetail.canViewSensitive);
      System.assertEquals('**** 9012', selfDetail.bankInfo.maskedAccountNumber);
      System.assertEquals(false, otherDetail.canViewSensitive);
      System.assertEquals(null, otherDetail.bankInfo);
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_EmployeeDirectoryController.testUserTypeOverride = null;
    }
  }

  @isTest
  static void testGuestWithoutContactPermissionIsRejected() {
    Contact contactRecord = [SELECT Id FROM Contact LIMIT 1];
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    Portal_Users__c portalUser = PWChrono_TestDataFactory.createPortalUser(
      'Restricted Directory Guest',
      'restricted-directory@example.com',
      'Employee'
    );
    portalUser.Contact__c = contactRecord.Id;
    portalUser.Portal_User_Profile__c = profile.Id;
    portalUser.Session_Token__c = 'restricted_directory_token';
    portalUser.Session_Expires_At__c = System.now().addHours(1);
    Database.update(portalUser, AccessLevel.SYSTEM_MODE);

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_EmployeeDirectoryController.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      try {
        PWChrono_EmployeeDirectoryController.getEmployeeDetail(
          contactRecord.Id,
          String.valueOf(portalUser.Id),
          'restricted_directory_token'
        );
        System.assert(false, 'Expected directory access to be rejected.');
      } catch (PWChrono_EmployeeDirectoryController.EmployeeDirectoryException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_EmployeeDirectoryController.testUserTypeOverride = null;
    }
  }
}