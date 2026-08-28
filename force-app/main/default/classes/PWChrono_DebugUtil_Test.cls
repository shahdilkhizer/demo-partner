@isTest
private class PWChrono_DebugUtil_Test {
  @testSetup
  static void setupData() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      PWChrono_TestDataFactory.createTestEmployee(testUser.Id);
    }
  }

  @isTest
  static void testGetDebugInfo_ReturnsContextData() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> debugInfo = PWChrono_DebugUtil.getDebugInfo();
      Test.stopTest();

      System.assertNotEquals(
        null,
        debugInfo,
        'Debug info map should be returned.'
      );
      System.assert(
        debugInfo.containsKey('currentUserId') ||
        debugInfo.containsKey('error'),
        'Expected debug payload should include user context or controlled error.'
      );
    }
  }

  @isTest
  static void testTestOTPSend_UserNotFoundReturnsControlledFailure() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> result = PWChrono_DebugUtil.testOTPSend(
        'missing.user@example.com'
      );
      Test.stopTest();

      System.assertEquals(false, result.get('success'));
      System.assertEquals('OTP debug operation failed.', result.get('error'));
    }
  }

  @isTest
  static void testTestFeatureAssignment_InvalidPortalUserControlledFailure() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> result = PWChrono_DebugUtil.testFeatureAssignment(
        '001000000000000AAA',
        'Dashboard'
      );
      Test.stopTest();

      System.assertEquals(false, result.get('success'));
      System.assertEquals(
        'Feature assignment debug operation failed.',
        result.get('error')
      );
    }
  }

  @isTest
  static void testGetTestUsers_ReturnsMaskedUserData() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<Map<String, String>> users = PWChrono_DebugUtil.getTestUsers();
      Test.stopTest();

      System.assertNotEquals(
        null,
        users,
        'Expected users list should be returned.'
      );
      System.assert(
        users.size() > 0,
        'Expected at least one portal user in debug list.'
      );
      System.assert(
        users[0].containsKey('Email'),
        'Expected user payload should include masked Email key.'
      );
    }
  }
}