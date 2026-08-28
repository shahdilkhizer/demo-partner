@isTest
private class PWChrono_HolidayController_Test {
  @TestSetup
  static void makeData() {
    // Create User (Standard User usually has read access to holidays)
    User testUser = PWChrono_TestDataFactory.createTestUser('Standard User');
    PWChrono_TestDataFactory.assignPermissionSet(
      testUser.Id,
      'PWChrono_HR_Admin'
    );

    // Create Holiday
    PWChrono_Holiday__c holiday = new PWChrono_Holiday__c(
      Name = 'New Year',
      Holiday_Date__c = Date.today().addDays(10),
      Description__c = 'Happy New Year',
      Is_Weekly_Off__c = false
    );
    insert holiday;
  }

  @isTest
  static void testGetUpcomingHolidays() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'Standard User'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Holiday__c> holidays = PWChrono_HolidayController.getUpcomingHolidays();
      Test.stopTest();

      System.assert(!holidays.isEmpty(), 'Should return upcoming holidays');
    }
  }
}