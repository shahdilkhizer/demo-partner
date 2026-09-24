@isTest
private class PWChrono_ReportingManagerController_Test {
  @TestSetup
  static void makeData() {
    Portal_User_Profile__c adminProfile = new Portal_User_Profile__c();
    insert adminProfile;
    Portal_User_Profile__c employeeProfile = new Portal_User_Profile__c();
    insert employeeProfile;

    Portal_Object__c portalUserObject = new Portal_Object__c(
      Object_API_Name__c = 'Portal_Users__c'
    );
    insert portalUserObject;
    insert new Portal_Object_Permission__c(
      Portal_User_Profile__c = adminProfile.Id,
      Portal_Object__c = portalUserObject.Id,
      Can_View__c = true,
      Can_Edit__c = true
    );

    Portal_Users__c adminUser = new Portal_Users__c(
      Name = 'Reporting Admin',
      Email__c = 'reporting-admin@example.com',
      Is_Active__c = true,
      Portal_User_Profile__c = adminProfile.Id,
      Session_Token__c = 'reporting_admin_token',
      Session_Expires_At__c = System.now().addHours(1)
    );
    Portal_Users__c manager = new Portal_Users__c(
      Name = 'Reporting Manager',
      Email__c = 'reporting-manager@example.com',
      Role__c = 'Manager',
      Is_Active__c = true,
      Portal_User_Profile__c = employeeProfile.Id
    );
    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Reporting Employee',
      Email__c = 'reporting-employee@example.com',
      Role__c = 'Employee',
      Is_Active__c = true,
      Portal_User_Profile__c = employeeProfile.Id
    );
    Portal_Users__c inactiveManager = new Portal_Users__c(
      Name = 'Inactive Manager',
      Email__c = 'inactive-manager@example.com',
      Is_Active__c = false,
      Portal_User_Profile__c = employeeProfile.Id
    );
    insert new List<Portal_Users__c>{
      adminUser,
      manager,
      employee,
      inactiveManager
    };
  }

  @isTest
  static void testGetReportingOptionsAndSaveUserSetup() {
    Portal_Users__c manager = userByName('Reporting Manager');
    Portal_Users__c employee = userByName('Reporting Employee');
    Id profileId = [
      SELECT Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :employee.Id
    ]
    .Portal_User_Profile__c;

    Test.startTest();
    List<PWChrono_ReportingManagerController.PortalUserOption> options = PWChrono_ReportingManagerController.getReportingOptions(
      null,
      null
    );
    String result = PWChrono_ReportingManagerController.saveUserSetup(
      employee.Id,
      profileId,
      manager.Id,
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(4, options.size());
    System.assertEquals('Success', result);
    System.assertEquals(
      manager.Id,
      [SELECT Reports_To__c FROM Portal_Users__c WHERE Id = :employee.Id]
      .Reports_To__c
    );
  }

  @isTest
  static void testCanClearManager() {
    Portal_Users__c manager = userByName('Reporting Manager');
    Portal_Users__c employee = userByName('Reporting Employee');
    employee.Reports_To__c = manager.Id;
    update employee;

    PWChrono_ReportingManagerController.saveUserSetup(
      employee.Id,
      employee.Portal_User_Profile__c,
      null,
      null,
      null
    );
    System.assertEquals(
      null,
      [SELECT Reports_To__c FROM Portal_Users__c WHERE Id = :employee.Id]
      .Reports_To__c
    );
  }

  @isTest
  static void testCreatePortalUserWithManager() {
    Portal_Users__c manager = userByName('Reporting Manager');
    Id profileId = manager.Portal_User_Profile__c;

    Id newUserId = PWChrono_ReportingManagerController.createPortalUser(
      new Portal_Users__c(
        Name = 'New Managed Employee',
        Email__c = 'new-managed-employee@example.com',
        Is_Active__c = true
      ),
      profileId,
      manager.Id,
      null,
      null
    );
    Portal_Users__c newUser = [
      SELECT Portal_User_Profile__c, Reports_To__c
      FROM Portal_Users__c
      WHERE Id = :newUserId
    ];
    System.assertEquals(profileId, newUser.Portal_User_Profile__c);
    System.assertEquals(manager.Id, newUser.Reports_To__c);
  }

  @isTest
  static void testRejectsSelfInactiveAndCycle() {
    Portal_Users__c manager = userByName('Reporting Manager');
    Portal_Users__c employee = userByName('Reporting Employee');
    Portal_Users__c inactiveManager = userByName('Inactive Manager');
    Id profileId = employee.Portal_User_Profile__c;

    assertRejected(employee.Id, profileId, employee.Id);
    assertRejected(employee.Id, profileId, inactiveManager.Id);

    manager.Reports_To__c = employee.Id;
    update manager;
    assertRejected(employee.Id, profileId, manager.Id);
  }

  @isTest
  static void testGuestAuthorization() {
    Portal_Users__c adminUser = userByName('Reporting Admin');
    User guestUser = [SELECT Id FROM User WHERE UserType = 'Guest' LIMIT 1];

    System.runAs(guestUser) {
      Test.startTest();
      List<PWChrono_ReportingManagerController.PortalUserOption> options = PWChrono_ReportingManagerController.getReportingOptions(
        String.valueOf(adminUser.Id),
        'reporting_admin_token'
      );
      Test.stopTest();
      System.assertEquals(4, options.size());
    }
  }

  private static Portal_Users__c userByName(String name) {
    return [
      SELECT Id, Portal_User_Profile__c, Reports_To__c
      FROM Portal_Users__c
      WHERE Name = :name
      LIMIT 1
    ];
  }

  private static void assertRejected(
    Id targetPortalUserId,
    Id profileId,
    Id managerPortalUserId
  ) {
    try {
      PWChrono_ReportingManagerController.saveUserSetup(
        targetPortalUserId,
        profileId,
        managerPortalUserId,
        null,
        null
      );
      System.assert(false, 'Expected reporting assignment to be rejected.');
    } catch (AuraHandledException expected) {
      System.assertNotEquals(null, expected.getMessage());
    }
  }
}