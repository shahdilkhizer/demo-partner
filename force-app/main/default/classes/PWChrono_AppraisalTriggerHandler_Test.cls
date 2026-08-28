@isTest
private class PWChrono_AppraisalTriggerHandler_Test {
  @testSetup
  static void setupData() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );

      PWChrono_Salary_Structure__c structure = new PWChrono_Salary_Structure__c(
        Name = 'Appraisal Salary Structure'
      );
      insert structure;

      PWChrono_Salary_Assignment__c assignment = new PWChrono_Salary_Assignment__c(
        Employees__c = employee.Id,
        Salary_Structure__c = structure.Id,
        Base_Salary__c = 5000,
        From_Date__c = Date.today().addYears(-1),
        Is_Active__c = true
      );
      insert assignment;
    }
  }

  @isTest
  static void testHandleAfterUpdate_SalaryIncrementCreatesNewAssignment() {
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    PWChrono_Appraisal__c oldAppraisal = new PWChrono_Appraisal__c(
      Employees__c = employee.Id,
      Appraisal_Period__c = '2026-H1',
      Start_Date__c = Date.today().addMonths(-1),
      End_Date__c = Date.today().addMonths(1),
      Status__c = PWChrono_Constants.STATUS_DRAFT,
      Outcome_Type__c = 'Salary Increment',
      Proposed_Amount__c = 750,
      Effective_Date__c = Date.today()
    );
    insert oldAppraisal;

    PWChrono_Appraisal__c updatedAppraisal = new PWChrono_Appraisal__c(
      Id = oldAppraisal.Id,
      Employees__c = oldAppraisal.Employees__c,
      Appraisal_Period__c = oldAppraisal.Appraisal_Period__c,
      Start_Date__c = oldAppraisal.Start_Date__c,
      End_Date__c = oldAppraisal.End_Date__c,
      Status__c = PWChrono_Constants.STATUS_COMPLETED,
      Outcome_Type__c = oldAppraisal.Outcome_Type__c,
      Proposed_Amount__c = oldAppraisal.Proposed_Amount__c,
      Effective_Date__c = oldAppraisal.Effective_Date__c
    );

    Test.startTest();
    PWChrono_AppraisalTriggerHandler.handleAfterUpdate(
      new List<PWChrono_Appraisal__c>{ updatedAppraisal },
      new Map<Id, PWChrono_Appraisal__c>{ oldAppraisal.Id => oldAppraisal }
    );
    Test.stopTest();

    List<PWChrono_Salary_Assignment__c> assignments = [
      SELECT Id, Employees__c, Base_Salary__c, Is_Active__c
      FROM PWChrono_Salary_Assignment__c
      WHERE Employees__c = :employee.Id
      ORDER BY CreatedDate ASC
    ];

    System.assertEquals(
      2,
      assignments.size(),
      'Expected old and new salary assignments.'
    );

    Integer activeCount = 0;
    Decimal activeSalary = 0;
    for (PWChrono_Salary_Assignment__c sa : assignments) {
      if (sa.Is_Active__c == true) {
        activeCount++;
        activeSalary = sa.Base_Salary__c;
      }
    }

    System.assertEquals(
      1,
      activeCount,
      'Exactly one active salary assignment should remain.'
    );
    System.assertEquals(
      5750,
      activeSalary,
      'Active salary should reflect increment amount.'
    );
  }

  @isTest
  static void testHandleAfterUpdate_PerformanceBonusCreatesBonusRecord() {
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    PWChrono_Appraisal__c oldAppraisal = new PWChrono_Appraisal__c(
      Employees__c = employee.Id,
      Appraisal_Period__c = '2026-H2',
      Start_Date__c = Date.today().addMonths(-1),
      End_Date__c = Date.today().addMonths(1),
      Status__c = PWChrono_Constants.STATUS_DRAFT,
      Outcome_Type__c = 'Performance Bonus',
      Proposed_Amount__c = 1200,
      Effective_Date__c = Date.today()
    );
    insert oldAppraisal;

    PWChrono_Appraisal__c updatedAppraisal = new PWChrono_Appraisal__c(
      Id = oldAppraisal.Id,
      Employees__c = oldAppraisal.Employees__c,
      Appraisal_Period__c = oldAppraisal.Appraisal_Period__c,
      Start_Date__c = oldAppraisal.Start_Date__c,
      End_Date__c = oldAppraisal.End_Date__c,
      Status__c = PWChrono_Constants.STATUS_COMPLETED,
      Outcome_Type__c = oldAppraisal.Outcome_Type__c,
      Proposed_Amount__c = oldAppraisal.Proposed_Amount__c,
      Effective_Date__c = oldAppraisal.Effective_Date__c
    );

    Test.startTest();
    PWChrono_AppraisalTriggerHandler.handleAfterUpdate(
      new List<PWChrono_Appraisal__c>{ updatedAppraisal },
      new Map<Id, PWChrono_Appraisal__c>{ oldAppraisal.Id => oldAppraisal }
    );
    Test.stopTest();

    List<PWChrono_Bonus__c> bonuses = [
      SELECT Id, Employees__c, Amount__c, Appraisal__c
      FROM PWChrono_Bonus__c
      WHERE Appraisal__c = :oldAppraisal.Id
    ];

    System.assertEquals(
      1,
      bonuses.size(),
      'Expected one bonus record to be created.'
    );
    System.assertEquals(
      1200,
      bonuses[0].Amount__c,
      'Bonus amount should match proposed amount.'
    );
    System.assertEquals(
      employee.Id,
      bonuses[0].Employees__c,
      'Bonus should be linked to employee.'
    );
  }

  @isTest
  static void testHandleAfterUpdate_NoChangesWhenNotCompletedTransition() {
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    Integer assignmentCountBefore = [
      SELECT COUNT()
      FROM PWChrono_Salary_Assignment__c
      WHERE Employees__c = :employee.Id
    ];
    Integer bonusCountBefore = [SELECT COUNT() FROM PWChrono_Bonus__c];

    PWChrono_Appraisal__c oldAppraisal = new PWChrono_Appraisal__c(
      Employees__c = employee.Id,
      Appraisal_Period__c = '2026-H3',
      Start_Date__c = Date.today().addMonths(-1),
      End_Date__c = Date.today().addMonths(1),
      Status__c = PWChrono_Constants.STATUS_DRAFT,
      Outcome_Type__c = 'Salary Increment',
      Proposed_Amount__c = 400,
      Effective_Date__c = Date.today()
    );
    insert oldAppraisal;

    PWChrono_Appraisal__c updatedAppraisal = new PWChrono_Appraisal__c(
      Id = oldAppraisal.Id,
      Employees__c = oldAppraisal.Employees__c,
      Appraisal_Period__c = oldAppraisal.Appraisal_Period__c,
      Start_Date__c = oldAppraisal.Start_Date__c,
      End_Date__c = oldAppraisal.End_Date__c,
      Status__c = PWChrono_Constants.STATUS_SUBMITTED,
      Outcome_Type__c = oldAppraisal.Outcome_Type__c,
      Proposed_Amount__c = oldAppraisal.Proposed_Amount__c,
      Effective_Date__c = oldAppraisal.Effective_Date__c
    );

    Test.startTest();
    PWChrono_AppraisalTriggerHandler.handleAfterUpdate(
      new List<PWChrono_Appraisal__c>{ updatedAppraisal },
      new Map<Id, PWChrono_Appraisal__c>{ oldAppraisal.Id => oldAppraisal }
    );
    Test.stopTest();

    Integer assignmentCountAfter = [
      SELECT COUNT()
      FROM PWChrono_Salary_Assignment__c
      WHERE Employees__c = :employee.Id
    ];
    Integer bonusCountAfter = [SELECT COUNT() FROM PWChrono_Bonus__c];

    System.assertEquals(
      assignmentCountBefore,
      assignmentCountAfter,
      'No salary assignment changes should happen when appraisal is not completed.'
    );
    System.assertEquals(
      bonusCountBefore,
      bonusCountAfter,
      'No bonus should be created when appraisal is not completed.'
    );
  }

  @isTest
  static void testHandleAfterUpdate_CompletedWithZeroAmount_NoFinancialRecords() {
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];

    Integer assignmentCountBefore = [
      SELECT COUNT()
      FROM PWChrono_Salary_Assignment__c
      WHERE Employees__c = :employee.Id
    ];
    Integer bonusCountBefore = [SELECT COUNT() FROM PWChrono_Bonus__c];

    PWChrono_Appraisal__c oldAppraisal = new PWChrono_Appraisal__c(
      Employees__c = employee.Id,
      Appraisal_Period__c = '2026-H4',
      Start_Date__c = Date.today().addMonths(-1),
      End_Date__c = Date.today().addMonths(1),
      Status__c = PWChrono_Constants.STATUS_DRAFT,
      Outcome_Type__c = 'Performance Bonus',
      Proposed_Amount__c = 0,
      Effective_Date__c = Date.today()
    );
    insert oldAppraisal;

    PWChrono_Appraisal__c updatedAppraisal = new PWChrono_Appraisal__c(
      Id = oldAppraisal.Id,
      Employees__c = oldAppraisal.Employees__c,
      Appraisal_Period__c = oldAppraisal.Appraisal_Period__c,
      Start_Date__c = oldAppraisal.Start_Date__c,
      End_Date__c = oldAppraisal.End_Date__c,
      Status__c = PWChrono_Constants.STATUS_COMPLETED,
      Outcome_Type__c = oldAppraisal.Outcome_Type__c,
      Proposed_Amount__c = oldAppraisal.Proposed_Amount__c,
      Effective_Date__c = oldAppraisal.Effective_Date__c
    );

    Test.startTest();
    PWChrono_AppraisalTriggerHandler.handleAfterUpdate(
      new List<PWChrono_Appraisal__c>{ updatedAppraisal },
      new Map<Id, PWChrono_Appraisal__c>{ oldAppraisal.Id => oldAppraisal }
    );
    Test.stopTest();

    Integer assignmentCountAfter = [
      SELECT COUNT()
      FROM PWChrono_Salary_Assignment__c
      WHERE Employees__c = :employee.Id
    ];
    Integer bonusCountAfter = [SELECT COUNT() FROM PWChrono_Bonus__c];

    System.assertEquals(
      assignmentCountBefore,
      assignmentCountAfter,
      'Salary assignments should not change when proposed amount is zero.'
    );
    System.assertEquals(
      bonusCountBefore,
      bonusCountAfter,
      'Bonus records should not be created when proposed amount is zero.'
    );
  }
}