@isTest
private class PWChrono_PayrollController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );

      PWChrono_Salary_Slip__c slip1 = new PWChrono_Salary_Slip__c(
        Employees__c = employee.Id,
        Payroll_Period__c = Date.today().addMonths(-1),
        Gross_Pay__c = 5000,
        Total_Deductions__c = 500,
        Net_Pay__c = 4500,
        Status__c = PWChrono_Constants.STATUS_PAID,
        Earning_Details__c = '[{"name":"Basic","amount":5000}]',
        Deduction_Details__c = '[{"name":"Tax","amount":500}]'
      );
      insert slip1;

      PWChrono_Salary_Slip__c slip2 = new PWChrono_Salary_Slip__c(
        Employees__c = employee.Id,
        Payroll_Period__c = Date.today().addMonths(-2),
        Gross_Pay__c = 5000,
        Total_Deductions__c = 500,
        Net_Pay__c = 4500,
        Status__c = PWChrono_Constants.STATUS_PAID
      );
      insert slip2;

      // Create Salary Structure and Assignment
      PWChrono_Salary_Structure__c structure = new PWChrono_Salary_Structure__c(
        Name = 'Standard Structure'
      );
      insert structure;

      PWChrono_Salary_Component__c component = new PWChrono_Salary_Component__c(
        Name = 'Basic Salary',
        Component_Type__c = 'Earning'
      );
      insert component;

      PWChrono_Structure_Component__c structComp = new PWChrono_Structure_Component__c(
        Salary_Structure__c = structure.Id,
        Salary_Component__c = component.Id,
        Amount__c = 5000
      );
      insert structComp;

      PWChrono_Salary_Assignment__c assignment = new PWChrono_Salary_Assignment__c(
        Employees__c = employee.Id,
        Salary_Structure__c = structure.Id,
        Base_Salary__c = 5000,
        From_Date__c = Date.today().addYears(-1)
      );
      insert assignment;
    }
  }

  @isTest
  static void testGetMySalarySlips() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Salary_Slip__c> slips = PWChrono_PayrollController.getMySalarySlips(
        null,
        null,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(2, slips.size(), 'Should return 2 salary slips');
    }
  }

  @isTest
  static void testGetSalarySlipDetails() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Salary_Slip__c slip = [
      SELECT Id
      FROM PWChrono_Salary_Slip__c
      ORDER BY Payroll_Period__c DESC
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> details = PWChrono_PayrollController.getSalarySlipDetails(
        slip.Id,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assert(
        details.containsKey('salarySlip'),
        'Should contain salary slip'
      );
      System.assert(details.containsKey('earnings'), 'Should contain earnings');
      System.assert(
        details.containsKey('deductions'),
        'Should contain deductions'
      );
    }
  }

  @isTest
  static void testGetMySalaryStructure() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> structure = PWChrono_PayrollController.getMySalaryStructure();
      Test.stopTest();

      System.assert(
        structure.containsKey('assignment'),
        'Should contain assignment'
      );
      System.assert(
        structure.containsKey('components'),
        'Should contain components'
      );
    }
  }

  @isTest
  static void testGetYTDSummary() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Integer currentYear = Date.today().year();

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Decimal> summary = PWChrono_PayrollController.getYTDSummary(
        currentYear
      );
      Test.stopTest();

      System.assertEquals(
        10000,
        summary.get('totalGross'),
        'Total gross should be 10000'
      );
      System.assertEquals(
        1000,
        summary.get('totalDeductions'),
        'Total deductions should be 1000'
      );
      System.assertEquals(
        9000,
        summary.get('totalNet'),
        'Total net should be 9000'
      );
    }
  }

  @isTest
  static void testGetMySalarySlipsNoEmployee() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      try {
        PWChrono_PayrollController.getMySalarySlips(
          null,
          null,
          null,
          null,
          null
        );
        System.assert(false, 'Should throw exception');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }
}