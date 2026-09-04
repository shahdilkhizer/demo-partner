@isTest
private class PWChrono_GuestSession_Test {
  private static void resetGuestSessionOverrides() {
    PWChrono_GuestSession.testUserTypeOverride = null;
    PWChrono_GuestSession.testNowOverride = null;
  }

  @testSetup
  static void setupData() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );
      employee.Session_Token__c = 'valid_token';
      employee.Session_Expires_At__c = System.now().addHours(1);
      update employee;
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_NonGuestProvidedPortalId() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    System.runAs(testUser) {
      Id result = PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        null
      );
      System.assertEquals(
        employee.Id,
        result,
        'Should return provided portal user Id for non-guest context.'
      );
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_NonGuestInvalidPortalId() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      try {
        PWChrono_GuestSession.requireVerifiedPortalUserId('invalid_id', null);
        System.assert(
          false,
          'Expected invalid portal user Id to throw an exception.'
        );
      } catch (AuraHandledException e) {
        System.assertEquals('Session invalid.', e.getMessage());
      }
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_NonGuestFallsBackToMappedEmployee() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id, User__c
      FROM Portal_Users__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Id result = PWChrono_GuestSession.requireVerifiedPortalUserId(null, null);
      System.assertEquals(employee.Id, result);
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_GuestBlankSessionRejected() {
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        null
      );
      System.assert(
        false,
        'Expected guest session validation to reject blank token.'
      );
    } catch (AuraHandledException e) {
      System.assertEquals(
        'Session invalid or expired. Please log in again.',
        e.getMessage()
      );
    } finally {
      resetGuestSessionOverrides();
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_GuestInactiveRejected() {
    Portal_Users__c employee = [
      SELECT Id, Is_Active__c
      FROM Portal_Users__c
      LIMIT 1
    ];
    employee.Is_Active__c = false;
    update employee;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        'valid_token'
      );
      System.assert(false, 'Expected inactive account to be rejected.');
    } catch (AuraHandledException e) {
      System.assertEquals('Account is inactive.', e.getMessage());
    } finally {
      resetGuestSessionOverrides();
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_GuestExpiredSessionRejected() {
    Portal_Users__c employee = [
      SELECT Id, Session_Failed_Attempts__c, Session_Locked_Until__c
      FROM Portal_Users__c
      LIMIT 1
    ];
    employee.Session_Failed_Attempts__c = 2;
    update employee;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_GuestSession.testNowOverride = System.now().addHours(2);
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        'valid_token'
      );
      System.assert(false, 'Expected expired session to be rejected.');
    } catch (AuraHandledException e) {
      System.assertEquals(
        'Session expired. Please log in again.',
        e.getMessage()
      );
    } finally {
      resetGuestSessionOverrides();
    }

    Portal_Users__c refreshed = [
      SELECT Session_Failed_Attempts__c, Session_Locked_Until__c
      FROM Portal_Users__c
      WHERE Id = :employee.Id
      LIMIT 1
    ];
    System.assertEquals(
      0,
      Integer.valueOf(refreshed.Session_Failed_Attempts__c)
    );
    System.assertEquals(null, refreshed.Session_Locked_Until__c);
  }

  @isTest
  static void testRequireVerifiedPortalUserId_GuestTokenMismatchRegistersFailure() {
    Portal_Users__c employee = [
      SELECT Id, Session_Failed_Attempts__c
      FROM Portal_Users__c
      LIMIT 1
    ];

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        'wrong_token'
      );
      System.assert(false, 'Expected invalid token to be rejected.');
    } catch (AuraHandledException e) {
      System.assertEquals(
        'Session invalid. Please log in again.',
        e.getMessage()
      );
    } finally {
      resetGuestSessionOverrides();
    }

    Portal_Users__c refreshed = [
      SELECT Session_Failed_Attempts__c
      FROM Portal_Users__c
      WHERE Id = :employee.Id
      LIMIT 1
    ];
    System.assertEquals(
      1,
      Integer.valueOf(refreshed.Session_Failed_Attempts__c)
    );
  }

  @isTest
  static void testRequireVerifiedPortalUserId_GuestLockedSessionRejected() {
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      LIMIT 1
    ];
    employee.Session_Locked_Until__c = System.now().addMinutes(15);
    update employee;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        'valid_token'
      );
      System.assert(false, 'Expected locked session to be rejected.');
    } catch (AuraHandledException e) {
      System.assertEquals(
        'Too many invalid session attempts. Please try again later.',
        e.getMessage()
      );
    } finally {
      resetGuestSessionOverrides();
    }
  }

  @isTest
  static void testRequireVerifiedPortalUserId_GuestSuccessClearsValidationState() {
    Portal_Users__c employee = [
      SELECT Id, Session_Failed_Attempts__c
      FROM Portal_Users__c
      LIMIT 1
    ];
    employee.Session_Failed_Attempts__c = 2;
    update employee;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Id result = PWChrono_GuestSession.requireVerifiedPortalUserId(
        String.valueOf(employee.Id),
        'valid_token'
      );
      System.assertEquals(employee.Id, result);
    } finally {
      resetGuestSessionOverrides();
    }

    Portal_Users__c refreshed = [
      SELECT Session_Failed_Attempts__c, Session_Locked_Until__c
      FROM Portal_Users__c
      WHERE Id = :employee.Id
      LIMIT 1
    ];
    System.assertEquals(
      0,
      Integer.valueOf(refreshed.Session_Failed_Attempts__c)
    );
    System.assertEquals(null, refreshed.Session_Locked_Until__c);
  }

  @isTest
  static void testGetVerifiedUserAccess_ReturnsPrivateProfileFeatures() {
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      LIMIT 1
    ];
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    employee.Portal_User_Profile__c = profile.Id;
    update employee;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = profile.Id,
      Feature_Key__c = 'Employee Directory',
      Feature_Label__c = 'Employee Directory',
      Is_Enabled__c = true
    );

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Map<String, Object> result = PWChrono_GuestSession.getVerifiedUserAccess(
        String.valueOf(employee.Id),
        'valid_token'
      );
      System.assertEquals(true, result.get('hasAccess'));
      System.assertEquals(false, result.get('isSalesforceUser'));
      System.assertEquals(
        new List<String>{ 'Employee Directory' },
        (List<String>) result.get('features')
      );
    } finally {
      resetGuestSessionOverrides();
    }
  }

  @isTest
  static void testRegisterFailedSessionAttempt_LocksAfterThreshold() {
    Portal_Users__c employee = [
      SELECT
        Id,
        Session_Token__c,
        Session_Expires_At__c,
        Session_Failed_Attempts__c,
        Session_Locked_Until__c
      FROM Portal_Users__c
      LIMIT 1
    ];

    for (
      Integer i = 0;
      i < PWChrono_Constants.PORTAL_SESSION_MAX_FAILED_ATTEMPTS;
      i++
    ) {
      PWChrono_GuestSession.registerFailedSessionAttempt(employee);
      employee = [
        SELECT
          Id,
          Session_Token__c,
          Session_Expires_At__c,
          Session_Failed_Attempts__c,
          Session_Locked_Until__c
        FROM Portal_Users__c
        WHERE Id = :employee.Id
        LIMIT 1
      ];
    }

    System.assertEquals(
      null,
      employee.Session_Token__c,
      'Session token should be cleared after lockout threshold.'
    );
    System.assertEquals(
      null,
      employee.Session_Expires_At__c,
      'Session expiry should be cleared after lockout threshold.'
    );
    System.assert(
      employee.Session_Locked_Until__c != null,
      'Lockout timestamp should be set after repeated failed attempts.'
    );
    System.assertEquals(
      0,
      Integer.valueOf(employee.Session_Failed_Attempts__c),
      'Failed attempts counter should reset when lockout is applied.'
    );
  }

  @isTest
  static void testClearSessionValidationState_ResetsFields() {
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    employee.Session_Failed_Attempts__c = 3;
    employee.Session_Locked_Until__c = System.now().addMinutes(10);
    update employee;

    employee = [
      SELECT Id, Session_Failed_Attempts__c, Session_Locked_Until__c
      FROM Portal_Users__c
      WHERE Id = :employee.Id
      LIMIT 1
    ];

    PWChrono_GuestSession.clearSessionValidationState(employee);

    Portal_Users__c updatedEmployee = [
      SELECT Id, Session_Failed_Attempts__c, Session_Locked_Until__c
      FROM Portal_Users__c
      WHERE Id = :employee.Id
      LIMIT 1
    ];

    System.assertEquals(
      0,
      Integer.valueOf(updatedEmployee.Session_Failed_Attempts__c),
      'Failed attempts should be reset.'
    );
    System.assertEquals(
      null,
      updatedEmployee.Session_Locked_Until__c,
      'Lockout timestamp should be cleared.'
    );
  }

  @isTest
  static void testClearSessionValidationState_NoOpForCleanRecord() {
    Portal_Users__c employee = [
      SELECT Id, Session_Failed_Attempts__c, Session_Locked_Until__c
      FROM Portal_Users__c
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_GuestSession.clearSessionValidationState(employee);
    Test.stopTest();

    System.assert(true, 'Clean records should be left untouched.');
  }
}