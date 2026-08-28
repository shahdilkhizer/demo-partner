@isTest
private class PWChrono_ProjectController_Test {
  @testSetup
  static void makeData() {
    // Create a test Account
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    // Create a test Opportunity (Project)
    Opportunity testOpp = new Opportunity(
      Name = 'Test Project',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = testAccount.Id
    );
    insert testOpp;

    // Create a test Case (Task) related to the Opportunity
    Case testCase = new Case(
      Subject = 'Test Task',
      Status = 'New',
      Priority = 'Medium',
      Related_to_Opportunity__c = testOpp.Id
    );
    insert testCase;

    // Create a test Task (Subtask) related to the Case
    Task testSubtask = new Task(Subject = 'Test Subtask', WhatId = testCase.Id);
    insert testSubtask;
  }

  @isTest
  static void testGetTasks() {
    // Get the test Opportunity
    Opportunity opp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = 'Test Project'
      LIMIT 1
    ];

    Test.startTest();
    List<Case> tasks = PWChrono_ProjectController.getTasks(opp.Id);
    Test.stopTest();

    // Verify that the correct number of tasks are returned
    System.assertEquals(1, tasks.size(), 'Should return one task');
    System.assertEquals(
      'Test Task',
      tasks[0].Subject,
      'The task subject should match'
    );
  }

  @isTest
  static void testGetSubtasks() {
    // Get the test Case
    Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Task' LIMIT 1];

    Test.startTest();
    List<Task> subtasks = PWChrono_ProjectController.getSubtasks(testCase.Id);
    Test.stopTest();

    // Verify that the correct number of subtasks are returned
    System.assertEquals(1, subtasks.size(), 'Should return one subtask');
    System.assertEquals(
      'Test Subtask',
      subtasks[0].Subject,
      'The subtask name should match'
    );
  }

  @isTest
  static void testGetTasks_NoResults() {
    // Create an opportunity with no tasks
    Account testAccount = new Account(Name = 'No Task Account');
    insert testAccount;
    Opportunity oppWithNoTasks = new Opportunity(
      Name = 'Project With No Tasks',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = testAccount.Id
    );
    insert oppWithNoTasks;

    Test.startTest();
    List<Case> tasks = PWChrono_ProjectController.getTasks(oppWithNoTasks.Id);
    Test.stopTest();

    // Verify that no tasks are returned
    System.assertEquals(0, tasks.size(), 'Should return no tasks');
  }

  @isTest
  static void testGetSubtasks_NoResults() {
    // Create a case with no subtasks
    Case caseWithNoItems = new Case(
      Subject = 'Task With No Items',
      Status = 'New',
      Priority = 'Medium'
    );
    insert caseWithNoItems;

    Test.startTest();
    List<Task> subtasks = PWChrono_ProjectController.getSubtasks(
      caseWithNoItems.Id
    );
    Test.stopTest();

    // Verify that no subtasks are returned
    System.assertEquals(0, subtasks.size(), 'Should return no subtasks');
  }
}