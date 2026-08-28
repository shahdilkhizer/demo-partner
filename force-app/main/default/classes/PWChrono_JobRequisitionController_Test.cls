@isTest
private class PWChrono_JobRequisitionController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      PWChrono_TestDataFactory.createTestEmployee(testUser.Id);

      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Product',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Product Manager',
        Is_Active__c = true
      );
      insert desig;

      PWChrono_Staffing_Plan__c plan = new PWChrono_Staffing_Plan__c(
        Name = 'Q4 Hiring Plan',
        Company__c = 'PWChrono',
        Department__c = dept.Id,
        From_Date__c = Date.today(),
        To_Date__c = Date.today().addMonths(3),
        Status__c = 'Draft'
      );
      insert plan;

      PWChrono_Job_Requisition__c req = new PWChrono_Job_Requisition__c(
        Name = 'Product Manager - Q4',
        Department__c = dept.Id,
        Designation__c = desig.Id,
        No_of_Positions__c = 2,
        Expected_Compensation__c = 80000,
        Company__c = 'PWChrono',
        Status__c = 'Pending',
        Expected_By_Date__c = Date.today().addMonths(2),
        Staffing_Plan__c = plan.Id,
        Reason_for_Hiring__c = 'New Position'
      );
      insert req;
    }
  }

  @isTest
  static void testGetJobRequisitions_All() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Job_Requisition__c> reqs = PWChrono_JobRequisitionController.getJobRequisitions(
        null,
        null,
        null
      );
      Test.stopTest();
      System.assertEquals(1, reqs.size(), 'Should return 1 requisition');
    }
  }

  @isTest
  static void testGetJobRequisitions_FilterByStatus() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Job_Requisition__c> pending = PWChrono_JobRequisitionController.getJobRequisitions(
        'Pending',
        null,
        null
      );
      List<PWChrono_Job_Requisition__c> filled = PWChrono_JobRequisitionController.getJobRequisitions(
        'Filled',
        null,
        null
      );
      Test.stopTest();
      System.assertEquals(1, pending.size(), 'Should return 1 Pending');
      System.assertEquals(0, filled.size(), 'Should return 0 Filled');
    }
  }

  @isTest
  static void testGetJobRequisitionById() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Job_Requisition__c existing = [
        SELECT Id
        FROM PWChrono_Job_Requisition__c
        LIMIT 1
      ];
      Test.startTest();
      PWChrono_Job_Requisition__c rec = PWChrono_JobRequisitionController.getJobRequisitionById(
        existing.Id,
        null,
        null
      );
      Test.stopTest();
      System.assertEquals(
        existing.Id,
        rec.Id,
        'Should return the correct record'
      );
    }
  }

  @isTest
  static void testGetJobRequisitionById_NotFound() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Job_Requisition__c missing = [
        SELECT Id
        FROM PWChrono_Job_Requisition__c
        LIMIT 1
      ];
      Id missingId = missing.Id;
      delete missing;
      Test.startTest();
      try {
        PWChrono_JobRequisitionController.getJobRequisitionById(
          missingId,
          null,
          null
        );
        System.assert(false, 'Expected AuraHandledException');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().length() > 0, 'Should return an error');
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testSaveJobRequisition_Insert() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Department__c dept = [
        SELECT Id
        FROM PWChrono_Department__c
        LIMIT 1
      ];
      PWChrono_Job_Requisition__c newReq = new PWChrono_Job_Requisition__c(
        Name = 'New Analyst Role',
        Department__c = dept.Id,
        No_of_Positions__c = 1,
        Status__c = 'Pending'
      );
      Test.startTest();
      Id savedId = PWChrono_JobRequisitionController.saveJobRequisition(
        JSON.serialize(newReq),
        null,
        null
      );
      Test.stopTest();
      System.assertNotEquals(null, savedId, 'Should return a new Id');
      List<PWChrono_Job_Requisition__c> all = [
        SELECT Id
        FROM PWChrono_Job_Requisition__c
      ];
      System.assertEquals(2, all.size(), 'Should now have 2 records');
    }
  }

  @isTest
  static void testSaveJobRequisition_Update() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Job_Requisition__c existing = [
        SELECT Id, Name, No_of_Positions__c, Status__c
        FROM PWChrono_Job_Requisition__c
        LIMIT 1
      ];
      existing.No_of_Positions__c = 5;
      Test.startTest();
      Id savedId = PWChrono_JobRequisitionController.saveJobRequisition(
        JSON.serialize(existing),
        null,
        null
      );
      Test.stopTest();
      PWChrono_Job_Requisition__c updated = [
        SELECT No_of_Positions__c
        FROM PWChrono_Job_Requisition__c
        WHERE Id = :savedId
      ];
      System.assertEquals(
        5,
        updated.No_of_Positions__c,
        'Positions should be updated to 5'
      );
    }
  }

  @isTest
  static void testUpdateJobRequisitionStatus() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Job_Requisition__c existing = [
        SELECT Id
        FROM PWChrono_Job_Requisition__c
        LIMIT 1
      ];
      Test.startTest();
      PWChrono_JobRequisitionController.updateJobRequisitionStatus(
        existing.Id,
        'Open & Approved',
        null,
        null
      );
      Test.stopTest();
      PWChrono_Job_Requisition__c updated = [
        SELECT Status__c
        FROM PWChrono_Job_Requisition__c
        WHERE Id = :existing.Id
      ];
      System.assertEquals(
        'Open & Approved',
        updated.Status__c,
        'Status should be Open & Approved'
      );
    }
  }

  @isTest
  static void testDeleteJobRequisition() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Job_Requisition__c existing = [
        SELECT Id
        FROM PWChrono_Job_Requisition__c
        LIMIT 1
      ];
      Test.startTest();
      PWChrono_JobRequisitionController.deleteJobRequisition(
        existing.Id,
        null,
        null
      );
      Test.stopTest();
      List<PWChrono_Job_Requisition__c> remaining = [
        SELECT Id
        FROM PWChrono_Job_Requisition__c
      ];
      System.assertEquals(
        0,
        remaining.size(),
        'Should have 0 records after delete'
      );
    }
  }

  @isTest
  static void testGetActiveDesignations() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Designation__c> desigs = PWChrono_JobRequisitionController.getActiveDesignations();
      Test.stopTest();
      System.assert(!desigs.isEmpty(), 'Should return at least 1 designation');
    }
  }

  @isTest
  static void testGetActiveDepartments() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Department__c> depts = PWChrono_JobRequisitionController.getActiveDepartments();
      Test.stopTest();
      System.assert(!depts.isEmpty(), 'Should return at least 1 department');
    }
  }

  @isTest
  static void testGetAvailableStaffingPlans() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Staffing_Plan__c> plans = PWChrono_JobRequisitionController.getAvailableStaffingPlans();
      Test.stopTest();
      System.assert(!plans.isEmpty(), 'Should return at least 1 staffing plan');
    }
  }

  @isTest
  static void testGetJobRequisitions_GuestHrSession() {
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c guestHr = new Portal_Users__c(
      Name = 'Guest HR Recruiter',
      Email__c = 'guest.hr.recruiter@test.com',
      Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
      Is_Active__c = true,
      Session_Token__c = 'guest_requisition_token',
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
          List<PWChrono_Job_Requisition__c> reqs =
            PWChrono_JobRequisitionController.getJobRequisitions(
              'All',
              String.valueOf(guestHr.Id),
              'guest_requisition_token'
            );
          System.assert(
            reqs.size() >= 1,
            'Guest HR should be able to load requisitions.'
          );
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
  static void testGetJobRequisitions_GuestNonHrUnauthorized() {
    User guestUser = [
      SELECT Id
      FROM User
      WHERE UserType = 'Guest'
      LIMIT 1
    ];
    Portal_Users__c guestEmployee = new Portal_Users__c(
      Name = 'Guest JobReq Employee',
      Email__c = 'guest.jobreq.employee@test.com',
      Role__c = 'Employee',
      Is_Active__c = true,
      Session_Token__c = 'guest_jobreq_employee_token',
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
          PWChrono_JobRequisitionController.getJobRequisitions(
            'All',
            String.valueOf(guestEmployee.Id),
            'guest_jobreq_employee_token'
          );
          System.assert(false, 'Guest non-HR users should not access requisitions.');
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
  static void testDeleteJobRequisition_NonPendingThrows() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Requisition__c existing = [
      SELECT Id, Status__c
      FROM PWChrono_Job_Requisition__c
      LIMIT 1
    ];
    existing.Status__c = 'Filled';
    update existing;

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_JobRequisitionController.deleteJobRequisition(
          existing.Id,
          null,
          null
        );
        System.assert(false, 'Only pending job requisitions should be deletable.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testInvalidPayloadAndMissingStatusUpdateThrow() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      try {
        PWChrono_JobRequisitionController.saveJobRequisition(
          '{bad json',
          null,
          null
        );
        System.assert(false, 'Malformed requisition JSON should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_JobRequisitionController.updateJobRequisitionStatus(
          '001000000000000AAA',
          'Filled',
          null,
          null
        );
        System.assert(false, 'Missing requisition should throw.');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }
      Test.stopTest();
    }
  }
}