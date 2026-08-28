@isTest
private class PWChrono_PolicyController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    PWChrono_Company_Policy__c policy1 = new PWChrono_Company_Policy__c(
      Name = 'Policy 1',
      Category__c = 'HR',
      Description__c = 'Description 1',
      Effective_Date__c = Date.today()
    );
    insert policy1;

    PWChrono_Company_Policy__c policy2 = new PWChrono_Company_Policy__c(
      Name = 'Policy 2',
      Category__c = 'IT',
      Description__c = 'Description 2',
      Effective_Date__c = Date.today().addDays(-10)
    );
    insert policy2;
  }

  @isTest
  static void testGetPolicies() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Company_Policy__c> policies = PWChrono_PolicyController.getPolicies(
        null
      );
      Test.stopTest();

      System.assertEquals(2, policies.size(), 'Should return 2 policies');
    }
  }

  @isTest
  static void testGetPoliciesByCategory() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Company_Policy__c> policies = PWChrono_PolicyController.getPolicies(
        'HR'
      );
      Test.stopTest();

      System.assertEquals(1, policies.size(), 'Should return 1 HR policy');
      System.assertEquals(
        'HR',
        policies[0].Category__c,
        'Category should be HR'
      );
    }
  }
}