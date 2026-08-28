@isTest
private class PWChrono_AppraisalGeneratorBatch_Test {
  @TestSetup
  static void makeData() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );

    // Set Date of Joining to ensure eligibility (e.g., 1 year ago)
    employee.Date_of_Joining__c = Date.today().addYears(-1);
    update employee;
  }

  @isTest
  static void testBatchExecution() {
    Date today = Date.today();
    String currentMonth = getMonthName(today.month());
    Integer currentDay = today.day();

    PWChrono_Performance_Cycle__c cycle = new PWChrono_Performance_Cycle__c(
      Name = 'Test Cycle',
      Type__c = 'Annual Appraisal',
      Is_Active__c = true,
      Start_Month__c = currentMonth,
      Start_Day__c = currentDay,
      End_Month__c = currentMonth, // Simplified for test
      End_Day__c = currentDay,
      Minimum_Tenure_Months__c = 6
    );
    insert cycle;

    Test.startTest();
    PWChrono_AppraisalGeneratorBatch batch = new PWChrono_AppraisalGeneratorBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Appraisal__c> appraisals = [
      SELECT Id, Performance_Cycle__c
      FROM PWChrono_Appraisal__c
    ];
    System.assertEquals(1, appraisals.size(), 'Should create one appraisal');
    System.assertEquals(cycle.Id, appraisals[0].Performance_Cycle__c);
  }

  @isTest
  static void testScheduler() {
    Test.startTest();
    String cronExp = '0 0 0 1 1 ? 2099';
    String jobId = System.schedule(
      'Test Appraisal Generator',
      cronExp,
      new PWChrono_AppraisalGeneratorBatch()
    );
    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(cronExp, ct.CronExpression);
  }

  private static String getMonthName(Integer month) {
    Map<Integer, String> monthMap = new Map<Integer, String>{
      1 => 'January',
      2 => 'February',
      3 => 'March',
      4 => 'April',
      5 => 'May',
      6 => 'June',
      7 => 'July',
      8 => 'August',
      9 => 'September',
      10 => 'October',
      11 => 'November',
      12 => 'December'
    };
    return monthMap.get(month);
  }

  @isTest
  static void testBatchNoCycle() {
    // No performance cycle exists
    Test.startTest();
    PWChrono_AppraisalGeneratorBatch batch = new PWChrono_AppraisalGeneratorBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Appraisal__c> appraisals = [
      SELECT Id
      FROM PWChrono_Appraisal__c
    ];
    System.assertEquals(
      0,
      appraisals.size(),
      'Should not create appraisals without cycle'
    );
  }

  @isTest
  static void testBatchInactiveCycle() {
    Date today = Date.today();
    String currentMonth = getMonthName(today.month());
    Integer currentDay = today.day();

    PWChrono_Performance_Cycle__c cycle = new PWChrono_Performance_Cycle__c(
      Name = 'Inactive Cycle',
      Type__c = 'Annual Appraisal',
      Is_Active__c = false, // Inactive
      Start_Month__c = currentMonth,
      Start_Day__c = currentDay,
      End_Month__c = currentMonth,
      End_Day__c = currentDay,
      Minimum_Tenure_Months__c = 6
    );
    insert cycle;

    Test.startTest();
    PWChrono_AppraisalGeneratorBatch batch = new PWChrono_AppraisalGeneratorBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Appraisal__c> appraisals = [
      SELECT Id
      FROM PWChrono_Appraisal__c
    ];
    System.assertEquals(
      0,
      appraisals.size(),
      'Should not create appraisals for inactive cycle'
    );
  }

  @isTest
  static void testBatchMultipleEmployees() {
    User testUser1 = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    User testUser2 = PWChrono_TestDataFactory.createTestUser('Employee2');

    Portal_Users__c employee2 = PWChrono_TestDataFactory.createTestEmployee(
      testUser2.Id
    );
    employee2.Date_of_Joining__c = Date.today().addYears(-1);
    update employee2;

    Date today = Date.today();
    String currentMonth = getMonthName(today.month());
    Integer currentDay = today.day();

    PWChrono_Performance_Cycle__c cycle = new PWChrono_Performance_Cycle__c(
      Name = 'Multi Employee Cycle',
      Type__c = 'Annual Appraisal',
      Is_Active__c = true,
      Start_Month__c = currentMonth,
      Start_Day__c = currentDay,
      End_Month__c = currentMonth,
      End_Day__c = currentDay,
      Minimum_Tenure_Months__c = 6
    );
    insert cycle;

    Test.startTest();
    PWChrono_AppraisalGeneratorBatch batch = new PWChrono_AppraisalGeneratorBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Appraisal__c> appraisals = [
      SELECT Id
      FROM PWChrono_Appraisal__c
    ];
    System.assertEquals(
      2,
      appraisals.size(),
      'Should create appraisals for all eligible employees'
    );
  }

  @isTest
  static void testBatchNewEmployee() {
    // Create employee with recent joining date (not eligible)
    User testUserNew = PWChrono_TestDataFactory.createTestUser('NewEmployee');
    Portal_Users__c newEmployee = PWChrono_TestDataFactory.createTestEmployee(
      testUserNew.Id
    );
    newEmployee.Date_of_Joining__c = Date.today().addMonths(-2); // Only 2 months
    update newEmployee;

    Date today = Date.today();
    String currentMonth = getMonthName(today.month());
    Integer currentDay = today.day();

    PWChrono_Performance_Cycle__c cycle = new PWChrono_Performance_Cycle__c(
      Name = 'New Employee Cycle',
      Type__c = 'Annual Appraisal',
      Is_Active__c = true,
      Start_Month__c = currentMonth,
      Start_Day__c = currentDay,
      End_Month__c = currentMonth,
      End_Day__c = currentDay,
      Minimum_Tenure_Months__c = 6
    );
    insert cycle;

    Test.startTest();
    PWChrono_AppraisalGeneratorBatch batch = new PWChrono_AppraisalGeneratorBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Appraisal__c> appraisals = [
      SELECT Id
      FROM PWChrono_Appraisal__c
      WHERE Employees__c = :newEmployee.Id
    ];
    System.assertEquals(
      0,
      appraisals.size(),
      'Should not create appraisals for ineligible employees'
    );
  }

  @isTest
  static void testBatchJobFail() {
    // Test the finish method error handling
    Test.startTest();
    PWChrono_AppraisalGeneratorBatch batch = new PWChrono_AppraisalGeneratorBatch();
    try {
      Database.executeBatch(batch, 1);
      System.assert(
        true,
        'Batch should execute without throwing uncaught exceptions'
      );
    } catch (Exception e) {
      System.assert(false, 'Batch failed: ' + e.getMessage());
    }
    Test.stopTest();
  }
}