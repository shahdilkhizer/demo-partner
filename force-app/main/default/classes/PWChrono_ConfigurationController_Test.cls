@isTest
private class PWChrono_ConfigurationController_Test {
  @TestSetup
  static void makeData() {
    Portal_User_Profile__c adminProfile = new Portal_User_Profile__c();
    insert adminProfile;

    Portal_Object__c portalUserObject = new Portal_Object__c(
      Object_API_Name__c = 'Portal_Users__c'
    );
    insert portalUserObject;
    insert new Portal_Object_Permission__c(
      Portal_User_Profile__c = adminProfile.Id,
      Portal_Object__c = portalUserObject.Id,
      Can_View__c = true,
      Can_Edit__c = true
    );

    List<Portal_Users__c> portalUsers = new List<Portal_Users__c>();
    for (Integer i = 0; i < 5; i++) {
      portalUsers.add(
        new Portal_Users__c(
          Name = 'Test User ' + i,
          Email__c = 'test' + i + '@test.com',
          Is_Active__c = true,
          Portal_User_Profile__c = adminProfile.Id
        )
      );
    }
    portalUsers[0].Session_Token__c = 'configuration_admin_token';
    portalUsers[0].Session_Expires_At__c = System.now().addHours(1);
    insert portalUsers;

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
    // The configuration surface now reads access from the assigned profile.
    for (
      PWChrono_ConfigurationController.UserConfiguration config : userConfigs
    ) {
      if (config.userName == 'Test User 0') {
        System.assertEquals(
          0,
          config.featureAccess.size(),
          'Legacy per-user feature records must not drive this component.'
        );
        System.assertNotEquals(null, config.profileId);
        System.assertNotEquals('Unassigned', config.profileName);
      }
    }
  }

  @isTest
  static void testGetAvailableProfiles() {
    Test.startTest();
    List<PWChrono_ConfigurationController.PortalProfileOption> profiles = PWChrono_ConfigurationController.getAvailableProfiles(
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(1, profiles.size());
    System.assertNotEquals(null, profiles[0].profileId);
    System.assertNotEquals(null, profiles[0].profileName);
  }

  @isTest
  static void testAssignUserProfile() {
    Portal_Users__c targetUser = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'Test User 1'
      LIMIT 1
    ];
    Portal_User_Profile__c employeeProfile = new Portal_User_Profile__c();
    insert employeeProfile;

    Test.startTest();
    String result = PWChrono_ConfigurationController.assignUserProfile(
      targetUser.Id,
      employeeProfile.Id,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals('Success', result);
    Portal_Users__c updatedUser = [
      SELECT Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :targetUser.Id
    ];
    System.assertEquals(employeeProfile.Id, updatedUser.Portal_User_Profile__c);
  }

  @isTest
  static void testCreatePortalUserUsesProfile() {
    Portal_User_Profile__c profile = [
      SELECT Id
      FROM Portal_User_Profile__c
      LIMIT 1
    ];

    Test.startTest();
    Id userId = PWChrono_ConfigurationController.createPortalUser(
      new Portal_Users__c(
        Name = 'Profile Based User',
        Email__c = 'profile-based@example.com',
        Is_Active__c = true
      ),
      profile.Id,
      null,
      null
    );
    Test.stopTest();

    Portal_Users__c createdUser = [
      SELECT Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :userId
    ];
    System.assertEquals(profile.Id, createdUser.Portal_User_Profile__c);
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM PWChrono_User_Feature_Access__c
        WHERE Portal_User__c = :userId
      ],
      'Profile-based creation must not create per-user feature records.'
    );
  }

  @isTest
  static void testGuestProfilePermissionControlsAdministration() {
    Portal_Users__c adminUser = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'Test User 0'
      LIMIT 1
    ];
    User guestUser = [SELECT Id FROM User WHERE UserType = 'Guest' LIMIT 1];

    System.runAs(guestUser) {
      Test.startTest();
      List<PWChrono_ConfigurationController.PortalProfileOption> profiles = PWChrono_ConfigurationController.getAvailableProfiles(
        String.valueOf(adminUser.Id),
        'configuration_admin_token'
      );
      Test.stopTest();
      System.assertEquals(1, profiles.size());
    }
  }

  @isTest
  static void testGuestWithoutProfilePermissionIsRejected() {
    Portal_User_Profile__c restrictedProfile = new Portal_User_Profile__c();
    insert restrictedProfile;
    Portal_Users__c restrictedUser = new Portal_Users__c(
      Name = 'Restricted Profile User',
      Email__c = 'restricted-profile@example.com',
      Is_Active__c = true,
      Portal_User_Profile__c = restrictedProfile.Id,
      Session_Token__c = 'restricted_profile_token',
      Session_Expires_At__c = System.now().addHours(1)
    );
    insert restrictedUser;
    User guestUser = [SELECT Id FROM User WHERE UserType = 'Guest' LIMIT 1];

    System.runAs(guestUser) {
      Test.startTest();
      try {
        PWChrono_ConfigurationController.getAvailableProfiles(
          String.valueOf(restrictedUser.Id),
          'restricted_profile_token'
        );
        System.assert(false, 'Expected profile administration to be denied.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    }
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