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
        Contact__c = employee.Contact__c,
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
        Contact__c = employee.Contact__c,
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
        Contact__c = employee.Contact__c,
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
      System.assertEquals(
        employeeContactId(testUser.Id),
        slips[0].Contact__c,
        'Salary slips must be owned by Contact.'
      );
    }
  }

  @isTest
  static void testGetMySalarySlipsFiltersByPeriod() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Date expectedPeriod = Date.today().addMonths(-1);

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Salary_Slip__c> slips = PWChrono_PayrollController.getMySalarySlips(
        expectedPeriod.year(),
        expectedPeriod.month(),
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(1, slips.size(), 'Period filters should be applied.');
      System.assertEquals(expectedPeriod, slips[0].Payroll_Period__c);
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
      PWChrono_Salary_Slip__c returnedSlip = (PWChrono_Salary_Slip__c) details.get(
        'salarySlip'
      );
      System.assertNotEquals(
        null,
        returnedSlip.Contact__c,
        'Salary-slip details must be resolved by Contact.'
      );
    }
  }

  @isTest
  static void testGetSalarySlipDetailsInvalidJsonFallsBackToEmpty() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Salary_Slip__c slip = [
      SELECT Id, Earning_Details__c, Deduction_Details__c
      FROM PWChrono_Salary_Slip__c
      LIMIT 1
    ];
    slip.Earning_Details__c = 'not-json';
    slip.Deduction_Details__c = '{invalid-json';
    update slip;

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> details = PWChrono_PayrollController.getSalarySlipDetails(
        slip.Id,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        0,
        ((List<PWChrono_PayrollController.SalaryComponent>) details.get(
            'earnings'
          ))
          .size(),
        'Invalid legacy earnings JSON must not prevent a payslip from loading.'
      );
      System.assertEquals(
        0,
        ((List<PWChrono_PayrollController.SalaryComponent>) details.get(
            'deductions'
          ))
          .size(),
        'Invalid legacy deduction JSON must not prevent a payslip from loading.'
      );
    }
  }

  @isTest
  static void testGetSalarySlipDetailsRejectsWrongContact() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Salary_Slip__c slip = [
      SELECT Id
      FROM PWChrono_Salary_Slip__c
      LIMIT 1
    ];
    Contact unrelatedContact = new Contact(
      LastName = 'Unrelated Payroll Contact',
      Email = 'unrelated.payroll@example.com'
    );
    insert unrelatedContact;

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_PayrollController.getSalarySlipDetails(
          slip.Id,
          unrelatedContact.Id,
          null,
          null
        );
        Assert.fail('A Contact must not access another Contact\'s payslip.');
      } catch (AuraHandledException expected) {
        Assert.isNotNull(expected);
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testEmployeeDropdownReturnsContacts() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Id expectedContactId = employeeContactId(testUser.Id);

    System.runAs(testUser) {
      Test.startTest();
      List<Contact> employees = PWChrono_PayrollController.getEmployeesForDropdown(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(1, employees.size());
      System.assertEquals(
        expectedContactId,
        employees[0].Id,
        'The employee selector must return Contact IDs.'
      );
    }
  }

  @isTest
  static void testPayrollConfiguration() {
    Test.startTest();
    Map<String, String> configuration = PWChrono_PayrollController.getPayrollConfiguration();
    Test.stopTest();

    System.assert(configuration.containsKey('ccEmail'));
    System.assertNotEquals(null, configuration.get('ccEmail'));
  }

  @isTest
  static void testSendSalarySlipRequiresCustomPermission() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Salary_Slip__c slip = [
      SELECT Id, Contact__r.Email
      FROM PWChrono_Salary_Slip__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_PayrollController.sendSalarySlipEmail(
          slip.Id,
          slip.Contact__r.Email,
          null,
          'Salary Slip',
          'Body',
          null,
          null
        );
        Assert.fail('Sending must require PWChrono_Send_Payslips.');
      } catch (AuraHandledException expected) {
        Assert.isNotNull(expected);
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testAuthorizedSendUsesContactRecipient() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PermissionSet payrollPermission = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'PWChrono_Payroll_Manager'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = testUser.Id,
      PermissionSetId = payrollPermission.Id
    );
    PWChrono_Salary_Slip__c slip = [
      SELECT Id, Contact__r.Email
      FROM PWChrono_Salary_Slip__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      List<Contact> payrollContacts = PWChrono_PayrollController.getEmployeesForDropdown(
        null,
        null
      );
      PWChrono_PayrollController.sendSalarySlipEmail(
        slip.Id,
        slip.Contact__r.Email,
        null,
        'Salary Slip',
        'Body',
        null,
        null
      );
      Integer emailInvocations = Limits.getEmailInvocations();
      Test.stopTest();

      System.assertEquals(
        employeeContactId(testUser.Id),
        payrollContacts[0].Id,
        'An authorized payroll manager can use the Contact selector.'
      );
      System.assertEquals(1, emailInvocations);
    }
  }

  @isTest
  static void testGuestPayrollRequiresEnabledProfileFeature() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    Portal_Users__c portalUser = PWChrono_TestDataFactory.createPortalUser(
      'Restricted Payroll Guest',
      'restricted-payroll@example.com',
      'Employee'
    );
    portalUser.Portal_User_Profile__c = profile.Id;
    portalUser.Session_Token__c = 'restricted_payroll_token';
    portalUser.Session_Expires_At__c = System.now().addHours(1);
    update portalUser;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_PayrollController.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      try {
        PWChrono_PayrollController.getEmployeesForDropdown(
          String.valueOf(portalUser.Id),
          'restricted_payroll_token'
        );
        Assert.fail('A guest without the Payroll feature must be rejected.');
      } catch (AuraHandledException expected) {
        Assert.isNotNull(expected);
      }
      Test.stopTest();
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_PayrollController.testUserTypeOverride = null;
    }
  }

  @isTest
  static void testGuestPayrollReturnsOnlyOwnContactWhenFeatureIsEnabled() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = profile.Id,
      Feature_Key__c = 'Payroll',
      Feature_Label__c = 'Payroll',
      Is_Enabled__c = true
    );
    Portal_Users__c portalUser = PWChrono_TestDataFactory.createPortalUser(
      'Authorized Payroll Guest',
      'authorized-payroll@example.com',
      'Employee'
    );
    portalUser.Portal_User_Profile__c = profile.Id;
    portalUser.Session_Token__c = 'authorized_payroll_token';
    portalUser.Session_Expires_At__c = System.now().addHours(1);
    update portalUser;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_PayrollController.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<Contact> contacts = PWChrono_PayrollController.getEmployeesForDropdown(
        String.valueOf(portalUser.Id),
        'authorized_payroll_token'
      );
      Test.stopTest();

      System.assertEquals(1, contacts.size());
      System.assertEquals(portalUser.Contact__c, contacts[0].Id);
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_PayrollController.testUserTypeOverride = null;
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
  static void testGetMySalaryStructureWithoutAssignment() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    System.runAs(adminUser) {
      PWChrono_TestDataFactory.createTestEmployee(adminUser.Id);

      Test.startTest();
      try {
        PWChrono_PayrollController.getMySalaryStructure();
        Assert.fail('An employee without an assignment must receive an error.');
      } catch (AuraHandledException expected) {
        Assert.isNotNull(expected);
      }
      Test.stopTest();
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
  static void testGetYTDSummaryWithoutSalarySlipsReturnsZeros() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];
    System.runAs(adminUser) {
      PWChrono_TestDataFactory.createTestEmployee(adminUser.Id);

      Test.startTest();
      Map<String, Decimal> summary = PWChrono_PayrollController.getYTDSummary(
        Date.today().year()
      );
      Test.stopTest();

      System.assertEquals(0, summary.get('totalGross'));
      System.assertEquals(0, summary.get('totalDeductions'));
      System.assertEquals(0, summary.get('totalNet'));
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

  private static Id employeeContactId(Id userId) {
    return [
      SELECT Contact__c
      FROM Portal_Users__c
      WHERE User__c = :userId
      LIMIT 1
    ]
    .Contact__c;
  }
}