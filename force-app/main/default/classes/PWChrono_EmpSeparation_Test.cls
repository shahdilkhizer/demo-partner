@isTest
private class PWChrono_EmpSeparation_Test {
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

      PWChrono_Separation_Template__c tmpl = new PWChrono_Separation_Template__c(
        Name = 'Standard Exit',
        Is_Active__c = true
      );
      insert tmpl;

      PWChrono_Separation_Template_Activity__c act = new PWChrono_Separation_Template_Activity__c(
        Name = 'Return Laptop',
        Separation_Template__c = tmpl.Id,
        Is_Required__c = true,
        Begin_On_Day__c = 1,
        Duration__c = 1
      );
      insert act;

      PWChrono_Employee_Separation__c sep = new PWChrono_Employee_Separation__c(
        Employee__c = employee.Id,
        Employee_Name__c = employee.Name,
        Company__c = 'PWChrono Corp',
        Department__c = dept.Id,
        Designation__c = desig.Id,
        Resignation_Letter_Date__c = Date.today(),
        Relieving_Date__c = Date.today().addDays(30),
        Status__c = 'Pending',
        Separation_Template__c = tmpl.Id
      );
      insert sep;

      PWChrono_Separation_Checklist__c item = new PWChrono_Separation_Checklist__c(
        Name = 'Return Laptop',
        Separation__c = sep.Id,
        Status__c = 'Pending',
        Is_Required__c = true
      );
      insert item;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getSeparations
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetSeparations_AllAsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Separation__c> results = PWChrono_EmployeeSeparationController.getSeparations(
      'All',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size());
  }

  @isTest
  static void testGetSeparations_OwnAsEmployee() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Separation__c> results = PWChrono_EmployeeSeparationController.getSeparations(
      'All',
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size());
  }

  @isTest
  static void testGetSeparations_FilterByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Employee_Separation__c> pending = PWChrono_EmployeeSeparationController.getSeparations(
      'Pending',
      hr.Id,
      null
    );
    List<PWChrono_Employee_Separation__c> completed = PWChrono_EmployeeSeparationController.getSeparations(
      'Completed',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, pending.size());
    System.assertEquals(0, completed.size());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getSeparationById
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetSeparationById() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Employee_Separation__c result = PWChrono_EmployeeSeparationController.getSeparationById(
      sep.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals('PWChrono Corp', result.Company__c);
  }

  @isTest
  static void testGetSeparationById_NotFound() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeeSeparationController.getSeparationById(
        'a0C000000000001AAA',
        hr.Id,
        null
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getChecklistItems
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetChecklistItems() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Separation_Checklist__c> items = PWChrono_EmployeeSeparationController.getChecklistItems(
      sep.Id,
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, items.size());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // saveSeparation
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSaveSeparation_Insert() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => emp.Id,
      'Employee_Name__c' => 'Test Employee',
      'Company__c' => 'New Corp',
      'Resignation_Letter_Date__c' => String.valueOf(Date.today()),
      'Relieving_Date__c' => String.valueOf(Date.today().addDays(30)),
      'Status__c' => 'Pending'
    };
    List<Map<String, Object>> checklist = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Name' => 'Return Badge',
        'Status__c' => 'Pending',
        'Is_Required__c' => false
      }
    };
    Test.startTest();
    String newId = PWChrono_EmployeeSeparationController.saveSeparation(
      JSON.serialize(rec),
      JSON.serialize(checklist),
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertNotEquals(null, newId);
    List<PWChrono_Separation_Checklist__c> items = [
      SELECT Id
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :newId
    ];
    System.assertEquals(1, items.size());
  }

  @isTest
  static void testSaveSeparation_Update() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Map<String, Object> rec = new Map<String, Object>{
      'Id' => sep.Id,
      'Company__c' => 'Updated Corp'
    };
    Test.startTest();
    String savedId = PWChrono_EmployeeSeparationController.saveSeparation(
      JSON.serialize(rec),
      '[]',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(sep.Id, savedId);
    PWChrono_Employee_Separation__c updated = [
      SELECT Company__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :sep.Id
    ];
    System.assertEquals('Updated Corp', updated.Company__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // updateSeparationStatus
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testUpdateSeparationStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeeSeparationController.updateSeparationStatus(
      sep.Id,
      'In Process',
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(
      'In Process',
      [SELECT Status__c FROM PWChrono_Employee_Separation__c WHERE Id = :sep.Id]
      .Status__c
    );
  }

  @isTest
  static void testUpdateSeparationStatus_NotHR() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_EmployeeSeparationController.updateSeparationStatus(
        sep.Id,
        'Completed',
        emp.Id,
        null
      );
    } catch (AuraHandledException ex) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // deleteSeparation
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testDeleteSeparation() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_EmployeeSeparationController.deleteSeparation(sep.Id, hr.Id, null);
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT Id FROM PWChrono_Employee_Separation__c WHERE Id = :sep.Id].size()
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Exit record
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSaveExitRecord_Insert() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => emp.Id,
      'Employee_Name__c' => 'Test Employee',
      'Resignation_Date__c' => String.valueOf(Date.today()),
      'Relieving_Date__c' => String.valueOf(Date.today().addDays(30)),
      'Exit_Type__c' => 'Resignation',
      'Separation__c' => sep.Id
    };
    Test.startTest();
    String newId = PWChrono_EmployeeSeparationController.saveExitRecord(
      JSON.serialize(rec),
      emp.Id,
      null
    );
    Test.stopTest();
    System.assertNotEquals(null, newId);
  }

  @isTest
  static void testGetExitRecords_AsHR() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'emp@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c sep = [
      SELECT Id
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    insert new PWChrono_Employee_Exit__c(
      Employee__c = emp.Id,
      Employee_Name__c = 'Test Employee',
      Resignation_Date__c = Date.today(),
      Exit_Type__c = 'Resignation',
      Separation__c = sep.Id
    );
    Test.startTest();
    List<PWChrono_Employee_Exit__c> results = PWChrono_EmployeeSeparationController.getExitRecords(
      hr.Id,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetActiveDesignations() {
    Test.startTest();
    List<PWChrono_Designation__c> r = PWChrono_EmployeeSeparationController.getActiveDesignations();
    Test.stopTest();
    System.assert(r.size() >= 1);
  }

  @isTest
  static void testGetActiveDepartments() {
    Test.startTest();
    List<PWChrono_Department__c> r = PWChrono_EmployeeSeparationController.getActiveDepartments();
    Test.stopTest();
    System.assert(r.size() >= 1);
  }

  @isTest
  static void testGetActiveEmployees() {
    Test.startTest();
    List<Portal_Users__c> r = PWChrono_EmployeeSeparationController.getActiveEmployees();
    Test.stopTest();
    System.assert(r.size() >= 1);
  }

  @isTest
  static void testGetActiveSeparationTemplates() {
    Test.startTest();
    List<PWChrono_Separation_Template__c> r = PWChrono_EmployeeSeparationController.getActiveSeparationTemplates();
    Test.stopTest();
    System.assert(r.size() >= 1);
  }

  @isTest
  static void testGetSeparations_GuestHrSession() {
    Portal_Users__c hr = [
      SELECT Id, Session_Token__c, Session_Expires_At__c
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_separation_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Employee_Separation__c> results =
        PWChrono_EmployeeSeparationController.getSeparations(
          'All',
          String.valueOf(hr.Id),
          'guest_separation_token'
        );
      Test.stopTest();
      System.assertEquals(1, results.size());
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testDeleteSeparation_NonPendingThrows() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    PWChrono_Employee_Separation__c separation = [
      SELECT Id, Status__c
      FROM PWChrono_Employee_Separation__c
      LIMIT 1
    ];
    separation.Status__c = 'Completed';
    update separation;

    Test.startTest();
    try {
      PWChrono_EmployeeSeparationController.deleteSeparation(
        String.valueOf(separation.Id),
        String.valueOf(hr.Id),
        null
      );
      System.assert(false, 'Only pending separation records should be deletable.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @isTest
  static void testMalformedPayloadsThrow() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Name = 'HR Admin'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_EmployeeSeparationController.saveSeparation(
        '{bad json',
        '[]',
        hr.Id,
        null
      );
      System.assert(false, 'Malformed separation JSON should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }

    try {
      PWChrono_EmployeeSeparationController.saveExitRecord(
        '{bad json',
        hr.Id,
        null
      );
      System.assert(false, 'Malformed exit record JSON should throw.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }
}