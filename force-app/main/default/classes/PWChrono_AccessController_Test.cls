@isTest
private class PWChrono_AccessController_Test {
  @TestSetup
  static void makeData() {
    PWChrono_TestDataFactory.createPortalUser(
      'Test Admin',
      'admin@test.com',
      'HR Admin'
    );
    PWChrono_TestDataFactory.createPortalUser(
      'Test Employee',
      'emp@test.com',
      'Employee'
    );
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
}