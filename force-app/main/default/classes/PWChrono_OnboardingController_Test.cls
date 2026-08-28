@isTest
private class PWChrono_OnboardingController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );

      PWChrono_Onboarding_Task__c task1 = new PWChrono_Onboarding_Task__c(
        Name = 'Task 1',
        Description__c = 'Description 1',
        Status__c = PWChrono_Constants.STATUS_PENDING,
        Due_Date__c = Date.today().addDays(5),
        Is_Mandatory__c = true,
        Assigned_Tos__c = employee.Id
      );
      insert task1;

      PWChrono_Onboarding_Task__c task2 = new PWChrono_Onboarding_Task__c(
        Name = 'Task 2',
        Description__c = 'Description 2',
        Status__c = PWChrono_Constants.STATUS_COMPLETED,
        Due_Date__c = Date.today().addDays(2),
        Is_Mandatory__c = false,
        Assigned_Tos__c = employee.Id
      );
      insert task2;
    }
  }

  @isTest
  static void testGetOnboardingTasks() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Onboarding_Task__c> tasks = PWChrono_OnboardingController.getOnboardingTasks(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(2, tasks.size(), 'Should return 2 tasks');
    }
  }

  @isTest
  static void testUpdateTaskStatus() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Onboarding_Task__c task = [
      SELECT Id, Status__c
      FROM PWChrono_Onboarding_Task__c
      WHERE Name = 'Task 1'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_OnboardingController.updateTaskStatus(
        task.Id,
        'Completed',
        null,
        null
      );
      Test.stopTest();

      PWChrono_Onboarding_Task__c updatedTask = [
        SELECT Status__c
        FROM PWChrono_Onboarding_Task__c
        WHERE Id = :task.Id
      ];
      System.assertEquals(
        'Completed',
        updatedTask.Status__c,
        'Status should be updated'
      );
    }
  }

  @isTest
  static void testGetOnboardingTasksNoEmployee() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      List<PWChrono_Onboarding_Task__c> tasks = PWChrono_OnboardingController.getOnboardingTasks(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        0,
        tasks.size(),
        'Should return 0 tasks for user without employee record'
      );
    }
  }
}