@isTest
private class PWChrono_TaxController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_TestDataFactory.assignPermissionSet(
      testUser.Id,
      'PWChrono_HR_Admin'
    );

    Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
      testUser.Id
    );

    PWChrono_Tax_Declaration__c decl1 = new PWChrono_Tax_Declaration__c(
      Employees__c = employee.Id,
      Fiscal_Year__c = '2023-2024',
      Status__c = PWChrono_Constants.STATUS_DRAFT,
      Section_80C__c = 150000,
      HRA__c = 50000
    );
    insert decl1;

    PWChrono_Tax_Declaration__c decl2 = new PWChrono_Tax_Declaration__c(
      Employees__c = employee.Id,
      Fiscal_Year__c = '2022-2023',
      Status__c = PWChrono_Constants.STATUS_APPROVED,
      Section_80C__c = 150000,
      HRA__c = 50000
    );
    insert decl2;
  }

  @isTest
  static void testGetMyTaxDeclarations() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Tax_Declaration__c> declarations = PWChrono_TaxController.getMyTaxDeclarations(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        2,
        declarations.size(),
        'Should return 2 declarations'
      );
    }
  }

  @isTest
  static void testSaveTaxDeclaration() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      PWChrono_Tax_Declaration__c newDecl = new PWChrono_Tax_Declaration__c(
        Fiscal_Year__c = '2024-2025',
        Section_80C__c = 100000
      );

      Test.startTest();
      PWChrono_Tax_Declaration__c savedDecl = PWChrono_TaxController.saveTaxDeclaration(
        newDecl,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, savedDecl.Id, 'Declaration should be saved');
      System.assertEquals(
        PWChrono_Constants.STATUS_DRAFT,
        savedDecl.Status__c,
        'Status should be Draft'
      );
    }
  }

  @isTest
  static void testUpdateTaxDeclaration() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Tax_Declaration__c decl = [
      SELECT Id, Section_80C__c
      FROM PWChrono_Tax_Declaration__c
      WHERE Status__c = :PWChrono_Constants.STATUS_DRAFT
      LIMIT 1
    ];

    System.runAs(testUser) {
      decl.Section_80C__c = 120000;

      Test.startTest();
      PWChrono_Tax_Declaration__c updatedDecl = PWChrono_TaxController.saveTaxDeclaration(
        decl,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        120000,
        updatedDecl.Section_80C__c,
        'Section 80C should be updated'
      );
    }
  }

  @isTest
  static void testSubmitTaxDeclaration() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Tax_Declaration__c decl = [
      SELECT Id
      FROM PWChrono_Tax_Declaration__c
      WHERE Status__c = :PWChrono_Constants.STATUS_DRAFT
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_TaxController.submitTaxDeclaration(decl.Id, null, null);
      Test.stopTest();

      PWChrono_Tax_Declaration__c submittedDecl = [
        SELECT Status__c
        FROM PWChrono_Tax_Declaration__c
        WHERE Id = :decl.Id
      ];
      System.assertEquals(
        PWChrono_Constants.STATUS_SUBMITTED,
        submittedDecl.Status__c,
        'Status should be Submitted'
      );
    }
  }

  @isTest
  static void testGetMyTaxDeclarationsNoEmployee() {
    User adminUser = [SELECT Id FROM User WHERE Alias = 'admin' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();
      try {
        PWChrono_TaxController.getMyTaxDeclarations(null, null);
        System.assert(false, 'Should throw exception');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }
}