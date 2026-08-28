@isTest
private class PWChrono_EmpDirectoryCtrl_Test {
  @TestSetup
  static void makeData() {
    // Create User and Employee
    User testUser = PWChrono_TestDataFactory.createTestUser('Standard User');

    // Department is a formula (Contact__r.Department) — set it on the Contact.
    Contact con = new Contact(LastName = 'Test Employee', Department = 'IT');
    insert con;

    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );
    employee.Designation__c = 'Developer';
    employee.Contact__c = con.Id;
    update employee;
  }

  @isTest
  static void testSearchEmployees() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'Standard User'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      List<Portal_Users__c> employees = PWChrono_EmployeeDirectoryController.searchEmployees(
        'Test'
      );
      Test.stopTest();

      System.assert(!employees.isEmpty(), 'Should find employee');
    }
  }

  @isTest
  static void testSearchEmployeesWithDepartment() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'Standard User'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      List<Portal_Users__c> employees = PWChrono_EmployeeDirectoryController.searchEmployees(
        'IT'
      );
      Test.stopTest();

      System.assert(!employees.isEmpty(), 'Should find employee by department');
    }
  }

  @isTest
  static void testCheckRecordAccess() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'Standard User'
      LIMIT 1
    ];
    Portal_Users__c employee = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :testUser.Id
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      Boolean hasAccess = PWChrono_EmployeeDirectoryController.checkRecordAccess(
        employee.Id
      );
      Test.stopTest();

      System.assert(hasAccess, 'Should have access to own record');
    }
  }
}