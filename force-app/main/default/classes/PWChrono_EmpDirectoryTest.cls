@isTest
private class PWChrono_EmpDirectoryTest {
  @TestSetup
  static void setupTestData() {
    Account acc = new Account(Name = 'Test Corp');
    insert acc;

    Contact mgr = new Contact(
      FirstName = 'Manager',
      LastName = 'One',
      Title = 'Manager',
      Department = 'Finance',
      Email = 'mgr@test.com',
      Phone = '1234567890',
      AccountId = acc.Id
    );
    insert mgr;

    List<Contact> contacts = new List<Contact>();
    contacts.add(
      new Contact(
        FirstName = 'Alice',
        LastName = 'Developer',
        Title = 'Developer',
        Department = 'Engineering',
        Email = 'alice@test.com',
        Phone = '1112223333',
        ReportsToId = mgr.Id,
        AccountId = acc.Id
      )
    );
    contacts.add(
      new Contact(
        FirstName = 'Bob',
        LastName = 'Finance',
        Title = 'Finance',
        Department = 'Finance',
        Email = 'bob@test.com',
        Phone = '4445556666',
        ReportsToId = mgr.Id,
        AccountId = acc.Id
      )
    );
    insert contacts;
  }

  @isTest
  static void testGetEmployees_All() {
    Test.startTest();
    List<PWChrono_EmployeeDirectoryController.EmployeeWrapper> results =
      PWChrono_EmployeeDirectoryController.getEmployees('', 'All', 'All', 'Ascending');
    Test.stopTest();

    System.assertNotEquals(null, results, 'Results should not be null');
    System.assert(results.size() >= 3, 'Should return at least 3 contacts');
  }

  @isTest
  static void testGetEmployees_WithFilters() {
    Test.startTest();
    List<PWChrono_EmployeeDirectoryController.EmployeeWrapper> filtered =
      PWChrono_EmployeeDirectoryController.getEmployees('Alice', 'Developer', 'All', 'Descending');
    Test.stopTest();

    System.assertNotEquals(null, filtered, 'Results should not be null');
    System.assert(filtered.size() >= 1, 'Should find at least 1 developer');
    System.assertEquals('Alice Developer', filtered[0].name);
  }

  @isTest
  static void testGetEmployeeDirectoryMetrics() {
    Test.startTest();
    Map<String, Object> metrics = PWChrono_EmployeeDirectoryController.getEmployeeDirectoryMetrics();
    Test.stopTest();

    System.assertNotEquals(null, metrics, 'Metrics map should not be null');
    System.assert(metrics.containsKey('total'), 'Should contain total count');
    System.assert(metrics.containsKey('active'), 'Should contain active count');
  }

  @isTest
  static void testGetEmployeeDesignations() {
    Test.startTest();
    List<String> designations = PWChrono_EmployeeDirectoryController.getEmployeeDesignations();
    Test.stopTest();

    System.assertNotEquals(null, designations, 'Designations should not be null');
    System.assert(designations.size() > 0, 'Should return designations');
  }

  @isTest
  static void testGetEmployeeDetail() {
    Contact c = [SELECT Id FROM Contact WHERE FirstName = 'Alice' LIMIT 1];

    Test.startTest();
    PWChrono_EmployeeDirectoryController.EmployeeWrapper detail =
      PWChrono_EmployeeDirectoryController.getEmployeeDetail(c.Id);
    Test.stopTest();

    System.assertNotEquals(null, detail, 'Employee detail should not be null');
    System.assertEquals('Alice Developer', detail.name);
  }

  @isTest
  static void testSaveAndDeleteEmployee() {
    Contact newContact = new Contact(
      FirstName = 'Charlie',
      LastName = 'Tester',
      Email = 'charlie@test.com',
      Title = 'QA Engineer'
    );

    Test.startTest();
    Contact saved = PWChrono_EmployeeDirectoryController.saveEmployee(newContact);
    System.assertNotEquals(null, saved.Id, 'Contact should be inserted');

    saved.LastName = 'Updated';
    PWChrono_EmployeeDirectoryController.saveEmployee(saved);

    PWChrono_EmployeeDirectoryController.deleteEmployee(saved.Id);
    Test.stopTest();

    List<Contact> check = [SELECT Id FROM Contact WHERE Id = :saved.Id];
    System.assertEquals(0, check.size(), 'Contact should be deleted');
  }

  @isTest
  static void testLegacyMethods() {
    Contact c = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    List<SObject> legacy = PWChrono_EmployeeDirectoryController.searchEmployees('Alice');
    Boolean hasAccess = PWChrono_EmployeeDirectoryController.checkRecordAccess(c.Id);
    Test.stopTest();

    System.assertNotEquals(null, legacy, 'Legacy search should return results');
    System.assertEquals(true, hasAccess, 'User should have access');
  }
}
