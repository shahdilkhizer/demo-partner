@isTest
private class PWChrono_Utils_Test {
  @isTest
  static void testGetCurrentEmployeeId() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );

    System.runAs(testUser) {
      Id empId = PWChrono_Utils.getCurrentEmployeeId(testUser.Id);
      System.assertEquals(employee.Id, empId);
    }
  }

  @isTest
  static void testGetCurrentEmployeeIdNull() {
    Id empId = PWChrono_Utils.getCurrentEmployeeId(null);
    System.assertEquals(null, empId);
  }
}