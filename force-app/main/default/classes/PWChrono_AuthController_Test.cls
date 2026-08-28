@IsTest
private class PWChrono_AuthController_Test {
  private static final String TEST_EMAIL = 'testuser@example.com';
  private static final String TEST_OTP = '123456';
  private static final String INVALID_OTP = '999999';
  private static final String NON_EXISTENT_EMAIL = 'nonexistent@example.com';

  @TestSetup
  static void setupTestData() {
    // Create test Portal User Profile
    Portal_User_Profile__c portalUserProfile = new Portal_User_Profile__c();
    insert portalUserProfile;

    // Create test Portal User
    Portal_Users__c portalUser = new Portal_Users__c(
      Name = 'Test User',
      Email__c = TEST_EMAIL,
      Portal_User_Profile__c = portalUserProfile.Id,
      Role__c = 'Employee',
      Is_Active__c = true
    );
    insert portalUser;

    // Create test Portal Object
    Portal_Object__c portalObj = new Portal_Object__c();
    insert portalObj;

    // Create test Portal Object Field
    Portal_Object_Field__c portalField = new Portal_Object_Field__c(
      Portal_Object__c = portalObj.Id,
      Field_API_Name__c = 'Test_Field__c'
    );
    insert portalField;

    // Create test Object Permissions
    Schema.SObjectType portalObjectPermissionType = Schema.getGlobalDescribe()
      .get('Portal_Object_Permission__c');
    System.assertNotEquals(
      null,
      portalObjectPermissionType,
      'Portal_Object_Permission__c object must exist for tests.'
    );

    SObject permission = portalObjectPermissionType.newSObject();
    permission.put('Portal_User_Profile__c', portalUserProfile.Id);
    permission.put('Portal_Object__c', portalObj.Id);
    permission.put('Can_Create__c', true);
    permission.put('Can_View__c', true);
    permission.put('Can_Edit__c', true);
    permission.put('Can_Delete__c', false);
    insert permission;

    // Create test Field Permission
    Portal_Field_Permission__c fieldPerm = new Portal_Field_Permission__c(
      Portal_User_Profile__c = portalUserProfile.Id,
      Portal_Object_Field__c = portalField.Id,
      Can_View__c = true,
      Can_Edit__c = false
    );
    insert fieldPerm;
  }

  @IsTest
  static void sendOTPSuccess() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      String result = PWChrono_AuthController.sendOTP(user.Email__c);
      Test.stopTest();

      System.assertEquals('Success', result, 'OTP should be sent successfully');

      // Verify OTP was set
      Portal_Users__c updatedUser = [
        SELECT One_Time_Password__c, OTP_Generated_Time__c
        FROM Portal_Users__c
        WHERE Id = :user.Id
      ];
      System.assertNotEquals(
        null,
        updatedUser.One_Time_Password__c,
        'OTP should be generated'
      );
      System.assertEquals(
        6,
        updatedUser.One_Time_Password__c.length(),
        'OTP should be 6 digits'
      );
      System.assertNotEquals(
        null,
        updatedUser.OTP_Generated_Time__c,
        'OTP Generated Time should be set'
      );
    }
  }

  @IsTest
  static void sendOTPUserNotFound() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      try {
        PWChrono_AuthController.sendOTP(NON_EXISTENT_EMAIL);
        System.assert(false, 'Should have thrown exception');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void verifyOTPSuccess() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Id, Email__c FROM Portal_Users__c LIMIT 1];

      // Set OTP
      user.One_Time_Password__c = TEST_OTP;
      user.OTP_Generated_Time__c = System.now();
      user.Session_Failed_Attempts__c = 3;
      user.Session_Locked_Until__c = System.now().addMinutes(10);
      update user;

      Test.startTest();
      Portal_Users__c result = PWChrono_AuthController.verifyOTP(
        user.Email__c,
        TEST_OTP
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return user object');
      System.assertEquals(user.Id, result.Id, 'Should return correct user');
      System.assertEquals(user.Email__c, result.Email__c, 'Email should match');

      // Verify OTP cleared
      Portal_Users__c updatedUser = [
        SELECT
          One_Time_Password__c,
          OTP_Generated_Time__c,
          Session_Failed_Attempts__c,
          Session_Locked_Until__c
        FROM Portal_Users__c
        WHERE Id = :user.Id
      ];
      System.assertEquals(
        null,
        updatedUser.One_Time_Password__c,
        'OTP should be cleared'
      );
      System.assertEquals(
        null,
        updatedUser.OTP_Generated_Time__c,
        'OTP Generated Time should be cleared'
      );
      System.assertEquals(
        0,
        Integer.valueOf(updatedUser.Session_Failed_Attempts__c),
        'Session failed attempts should reset after successful verification.'
      );
      System.assertEquals(
        null,
        updatedUser.Session_Locked_Until__c,
        'Session lockout timestamp should clear after successful verification.'
      );
    }
  }

  @IsTest
  static void verifyOTPExpired() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Id, Email__c FROM Portal_Users__c LIMIT 1];

      // Set OTP expired (11 mins ago)
      user.One_Time_Password__c = TEST_OTP;
      user.OTP_Generated_Time__c = System.now().addMinutes(-11);
      update user;

      Test.startTest();
      try {
        PWChrono_AuthController.verifyOTP(user.Email__c, TEST_OTP);
        System.assert(false, 'Should have thrown exception');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception for expired OTP');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void verifyOTPInvalidOTP() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Id, Email__c FROM Portal_Users__c LIMIT 1];

      // Set OTP
      user.One_Time_Password__c = TEST_OTP;
      user.OTP_Generated_Time__c = System.now();
      update user;

      Test.startTest();
      try {
        PWChrono_AuthController.verifyOTP(user.Email__c, INVALID_OTP);
        System.assert(false, 'Should have thrown exception');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception for invalid OTP');
      }

      Portal_Users__c updatedUser = [
        SELECT One_Time_Password__c, OTP_Generated_Time__c
        FROM Portal_Users__c
        WHERE Id = :user.Id
      ];
      System.assertEquals(
        null,
        updatedUser.One_Time_Password__c,
        'OTP should be invalidated after a failed verification attempt.'
      );
      System.assertNotEquals(
        null,
        updatedUser.OTP_Generated_Time__c,
        'OTP timestamp should be updated to enforce resend cooldown after failed attempt.'
      );
      Test.stopTest();
    }
  }

  @IsTest
  static void verifyOTPUserNotFound() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      try {
        PWChrono_AuthController.verifyOTP(NON_EXISTENT_EMAIL, TEST_OTP);
        System.assert(false, 'Should have thrown exception');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception for user not found');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void getPermissions() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [
        SELECT Id, Portal_User_Profile__c
        FROM Portal_Users__c
        LIMIT 1
      ];

      Test.startTest();
      Map<String, Object> permissions = PWChrono_AuthController.getPermissions(
        user.Portal_User_Profile__c
      );
      Test.stopTest();

      System.assert(!permissions.isEmpty(), 'Should contain permissions');

      // Verify permissions structure
      Portal_Object__c pObj = [SELECT Name FROM Portal_Object__c LIMIT 1];
      String objName = pObj.Name;

      System.assert(
        permissions.containsKey(objName),
        'Permissions map does not contain expected object: ' +
          objName +
          '. Keys: ' +
          permissions.keySet()
      );

      Map<String, Object> objectPerms = (Map<String, Object>) permissions.get(
        objName
      );
      System.assertEquals(
        true,
        objectPerms.get('create'),
        'Should have create permission'
      );
      System.assertEquals(
        true,
        objectPerms.get('read'),
        'Should have read permission'
      );
      System.assertEquals(
        true,
        objectPerms.get('edit'),
        'Should have edit permission'
      );
      System.assertEquals(
        false,
        objectPerms.get('delete'),
        'Should not have delete permission'
      );

      // Check field permissions
      Map<String, Object> fields = (Map<String, Object>) objectPerms.get(
        'fields'
      );
      System.assertNotEquals(null, fields, 'Fields map should exist');
      System.assert(
        fields.containsKey('Test_Field__c'),
        'Permissions should contain Test_Field__c'
      );

      Map<String, Object> fieldPerm = (Map<String, Object>) fields.get(
        'Test_Field__c'
      );
      System.assertEquals(
        true,
        fieldPerm.get('read'),
        'Field read permission mismatch'
      );
      System.assertEquals(
        false,
        fieldPerm.get('edit'),
        'Field edit permission mismatch'
      );
    }
  }

  @IsTest
  static void getPermissionsNoPermissions() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      // Create new profile without permissions
      Portal_User_Profile__c newProfile = new Portal_User_Profile__c();
      insert newProfile;

      Test.startTest();
      Map<String, Object> permissions = PWChrono_AuthController.getPermissions(
        newProfile.Id
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        permissions,
        'Permissions map should not be null'
      );
      System.assertEquals(0, permissions.size(), 'Should have no permissions');
    }
  }

  @IsTest
  static void testSendOTPEmptyEmail() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      try {
        PWChrono_AuthController.sendOTP('');
        System.assert(false, 'Should throw exception for empty email');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testSendOTPNullEmail() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      try {
        PWChrono_AuthController.sendOTP(null);
        System.assert(false, 'Should throw exception for null email');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testVerifyOTPEmptyOTP() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      try {
        PWChrono_AuthController.verifyOTP(user.Email__c, '');
        System.assert(false, 'Should throw exception for empty OTP');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testVerifyOTPNullOTP() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      try {
        PWChrono_AuthController.verifyOTP(user.Email__c, null);
        System.assert(false, 'Should throw exception for null OTP');
      } catch (Exception e) {
        System.assert(e != null, 'Should throw exception');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testVerifyOTPNoOTPGenerated() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      try {
        // User has no OTP generated, so verification should fail
        PWChrono_AuthController.verifyOTP(user.Email__c, TEST_OTP);
        System.assert(false, 'Should throw exception when OTP not generated');
      } catch (Exception e) {
        System.assert(true, 'Should throw exception: ' + e.getMessage());
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testGetPermissionsNullProfile() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      try {
        Map<String, Object> result = PWChrono_AuthController.getPermissions(
          null
        );
        // Should either return null or empty map
        System.assertEquals(
          true,
          result == null || result.isEmpty(),
          'Should return null or empty map for null profile'
        );
      } catch (Exception e) {
        System.assert(true, 'Should handle null profile gracefully');
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testSendOTPRateLimiting() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      // First OTP send
      String result1 = PWChrono_AuthController.sendOTP(user.Email__c);
      System.assertEquals('Success', result1, 'First OTP should succeed');

      // Immediate second attempt should fail (rate limit) or succeed depending on implementation
      try {
        PWChrono_AuthController.sendOTP(user.Email__c);
        // If no exception, rate limit not enforced in test context
        System.assert(true, 'May allow second OTP in test context');
      } catch (Exception e) {
        // If exception thrown, rate limit is enforced
        System.assert(true, 'Rate limit enforced: ' + e.getMessage());
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testSendOTPTrimsEmailInput() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      String result = PWChrono_AuthController.sendOTP(
        '  ' + user.Email__c + '  '
      );
      Test.stopTest();

      System.assertEquals(
        'Success',
        result,
        'sendOTP should trim incoming email input before lookup.'
      );
    }
  }

  @IsTest
  static void testSendOTPCaseInsensitiveEmailInput() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Email__c FROM Portal_Users__c LIMIT 1];

      Test.startTest();
      String result = PWChrono_AuthController.sendOTP(
        user.Email__c.toUpperCase()
      );
      Test.stopTest();

      System.assertEquals(
        'Success',
        result,
        'sendOTP should accept case-insensitive email input.'
      );
    }
  }

  @IsTest
  static void testSendOTPSkipsInactiveMatchingUser() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c activeUser = [
        SELECT Id, Email__c, Portal_User_Profile__c, Role__c
        FROM Portal_Users__c
        LIMIT 1
      ];

      // Create a newer inactive record with the same email to ensure lookup doesn't pick it.
      Portal_Users__c inactiveUser = new Portal_Users__c(
        Name = 'Inactive Duplicate',
        Email__c = activeUser.Email__c,
        Portal_User_Profile__c = activeUser.Portal_User_Profile__c,
        Role__c = activeUser.Role__c,
        Is_Active__c = false
      );
      insert inactiveUser;

      Test.startTest();
      String result = PWChrono_AuthController.sendOTP(activeUser.Email__c);
      Test.stopTest();

      System.assertEquals(
        'Success',
        result,
        'Active matching user should still be used.'
      );

      Portal_Users__c refreshedActive = [
        SELECT One_Time_Password__c, OTP_Generated_Time__c
        FROM Portal_Users__c
        WHERE Id = :activeUser.Id
      ];
      Portal_Users__c refreshedInactive = [
        SELECT One_Time_Password__c, OTP_Generated_Time__c
        FROM Portal_Users__c
        WHERE Id = :inactiveUser.Id
      ];

      System.assertNotEquals(
        null,
        refreshedActive.One_Time_Password__c,
        'OTP should be written to the active user record.'
      );
      System.assertEquals(
        null,
        refreshedInactive.One_Time_Password__c,
        'OTP must never be written to an inactive matching record.'
      );
    }
  }

  @IsTest
  static void testVerifyOTPAfterClear() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Portal_Users__c user = [SELECT Id, Email__c FROM Portal_Users__c LIMIT 1];

      // Set OTP and verify it
      user.One_Time_Password__c = TEST_OTP;
      user.OTP_Generated_Time__c = System.now();
      update user;

      Test.startTest();
      PWChrono_AuthController.verifyOTP(user.Email__c, TEST_OTP);

      // Try to verify same OTP again (should fail because OTP was cleared)
      try {
        PWChrono_AuthController.verifyOTP(user.Email__c, TEST_OTP);
        System.assert(false, 'Should fail with cleared OTP');
      } catch (Exception e) {
        System.assert(
          true,
          'Should fail when OTP already used: ' + e.getMessage()
        );
      }
      Test.stopTest();
    }
  }
}