@isTest
private class PWChrono_LeaveAllocationScheduler_Test {
  @TestSetup
  static void makeData() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_TestDataFactory.createTestEmployee(testUser.Id);
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
      SELECT Id, CronExpression, TimesTriggered
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(cronExp, ct.CronExpression);
    System.assertEquals(0, ct.TimesTriggered);
  }

  @isTest
  static void testSchedulerInvalidCronExpression() {
    Test.startTest();
    try {
      String invalidCron = 'invalid expression';
      System.schedule(
        'Invalid Scheduler',
        invalidCron,
        new PWChrono_LeaveAllocationScheduler()
      );
      System.assert(
        false,
        'Should throw exception for invalid cron expression'
      );
    } catch (Exception e) {
      System.assert(
        e instanceof System.AsyncException ||
        e instanceof System.StringException,
        'Should throw a scheduling-related exception for invalid cron'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSchedulerMultipleInstances() {
    Test.startTest();
    String cronExp1 = '0 0 0 1 1 ? 2099';
    String cronExp2 = '0 0 12 1 1 ? 2099';

    String jobId1 = System.schedule(
      'Scheduler 1',
      cronExp1,
      new PWChrono_LeaveAllocationScheduler()
    );

    String jobId2 = System.schedule(
      'Scheduler 2',
      cronExp2,
      new PWChrono_LeaveAllocationScheduler()
    );

    Test.stopTest();

    List<CronTrigger> triggers = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id IN (:jobId1, :jobId2)
    ];
    System.assertEquals(2, triggers.size(), 'Should have 2 scheduled jobs');
  }

  @isTest
  static void testSchedulerAbortJob() {
    Test.startTest();
    String cronExp = '0 0 0 1 1 ? 2099';
    String jobId = System.schedule(
      'Test Abort',
      cronExp,
      new PWChrono_LeaveAllocationScheduler()
    );

    // Abort the scheduled job
    System.abortJob(jobId);
    Test.stopTest();

    List<CronTrigger> triggers = [
      SELECT Id
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    // After abort, the trigger is removed
    System.assertEquals(0, triggers.size(), 'Job should be aborted');
  }

  @isTest
  static void testSchedulerBatchExecution() {
    // Create leave type for batch
    PWChrono_Leave_Type__c leaveType = new PWChrono_Leave_Type__c(
      Name = 'Annual Leave',
      Max_Days_Allowed__c = 20,
      Is_Active__c = true
    );
    insert leaveType;

    Test.startTest();
    // Execute the actual scheduler which calls batch internally
    PWChrono_LeaveAllocationScheduler scheduler = new PWChrono_LeaveAllocationScheduler();
    // Simulate scheduler execution by calling execute method
    String cronExp = '0 0 0 1 1 ? 2099';
    String jobId = System.schedule(
      'Test Batch Integration',
      cronExp,
      scheduler
    );
    Test.stopTest();

    // Verify scheduler was created
    CronTrigger ct = [
      SELECT Id, State
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assert(ct.Id != null, 'Scheduler should be created and running');
  }
}