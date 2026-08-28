@isTest
private class PWChrono_TrainingController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      testUser.Id,
      'PWChrono_HR_Admin'
    );

    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );

    PWChrono_Training_Program__c program = new PWChrono_Training_Program__c(
      Name = 'Apex Basics',
      Description__c = 'Learn Apex',
      Trainer__c = 'John Doe',
      Duration_Hours__c = 10
    );
    insert program;

    PWChrono_Training_Event__c event1 = new PWChrono_Training_Event__c(
      Training_Program__c = program.Id,
      Start_Date__c = Date.today().addDays(5),
      End_Date__c = Date.today().addDays(6),
      Location__c = 'Room A',
      Status__c = PWChrono_Constants.STATUS_SCHEDULED
    );
    insert event1;

    PWChrono_Training_Event__c event2 = new PWChrono_Training_Event__c(
      Training_Program__c = program.Id,
      Start_Date__c = Date.today().addDays(10),
      End_Date__c = Date.today().addDays(11),
      Location__c = 'Room B',
      Status__c = PWChrono_Constants.STATUS_SCHEDULED
    );
    insert event2;

    PWChrono_Training_Attendance__c attendance = new PWChrono_Training_Attendance__c(
      Employees__c = employee.Id,
      Training_Event__c = event2.Id
    );
    insert attendance;
  }

  @isTest
  static void testGetUpcomingTrainings() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Training_Event__c> events = PWChrono_TrainingController.getUpcomingTrainings();
      Test.stopTest();

      System.assertEquals(2, events.size(), 'Should return 2 upcoming events');
    }
  }

  @isTest
  static void testGetMyRegistrations() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Training_Attendance__c> registrations = PWChrono_TrainingController.getMyRegistrations(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        registrations.size(),
        'Should return 1 registration'
      );
    }
  }

  @isTest
  static void testRegisterForTraining() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Training_Event__c event = [
      SELECT Id
      FROM PWChrono_Training_Event__c
      WHERE Location__c = 'Room A'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_TrainingController.registerForTraining(event.Id, null, null);
      Test.stopTest();

      List<PWChrono_Training_Attendance__c> registrations = [
        SELECT Id
        FROM PWChrono_Training_Attendance__c
        WHERE Training_Event__c = :event.Id
      ];
      System.assertEquals(1, registrations.size(), 'Should be registered');
    }
  }

  @isTest
  static void testCancelRegistration() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Training_Attendance__c attendance = [
      SELECT Id
      FROM PWChrono_Training_Attendance__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_TrainingController.cancelRegistration(attendance.Id, null, null);
      Test.stopTest();

      List<PWChrono_Training_Attendance__c> registrations = [
        SELECT Id
        FROM PWChrono_Training_Attendance__c
        WHERE Id = :attendance.Id
      ];
      System.assertEquals(
        0,
        registrations.size(),
        'Registration should be cancelled'
      );
    }
  }

  @isTest
  static void testGetMyRegistrationsNoEmployee() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      try {
        PWChrono_TrainingController.getMyRegistrations(null, null);
        System.assert(false, 'Should throw exception');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }
}