@IsTest
private class PWChrono_PayrollRunService_Test {
  @TestSetup
  static void setupData() {
    PWChrono_TestDataFactory.createTestUsers();
    User employeeUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(employeeUser) {
      PWChrono_TestDataFactory.createTestEmployee(employeeUser.Id);
    }
  }

  @IsTest
  static void testCompletePayrollLifecycle() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    User employeeUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id, Contact__c
      FROM Portal_Users__c
      WHERE User__c = :employeeUser.Id
      LIMIT 1
    ];
    Date period = Date.newInstance(
      Date.today().year(),
      Date.today().month(),
      1
    );

    System.runAs(adminUser) {
      createSalaryConfiguration(employee, period);

      Test.startTest();
      PWChrono_PayrollRunService.PayrollWorkspaceDTO initial = PWChrono_PayrollController.getPayrollWorkspace(
        period,
        null,
        null
      );
      PWChrono_PayrollRunService.PayrollMutationResult generated = PWChrono_PayrollController.generatePayrollDrafts(
        period,
        null,
        null
      );
      Test.stopTest();

      Assert.areEqual(1, initial.activeEmployeeCount);
      Assert.areEqual(1, initial.readyEmployeeCount);
      Assert.areEqual(true, initial.configurationComplete);
      Assert.areEqual(1, generated.createdCount);

      PWChrono_Salary_Slip__c draft = [
        SELECT
          Id,
          Contact__c,
          Status__c,
          Basic_Pay__c,
          Gross_Pay__c,
          Total_Deductions__c,
          Net_Pay__c,
          Snapshot_Locked__c,
          Delivery_Status__c
        FROM PWChrono_Salary_Slip__c
        WHERE Contact__c = :employee.Contact__c
        LIMIT 1
      ];
      Assert.areEqual(PWChrono_Constants.STATUS_DRAFT, draft.Status__c);
      Assert.areEqual(5000, draft.Basic_Pay__c);
      Assert.areEqual(5500, draft.Gross_Pay__c);
      Assert.areEqual(100, draft.Total_Deductions__c);
      Assert.areEqual(5400, draft.Net_Pay__c);
      Assert.areEqual(false, draft.Snapshot_Locked__c);
      Assert.areEqual(3, [SELECT COUNT() FROM PWChrono_Salary_Slip_Line__c]);
    }

    System.runAs(employeeUser) {
      Assert.areEqual(
        0,
        PWChrono_PayrollController.getMySalarySlips(
            period.year(),
            period.month(),
            null,
            null,
            null
          )
          .size(),
        'Draft payslips must remain hidden from employee self service.'
      );
    }

    System.runAs(adminUser) {
      PWChrono_PayrollRunService.PayrollMutationResult submitted = PWChrono_PayrollController.submitPayroll(
        period,
        null,
        null
      );
      Assert.areEqual(1, submitted.updatedCount);
    }

    System.runAs(employeeUser) {
      Assert.areEqual(
        1,
        PWChrono_PayrollController.getMySalarySlips(
            period.year(),
            period.month(),
            null,
            null,
            null
          )
          .size(),
        'Submitted payslips must be visible to the employee.'
      );
    }

    System.runAs(adminUser) {
      PWChrono_PayrollRunService.PayrollMutationResult paid = PWChrono_PayrollController.markPayrollPaid(
        period,
        period.addMonths(1),
        'Bank Transfer',
        null,
        null
      );

      Assert.areEqual(1, paid.updatedCount);
      PWChrono_Salary_Slip__c paidSlip = [
        SELECT
          Status__c,
          Payment_Date__c,
          Payment_Method__c,
          Snapshot_Locked__c,
          Delivery_Status__c
        FROM PWChrono_Salary_Slip__c
        WHERE Contact__c = :employee.Contact__c
        LIMIT 1
      ];
      Assert.areEqual(PWChrono_Constants.STATUS_PAID, paidSlip.Status__c);
      Assert.areEqual(period.addMonths(1), paidSlip.Payment_Date__c);
      Assert.areEqual('Bank Transfer', paidSlip.Payment_Method__c);
      Assert.areEqual(true, paidSlip.Snapshot_Locked__c);
      Assert.areEqual('Generated', paidSlip.Delivery_Status__c);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM PWChrono_Salary_History__c],
        'Transitioning to Paid must create one salary history record.'
      );
    }
  }

  @IsTest
  static void testSaveSalaryAssignmentCreatesCanonicalRelationships() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    Portal_Users__c employee = [
      SELECT Id, Contact__c
      FROM Portal_Users__c
      LIMIT 1
    ];
    Date effectiveDate = Date.newInstance(
      Date.today().year(),
      Date.today().month(),
      1
    );

    System.runAs(adminUser) {
      Test.startTest();
      PWChrono_PayrollRunService.PayrollMutationResult result = PWChrono_PayrollController.saveSalaryAssignment(
        employee.Contact__c,
        6250,
        effectiveDate,
        null,
        null
      );
      Test.stopTest();

      Assert.areEqual(1, result.createdCount);
      PWChrono_Salary_Assignment__c assignment = [
        SELECT
          Contact__c,
          Employee__c,
          Employees__c,
          Portal_Users__c,
          Base_Salary__c,
          From_Date__c,
          Is_Active__c,
          Change_Reason__c
        FROM PWChrono_Salary_Assignment__c
        LIMIT 1
      ];
      Assert.areEqual(employee.Contact__c, assignment.Contact__c);
      Assert.areEqual(employee.Id, assignment.Employee__c);
      Assert.areEqual(employee.Id, assignment.Employees__c);
      Assert.areEqual(employee.Id, assignment.Portal_Users__c);
      Assert.areEqual(6250, assignment.Base_Salary__c);
      Assert.areEqual(effectiveDate, assignment.From_Date__c);
      Assert.areEqual(true, assignment.Is_Active__c);
      Assert.areEqual('Initial Offer', assignment.Change_Reason__c);
    }
  }

  @IsTest
  static void testFinalizeBlocksIncompleteSalarySetup() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    Date period = Date.newInstance(
      Date.today().year(),
      Date.today().month(),
      1
    );

    System.runAs(adminUser) {
      Test.startTest();
      try {
        PWChrono_PayrollController.submitPayroll(period, null, null);
        Assert.fail(
          'Payroll must not finalize while salary setup is incomplete.'
        );
      } catch (AuraHandledException expected) {
        Assert.isTrue(expected.getMessage().contains('Complete salary setup'));
      }
      Test.stopTest();
    }
  }

  private static void createSalaryConfiguration(
    Portal_Users__c employee,
    Date period
  ) {
    PWChrono_Salary_Structure__c structure = new PWChrono_Salary_Structure__c(
      Name = 'Monthly Payroll',
      Is_Active__c = true
    );
    insert structure;

    List<PWChrono_Salary_Component__c> components = new List<PWChrono_Salary_Component__c>{
      new PWChrono_Salary_Component__c(
        Name = 'Basic',
        Component_Type__c = 'Earning',
        Is_Active__c = true,
        Is_Taxable__c = true
      ),
      new PWChrono_Salary_Component__c(
        Name = 'Housing',
        Component_Type__c = 'Earning',
        Is_Active__c = true,
        Is_Taxable__c = true
      ),
      new PWChrono_Salary_Component__c(
        Name = 'Tax',
        Component_Type__c = 'Deduction',
        Is_Active__c = true,
        Is_Taxable__c = true
      )
    };
    insert components;

    insert new List<PWChrono_Structure_Component__c>{
      new PWChrono_Structure_Component__c(
        Salary_Structure__c = structure.Id,
        Salary_Component__c = components[0].Id,
        Amount__c = 5000
      ),
      new PWChrono_Structure_Component__c(
        Salary_Structure__c = structure.Id,
        Salary_Component__c = components[1].Id,
        Amount__c = 500
      ),
      new PWChrono_Structure_Component__c(
        Salary_Structure__c = structure.Id,
        Salary_Component__c = components[2].Id,
        Amount__c = 100
      )
    };

    insert new PWChrono_Salary_Assignment__c(
      Contact__c = employee.Contact__c,
      Employee__c = employee.Id,
      Employees__c = employee.Id,
      Portal_Users__c = employee.Id,
      Salary_Structure__c = structure.Id,
      Base_Salary__c = 5000,
      From_Date__c = period,
      Is_Active__c = true,
      Change_Reason__c = 'Initial Offer'
    );
  }
}