@isTest
private class PWChrono_ProfileController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      testUser.Id,
      'PWChrono_Employee'
    );
    PWChrono_TestDataFactory.createTestEmployee(testUser.Id);
  }

  @isTest
  static void testGetProfile() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      Portal_Users__c profile = PWChrono_ProfileController.getProfile(
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, profile, 'Should return profile');
      System.assertEquals('Test Employee', profile.Name, 'Name should match');
    }
  }

  @isTest
  static void testUpdateProfile() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Map<String, Object> profileData = new Map<String, Object>{
        'Phone__c' => '9876543210',
        'Address__c' => 'New Address',
        'Emergency_Contact_Name__c' => 'Emergency Contact',
        'Emergency_Contact_Phone__c' => '1122334455'
      };

      Test.startTest();
      Portal_Users__c currentEmployee = [
        SELECT Id
        FROM Portal_Users__c
        WHERE User__c = :testUser.Id
        LIMIT 1
      ];
      PWChrono_ProfileController.updateProfile(
        profileData,
        currentEmployee.Id,
        null
      );
      Test.stopTest();

      Portal_Users__c updatedProfile = [
        SELECT Phone__c, Address__c
        FROM Portal_Users__c
        WHERE User__c = :testUser.Id
      ];
      System.assertEquals(
        '9876543210',
        updatedProfile.Phone__c,
        'Phone should be updated'
      );
      System.assertEquals(
        'New Address',
        updatedProfile.Address__c,
        'Address should be updated'
      );
    }
  }

  @isTest
  static void testAccessAwareProfileReadAndUpdate() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      Portal_Users__c profile = PWChrono_ProfileController.getProfileWithAccess(
        employee.Id,
        employee.Id,
        null
      );
      PWChrono_ProfileController.updateProfileWithAccess(
        new Map<String, Object>{
          'Name' => 'Updated Employee',
          'Phone__c' => '5550101',
          'Address__c' => 'Updated Address',
          'Emergency_Contact_Name__c' => 'Emergency Person',
          'Emergency_Contact_Phone__c' => '5550102'
        },
        employee.Id,
        employee.Id,
        null
      );
      Test.stopTest();

      System.assertEquals(employee.Id, profile.Id, 'Profile should match.');
      Portal_Users__c updated = [
        SELECT Name, Phone__c, Address__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertEquals('Updated Employee', updated.Name);
      System.assertEquals('5550101', updated.Phone__c);
      System.assertEquals('Updated Address', updated.Address__c);
    }
  }

  @isTest
  static void testAccessAwareProfileImageUploadReturnsCanonicalUrl() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      String photoUrl = PWChrono_ProfileController.uploadProfileImageWithAccess(
        employee.Id,
        'profile.png',
        EncodingUtil.base64Encode(Blob.valueOf('profile-image')),
        employee.Id,
        null
      );
      Test.stopTest();

      Portal_Users__c updated = [
        SELECT Photo_Url__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertEquals(photoUrl, updated.Photo_Url__c);
      System.assertNotEquals(null, photoUrl, 'Upload should return its URL.');
    }
  }

  @isTest
  static void testLegacyProfileImageUploadReturnsCanonicalUrl() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      String photoUrl = PWChrono_ProfileController.uploadProfileImage(
        employee.Id,
        'legacy-profile.png',
        EncodingUtil.base64Encode(Blob.valueOf('legacy-profile-image')),
        employee.Id,
        null
      );
      Test.stopTest();

      Portal_Users__c updated = [
        SELECT Photo_Url__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertEquals(photoUrl, updated.Photo_Url__c);
      System.assertNotEquals(null, photoUrl, 'Upload should return its URL.');
    }
  }

  @isTest
  static void testInternalAdminCanManageAnotherEmployee() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c currentEmployee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];
    Portal_Users__c otherEmployee = new Portal_Users__c(
      Name = 'Other Employee',
      Email__c = 'other.employee@example.com',
      Is_Active__c = true
    );
    insert otherEmployee;

    System.runAs(testUser) {
      Test.startTest();
      Portal_Users__c profile = PWChrono_ProfileController.getProfileWithAccess(
        otherEmployee.Id,
        currentEmployee.Id,
        null
      );
      PWChrono_ProfileController.updateProfileWithAccess(
        new Map<String, Object>{ 'Phone__c' => '5550199' },
        otherEmployee.Id,
        currentEmployee.Id,
        null
      );
      String photoUrl = PWChrono_ProfileController.uploadProfileImageWithAccess(
        otherEmployee.Id,
        'admin-upload.png',
        EncodingUtil.base64Encode(Blob.valueOf('admin-upload')),
        currentEmployee.Id,
        null
      );
      Test.stopTest();

      System.assertEquals(otherEmployee.Id, profile.Id);
      System.assertNotEquals(null, photoUrl);
      Portal_Users__c updated = [
        SELECT Phone__c, Photo_Url__c
        FROM Portal_Users__c
        WHERE Id = :otherEmployee.Id
      ];
      System.assertEquals('5550199', updated.Phone__c);
      System.assertEquals(photoUrl, updated.Photo_Url__c);
    }
  }

  @isTest
  static void testInvalidInputsReturnSafeErrors() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_ProfileController.getProfile('invalid-id', null);
        System.assert(false, 'Malformed profile id should fail.');
      } catch (AuraHandledException expected) {
        System.assertNotEquals(null, expected.getMessage());
      }
      try {
        PWChrono_ProfileController.updateProfile(
          new Map<String, Object>{ 'Name' => 'Invalid' },
          'invalid-id',
          null
        );
        System.assert(false, 'Malformed update id should fail.');
      } catch (AuraHandledException expected) {
        System.assertNotEquals(null, expected.getMessage());
      }
      try {
        PWChrono_ProfileController.uploadProfileImageWithAccess(
          employee.Id,
          'invalid.png',
          'not-base64',
          employee.Id,
          null
        );
        System.assert(false, 'Malformed image content should fail.');
      } catch (AuraHandledException expected) {
        System.assertNotEquals(null, expected.getMessage());
      }
      try {
        PWChrono_ProfileController.uploadProfileImage(
          employee.Id,
          'legacy-invalid.png',
          'not-base64',
          employee.Id,
          null
        );
        System.assert(false, 'Malformed legacy image content should fail.');
      } catch (AuraHandledException expected) {
        System.assertNotEquals(null, expected.getMessage());
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testGetProfileNoEmployee() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      Portal_Users__c profile = PWChrono_ProfileController.getProfile(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        null,
        profile,
        'Should return null for user without employee record'
      );
    }
  }

  @isTest
  static void testRemoveProfileImageWithAccess() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      // 1. Upload photo first
      PWChrono_ProfileController.uploadProfileImageWithAccess(
        employee.Id,
        'profile-to-remove.png',
        EncodingUtil.base64Encode(Blob.valueOf('photo-data')),
        employee.Id,
        null
      );

      Portal_Users__c withPhoto = [
        SELECT Photo_Url__c, Use_No_Profile_Picture__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertNotEquals(null, withPhoto.Photo_Url__c);

      Test.startTest();
      // 2. Remove photo
      PWChrono_ProfileController.removeProfileImageWithAccess(
        employee.Id,
        employee.Id,
        null
      );
      Test.stopTest();

      Portal_Users__c removed = [
        SELECT Photo_Url__c, Use_No_Profile_Picture__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertEquals(null, removed.Photo_Url__c);
      System.assertEquals(true, removed.Use_No_Profile_Picture__c);

      List<ContentDocumentLink> links = [
        SELECT Id
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :employee.Id
      ];
      System.assertEquals(0, links.size(), 'Attached files should be deleted.');
    }
  }

  @isTest
  static void testLegacyRemoveProfileImage() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      PWChrono_ProfileController.uploadProfileImage(
        employee.Id,
        'legacy-photo.png',
        EncodingUtil.base64Encode(Blob.valueOf('legacy-photo-data')),
        employee.Id,
        null
      );

      Test.startTest();
      PWChrono_ProfileController.removeProfileImage(
        employee.Id,
        employee.Id,
        null
      );
      Test.stopTest();

      Portal_Users__c removed = [
        SELECT Photo_Url__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
      ];
      System.assertEquals(null, removed.Photo_Url__c);
    }
  }

  @isTest
  static void testGuestContentDistribution() {
    User guestUser = [SELECT Id FROM User WHERE UserType = 'Guest' AND Profile.Name = 'Pulse Work Chrono Profile' AND IsActive = true LIMIT 1];
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c LIMIT 1];
    System.runAs(guestUser) {
      try {
        PWChrono_ProfileController.uploadProfileImage(
          emp.Id,
          'guest-test.png',
          EncodingUtil.base64Encode(Blob.valueOf('test')),
          emp.Id,
          null
        );
      } catch (Exception e) {
        System.debug('=== RUNAS GUEST ERROR: ' + e.getMessage());
      }
    }
  }
}