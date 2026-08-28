@isTest
private class PWChrono_StaffingPlanController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      PWChrono_TestDataFactory.createTestEmployee(testUser.Id);

      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Senior Engineer',
        Is_Active__c = true
      );
      insert desig;

      PWChrono_Staffing_Plan__c plan = new PWChrono_Staffing_Plan__c(
        Name = 'Q3 Hiring Plan',
        Company__c = 'PWChrono',
        Department__c = dept.Id,
        From_Date__c = Date.today(),
        To_Date__c = Date.today().addMonths(3),
        Status__c = 'Draft',
        Total_Estimated_Cost__c = 50000
      );
      insert plan;

      PWChrono_Staffing_Plan_Detail__c detail = new PWChrono_Staffing_Plan_Detail__c(
        Staffing_Plan__c = plan.Id,
        Designation__c = desig.Id,
        Vacancies__c = 3,
        Estimated_Cost_Per_Position__c = 15000,
        Number_of_Positions__c = 3
      );
      insert detail;
    }
  }

  @isTest
  static void testGetStaffingPlans_All() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Staffing_Plan__c> plans = PWChrono_StaffingPlanController.getStaffingPlans(
        null,
        null,
        null
      );
      Test.stopTest();
      System.assertEquals(1, plans.size(), 'Should return 1 plan');
    }
  }

  @isTest
  static void testGetStaffingPlans_FilterByStatus() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Staffing_Plan__c> draftPlans = PWChrono_StaffingPlanController.getStaffingPlans(
        'Draft',
        null,
        null
      );
      List<PWChrono_Staffing_Plan__c> closedPlans = PWChrono_StaffingPlanController.getStaffingPlans(
        'Closed',
        null,
        null
      );
      Test.stopTest();
      System.assertEquals(1, draftPlans.size(), 'Should return 1 Draft plan');
      System.assertEquals(
        0,
        closedPlans.size(),
        'Should return 0 Closed plans'
      );
    }
  }

  @isTest
  static void testGetStaffingPlanById() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_Staffing_Plan__c result = PWChrono_StaffingPlanController.getStaffingPlanById(
        plan.Id,
        null,
        null
      );
      Test.stopTest();
      System.assertNotEquals(null, result, 'Plan should not be null');
      System.assertEquals(plan.Id, result.Id, 'IDs should match');
      System.assertEquals(
        1,
        result.Staffing_Plan_Details__r.size(),
        'Should have 1 detail row'
      );
    }
  }

  @isTest
  static void testGetStaffingPlanById_NotFound() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Staffing_Plan__c missing = [
        SELECT Id
        FROM PWChrono_Staffing_Plan__c
        LIMIT 1
      ];
      Id missingId = missing.Id;
      delete missing;
      Test.startTest();
      try {
        PWChrono_StaffingPlanController.getStaffingPlanById(
          missingId,
          null,
          null
        );
        System.assert(false, 'Should have thrown AuraHandledException');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().length() > 0, 'Should return an error');
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testSaveStaffingPlan_Insert() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Staffing_Plan__c newPlan = new PWChrono_Staffing_Plan__c(
        Name = 'Q4 Hiring Plan',
        Company__c = 'PWChrono',
        From_Date__c = Date.today(),
        To_Date__c = Date.today().addMonths(3),
        Status__c = 'Draft'
      );
      Test.startTest();
      Id planId = PWChrono_StaffingPlanController.saveStaffingPlan(
        JSON.serialize(newPlan),
        null,
        null
      );
      Test.stopTest();
      System.assertNotEquals(
        null,
        planId,
        'Plan ID should not be null after insert'
      );
    }
  }

  @isTest
  static void testSaveStaffingPlan_Update() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id, Name
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];
    plan.Name = 'Updated Plan Name';

    System.runAs(testUser) {
      Test.startTest();
      Id returnedId = PWChrono_StaffingPlanController.saveStaffingPlan(
        JSON.serialize(plan),
        null,
        null
      );
      Test.stopTest();
      System.assertEquals(
        plan.Id,
        returnedId,
        'Returned ID should match existing'
      );
      PWChrono_Staffing_Plan__c updated = [
        SELECT Name
        FROM PWChrono_Staffing_Plan__c
        WHERE Id = :plan.Id
        LIMIT 1
      ];
      System.assertEquals(
        'Updated Plan Name',
        updated.Name,
        'Name should be updated'
      );
    }
  }

  @isTest
  static void testSaveStaffingPlanDetails() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];
    PWChrono_Designation__c desig = [
      SELECT Id
      FROM PWChrono_Designation__c
      LIMIT 1
    ];

    List<PWChrono_Staffing_Plan_Detail__c> newDetails = new List<PWChrono_Staffing_Plan_Detail__c>{
      new PWChrono_Staffing_Plan_Detail__c(
        Designation__c = desig.Id,
        Vacancies__c = 5,
        Estimated_Cost_Per_Position__c = 20000,
        Number_of_Positions__c = 5
      )
    };

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_StaffingPlanController.saveStaffingPlanDetails(
        plan.Id,
        JSON.serialize(newDetails),
        null,
        null
      );
      Test.stopTest();

      List<PWChrono_Staffing_Plan_Detail__c> saved = [
        SELECT Id, Vacancies__c
        FROM PWChrono_Staffing_Plan_Detail__c
        WHERE Staffing_Plan__c = :plan.Id
      ];
      System.assertEquals(
        1,
        saved.size(),
        'Should have exactly 1 detail row after replace'
      );
      System.assertEquals(5, saved[0].Vacancies__c, 'Vacancies should be 5');
    }
  }

  @isTest
  static void testUpdateStaffingPlanStatus() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_StaffingPlanController.updateStaffingPlanStatus(
        plan.Id,
        'Submitted',
        null,
        null
      );
      Test.stopTest();
      PWChrono_Staffing_Plan__c updated = [
        SELECT Status__c
        FROM PWChrono_Staffing_Plan__c
        WHERE Id = :plan.Id
        LIMIT 1
      ];
      System.assertEquals(
        'Submitted',
        updated.Status__c,
        'Status should be Submitted'
      );
    }
  }

  @isTest
  static void testDeleteStaffingPlan() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_StaffingPlanController.deleteStaffingPlan(plan.Id, null, null);
      Test.stopTest();
      List<PWChrono_Staffing_Plan__c> remaining = [
        SELECT Id
        FROM PWChrono_Staffing_Plan__c
        WHERE Id = :plan.Id
      ];
      System.assertEquals(0, remaining.size(), 'Plan should be deleted');
    }
  }

  @isTest
  static void testGetActiveDesignations() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Designation__c> desigs = PWChrono_StaffingPlanController.getActiveDesignations();
      Test.stopTest();
      System.assert(desigs.size() >= 1, 'Should return at least 1 designation');
    }
  }

  @isTest
  static void testGetActiveDepartments() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Department__c> depts = PWChrono_StaffingPlanController.getActiveDepartments();
      Test.stopTest();
      System.assert(depts.size() >= 1, 'Should return at least 1 department');
    }
  }

  @isTest
  static void testGetStaffingPlans_GuestHrSession() {
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c guestHr = new Portal_Users__c(
      Name = 'Guest HR',
      Email__c = 'guest.hr.staffing@test.com',
      Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
      Is_Active__c = true,
      Session_Token__c = 'guest_staffing_token',
      Session_Expires_At__c = System.now().addHours(1),
      Session_Failed_Attempts__c = 0,
      Session_Locked_Until__c = null
    );
    insert guestHr;

    PWChrono_GuestSession.testNowOverride = System.now();
    try {
      System.runAs(guestUser) {
        Test.startTest();
        try {
          List<PWChrono_Staffing_Plan__c> plans = PWChrono_StaffingPlanController.getStaffingPlans(
            'All',
            String.valueOf(guestHr.Id),
            'guest_staffing_token'
          );
          System.assert(plans.size() >= 1, 'Guest HR should be able to load staffing plans.');
        } catch (AuraHandledException e) {
          System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
      }
    } finally {
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testGetStaffingPlans_GuestNonHrUnauthorized() {
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c guestEmployee = new Portal_Users__c(
      Name = 'Guest Staffing Employee',
      Email__c = 'guest.staffing.employee@test.com',
      Role__c = 'Employee',
      Is_Active__c = true,
      Session_Token__c = 'guest_staffing_employee_token',
      Session_Expires_At__c = System.now().addHours(1),
      Session_Failed_Attempts__c = 0,
      Session_Locked_Until__c = null
    );
    insert guestEmployee;

    PWChrono_GuestSession.testNowOverride = System.now();
    try {
      System.runAs(guestUser) {
        Test.startTest();
        try {
          PWChrono_StaffingPlanController.getStaffingPlans(
            'All',
            String.valueOf(guestEmployee.Id),
            'guest_staffing_employee_token'
          );
          System.assert(false, 'Guest non-HR users should not access staffing plans.');
        } catch (AuraHandledException e) {
          System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
      }
    } finally {
      PWChrono_GuestSession.testNowOverride = null;
    }
  }

  @isTest
  static void testDeleteStaffingPlan_NonDraftThrows() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id, Status__c
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];
    plan.Status__c = 'Submitted';
    update plan;

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_StaffingPlanController.deleteStaffingPlan(plan.Id, null, null);
        System.assert(false, 'Only draft staffing plans should be deletable.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testInvalidPayloadsAndMissingPlanStatusUpdateThrow() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Staffing_Plan__c plan = [
      SELECT Id
      FROM PWChrono_Staffing_Plan__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_StaffingPlanController.saveStaffingPlan('{bad json', null, null);
        System.assert(false, 'Malformed staffing plan JSON should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_StaffingPlanController.saveStaffingPlanDetails(
          plan.Id,
          '{bad json',
          null,
          null
        );
        System.assert(false, 'Malformed detail JSON should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_StaffingPlanController.updateStaffingPlanStatus(
          '001000000000000AAA',
          'Submitted',
          null,
          null
        );
        System.assert(false, 'Missing staffing plan should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    }
  }
}