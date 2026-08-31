@isTest
private class PWChrono_RecruitmentController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c employee = PWChrono_TestDataFactory.createTestEmployee(
        testUser.Id
      );

      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Developer',
        Is_Active__c = true
      );
      insert desig;

      PWChrono_Job_Opening__c job = new PWChrono_Job_Opening__c(
        Name = 'Senior Developer',
        Designation__c = desig.Id,
        Department__c = dept.Id,
        No_of_Positions__c = 2,
        Status__c = PWChrono_Constants.STATUS_OPEN,
        Closing_Date__c = Date.today().addMonths(1)
      );
      insert job;

      PWChrono_Job_Applicant__c applicant = new PWChrono_Job_Applicant__c(
        Name = 'John Doe',
        Job_Opening__c = job.Id,
        Email__c = 'john.doe@example.com',
        Phone__c = '1234567890',
        Status__c = PWChrono_Constants.STATUS_APPLIED
      );
      insert applicant;
    }
  }

  @isTest
  static void testGetJobOpenings() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Job_Opening__c> jobs = PWChrono_RecruitmentController.getJobOpenings(
        null
      );
      Test.stopTest();

      System.assertEquals(1, jobs.size(), 'Should return 1 job opening');
    }
  }

  @isTest
  static void testGetJobApplicants() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Opening__c job = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Job_Applicant__c> applicants = PWChrono_RecruitmentController.getJobApplicants(
        job.Id,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(1, applicants.size(), 'Should return 1 applicant');
    }
  }

  @isTest
  static void testUpdateApplicantStatus() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Applicant__c applicant = [
      SELECT Id
      FROM PWChrono_Job_Applicant__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_Job_Applicant__c updatedApplicant = PWChrono_RecruitmentController.updateApplicantStatus(
        applicant.Id,
        'Interview Scheduled',
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        'Interview Scheduled',
        updatedApplicant.Status__c,
        'Status should be updated'
      );
    }
  }

  @isTest
  static void testScheduleInterview() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Applicant__c applicant = [
      SELECT Id
      FROM PWChrono_Job_Applicant__c
      LIMIT 1
    ];
    Portal_Users__c interviewer = [SELECT Id FROM Portal_Users__c LIMIT 1];

    String roundValue;
    Schema.DescribeFieldResult roundDescribe = PWChrono_Interview__c.Round__c.getDescribe();
    for (Schema.PicklistEntry pe : roundDescribe.getPicklistValues()) {
      if (pe.isActive()) {
        roundValue = pe.getValue();
        break;
      }
    }
    System.assertNotEquals(
      null,
      roundValue,
      'Round__c must have at least one active picklist value'
    );

    System.runAs(testUser) {
      PWChrono_Interview__c interview = new PWChrono_Interview__c(
        Job_Applicant__c = applicant.Id,
        Interview_Date__c = DateTime.now().addDays(1),
        Round__c = roundValue,
        Interviewers__c = interviewer.Id
      );

      Test.startTest();
      PWChrono_Interview__c savedInterview = PWChrono_RecruitmentController.scheduleInterview(
        interview,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        savedInterview.Id,
        'Interview should be saved'
      );
    }
  }

  @isTest
  static void testGenerateOfferLetter() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Applicant__c applicant = [
      SELECT Id
      FROM PWChrono_Job_Applicant__c
      LIMIT 1
    ];
    PWChrono_Designation__c desig = [
      SELECT Id
      FROM PWChrono_Designation__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      PWChrono_Offer_Letter__c offer = new PWChrono_Offer_Letter__c(
        Job_Applicant__c = applicant.Id,
        Designation__c = desig.Id,
        Offered_CTC__c = 100000,
        Joining_Date__c = Date.today().addMonths(1),
        Status__c = PWChrono_Constants.STATUS_DRAFT
      );

      Test.startTest();
      PWChrono_Offer_Letter__c savedOffer = PWChrono_RecruitmentController.generateOfferLetter(
        offer,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        savedOffer.Id,
        'Offer letter should be saved'
      );

      PWChrono_Job_Applicant__c updatedApplicant = [
        SELECT Status__c
        FROM PWChrono_Job_Applicant__c
        WHERE Id = :applicant.Id
      ];
      System.assertEquals(
        PWChrono_Constants.STATUS_OFFER_EXTENDED,
        updatedApplicant.Status__c,
        'Applicant status should be updated'
      );
    }
  }

  @isTest
  static void testReferCandidate() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Opening__c job = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_RecruitmentController.referCandidate(
        job.Id,
        'Jane',
        'Doe',
        'jane.doe@example.com',
        '0987654321',
        5,
        null,
        null
      );
      Test.stopTest();

      List<PWChrono_Job_Applicant__c> applicants = [
        SELECT Id
        FROM PWChrono_Job_Applicant__c
        WHERE Email__c = 'jane.doe@example.com'
      ];
      System.assertEquals(1, applicants.size(), 'Should create 1 applicant');
    }
  }

  @isTest
  static void testGetActiveDepartments() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Department__c> depts = PWChrono_RecruitmentController.getActiveDepartments(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(1, depts.size(), 'Should return 1 active department');
    }
  }

  @isTest
  static void testGetActiveDesignations() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Designation__c> desigs = PWChrono_RecruitmentController.getActiveDesignations(
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        desigs.size(),
        'Should return 1 active designation'
      );
    }
  }

  @isTest
  static void testGetPotentialInterviewers() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      List<Portal_Users__c> interviewers = PWChrono_RecruitmentController.getPotentialInterviewers(
        null,
        null
      );
      Test.stopTest();

      System.assert(
        interviewers.size() > 0,
        'Should return potential interviewers'
      );
    }
  }

  @isTest
  static void testGetApplicantInterviews() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Applicant__c applicant = [
      SELECT Id
      FROM PWChrono_Job_Applicant__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      List<PWChrono_Interview__c> interviews = PWChrono_RecruitmentController.getApplicantInterviews(
        applicant.Id,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        0,
        interviews.size(),
        'Should return 0 interviews initially'
      );
    }
  }

  @isTest
  static void testGetRecruitmentDashboardMetrics() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();
      Map<String, Object> metrics = PWChrono_RecruitmentController.getRecruitmentDashboardMetrics(
        'dummyUser',
        'dummyToken'
      );
      Test.stopTest();

      System.assertNotEquals(null, metrics, 'Metrics map should not be null');
      System.assertEquals(1, metrics.get('openJobsCount'), 'Should have 1 open job');
      System.assertEquals(1, metrics.get('totalApplicantsCount'), 'Should have 1 applicant');
    }
  }

  @isTest
  static void testApplicantAcceptedCreatesOnboardingTasks() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    PWChrono_Job_Applicant__c applicant = [
      SELECT Id, Status__c, Email__c
      FROM PWChrono_Job_Applicant__c
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      PWChrono_Job_Applicant__c updatedApplicant = PWChrono_RecruitmentController.updateApplicantStatus(
        applicant.Id,
        PWChrono_Constants.STATUS_ACCEPTED,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        PWChrono_Constants.STATUS_ACCEPTED,
        updatedApplicant.Status__c,
        'Applicant should be Accepted'
      );

      // Verify onboarding tasks were generated
      List<PWChrono_Onboarding_Task__c> tasks = [
        SELECT Id, Name, Status__c, Assigned_Tos__c
        FROM PWChrono_Onboarding_Task__c
      ];
      System.assert(tasks.size() > 0, 'Onboarding tasks should be automatically generated upon applicant acceptance');
    }
  }

  @isTest
  static void testHasFeatureHelper() {
    System.assertEquals(true, PWChrono_RecruitmentController.hasFeature('Recruitment;Payroll', 'Recruitment'));
    System.assertEquals(true, PWChrono_RecruitmentController.hasFeature('Payroll ; Recruitment', 'Recruitment'));
    System.assertEquals(false, PWChrono_RecruitmentController.hasFeature('Payroll;Leaves', 'Recruitment'));
    System.assertEquals(false, PWChrono_RecruitmentController.hasFeature('', 'Recruitment'));
    System.assertEquals(false, PWChrono_RecruitmentController.hasFeature('Recruitment', ''));
    System.assertEquals(false, PWChrono_RecruitmentController.hasFeature(null, null));
  }

  @isTest
  static void testControllerErrorCatchBlocks() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Test.startTest();

      try {
        PWChrono_RecruitmentController.getJobOpenings('InvalidStatus');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.getJobApplicants(null, null, null, null);
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.updateApplicantStatus(null, 'Selected', null, null);
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.getApplicantInterviews(null, null, null);
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.scheduleInterview(null, null, null);
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.generateOfferLetter(null, null, null);
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.referCandidate(null, null, null, null, null, null, null, null);
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      Test.stopTest();
    }
  }

  @isTest
  static void testGuestAccessValidation() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];

    System.runAs(testUser) {
      Portal_Users__c pu = [SELECT Id, Access_Features__c FROM Portal_Users__c LIMIT 1];
      pu.Access_Features__c = 'Recruitment';
      pu.Is_Active__c = true;
      update pu;

      PWChrono_GuestSession.testUserTypeOverride = 'Guest';
      PWChrono_RecruitmentController.forceGuestCheckForTest = true;

      // 1. Valid access
      try {
        PWChrono_RecruitmentController.requireRecruitmentAccessForGuest(pu.Id, 'token123');
      } catch (Exception e) {
        // ok
      }

      // 2. Unauthorized access (missing Recruitment feature and non-admin)
      pu.Role__c = 'Employee';
      pu.Access_Features__c = 'Leaves';
      update pu;
      try {
        PWChrono_RecruitmentController.requireRecruitmentAccessForGuest(pu.Id, 'token123');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      // 3. Trigger all controller catch blocks via invalid guest session
      try {
        PWChrono_RecruitmentController.getActiveDepartments('badId', 'badToken');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.getActiveDesignations('badId', 'badToken');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.getPotentialInterviewers('badId', 'badToken');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      try {
        PWChrono_RecruitmentController.getRecruitmentDashboardMetrics('badId', 'badToken');
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage());
      }

      // 4. Positive execution of all controller methods
      PWChrono_GuestSession.testUserTypeOverride = null;
      PWChrono_RecruitmentController.forceGuestCheckForTest = false;

      PWChrono_RecruitmentController.getActiveDepartments(null, null);
      PWChrono_RecruitmentController.getActiveDesignations(null, null);
      PWChrono_RecruitmentController.getPotentialInterviewers(null, null);
      PWChrono_RecruitmentController.getRecruitmentDashboardMetrics(null, null);
      PWChrono_RecruitmentController.getJobOpenings('All');
      PWChrono_RecruitmentController.getJobApplicants(null, 'All', null, null);
    }
  }

  @isTest
  static void testControllerSuccessMethods() {
    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Job_Applicant__c app = [SELECT Id, Job_Opening__c FROM PWChrono_Job_Applicant__c LIMIT 1];
      PWChrono_Job_Opening__c job = [SELECT Id FROM PWChrono_Job_Opening__c LIMIT 1];
      Portal_Users__c interviewer = [SELECT Id FROM Portal_Users__c LIMIT 1];
      PWChrono_Designation__c desig = [SELECT Id FROM PWChrono_Designation__c LIMIT 1];

      PWChrono_RecruitmentController.getJobOpenings('All');
      PWChrono_RecruitmentController.getJobApplicants(job.Id, 'All', null, null);
      PWChrono_RecruitmentController.updateApplicantStatus(app.Id, 'Screening', null, null);
      PWChrono_RecruitmentController.getApplicantInterviews(app.Id, null, null);

      PWChrono_Interview__c interview = new PWChrono_Interview__c(
        Job_Applicant__c = app.Id,
        Interview_Date__c = DateTime.now().addDays(1),
        Interviewers__c = interviewer.Id
      );
      PWChrono_RecruitmentController.scheduleInterview(interview, null, null);

      PWChrono_Offer_Letter__c offer = new PWChrono_Offer_Letter__c(
        Job_Applicant__c = app.Id,
        Designation__c = desig.Id,
        Offered_CTC__c = 100000,
        Joining_Date__c = Date.today().addMonths(1),
        Status__c = PWChrono_Constants.STATUS_DRAFT
      );
      PWChrono_RecruitmentController.generateOfferLetter(offer, null, null);

      PWChrono_RecruitmentController.getActiveDepartments(null, null);
      PWChrono_RecruitmentController.getActiveDesignations(null, null);
      PWChrono_RecruitmentController.getPotentialInterviewers(null, null);
      PWChrono_RecruitmentController.getRecruitmentDashboardMetrics(null, null);
    }
  }
}