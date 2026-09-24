@IsTest
private with sharing class PWChrono_PortalApi_Test {
  @IsTest
  static void rejectsUnverifiedGuestBeforeAnyRead() {
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_PortalApi.getAdminDashboardStats(null, null);
      System.assert(
        false,
        'Guest must prove a session before entering the data boundary'
      );
    } catch (AuraHandledException expected) {
      System.assert(expected.getMessage().contains('Session'));
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }
  @IsTest
  static void employeeCannotUseAdministratorEndpoint() {
    Portal_Users__c employee = PWChrono_TestDataFactory.createPortalUser(
      'Portal API employee',
      'api-employee@example.com',
      'Employee'
    );
    employee.Session_Token__c = 'portal-api-test-token';
    employee.Session_Expires_At__c = System.now().addHours(1);
    update employee;
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_PortalApi.getAdminDashboardStats(
        employee.Id,
        'portal-api-test-token'
      );
      System.assert(
        false,
        'A valid session does not grant administrator access'
      );
    } catch (AuraHandledException expected) {
      System.assert(expected.getMessage().contains('Access denied'));
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }
  @IsTest
  static void rejectsUnverifiedGuestBeforeWrite() {
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_PortalApi.saveProject(
        new Map<String, Object>{ 'Name' => 'Should not be written' },
        null,
        null
      );
      System.assert(false, 'Guest writes require session proof');
    } catch (AuraHandledException expected) {
      System.assertEquals(
        0,
        [
          SELECT COUNT()
          FROM PWChrono_Project__c
          WHERE Name = 'Should not be written'
        ]
      );
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }
  @IsTest
  static void verifiedAdminReadsPrivateDataFromSharingCaller() {
    Portal_Users__c admin = PWChrono_TestDataFactory.createPortalUser(
      'Portal API administrator',
      'api-admin@example.com',
      'HR Admin'
    );
    admin.Session_Token__c = 'verified-admin-token';
    admin.Session_Expires_At__c = System.now().addHours(1);
    update admin;
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    Test.startTest();
    PWChrono_AdminController.AdminDashboardDTO result = PWChrono_PortalApi.getAdminDashboardStats(
      admin.Id,
      'verified-admin-token'
    );
    Test.stopTest();
    System.assertEquals(
      1,
      result.totalEmployees,
      'Verified admin receives actual employee data'
    );
    PWChrono_GuestSession.testUserTypeOverride = null;
  }

  @IsTest
  static void verifiedPayrollAdminReadsWorkspaceAcrossGuestSharingBoundary() {
    Portal_User_Profile__c profile = new Portal_User_Profile__c();
    insert profile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = profile.Id,
      Feature_Key__c = 'Payroll',
      Feature_Label__c = 'Payroll',
      Is_Enabled__c = true
    );
    Portal_Users__c admin = PWChrono_TestDataFactory.createPortalUser(
      'Portal API payroll administrator',
      'api-payroll-admin@example.com',
      'HR Admin'
    );
    admin.Portal_User_Profile__c = profile.Id;
    admin.Session_Token__c = 'verified-payroll-admin-token';
    admin.Session_Expires_At__c = System.now().addHours(1);
    update admin;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    PWChrono_PayrollController.testUserTypeOverride = 'Guest';
    try {
      Date period = Date.newInstance(
        Date.today().year(),
        Date.today().month(),
        1
      );
      Test.startTest();
      PWChrono_PayrollRunService.PayrollWorkspaceDTO workspace = PWChrono_PortalApi.getPayrollWorkspace(
        period,
        admin.Id,
        'verified-payroll-admin-token'
      );
      PWChrono_PayrollRunService.PayrollMutationResult salaryResult = PWChrono_PortalApi.saveSalaryAssignment(
        admin.Contact__c,
        5000,
        period,
        admin.Id,
        'verified-payroll-admin-token'
      );
      PWChrono_PayrollRunService.PayrollMutationResult draftResult = PWChrono_PortalApi.generatePayrollDrafts(
        period,
        admin.Id,
        'verified-payroll-admin-token'
      );
      PWChrono_PayrollRunService.PayrollMutationResult submitResult = PWChrono_PortalApi.submitPayroll(
        period,
        admin.Id,
        'verified-payroll-admin-token'
      );
      PWChrono_PayrollRunService.PayrollMutationResult paidResult = PWChrono_PortalApi.markPayrollPaid(
        period,
        period.addMonths(1),
        'Bank Transfer',
        admin.Id,
        'verified-payroll-admin-token'
      );
      List<Contact> ownContacts = PWChrono_PortalApi.getEmployeesForDropdown(
        admin.Id,
        'verified-payroll-admin-token'
      );
      List<PWChrono_Salary_Slip__c> ownSlips = PWChrono_PortalApi.getMySalarySlips(
        period.year(),
        period.month(),
        null,
        admin.Id,
        'verified-payroll-admin-token'
      );
      Map<String, Object> ownDetail = PWChrono_PortalApi.getSalarySlipDetails(
        ownSlips[0].Id,
        null,
        admin.Id,
        'verified-payroll-admin-token'
      );
      System.assertEquals(admin.Contact__c, ownContacts[0].Id);
      System.assertEquals(1, ownSlips.size());
      System.assertNotEquals(null, ownDetail.get('salarySlip'));
      Test.stopTest();

      System.assertEquals(1, workspace.activeEmployeeCount);
      System.assertEquals(0, workspace.readyEmployeeCount);
      System.assertEquals(false, workspace.configurationComplete);
      System.assertEquals(1, salaryResult.createdCount);
      System.assertEquals(1, draftResult.createdCount);
      System.assertEquals(1, submitResult.updatedCount);
      System.assertEquals(1, paidResult.updatedCount);
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_PayrollController.testUserTypeOverride = null;
    }
  }

  private static Portal_Users__c createSessionUser(
    String name,
    String email,
    String role,
    String token
  ) {
    Portal_Users__c portalUser = PWChrono_TestDataFactory.createPortalUser(
      name,
      email,
      role
    );
    portalUser.Session_Token__c = token;
    portalUser.Session_Expires_At__c = System.now().addHours(1);
    update portalUser;
    return portalUser;
  }

  @IsTest
  static void verifiedAdminManagesAdminSettingsThroughPortalApi() {
    Portal_Users__c admin = createSessionUser(
      'Settings administrator',
      'settings-admin@example.com',
      'HR Admin',
      'settings-admin-token'
    );
    Portal_Users__c employee = createSessionUser(
      'Settings employee',
      'settings-employee@example.com',
      'Employee',
      'settings-employee-token'
    );
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      PWChrono_Feature_Settings__c settings = PWChrono_PortalApi.getFeatureSettings(
        admin.Id,
        'settings-admin-token'
      );
      System.assertNotEquals(null, settings, 'Admin reads feature settings');
      PWChrono_Feature_Settings__c saved = PWChrono_PortalApi.saveFeatureSettings(
        settings,
        admin.Id,
        'settings-admin-token'
      );
      System.assertNotEquals(null, saved.Id, 'Feature settings are saved');
      PWChrono_PortalApi.getGlobalSettings(admin.Id, 'settings-admin-token');
      List<Portal_Users__c> found = PWChrono_PortalApi.searchPortalUsers(
        'Settings employee',
        admin.Id,
        'settings-admin-token'
      );
      System.assertEquals(1, found.size(), 'Admin searches portal users');
      PWChrono_PortalApi.updatePortalUserAccess(
        employee.Id,
        'Manager',
        new List<String>(),
        admin.Id,
        'settings-admin-token'
      );
      Test.stopTest();
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
    System.assertEquals(
      'Manager',
      [SELECT Role__c FROM Portal_Users__c WHERE Id = :employee.Id].Role__c,
      'Admin updates another user\'s role'
    );
  }

  @IsTest
  static void employeeCannotUseAdminSettingsThroughPortalApi() {
    Portal_Users__c employee = createSessionUser(
      'Settings denied employee',
      'settings-denied@example.com',
      'Employee',
      'settings-denied-token'
    );
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_PortalApi.getFeatureSettings(
        employee.Id,
        'settings-denied-token'
      );
      System.assert(false, 'Employees must not read Admin Settings');
    } catch (AuraHandledException expected) {
      System.assert(expected.getMessage().contains('Access denied'));
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  @IsTest
  static void rejectsUnverifiedGuestForAdminSettingsWrite() {
    Portal_Users__c employee = createSessionUser(
      'Settings target',
      'settings-target@example.com',
      'Employee',
      'settings-target-token'
    );
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      PWChrono_PortalApi.updatePortalUserAccess(
        employee.Id,
        'HR Admin',
        new List<String>(),
        null,
        null
      );
      System.assert(false, 'Role changes require session proof');
    } catch (AuraHandledException expected) {
      System.assert(expected.getMessage().contains('Session'));
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
    System.assertEquals(
      'Employee',
      [SELECT Role__c FROM Portal_Users__c WHERE Id = :employee.Id].Role__c,
      'Unverified callers cannot escalate a role'
    );
  }
}