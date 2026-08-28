/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
private class PWChrono_FFSettlement_Test {
  @testSetup
  static void setupData() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Portal_Users__c hrAdmin = new Portal_Users__c(
        Name = 'HR Admin',
        Email__c = 'hr@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
        Is_Active__c = true
      );
      insert hrAdmin;

      Portal_Users__c employee = new Portal_Users__c(
        Name = 'Settlement Employee',
        Email__c = 'semp@test.com',
        Role__c = 'Employee',
        Is_Active__c = true
      );
      insert employee;
      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Finance',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Accountant',
        Is_Active__c = true
      );
      insert desig;

      PWChrono_Employee_Separation__c sep = new PWChrono_Employee_Separation__c(
        Employee__c = employee.Id,
        Status__c = 'Pending',
        Resignation_Letter_Date__c = Date.today()
      );
      insert sep;

      PWChrono_Full_Final_Settlement__c settlement = new PWChrono_Full_Final_Settlement__c(
        Employee__c = employee.Id,
        Employee_Name__c = 'Settlement Employee',
        Company__c = 'PulseWork',
        Department__c = dept.Id,
        Designation__c = desig.Id,
        Separation__c = sep.Id,
        Date_of_Joining__c = Date.today().addYears(-3),
        Relieving_Date__c = Date.today(),
        Status__c = 'Draft',
        Total_Payable__c = 5000,
        Total_Receivable__c = 2000,
        Net_Payable__c = 3000
      );
      insert settlement;

      PWChrono_Settlement_Payable__c payable = new PWChrono_Settlement_Payable__c(
        Settlement__c = settlement.Id,
        Name = 'Salary Payable',
        Component__c = 'Basic Salary',
        Amount__c = 5000,
        Status__c = 'Pending'
      );
      insert payable;

      PWChrono_Settlement_Receivable__c receivable = new PWChrono_Settlement_Receivable__c(
        Settlement__c = settlement.Id,
        Name = 'Loan Recovery',
        Component__c = 'Personal Loan',
        Amount__c = 2000,
        Status__c = 'Pending'
      );
      insert receivable;
    }
  }

  @isTest
  static void testGetSettlements_AllAsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Full_Final_Settlement__c> results = PWChrono_FullFinalSettlementController.getSettlements(
      'All',
      hr.Id,
      ''
    );
    Test.stopTest();
    System.assert(!results.isEmpty(), 'HR should see all settlements');
  }

  @isTest
  static void testGetSettlements_OwnAsEmployee() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'semp@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Full_Final_Settlement__c> results = PWChrono_FullFinalSettlementController.getSettlements(
      'All',
      emp.Id,
      ''
    );
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'Employee should see only own settlement'
    );
  }

  @isTest
  static void testGetSettlements_FilterByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Full_Final_Settlement__c> results = PWChrono_FullFinalSettlementController.getSettlements(
      'Draft',
      hr.Id,
      ''
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'Should return Draft settlements');
  }

  @isTest
  static void testGetSettlementById() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Full_Final_Settlement__c result = PWChrono_FullFinalSettlementController.getSettlementById(
      s.Id,
      hr.Id,
      ''
    );
    Test.stopTest();
    System.assertEquals(s.Id, result.Id);
  }

  @isTest
  static void testGetPayables() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Settlement_Payable__c> payables = PWChrono_FullFinalSettlementController.getPayables(
      s.Id,
      hr.Id,
      ''
    );
    Test.stopTest();
    System.assertEquals(1, payables.size(), 'Should return 1 payable');
  }

  @isTest
  static void testGetReceivables() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Settlement_Receivable__c> receivables = PWChrono_FullFinalSettlementController.getReceivables(
      s.Id,
      hr.Id,
      ''
    );
    Test.stopTest();
    System.assertEquals(1, receivables.size(), 'Should return 1 receivable');
  }

  @isTest
  static void testSaveSettlement_Insert() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'semp@test.com'
      LIMIT 1
    ];
    PWChrono_Department__c dept = [
      SELECT Id
      FROM PWChrono_Department__c
      LIMIT 1
    ];

    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => emp.Id,
      'Employee_Name__c' => 'New Employee',
      'Company__c' => 'PW Corp',
      'Department__c' => dept.Id,
      'Relieving_Date__c' => String.valueOf(Date.today()),
      'Status__c' => 'Draft'
    };
    List<Map<String, Object>> payables = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Name' => 'Leave Encashment',
        'Component__c' => 'Leave',
        'Amount__c' => 1000,
        'Status__c' => 'Pending'
      }
    };
    List<Map<String, Object>> receivables = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Name' => 'Equipment',
        'Component__c' => 'Laptop',
        'Amount__c' => 500,
        'Status__c' => 'Pending'
      }
    };

    Test.startTest();
    String newId = PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(rec),
      JSON.serialize(payables),
      JSON.serialize(receivables),
      hr.Id,
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, newId, 'Should return new settlement Id');
    PWChrono_Full_Final_Settlement__c created = [
      SELECT Total_Payable__c, Total_Receivable__c, Net_Payable__c
      FROM PWChrono_Full_Final_Settlement__c
      WHERE Id = :newId
    ];
    System.assertEquals(1000, created.Total_Payable__c);
    System.assertEquals(500, created.Total_Receivable__c);
    System.assertEquals(500, created.Net_Payable__c);
  }

  @isTest
  static void testSaveSettlement_Update() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];

    Map<String, Object> rec = new Map<String, Object>{
      'Id' => s.Id,
      'Status__c' => 'Submitted'
    };

    Test.startTest();
    String updatedId = PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(rec),
      JSON.serialize(new List<Object>()),
      JSON.serialize(new List<Object>()),
      hr.Id,
      ''
    );
    Test.stopTest();
    System.assertEquals(s.Id, updatedId);
  }

  @isTest
  static void testUpdateSettlementStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_FullFinalSettlementController.updateSettlementStatus(
      s.Id,
      'Paid',
      hr.Id,
      ''
    );
    Test.stopTest();
    PWChrono_Full_Final_Settlement__c updated = [
      SELECT Status__c
      FROM PWChrono_Full_Final_Settlement__c
      WHERE Id = :s.Id
    ];
    System.assertEquals('Paid', updated.Status__c);
  }

  @isTest
  static void testUpdateSettlementStatus_NotHR() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'semp@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];
    Boolean threw = false;
    Test.startTest();
    try {
      PWChrono_FullFinalSettlementController.updateSettlementStatus(
        s.Id,
        'Paid',
        emp.Id,
        ''
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Non-HR should not update status');
  }

  @isTest
  static void testDeleteSettlement() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Full_Final_Settlement__c s = [
      SELECT Id
      FROM PWChrono_Full_Final_Settlement__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_FullFinalSettlementController.deleteSettlement(s.Id, hr.Id, '');
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT COUNT() FROM PWChrono_Full_Final_Settlement__c WHERE Id = :s.Id]
    );
  }

  @isTest
  static void testGetActiveDesignations() {
    Test.startTest();
    List<PWChrono_Designation__c> results = PWChrono_FullFinalSettlementController.getActiveDesignations();
    Test.stopTest();
    System.assert(!results.isEmpty());
  }

  @isTest
  static void testGetActiveDepartments() {
    Test.startTest();
    List<PWChrono_Department__c> results = PWChrono_FullFinalSettlementController.getActiveDepartments();
    Test.stopTest();
    System.assert(!results.isEmpty());
  }

  @isTest
  static void testGetActiveEmployees() {
    Test.startTest();
    List<Portal_Users__c> results = PWChrono_FullFinalSettlementController.getActiveEmployees();
    Test.stopTest();
    System.assert(!results.isEmpty());
  }

  @isTest
  static void testGetActiveSeparations() {
    Test.startTest();
    List<PWChrono_Employee_Separation__c> results = PWChrono_FullFinalSettlementController.getActiveSeparations();
    Test.stopTest();
    System.assert(!results.isEmpty());
  }
}