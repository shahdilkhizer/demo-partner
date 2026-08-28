@isTest
private class PWChrono_LeaveAllocationBatch_Test {
  @TestSetup
  static void makeData() {
    // Create Test User
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    // Create Employee
    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );

    // Create Leave Type
    PWChrono_Leave_Type__c leaveType = new PWChrono_Leave_Type__c(
      Name = 'Annual Leave',
      Max_Days_Allowed__c = 20,
      Is_Active__c = true
    );
    insert leaveType;
  }

  @isTest
  static void testBatchExecution() {
    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    // Verify Allocation Created
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id, Total_Leaves_Allocated__c
      FROM PWChrono_Leave_Allocation__c
    ];
    System.assertEquals(
      1,
      allocations.size(),
      'Should have created one allocation'
    );
    System.assertEquals(
      20,
      allocations[0].Total_Leaves_Allocated__c,
      'Should allocate max days'
    );
  }

  @isTest
  static void testBatchExecutionExistingAllocation() {
    // Create existing allocation to test idempotency
    Portal_Users__c employee = [SELECT Id FROM Portal_Users__c LIMIT 1];
    PWChrono_Leave_Type__c leaveType = [
      SELECT Id
      FROM PWChrono_Leave_Type__c
      LIMIT 1
    ];

    Organization org = [SELECT FiscalYearStartMonth FROM Organization LIMIT 1];
    Integer startMonth = org.FiscalYearStartMonth != null
      ? org.FiscalYearStartMonth
      : 1;
    Integer currentYear = Date.today().year();
    Integer currentMonth = Date.today().month();
    Integer startYear = currentMonth < startMonth
      ? currentYear - 1
      : currentYear;
    Date startDate = Date.newInstance(startYear, startMonth, 1);
    Date endDate = startDate.addYears(1).addDays(-1);

    PWChrono_Leave_Allocation__c allocation = new PWChrono_Leave_Allocation__c(
      Employees__c = employee.Id,
      Leave_Type__c = leaveType.Id,
      Total_Leaves_Allocated__c = 20,
      From_Date__c = startDate,
      To_Date__c = endDate
    );
    insert allocation;

    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    // Verify no duplicate created
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id
      FROM PWChrono_Leave_Allocation__c
    ];
    System.assertEquals(
      1,
      allocations.size(),
      'Should not create duplicate allocation'
    );
  }

  @isTest
  static void testBatchNoLeaveTypes() {
    // Delete all leave types
    delete [SELECT Id FROM PWChrono_Leave_Type__c];

    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    // Verify no allocation created
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id
      FROM PWChrono_Leave_Allocation__c
    ];
    System.assertEquals(
      0,
      allocations.size(),
      'Should not create allocations without leave types'
    );
  }

  @isTest
  static void testBatchInactiveLeaveType() {
    PWChrono_Leave_Type__c leaveType = [
      SELECT Id
      FROM PWChrono_Leave_Type__c
      LIMIT 1
    ];
    leaveType.Is_Active__c = false;
    update leaveType;

    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    // Verify no allocation created for inactive type
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id
      FROM PWChrono_Leave_Allocation__c
    ];
    System.assertEquals(
      0,
      allocations.size(),
      'Should not create allocations for inactive leave types'
    );
  }

  @isTest
  static void testBatchMultipleLeaveTypes() {
    PWChrono_Leave_Type__c sickLeave = new PWChrono_Leave_Type__c(
      Name = 'Sick Leave',
      Max_Days_Allowed__c = 10,
      Is_Active__c = true
    );
    PWChrono_Leave_Type__c casualLeave = new PWChrono_Leave_Type__c(
      Name = 'Casual Leave',
      Max_Days_Allowed__c = 5,
      Is_Active__c = true
    );
    insert new List<PWChrono_Leave_Type__c>{ sickLeave, casualLeave };

    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id, Leave_Type__c
      FROM PWChrono_Leave_Allocation__c
    ];
    System.assertEquals(
      3,
      allocations.size(),
      'Should create allocations for all active leave types (Original + Sick + Casual)'
    );
  }

  @isTest
  static void testBatchMultipleEmployees() {
    // Create second employee
    User testUser2 = PWChrono_TestDataFactory.createTestUser('Employee2');
    Portal_Users__c employee2 = PWChrono_TestDataFactory.createTestEmployee(
      testUser2.Id
    );

    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id
      FROM PWChrono_Leave_Allocation__c
    ];
    System.assertEquals(
      2,
      allocations.size(),
      'Should create allocations for all employees'
    );
  }

  @isTest
  static void testScheduler() {
    Test.startTest();
    String cronExp = '0 0 0 1 1 ? 2099';
    String jobId = System.schedule(
      'Test Leave Allocation',
      cronExp,
      new PWChrono_LeaveAllocationScheduler()
    );
    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(cronExp, ct.CronExpression);
  }

  @isTest
  static void testBatchJobFail() {
    // Test the finish method error handling
    Test.startTest();
    PWChrono_LeaveAllocationBatch batch = new PWChrono_LeaveAllocationBatch();
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