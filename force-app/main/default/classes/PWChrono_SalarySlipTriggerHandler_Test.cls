@isTest
private class PWChrono_SalarySlipTriggerHandler_Test {
  @testSetup
  static void setupData() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );

      List<PWChrono_Salary_Slip__c> slips = new List<PWChrono_Salary_Slip__c>{
        new PWChrono_Salary_Slip__c(
          Contact__c = employee.Contact__c,
          Employees__c = employee.Id,
          Payroll_Period__c = Date.today().addMonths(-1),
          Gross_Pay__c = 5000,
          Total_Deductions__c = 500,
          Net_Pay__c = 4500,
          Status__c = PWChrono_Constants.STATUS_PAID
        ),
        new PWChrono_Salary_Slip__c(
          Contact__c = employee.Contact__c,
          Employees__c = employee.Id,
          Gross_Pay__c = 6000,
          Total_Deductions__c = 800,
          Net_Pay__c = 5200,
          Status__c = PWChrono_Constants.STATUS_PAID
        ),
        new PWChrono_Salary_Slip__c(
          Contact__c = employee.Contact__c,
          Employees__c = employee.Id,
          Payroll_Period__c = Date.today().addMonths(-2),
          Gross_Pay__c = 5000,
          Total_Deductions__c = 500,
          Net_Pay__c = 0,
          Status__c = PWChrono_Constants.STATUS_PAID
        ),
        new PWChrono_Salary_Slip__c(
          Contact__c = employee.Contact__c,
          Employees__c = employee.Id,
          Payroll_Period__c = Date.today().addMonths(-3),
          Gross_Pay__c = 5000,
          Total_Deductions__c = 500,
          Net_Pay__c = 4500,
          Status__c = 'Draft'
        )
      };
      insert slips;
    }
  }

  @isTest
  static void testCreateSalaryHistory_OnlyForPaidPositiveNetPay() {
    List<PWChrono_Salary_Slip__c> allSlips = [
      SELECT
        Id,
        Contact__c,
        Employees__c,
        Payroll_Period__c,
        Gross_Pay__c,
        Net_Pay__c,
        Status__c
      FROM PWChrono_Salary_Slip__c
    ];

    Test.startTest();
    PWChrono_SalarySlipTriggerHandler.createSalaryHistory(allSlips);
    Test.stopTest();

    List<PWChrono_Salary_History__c> histories = [
      SELECT
        Id,
        Contact__c,
        Employee__c,
        Salary_Slip__c,
        Effective_Date__c,
        Gross_Salary__c,
        Net_Salary__c,
        Currency_Code__c,
        Change_Reason__c
      FROM PWChrono_Salary_History__c
    ];

    System.assertEquals(
      2,
      histories.size(),
      'Only paid slips with positive net pay should create history records.'
    );

    Map<Id, PWChrono_Salary_History__c> historyBySlipId = new Map<Id, PWChrono_Salary_History__c>();
    for (PWChrono_Salary_History__c history : histories) {
      historyBySlipId.put(history.Salary_Slip__c, history);
      System.assertEquals(
        'Salary Slip Generated',
        history.Change_Reason__c,
        'Expected change reason should be stamped.'
      );
      System.assertEquals(
        PWChrono_Constants.getEffectiveCurrencyCode(),
        history.Currency_Code__c,
        'Default currency should be applied.'
      );
      System.assertNotEquals(
        null,
        history.Contact__c,
        'Salary history must retain the canonical employee Contact.'
      );
    }

    PWChrono_Salary_Slip__c paidWithPeriod = [
      SELECT Id, Payroll_Period__c
      FROM PWChrono_Salary_Slip__c
      WHERE
        Status__c = :PWChrono_Constants.STATUS_PAID
        AND Payroll_Period__c != NULL
      ORDER BY Payroll_Period__c DESC
      LIMIT 1
    ];
    System.assertEquals(
      paidWithPeriod.Payroll_Period__c,
      historyBySlipId.get(paidWithPeriod.Id).Effective_Date__c,
      'Effective date should use payroll period when provided.'
    );

    PWChrono_Salary_Slip__c paidWithoutPeriod = [
      SELECT Id
      FROM PWChrono_Salary_Slip__c
      WHERE
        Status__c = :PWChrono_Constants.STATUS_PAID
        AND Payroll_Period__c = NULL
      LIMIT 1
    ];
    System.assertEquals(
      Date.today(),
      historyBySlipId.get(paidWithoutPeriod.Id).Effective_Date__c,
      'Effective date should default to today when payroll period is missing.'
    );
  }

  @isTest
  static void testCreateSalaryHistory_EmptyInput_NoInsert() {
    Integer beforeCount = [SELECT COUNT() FROM PWChrono_Salary_History__c];

    Test.startTest();
    PWChrono_SalarySlipTriggerHandler.createSalaryHistory(
      new List<PWChrono_Salary_Slip__c>()
    );
    Test.stopTest();

    Integer afterCount = [SELECT COUNT() FROM PWChrono_Salary_History__c];
    System.assertEquals(
      beforeCount,
      afterCount,
      'No history records should be created for empty input.'
    );
  }
}