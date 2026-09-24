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
    // Internal users without a linked PWChrono identity must not bypass RBAC.
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
        false,
        result.get('hasAccess'),
        'Unlinked internal users should not have portal access'
      );
      System.assertEquals(null, result.get('role'));
      System.assertEquals(
        false,
        result.get('isSalesforceUser'),
        'Only platform administrators receive the internal bypass flag'
      );

      List<Object> features = (List<Object>) result.get('features');
      System.assertEquals(0, features.size());
    }
  }

  @isTest
  static void testGetUserAccess_HRAdmin_LinkedToSalesforceUser() {
    // A linked internal user keeps the PWChrono role assigned to that identity.
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

      System.assertEquals(true, result.get('hasAccess'));
      System.assertEquals('HR Admin', result.get('role'));
      System.assertEquals(false, result.get('isSalesforceUser'));
      System.assertEquals(true, result.get('isAdmin'));
    }
  }

  @isTest
  static void testGetUserAccess_WithEmployeeId() {
    Test.startTest();
    Map<String, Object> result = PWChrono_AccessController.getUserAccess();
    Test.stopTest();

    // An unlinked platform administrator retains emergency administrative access.
    System.assertEquals(true, result.get('hasAccess'));
    System.assertEquals('System Administrator', result.get('role'));
    System.assertEquals(true, result.get('isAdmin'));
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
      new List<String>{ 'Attendance Management', 'Dashboard', 'My Profile' },
      (List<String>) portalResult.get('features')
    );
    System.assertEquals(true, guestResult.get('hasAccess'));
    System.assertEquals(
      new List<String>{ 'Attendance Management', 'Dashboard', 'My Profile' },
      (List<String>) guestResult.get('features')
    );
    System.assertEquals(false, guestLoginResult.get('hasAccess'));
    System.assertEquals(
      0,
      ((List<String>) guestLoginResult.get('features')).size()
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
    System.assertEquals(false, adminResult);
    System.assertEquals(true, nullAdminResult);
  }

  @isTest
  static void testHrManagerHasTeamScopeButNoGlobalAdministration() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c(
      Profile_Type__c = 'HR Manager',
      Can_Approve__c = true,
      Approval_Scope__c = 'All Employees',
      Is_Active__c = true
    );
    insert profile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = profile.Id,
      Feature_Key__c = 'Attendance Management',
      Feature_Label__c = 'Attendance Management',
      Is_Enabled__c = true
    );
    Portal_Users__c manager = PWChrono_TestDataFactory.createPortalUser(
      'Test HR Manager',
      'hr.manager@test.com',
      'HR Manager'
    );
    manager.Portal_User_Profile__c = profile.Id;
    manager.Department__c = 'People';
    update manager;

    Test.startTest();
    Map<String, Object> result = PWChrono_AccessController.getUserAccessImpl(
      manager.Id,
      'PowerCustomerSuccess'
    );
    Test.stopTest();

    List<String> features = (List<String>) result.get('features');
    System.assertEquals('HR Manager', result.get('role'));
    System.assertEquals('Department', result.get('approvalScope'));
    System.assert(features.contains('Attendance Team'));
    System.assert(!features.contains('Attendance Administration'));
    System.assert(!features.contains('Admin Settings'));
    System.assert(!features.contains('Configuration'));
  }
}