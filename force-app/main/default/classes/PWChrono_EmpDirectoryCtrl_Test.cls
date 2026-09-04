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
    Test.startTest();
    List<Contact> employees = PWChrono_EmployeeDirectoryController.searchEmployees(
      'Test',
      null,
      null
    );
    Test.stopTest();

    System.assert(!employees.isEmpty(), 'Should find employee');
  }

  @isTest
  static void testSearchEmployeesWithDepartment() {
    Test.startTest();
    List<Contact> employees = PWChrono_EmployeeDirectoryController.searchEmployees(
      'IT',
      null,
      null
    );
    Test.stopTest();

    System.assert(!employees.isEmpty(), 'Should find employee by department');
  }

  @isTest
  static void testCheckRecordAccess() {
    Portal_Users__c employee = [
      SELECT Id, Contact__c
      FROM Portal_Users__c
      LIMIT 1
    ];

    Test.startTest();
    Boolean hasAccess = PWChrono_EmployeeDirectoryController.checkRecordAccess(
      employee.Contact__c,
      null,
      null
    );
    Test.stopTest();

    System.assert(hasAccess, 'Should have access to the Contact record');
  }
}