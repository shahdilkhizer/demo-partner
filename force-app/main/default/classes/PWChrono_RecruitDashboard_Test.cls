/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
private class PWChrono_RecruitDashboard_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      // Portal user (HR Admin)
      Portal_Users__c hrAdmin = new Portal_Users__c(
        Name = 'HR Admin',
        Email__c = 'hr@test.com',
        Role__c = PWChrono_Constants.ROLE_HR_ADMIN
      );
      insert hrAdmin;

      // Department
      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      // Designation
      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Software Engineer',
        Is_Active__c = true
      );
      insert desig;

      // Job Openings
      PWChrono_Job_Opening__c openJob = new PWChrono_Job_Opening__c(
        Name = 'Senior Developer',
        Status__c = 'Open',
        Department__c = dept.Id,
        Designation__c = desig.Id,
        No_of_Positions__c = 2
      );
      insert openJob;

      PWChrono_Job_Opening__c closedJob = new PWChrono_Job_Opening__c(
        Name = 'Junior QA',
        Status__c = 'Closed',
        No_of_Positions__c = 1
      );
      insert closedJob;

      // Job Applicants
      List<PWChrono_Job_Applicant__c> applicants = new List<PWChrono_Job_Applicant__c>{
        new PWChrono_Job_Applicant__c(
          Name = 'Alice',
          Email__c = 'alice@test.com',
          Status__c = 'Applied',
          Source__c = 'Website',
          Job_Opening__c = openJob.Id,
          Offer_Status__c = 'Pending'
        ),
        new PWChrono_Job_Applicant__c(
          Name = 'Bob',
          Email__c = 'bob@test.com',
          Status__c = 'Interview Scheduled',
          Source__c = 'Referral',
          Job_Opening__c = openJob.Id
        ),
        new PWChrono_Job_Applicant__c(
          Name = 'Carol',
          Email__c = 'carol@test.com',
          Status__c = 'Offer Extended',
          Source__c = 'Job Board',
          Offer_Status__c = 'Extended'
        ),
        new PWChrono_Job_Applicant__c(
          Name = 'Dave',
          Email__c = 'dave@test.com',
          Status__c = 'Accepted',
          Source__c = 'Website',
          Offer_Status__c = 'Accepted'
        )
      };
      insert applicants;

      // Job Requisition with Time_to_Fill
      PWChrono_Job_Requisition__c req = new PWChrono_Job_Requisition__c(
        Name = 'Req-001',
        No_of_Positions__c = 1,
        Status__c = 'Open & Approved',
        Time_to_Fill__c = 30
      );
      insert req;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getDashboardData
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetDashboardData_Counts() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(
      2,
      data.totalJobOpenings,
      'Should have 2 total job openings'
    );
    System.assertEquals(
      1,
      data.openJobOpenings,
      'Should have 1 open job opening'
    );
    System.assertEquals(
      1,
      data.closedJobOpenings,
      'Should have 1 closed job opening'
    );
    System.assertEquals(
      4,
      data.totalApplicants,
      'Should have 4 total applicants'
    );
  }

  @isTest
  static void testGetDashboardData_ApplicantsByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      !data.applicantsByStatus.isEmpty(),
      'Applicants by status should not be empty'
    );
  }

  @isTest
  static void testGetDashboardData_ApplicantsBySource() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      !data.applicantsBySource.isEmpty(),
      'Applicants by source should not be empty'
    );
  }

  @isTest
  static void testGetDashboardData_ApplicantsByJobOpening() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      !data.applicantsByJobOpening.isEmpty(),
      'Applicants by job opening should not be empty'
    );
  }

  @isTest
  static void testGetDashboardData_OffersByStatus() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      !data.offersByStatus.isEmpty(),
      'Offers by status should not be empty'
    );
  }

  @isTest
  static void testGetDashboardData_DeptWiseOpenings() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assert(
      !data.deptWiseOpenings.isEmpty(),
      'Dept-wise openings should not be empty'
    );
  }

  @isTest
  static void testGetDashboardData_AvgTimeToFill() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(
      30.0,
      data.avgTimeToFill,
      'Avg time to fill should be 30'
    );
  }

  @isTest
  static void testGetDashboardData_HiringFunnel() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'hr@test.com'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_RecruitmentDashboardController.DashboardData data = PWChrono_RecruitmentDashboardController.getDashboardData(
      hr.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(1, data.funnelApplied, 'Funnel Applied = 1');
    System.assertEquals(1, data.funnelInterview, 'Funnel Interview = 1');
    System.assertEquals(1, data.funnelOffer, 'Funnel Offer = 1');
    System.assertEquals(1, data.funnelAccepted, 'Funnel Accepted = 1');
  }
}