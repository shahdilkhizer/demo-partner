@isTest
private class PWChrono_CareerPortalController_Test {
  @testSetup
  static void setup() {
    PWChrono_TestDataFactory.createTestUsers();

    User testUser = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
    System.runAs(testUser) {
      PWChrono_Department__c dept = new PWChrono_Department__c(
        Name = 'Engineering',
        Is_Active__c = true
      );
      insert dept;

      PWChrono_Designation__c desig = new PWChrono_Designation__c(
        Name = 'Software Engineer',
        Is_Active__c = true
      );
      insert desig;

      // Open job
      PWChrono_Job_Opening__c openJob = new PWChrono_Job_Opening__c(
        Name = 'Senior Software Engineer',
        Department__c = dept.Id,
        Designation__c = desig.Id,
        Status__c = 'Open',
        Company__c = 'PulseWork',
        Employment_Type__c = 'Full Time',
        Location__c = 'Remote',
        No_of_Positions__c = 3,
        Job_Description__c = 'Build amazing features.'
      );
      insert openJob;

      // Closed job (should not appear in results)
      PWChrono_Job_Opening__c closedJob = new PWChrono_Job_Opening__c(
        Name = 'Closed Role',
        Status__c = 'Closed',
        Company__c = 'PulseWork',
        Employment_Type__c = 'Full Time',
        No_of_Positions__c = 1
      );
      insert closedJob;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getOpenJobs
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetOpenJobs_NoFilter() {
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      null,
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'Should return only the Open job');
    System.assertEquals('Senior Software Engineer', results[0].Name);
  }

  @isTest
  static void testGetOpenJobs_KeywordMatch() {
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      'Engineer',
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'Keyword filter should match');
  }

  @isTest
  static void testGetOpenJobs_KeywordNoMatch() {
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      'XYZNotFound',
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(0, results.size(), 'No records should match');
  }

  @isTest
  static void testGetOpenJobs_DepartmentFilter() {
    PWChrono_Department__c dept = [
      SELECT Id
      FROM PWChrono_Department__c
      WHERE Name = 'Engineering'
      LIMIT 1
    ];
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      null,
      dept.Id,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'Department filter should match');
  }

  @isTest
  static void testGetOpenJobs_EmploymentTypeFilter() {
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      null,
      null,
      null,
      'Full Time',
      null
    );
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'Employment type filter should match'
    );
  }

  @isTest
  static void testGetOpenJobs_LocationFilter() {
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      null,
      null,
      null,
      null,
      'Remote'
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'Location filter should match');
  }

  @isTest
  static void testGetOpenJobs_KeywordMatchesDescription() {
    Test.startTest();
    List<PWChrono_Job_Opening__c> results = PWChrono_CareerPortalController.getOpenJobs(
      'amazing',
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(1, results.size(), 'Keyword should also match the job description.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getJobById
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetJobById() {
    PWChrono_Job_Opening__c job = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      WHERE Status__c = 'Open'
      LIMIT 1
    ];
    Test.startTest();
    PWChrono_Job_Opening__c result = PWChrono_CareerPortalController.getJobById(
      job.Id
    );
    Test.stopTest();
    System.assertNotEquals(null, result, 'Should return the job record');
    System.assertEquals('Senior Software Engineer', result.Name);
  }

  @isTest
  static void testGetJobById_NotFound() {
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_CareerPortalController.getJobById('a0B000000000001AAA');
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Should throw when job not found');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // getActiveDepartments
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testGetActiveDepartments() {
    Test.startTest();
    List<PWChrono_Department__c> depts = PWChrono_CareerPortalController.getActiveDepartments();
    Test.stopTest();
    System.assert(
      depts.size() >= 1,
      'Should return at least one active department'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // submitApplication
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void testSubmitApplication() {
    PWChrono_Job_Opening__c job = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      WHERE Status__c = 'Open'
      LIMIT 1
    ];
    Map<String, Object> appMap = new Map<String, Object>{
      'Name' => 'Jane Doe',
      'Email__c' => 'jane.doe@example.com',
      'Phone__c' => '+1-555-0100',
      'Country__c' => 'United States',
      'Job_Opening__c' => job.Id,
      'Source__c' => 'Website',
      'Expected_Salary__c' => 95000,
      'Cover_Letter__c' => 'I am excited to apply.'
    };
    Test.startTest();
    String newId = PWChrono_CareerPortalController.submitApplication(
      JSON.serialize(appMap)
    );
    Test.stopTest();
    System.assertNotEquals(null, newId, 'Should return the new record Id');
    PWChrono_Job_Applicant__c created = [
      SELECT Status__c
      FROM PWChrono_Job_Applicant__c
      WHERE Id = :newId
      LIMIT 1
    ];
    System.assertEquals(
      'Applied',
      created.Status__c,
      'Status should default to Applied'
    );
  }

  @isTest
  static void testSubmitApplication_BlankJson() {
    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_CareerPortalController.submitApplication('');
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Should throw on blank JSON');
  }

  @isTest
  static void testSubmitApplication_DuplicateEmailForJobRejected() {
    PWChrono_Job_Opening__c job = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      WHERE Status__c = 'Open'
      LIMIT 1
    ];
    Map<String, Object> appMap = new Map<String, Object>{
      'Name' => 'Jane Doe',
      'Email__c' => 'duplicate@example.com',
      'Phone__c' => '+1-555-0100',
      'Country__c' => 'United States',
      'Job_Opening__c' => job.Id,
      'Source__c' => 'Website'
    };
    insert new PWChrono_Job_Applicant__c(
      Name = 'Existing Applicant',
      Email__c = 'duplicate@example.com',
      Job_Opening__c = job.Id,
      Status__c = 'Applied'
    );

    Test.startTest();
    Boolean threw = false;
    try {
      PWChrono_CareerPortalController.submitApplication(JSON.serialize(appMap));
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Duplicate applications for the same job should be rejected.');
  }

  @isTest
  static void testSubmitApplication_InvalidEmailRejected() {
    PWChrono_Job_Opening__c job = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      WHERE Status__c = 'Open'
      LIMIT 1
    ];
    Map<String, Object> appMap = new Map<String, Object>{
      'Name' => 'Invalid Email Applicant',
      'Email__c' => 'not-an-email',
      'Phone__c' => '+1-555-0101',
      'Country__c' => 'United States',
      'Job_Opening__c' => job.Id
    };

    Test.startTest();
    try {
      PWChrono_CareerPortalController.submitApplication(JSON.serialize(appMap));
      System.assert(false, 'Invalid email should be rejected.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }
}