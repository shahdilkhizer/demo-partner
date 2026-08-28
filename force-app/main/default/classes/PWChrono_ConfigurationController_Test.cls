@isTest
private class PWChrono_ConfigurationController_Test {
  @TestSetup
  static void makeData() {
    // Create test data
    List<Portal_Users__c> portalUsers = new List<Portal_Users__c>();
    for (Integer i = 0; i < 5; i++) {
      portalUsers.add(
        new Portal_Users__c(
          Name = 'Test User ' + i,
          Email__c = 'test' + i + '@test.com'
        )
      );
    }
    insert portalUsers;

    List<PWChrono_User_Feature_Access__c> featureAccesses = new List<PWChrono_User_Feature_Access__c>();
    featureAccesses.add(
      new PWChrono_User_Feature_Access__c(
        Portal_User__c = portalUsers[0].Id,
        Feature_Name__c = 'Dashboard',
        Access_Level__c = 'Read Write',
        Is_Active__c = true
      )
    );
    insert featureAccesses;

    PWChrono_Feature_Settings__c settings = new PWChrono_Feature_Settings__c(
      Name = 'Default Settings',
      Enable_Payroll_Module__c = true
    );
    insert settings;
  }

  @isTest
  static void testGetAllUsersWithAccess() {
    Test.startTest();
    List<PWChrono_ConfigurationController.UserConfiguration> userConfigs = PWChrono_ConfigurationController.getAllUsersWithAccess(
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(
      5,
      userConfigs.size(),
      'Should return all 5 test users.'
    );
    // Note: The order is not guaranteed, so we find the user with feature access
    for (
      PWChrono_ConfigurationController.UserConfiguration config : userConfigs
    ) {
      if (config.userName == 'Test User 0') {
        System.assertEquals(
          1,
          config.featureAccess.size(),
          'User 0 should have one feature access record.'
        );
        System.assertEquals(
          'Dashboard',
          config.featureAccess[0].featureName,
          'Feature name should match.'
        );
      }
    }
  }

  @isTest
  static void testGetAvailableFeatures() {
    Test.startTest();
    List<String> features = PWChrono_ConfigurationController.getAvailableFeatures(
      null,
      null
    );
    Test.stopTest();

    System.assert(
      !features.isEmpty(),
      'Should return a list of available features.'
    );
  }

  @isTest
  static void testCheckFeatureAccess() {
    List<Portal_Users__c> portalUsers = [
      SELECT Id, User__c
      FROM Portal_Users__c
      WHERE Name = 'Test User 0'
    ];

    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    User u = new User(
      Alias = 'standt',
      Email = 'standarduser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'standarduser' + DateTime.now().getTime() + '@testorg.com'
    );
    insert u;

    portalUsers[0].User__c = u.Id;
    update portalUsers[0];

    System.runAs(u) {
      Test.startTest();
      PWChrono_ConfigurationController.FeatureAccessResult result = PWChrono_ConfigurationController.checkFeatureAccess(
        'Dashboard'
      );
      Test.stopTest();
      System.assertEquals(true, result.hasAccess, 'Result should show access');
    }
  }

  @isTest
  static void testSaveUserFeatureAccess() {
    Portal_Users__c user = [SELECT Id FROM Portal_Users__c LIMIT 1];
    List<PWChrono_ConfigurationController.FeatureAccessWrapper> features = new List<PWChrono_ConfigurationController.FeatureAccessWrapper>();
    PWChrono_ConfigurationController.FeatureAccessWrapper feature = new PWChrono_ConfigurationController.FeatureAccessWrapper();
    feature.featureName = 'Leave Management';
    feature.accessLevel = 'Read Only';
    feature.isActive = true;
    features.add(feature);

    Test.startTest();
    String result = PWChrono_ConfigurationController.saveUserFeatureAccess(
      user.Id,
      features,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(
      'Success',
      result,
      'The save operation should be successful.'
    );
    List<PWChrono_User_Feature_Access__c> savedFeatures = [
      SELECT Id
      FROM PWChrono_User_Feature_Access__c
      WHERE Portal_User__c = :user.Id AND Feature_Name__c = 'Leave Management'
    ];
    System.assertEquals(
      1,
      savedFeatures.size(),
      'A new feature access record should have been created.'
    );
  }

  @isTest
  static void testBulkAssignFeatures() {
    List<Portal_Users__c> users = [SELECT Id FROM Portal_Users__c LIMIT 2];
    List<String> userIds = new List<String>();
    for (Portal_Users__c u : users) {
      userIds.add(u.Id);
    }

    List<PWChrono_ConfigurationController.FeatureAccessWrapper> features = new List<PWChrono_ConfigurationController.FeatureAccessWrapper>();
    PWChrono_ConfigurationController.FeatureAccessWrapper feature = new PWChrono_ConfigurationController.FeatureAccessWrapper();
    feature.featureName = 'Attendance Management';
    feature.accessLevel = 'Read Only';
    feature.isActive = true;
    features.add(feature);

    Test.startTest();
    String result = PWChrono_ConfigurationController.bulkAssignFeatures(
      userIds,
      features,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(
      'Success: Assigned features to 2 users',
      result,
      'Bulk assignment should be successful.'
    );
    List<PWChrono_User_Feature_Access__c> savedFeatures = [
      SELECT Id
      FROM PWChrono_User_Feature_Access__c
      WHERE Feature_Name__c = 'Attendance Management'
    ];
    System.assertEquals(
      2,
      savedFeatures.size(),
      'Feature should be assigned to two users.'
    );
  }

  @isTest
  static void testDeleteFeatureAccess() {
    PWChrono_User_Feature_Access__c access = [
      SELECT Id
      FROM PWChrono_User_Feature_Access__c
      LIMIT 1
    ];

    Test.startTest();
    String result = PWChrono_ConfigurationController.deleteFeatureAccess(
      access.Id,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals('Success', result, 'Delete should be successful.');
    List<PWChrono_User_Feature_Access__c> remaining = [
      SELECT Id
      FROM PWChrono_User_Feature_Access__c
      WHERE Id = :access.Id
    ];
    System.assertEquals(
      0,
      remaining.size(),
      'The feature access record should be deleted.'
    );
  }

  @isTest
  static void testGetGlobalFeatureSettings() {
    Test.startTest();
    PWChrono_Feature_Settings__c settings = PWChrono_ConfigurationController.getGlobalFeatureSettings(
      null,
      null
    );
    Test.stopTest();

    System.assert(settings != null, 'Settings should not be null.');
    System.assertEquals(
      true,
      settings.Enable_Payroll_Module__c,
      'Payroll module should be enabled.'
    );
  }

  @isTest
  static void testSaveGlobalFeatureSettings() {
    PWChrono_Feature_Settings__c settings = [
      SELECT Id, Enable_Payroll_Module__c
      FROM PWChrono_Feature_Settings__c
      LIMIT 1
    ];
    settings.Enable_Payroll_Module__c = false;

    Test.startTest();
    String result = PWChrono_ConfigurationController.saveGlobalFeatureSettings(
      settings,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals('Success', result, 'Save should be successful.');
    PWChrono_Feature_Settings__c updatedSettings = [
      SELECT Enable_Payroll_Module__c
      FROM PWChrono_Feature_Settings__c
      LIMIT 1
    ];
    System.assertEquals(
      false,
      updatedSettings.Enable_Payroll_Module__c,
      'Payroll module should be disabled after save.'
    );
  }
}