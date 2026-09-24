@IsTest
private class PWChrono_OpportunityService_Test {
  private static Portal_Users__c caller(String role) {
    Portal_Users__c user = PWChrono_TestDataFactory.createPortalUser(
      'Opportunity reviewer',
      'opportunity-review@example.com',
      role
    );
    user.Session_Token__c = 'opportunity-test-token';
    user.Session_Expires_At__c = System.now().addHours(1);
    update user;
    return user;
  }
  @IsTest
  static void adminCanBrowseEveryPageAndReadDetails() {
    Portal_Users__c admin = caller('HR Admin');
    String stage = [
      SELECT MasterLabel
      FROM OpportunityStage
      WHERE IsActive = TRUE
      LIMIT 1
    ]
    .MasterLabel;
    List<Opportunity> rows = new List<Opportunity>();
    for (Integer i = 0; i < 53; i++)
      rows.add(
        new Opportunity(
          Name = 'Review Opportunity ' + i,
          StageName = stage,
          CloseDate = Date.today().addDays(20),
          Amount = i
        )
      );
    insert rows;
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    Test.startTest();
    PWChrono_OpportunityService.OpportunityPage first = PWChrono_PortalApi.getProjectOpportunities(
      admin.Id,
      'opportunity-test-token',
      null,
      null,
      null
    );
    System.assertEquals(53, first.total);
    System.assertEquals(50, first.records.size());
    System.assert(first.hasMore);
    PWChrono_OpportunityService.OpportunityPage last = PWChrono_PortalApi.getProjectOpportunities(
      admin.Id,
      'opportunity-test-token',
      null,
      null,
      first.records[49].Id
    );
    System.assertEquals(3, last.records.size());
    System.assert(!last.hasMore);
    System.assertNotEquals(first.records[0].Id, last.records[0].Id);
    System.assertEquals(
      rows[0].Name,
      PWChrono_PortalApi.getProjectOpportunity(
          admin.Id,
          'opportunity-test-token',
          rows[0].Id
        )
        .Name
    );
    System.assertEquals(
      0,
      PWChrono_PortalApi.getProjectOpportunities(
          admin.Id,
          'opportunity-test-token',
          'absent-name',
          stage,
          null
        )
        .total
    );
    try {
      PWChrono_PortalApi.getProjectOpportunity(
        admin.Id,
        'opportunity-test-token',
        null
      );
      System.assert(false, 'Missing detail must fail');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    Test.stopTest();
  }
  @IsTest
  static void employeeAndExpiredSessionCannotRead() {
    Portal_Users__c employee = caller('Employee');
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_PortalApi.getProjectOpportunities(
        employee.Id,
        'opportunity-test-token',
        null,
        null,
        null
      );
      System.assert(false, 'Employee must be denied');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    try {
      PWChrono_PortalApi.getProjectOpportunity(
        employee.Id,
        'opportunity-test-token',
        null
      );
      System.assert(false, 'Direct detail must be denied');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    try {
      PWChrono_PortalApi.getProjectOpportunities(
        employee.Id,
        'wrong-token',
        null,
        null,
        null
      );
      System.assert(false, 'Invalid session must be denied');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
    employee.Session_Expires_At__c = System.now().addHours(-1);
    update employee;
    try {
      PWChrono_PortalApi.getProjectOpportunities(
        employee.Id,
        'opportunity-test-token',
        null,
        null,
        null
      );
      System.assert(false, 'Expired session must be denied');
    } catch (AuraHandledException expected) {
      System.assert(true);
    }
  }
}