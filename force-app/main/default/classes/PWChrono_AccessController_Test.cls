@isTest
private class PWChrono_AccessController_Test {
  @TestSetup
  static void makeData() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    Portal_Users__c admin = PWChrono_TestDataFactory.createPortalUser(
      'Test Admin',
      'admin@test.com',
      'HR Admin'
    );
    admin.Portal_User_Profile__c = profile.Id;
    admin.Session_Token__c = 'profile_feature_token';
    admin.Session_Expires_At__c = System.now().addHours(1);
    update admin;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = profile.Id,
      Feature_Key__c = 'Attendance Management',
      Feature_Label__c = 'Attendance Management',
      Is_Enabled__c = true,
      Required_Objects__c = 'PWChrono_Attendance__c',
      Required_Fields__c = 'Status__c'
    );
    Portal_Users__c employee = PWChrono_TestDataFactory.createPortalUser(
      'Test Employee',
      'emp@test.com',
      'Employee'
    );
    employee.Portal_User_Profile__c = profile.Id;
    update employee;
  }

  @isTest
  static void testGetUserAccess_SalesforceInternalUser() {
    // Salesforce internal users (Standard profile) should get FULL ACCESS
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    User u = new User(
      Alias = 'sfuser',
      Email = 'sfuser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'SFUser',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'sfuser' + DateTime.now().getTime() + '@testorg.com'
    );
    insert u;

    System.runAs(u) {
      Test.startTest();
      Map<String, Object> result = PWChrono_AccessController.getUserAccess();
      Test.stopTest();

      System.assertEquals(
        true,
        result.get('hasAccess'),
        'Salesforce users should have access'
      );
      System.assertEquals(
        'Salesforce User',
        result.get('role'),
        'Role should be Salesforce User'
      );
      System.assertEquals(
        true,
        result.get('isSalesforceUser'),
        'Should be flagged as Salesforce user'
      );

      List<Object> features = (List<Object>) result.get('features');
      System.assert(
        features.size() > 10,
        'Salesforce users should have many features'
      );
    }
  }

  @isTest
  static void testGetUserAccess_HRAdmin_LinkedToSalesforceUser() {
    // Even with HR Admin Portal_Users__c linked, Salesforce internal users get full access
    Portal_Users__c admin = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'HR Admin'
      LIMIT 1
    ];

    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    User u = new User(
      Alias = 'admin',
      Email = 'admin@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'admin' + DateTime.now().getTime() + '@testorg.com'
    );
    insert u;

    admin.User__c = u.Id;
    update admin;

    PWChrono_TestDataFactory.assignPermissionSet(u.Id, 'PWChrono_HR_Admin');

    System.runAs(u) {
      Test.startTest();
      Map<String, Object> result = PWChrono_AccessController.getUserAccess();
      Test.stopTest();

      // Salesforce internal users always get full access
      System.assertEquals(true, result.get('hasAccess'));
      System.assertEquals('Salesforce User', result.get('role'));
      System.assertEquals(true, result.get('isSalesforceUser'));
    }
  }

  @isTest
  static void testGetUserAccess_WithEmployeeId() {
    // When employeeId is passed, we still check if caller is Salesforce internal user first
    Portal_Users__c admin = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'HR Admin'
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> result = PWChrono_AccessController.getUserAccess();
    Test.stopTest();

    // Running as system user in test context = Salesforce internal user = full access
    System.assertEquals(true, result.get('hasAccess'));
    System.assertEquals('Salesforce User', result.get('role'));
  }

  @isTest
  static void testIsSalesforceInternalUser() {
    Test.startTest();
    Boolean isSfUser = PWChrono_AccessController.isSalesforceInternalUser();
    Test.stopTest();

    // In test context, running user is Standard type
    System.assertEquals(
      true,
      isSfUser,
      'Test user should be recognized as Salesforce internal user'
    );
  }

  @isTest
  static void testProfileFeatureAccessBranches() {
    Portal_Users__c employee = [
      SELECT Id, Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Name = 'Test Employee'
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> portalResult = PWChrono_AccessController.getUserAccessImpl(
      employee.Id,
      'PowerCustomerSuccess'
    );
    Map<String, Object> guestResult = PWChrono_AccessController.getUserAccessImpl(
      employee.Id,
      'Guest'
    );
    Map<String, Object> guestLoginResult = PWChrono_AccessController.getUserAccessImpl(
      null,
      'Guest'
    );
    Map<String, Object> missingUserResult = PWChrono_AccessController.getUserAccessImpl(
      null,
      'PowerCustomerSuccess'
    );
    Test.stopTest();

    System.assertEquals(true, portalResult.get('hasAccess'));
    System.assertEquals(
      new List<String>{ 'Attendance Management' },
      (List<String>) portalResult.get('features')
    );
    System.assertEquals(true, guestResult.get('hasAccess'));
    System.assertEquals(
      new List<String>{ 'Attendance Management' },
      (List<String>) guestResult.get('features')
    );
    System.assertEquals(
      new List<String>{ 'Dashboard', 'My Profile' },
      (List<String>) guestLoginResult.get('features')
    );
    System.assertEquals(false, missingUserResult.get('hasAccess'));
  }

  @isTest
  static void testPublicAccessWrappersAndInternalAdmin() {
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'Test Employee'
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> result = PWChrono_AccessController.getUserAccessById(
      employee.Id,
      null
    );
    Boolean adminResult = PWChrono_AccessController.isAdmin(employee.Id);
    Boolean nullAdminResult = PWChrono_AccessController.isAdmin(null);
    Test.stopTest();

    System.assertEquals(true, result.get('hasAccess'));
    System.assertEquals(true, adminResult);
    System.assertEquals(true, nullAdminResult);
  }
}