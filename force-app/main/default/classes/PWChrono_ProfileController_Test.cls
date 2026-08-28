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
}