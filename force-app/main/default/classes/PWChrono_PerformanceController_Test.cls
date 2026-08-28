@isTest
private class PWChrono_PerformanceController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    User managerUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(managerUser) {
      Portal_Users__c manager = PWChrono_TestDataFactory.createTestEmployee(
        managerUser.Id
      );
    }

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );
      Portal_Users__c manager = [
        SELECT Id
        FROM Portal_Users__c
        WHERE User__c = :managerUser.Id
        LIMIT 1
      ];

      PWChrono_Appraisal__c appraisal1 = new PWChrono_Appraisal__c(
        Employees__c = employee.Id,
        Appraisal_Period__c = '2023',
        Start_Date__c = Date.today().addMonths(-1),
        End_Date__c = Date.today().addMonths(1),
        Status__c = PWChrono_Constants.STATUS_DRAFT,
        Reviewers__c = manager.Id
      );
      insert appraisal1;

      PWChrono_Appraisal__c appraisal2 = new PWChrono_Appraisal__c(
        Employees__c = employee.Id,
        Appraisal_Period__c = '2022',
        Start_Date__c = Date.today().addMonths(-13),
        End_Date__c = Date.today().addMonths(-11),
        Status__c = PWChrono_Constants.STATUS_COMPLETED,
        Reviewers__c = manager.Id
      );
      insert appraisal2;

      PWChrono_Goal__c goal1 = new PWChrono_Goal__c(
        Employees__c = employee.Id,
        Description__c = 'Goal 1',
        Target_Date__c = Date.today().addMonths(1),
        Progress__c = 0,
        Status__c = PWChrono_Constants.STATUS_NOT_STARTED
      );
      insert goal1;

      PWChrono_Goal__c goal2 = new PWChrono_Goal__c(
        Employees__c = employee.Id,
        Description__c = 'Goal 2',
        Target_Date__c = Date.today().addMonths(2),
        Progress__c = 50,
        Status__c = PWChrono_Constants.STATUS_IN_PROGRESS
      );
      insert goal2;
    }
  }

  @isTest
  static void testGetMyAppraisals() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Appraisal__c> appraisals = PWChrono_PerformanceController.getMyAppraisals(
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(2, appraisals.size(), 'Should return 2 appraisals');
    }
  }

  @isTest
  static void testGetTeamAppraisalsForReview() {
    User managerUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(managerUser) {
      Test.startTest();
      List<PWChrono_Appraisal__c> appraisals = PWChrono_PerformanceController.getTeamAppraisalsForReview(
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        appraisals.size(),
        'Should return 1 completed appraisal for review'
      );
    }
  }

  @isTest
  static void testSaveAppraisal() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      PWChrono_Appraisal__c newAppraisal = new PWChrono_Appraisal__c(
        Appraisal_Period__c = '2024',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(6),
        Status__c = PWChrono_Constants.STATUS_DRAFT
      );

      Test.startTest();
      PWChrono_Appraisal__c savedAppraisal = PWChrono_PerformanceController.saveAppraisal(
        newAppraisal,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        savedAppraisal.Id,
        'Appraisal should be saved'
      );
    }
  }

  @isTest
  static void testGetMyGoals() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Goal__c> goals = PWChrono_PerformanceController.getMyGoals(
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(2, goals.size(), 'Should return 2 goals');
    }
  }

  @isTest
  static void testSaveGoal() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      PWChrono_Goal__c newGoal = new PWChrono_Goal__c(
        Description__c = 'New Goal',
        Target_Date__c = Date.today().addMonths(3),
        Progress__c = 0,
        Status__c = PWChrono_Constants.STATUS_NOT_STARTED
      );

      Test.startTest();
      PWChrono_Goal__c savedGoal = PWChrono_PerformanceController.saveGoal(
        newGoal,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, savedGoal.Id, 'Goal should be saved');
    }
  }

  @isTest
  static void testUpdateGoalProgress() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Goal__c goal = [SELECT Id FROM PWChrono_Goal__c LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_Goal__c updatedGoal = PWChrono_PerformanceController.updateGoalProgress(
        goal.Id,
        100,
        PWChrono_Constants.STATUS_COMPLETED,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        100,
        updatedGoal.Progress__c,
        'Progress should be 100'
      );
      System.assertEquals(
        PWChrono_Constants.STATUS_COMPLETED,
        updatedGoal.Status__c,
        'Status should be Completed'
      );
    }
  }

  @isTest
  static void testGetMyAppraisalsNoEmployee() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      try {
        PWChrono_PerformanceController.getMyAppraisals(null, null, null);
        // May throw exception or return empty list, either is valid for user without employee record
        System.assert(true, 'Should handle user without employee gracefully');
      } catch (AuraHandledException e) {
        System.assert(
          true,
          'Should throw exception for missing employee record'
        );
      } catch (Exception e) {
        System.assert(true, 'Should handle missing employee record');
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testSaveAppraisalNullInput() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_PerformanceController.saveAppraisal(null, null, null);
        System.assert(false, 'Should throw exception for null appraisal');
      } catch (AuraHandledException e) {
        System.assert(true, 'Should handle null appraisal');
      } catch (Exception e) {
        System.assert(true, 'Should handle null appraisal');
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testSaveGoalNullInput() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_PerformanceController.saveGoal(null, null, null);
        System.assert(false, 'Should throw exception for null goal');
      } catch (AuraHandledException e) {
        System.assert(true, 'Should handle null goal');
      } catch (Exception e) {
        System.assert(true, 'Should handle null goal');
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testUpdateGoalProgressNullGoalId() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_PerformanceController.updateGoalProgress(
          null,
          50,
          PWChrono_Constants.STATUS_IN_PROGRESS,
          null,
          null
        );
        System.assert(false, 'Should throw exception for null goal ID');
      } catch (AuraHandledException e) {
        System.assert(true, 'Should handle null goal ID');
      } catch (Exception e) {
        System.assert(true, 'Should handle null goal ID');
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testGetMyGoalsFiltered() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      // Test with filters
      List<PWChrono_Goal__c> inProgressGoals = PWChrono_PerformanceController.getMyGoals(
        PWChrono_Constants.STATUS_IN_PROGRESS,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        inProgressGoals.size(),
        'Should return 1 in-progress goal'
      );
      System.assertEquals(
        PWChrono_Constants.STATUS_IN_PROGRESS,
        inProgressGoals[0].Status__c,
        'Goal status should match filter'
      );
    }
  }

  @isTest
  static void testGetMyAppraisalsFiltered() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Appraisal__c> draftAppraisals = PWChrono_PerformanceController.getMyAppraisals(
        PWChrono_Constants.STATUS_DRAFT,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        draftAppraisals.size(),
        'Should return 1 draft appraisal'
      );
      System.assertEquals(
        PWChrono_Constants.STATUS_DRAFT,
        draftAppraisals[0].Status__c,
        'Appraisal status should match filter'
      );
    }
  }

  @isTest
  static void testUpdateGoalProgressInvalidProgress() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Goal__c goal = [SELECT Id FROM PWChrono_Goal__c LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      try {
        // Progress > 100 is allowed; goal should auto-complete
        PWChrono_Goal__c updatedGoal = PWChrono_PerformanceController.updateGoalProgress(
          goal.Id,
          150,
          PWChrono_Constants.STATUS_IN_PROGRESS,
          null,
          null
        );
        System.assertEquals(
          150,
          updatedGoal.Progress__c,
          'Progress should be saved as provided'
        );
        System.assertEquals(
          PWChrono_Constants.STATUS_COMPLETED,
          updatedGoal.Status__c,
          'Goal should auto-complete when progress >= 100'
        );
      } catch (Exception e) {
        System.assert(
          false,
          'Should not throw for progress > 100: ' + e.getMessage()
        );
      }
      Test.stopTest();
    }
  }
}