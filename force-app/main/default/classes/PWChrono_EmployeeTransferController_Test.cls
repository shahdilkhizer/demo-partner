/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
private class PWChrono_EmployeeTransferController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Portal_Users__c employee = new Portal_Users__c(
        Name = 'Test Employee',
        Email__c = 'emp@test.com',
        Role__c = 'Employee',
        Is_Active__c = true
      );
      insert employee;

      Portal_Users__c hrAdmin = new Portal_Users__c(
        Name = 'HR Admin',
        Email__c = 'hr@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
        Is_Active__c = true
      );
      insert hrAdmin;

      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Developer',
        Is_Active__c = true
      );
      insert desig;

      PWChrono_Employee_Transfer__c transfer = new PWChrono_Employee_Transfer__c(
        Employee__c = employee.Id,
        Employee_Name__c = employee.Name,
        Company__c = 'PWChrono Corp',
        Transfer_Date__c = Date.today(),
        Current_Branch__c = 'HQ',
        New_Branch__c = 'North Office',
        Current_Department__c = dept.Id,
        New_Department__c = dept.Id,
        Current_Designation__c = desig.Id,
        New_Designation__c = desig.Id,
        Status__c = 'Draft'
      );
      insert transfer;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getTransfers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetTransfers_AllAsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Transfer__c> results = PWChrono_EmployeeTransferController.getTransfers(
      'All',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'HR should see all transfers');
  }

  @isTest
  static void testGetTransfers_OwnAsEmployee() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Transfer__c> results = PWChrono_EmployeeTransferController.getTransfers(
      'All',
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'Employee should see their own transfer'
    );
  }

  @isTest
  static void testGetTransfers_FilterByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Transfer__c> draft = PWChrono_EmployeeTransferController.getTransfers(
      'Draft',
      hr.Id,
      null
    );
    List<PWChrono_Employee_Transfer__c> approved = PWChrono_EmployeeTransferController.getTransfers(
      'Approved',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, draft.size());
    System.assertEquals(0, approved.size());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getTransferById
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetTransferById() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Transfer__c transfer = [
      SELECT Id
      FROM PWChrono_Employee_Transfer__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Employee_Transfer__c result = PWChrono_EmployeeTransferController.getTransferById(
      transfer.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals('PWChrono Corp', result.Company__c);
  }

  @isTest
  static void testGetTransferById_NotFound() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeeTransferController.getTransferById(
        'a0C000000000001AAA',
        hr.Id,
        null
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Should throw AuraHandledException when not found');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveTransfer
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSaveTransfer_Insert() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => emp.Id,
      'Employee_Name__c' => 'Test Employee',
      'Transfer_Date__c' => String.valueOf(Date.today()),
      'Company__c' => 'New Corp',
      'Current_Branch__c' => 'HQ',
      'New_Branch__c' => 'South Office',
      'Status__c' => 'Draft'
    };
    Test.startTest();
    String newId = PWChrono_EmployeeTransferController.saveTransfer(
      JSON.serialize(rec),
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertNotEquals(null, newId);
  }

  @isTest
  static void testSaveTransfer_Update() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Transfer__c transfer = [
      SELECT Id
      FROM PWChrono_Employee_Transfer__c
      LIMIT 1
    ];
    Map<String, Object> rec = new Map<String, Object>{
      'Id' => transfer.Id,
      'Company__c' => 'Updated Corp'
    };
    Test.startTest();
    String savedId = PWChrono_EmployeeTransferController.saveTransfer(
      JSON.serialize(rec),
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(transfer.Id, savedId);
    PWChrono_Employee_Transfer__c updated = [
      SELECT Company__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :transfer.Id
    ];
    System.assertEquals('Updated Corp', updated.Company__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // updateTransferStatus
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testUpdateTransferStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Transfer__c transfer = [
      SELECT Id
      FROM PWChrono_Employee_Transfer__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Approved',
      hr.Id,
      null
    );
    Test.stopTest();
    PWChrono_Employee_Transfer__c updated = [
      SELECT Status__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :transfer.Id
    ];
    System.assertEquals('Approved', updated.Status__c);
  }

  @isTest
  static void testUpdateTransferStatus_NotHR() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Transfer__c transfer = [
      SELECT Id
      FROM PWChrono_Employee_Transfer__c
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeeTransferController.updateTransferStatus(
        transfer.Id,
        'Approved',
        emp.Id,
        null
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Non-HR should not be able to update status');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // deleteTransfer
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testDeleteTransfer() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Transfer__c transfer = [
      SELECT Id
      FROM PWChrono_Employee_Transfer__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeeTransferController.deleteTransfer(
      transfer.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    List<PWChrono_Employee_Transfer__c> remaining = [
      SELECT Id
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :transfer.Id
    ];
    System.assertEquals(0, remaining.size());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetActiveDesignations() {
    Test.startTest();
    List<PWChrono_Designation__c> results = PWChrono_EmployeeTransferController.getActiveDesignations();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetActiveDepartments() {
    Test.startTest();
    List<PWChrono_Department__c> results = PWChrono_EmployeeTransferController.getActiveDepartments();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetActiveEmployees() {
    Test.startTest();
    List<Portal_Users__c> results = PWChrono_EmployeeTransferController.getActiveEmployees();
    Test.stopTest();
    System.assert(results.size() >= 1);
  }

  @isTest
  static void testGetTransfers_GuestHrSession() {
    Portal_Users__c hr = [
      SELECT Id, Session_Token__c, Session_Expires_At__c
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_transfer_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Employee_Transfer__c> results =
        PWChrono_EmployeeTransferController.getTransfers(
          'All',
          String.valueOf(hr.Id),
          'guest_transfer_token'
        );
      Test.stopTest();
      System.assertEquals(1, results.size(), 'Guest HR should see transfer records.');
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testDeleteTransfer_NonDraftThrows() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Transfer__c transfer = [
      SELECT Id, Status__c
      FROM PWChrono_Employee_Transfer__c
      LIMIT 1
    ];
    transfer.Status__c = 'Approved';
    update transfer;

    Test.startTest();
    try {
      PWChrono_EmployeeTransferController.deleteTransfer(
        String.valueOf(transfer.Id),
        String.valueOf(hr.Id),
        null
      );
      System.assert(false, 'Only draft transfer records should be deletable.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }
}