@isTest
private class PWChrono_ProbationController_Test {
  private static final String ADMIN_EMAIL = 'probation.admin@test.com';
  private static final String HR_MANAGER_EMAIL = 'probation.hrmanager@test.com';
  private static final String MANAGER_EMAIL = 'probation.manager@test.com';
  private static final String EMPLOYEE_EMAIL = 'probation.employee@test.com';
  private static final String CONTACT_EMPLOYEE_EMAIL = 'probation.contact@test.com';
  private static final String INACTIVE_EMAIL = 'probation.inactive@test.com';
  private static final String NO_PROFILE_EMAIL = 'probation.noprofile@test.com';
  private static final String GUEST_TOKEN = 'probation-guest-token';

  @testSetup
  static void setup() {
    Portal_User_Profile__c hrProfile = new Portal_User_Profile__c(
      Profile_Type__c = 'HR Manager',
      Is_Active__c = true
    );
    insert hrProfile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = hrProfile.Id,
      Feature_Key__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Feature_Label__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Is_Enabled__c = true
    );

    Contact financeContact = new Contact(
      LastName = 'Contact Employee',
      Department = 'Finance'
    );
    insert financeContact;

    Portal_Users__c admin = new Portal_Users__c(
      Name = 'Probation Admin',
      Email__c = ADMIN_EMAIL,
      Role__c = 'HR Admin',
      Is_Active__c = true,
      Session_Token__c = GUEST_TOKEN,
      Session_Expires_At__c = System.now().addHours(1)
    );
    Portal_Users__c hrManager = new Portal_Users__c(
      Name = 'Probation HR Manager',
      Email__c = HR_MANAGER_EMAIL,
      Role__c = 'HR Manager',
      Is_Active__c = true,
      Portal_User_Profile__c = hrProfile.Id
    );
    Portal_Users__c manager = new Portal_Users__c(
      Name = 'Probation Manager',
      Email__c = MANAGER_EMAIL,
      Role__c = 'Manager',
      Is_Active__c = true,
      Photo_Url__c = 'https://example.com/manager.png'
    );
    Portal_Users__c inactive = new Portal_Users__c(
      Name = 'Probation Inactive',
      Email__c = INACTIVE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = false
    );
    Portal_Users__c noProfile = new Portal_Users__c(
      Name = 'Probation No Profile',
      Email__c = NO_PROFILE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true
    );
    insert new List<Portal_Users__c>{
      admin,
      hrManager,
      manager,
      inactive,
      noProfile
    };

    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Alice Probationer',
      Email__c = EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true,
      Designation__c = 'Software Engineer',
      Department__c = 'Engineering',
      Date_of_Joining__c = Date.today().addDays(-10),
      Photo_Url__c = 'https://example.com/alice.png',
      Reports_To__c = manager.Id
    );
    Portal_Users__c contactEmployee = new Portal_Users__c(
      Name = 'Bob Contact',
      Email__c = CONTACT_EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true,
      Designation__c = 'Accountant',
      Contact__c = financeContact.Id
    );
    insert new List<Portal_Users__c>{ employee, contactEmployee };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private static Id idFor(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  private static String adminId() {
    return String.valueOf(idFor(ADMIN_EMAIL));
  }

  private static PWChrono_Probation__c insertProbation(
    String employeeEmail,
    String status,
    Date endDate
  ) {
    PWChrono_Probation__c probation = new PWChrono_Probation__c(
      Employee__c = idFor(employeeEmail),
      Start_Date__c = Date.today().addDays(-30),
      End_Date__c = endDate,
      Status__c = status
    );
    insert probation;
    return probation;
  }

  private static PWChrono_Probation__c reload(Id probationId) {
    return [
      SELECT
        Id,
        Status__c,
        Start_Date__c,
        End_Date__c,
        Original_End_Date__c,
        Confirmation_Date__c,
        Reviewer__c,
        Review_Notes__c
      FROM PWChrono_Probation__c
      WHERE Id = :probationId
    ];
  }

  /** Version the client would hold for an open record, as getProbations returns it. */
  private static String currentVersion(String probationId) {
    if (String.isBlank(probationId)) {
      return null;
    }
    Id target = Id.valueOf(probationId);
    for (
      PWChrono_ProbationController.ProbationRecord row : PWChrono_ProbationController.getProbations(
        adminId(),
        null
      )
    ) {
      if (row.id == target) {
        return row.recordVersion;
      }
    }
    return null;
  }

  private static String saveError(
    String probationId,
    String employeeId,
    Date startDate,
    Date endDate,
    String reviewerId
  ) {
    return saveErrorAs(
      adminId(),
      probationId,
      employeeId,
      startDate,
      endDate,
      reviewerId,
      null,
      currentVersion(probationId)
    );
  }

  private static String saveErrorAs(
    String actorId,
    String probationId,
    String employeeId,
    Date startDate,
    Date endDate,
    String reviewerId,
    String notes,
    String recordVersion
  ) {
    try {
      PWChrono_ProbationController.saveProbation(
        probationId,
        employeeId,
        startDate,
        endDate,
        reviewerId,
        notes,
        recordVersion,
        actorId,
        null
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    return null;
  }

  private static String statusError(
    Id probationId,
    String newStatus,
    Date newEndDate,
    String actorId
  ) {
    try {
      PWChrono_ProbationController.updateProbationStatus(
        probationId,
        newStatus,
        newEndDate,
        null,
        actorId,
        null
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    return null;
  }

  private static void assertContains(String actual, String expected) {
    Assert.isNotNull(actual, 'Expected an error containing: ' + expected);
    Assert.isTrue(
      actual.contains(expected),
      'Expected "' + expected + '" in "' + actual + '"'
    );
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  @isTest
  static void createDefaultsReviewerToManagerAndReturnsDto() {
    Id employeeId = idFor(EMPLOYEE_EMAIL);
    Date startDate = Date.today().addDays(-10);
    Date endDate = Date.today().addDays(80);

    Test.startTest();
    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      null,
      employeeId,
      startDate,
      endDate,
      '',
      '  First month went well.  ',
      null,
      adminId(),
      null
    );
    Test.stopTest();

    Assert.isNotNull(row.id);
    Assert.isTrue(row.probationNumber.startsWith('PROB-'));
    Assert.areEqual(employeeId, row.employeeId);
    Assert.areEqual('Alice Probationer', row.employeeName);
    Assert.areEqual('Software Engineer', row.designation);
    Assert.areEqual('Engineering', row.department);
    Assert.areEqual('https://example.com/alice.png', row.photoUrl);
    Assert.areEqual(Date.today().addDays(-10), row.dateOfJoining);
    Assert.areEqual(idFor(MANAGER_EMAIL), row.reviewerId);
    Assert.areEqual('Probation Manager', row.reviewerName);
    Assert.areEqual('https://example.com/manager.png', row.reviewerPhotoUrl);
    Assert.areEqual(PWChrono_ProbationController.STATUS_PENDING, row.status);
    Assert.areEqual(startDate, row.startDate);
    Assert.areEqual(endDate, row.endDate);
    Assert.isNull(row.originalEndDate);
    Assert.isNull(row.confirmationDate);
    Assert.areEqual('First month went well.', row.notes);
    Assert.areEqual(80, row.daysRemaining);
  }

  @isTest
  static void createWithoutManagerLeavesReviewerBlank() {
    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      null,
      idFor(CONTACT_EMPLOYEE_EMAIL),
      Date.today(),
      Date.today().addDays(90),
      null,
      null,
      null,
      adminId(),
      null
    );

    Assert.isNull(row.reviewerId);
    Assert.isNull(row.reviewerName);
    Assert.isNull(row.photoUrl, 'Blank photo should be returned as null');
    Assert.areEqual(
      'Finance',
      row.department,
      'Department falls back to the linked Contact'
    );
  }

  @isTest
  static void createRejectsDuplicateOpenProbation() {
    PWChrono_Probation__c existing = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_EXTENDED,
      Date.today().addDays(5)
    );
    String existingNumber = [
      SELECT Name
      FROM PWChrono_Probation__c
      WHERE Id = :existing.Id
    ]
    .Name;

    String error = saveError(
      null,
      idFor(EMPLOYEE_EMAIL),
      Date.today(),
      Date.today().addDays(30),
      null
    );

    assertContains(error, 'already has an open probation');
    assertContains(error, existingNumber);
  }

  @isTest
  static void createAllowedAfterPreviousProbationClosed() {
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_FAILED,
      Date.today().addDays(-5)
    );

    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      null,
      idFor(EMPLOYEE_EMAIL),
      Date.today(),
      Date.today().addDays(30),
      null,
      null,
      null,
      adminId(),
      null
    );

    Assert.areEqual(PWChrono_ProbationController.STATUS_PENDING, row.status);
  }

  @isTest
  static void createValidatesEmployeeAndDates() {
    String employeeId = String.valueOf(idFor(EMPLOYEE_EMAIL));

    assertContains(
      saveError(null, null, Date.today(), Date.today(), null),
      'Select an employee'
    );
    assertContains(
      saveError(null, 'not-an-id', Date.today(), Date.today(), null),
      'The selected employee is not valid'
    );
    assertContains(
      saveError(
        null,
        idFor(INACTIVE_EMAIL),
        Date.today(),
        Date.today().addDays(10),
        null
      ),
      'active employee'
    );
    assertContains(
      saveError(null, employeeId, null, Date.today(), null),
      'start and end dates are required'
    );
    assertContains(
      saveError(null, employeeId, Date.today(), null, null),
      'start and end dates are required'
    );
    assertContains(
      saveError(null, employeeId, Date.today(), Date.today().addDays(-1), null),
      'cannot be before the start date'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM PWChrono_Probation__c],
      'Invalid input must not create records'
    );
  }

  @isTest
  static void createEnforcesReviewerRules() {
    Id employeeId = idFor(EMPLOYEE_EMAIL);

    assertContains(
      saveError(
        null,
        employeeId,
        Date.today(),
        Date.today().addDays(30),
        employeeId
      ),
      'cannot review their own probation'
    );
    assertContains(
      saveError(
        null,
        employeeId,
        Date.today(),
        Date.today().addDays(30),
        idFor(INACTIVE_EMAIL)
      ),
      'reviewer must be an active employee'
    );

    Id hrManagerId = idFor(HR_MANAGER_EMAIL);
    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      null,
      employeeId,
      Date.today(),
      Date.today().addDays(30),
      hrManagerId,
      null,
      null,
      adminId(),
      null
    );
    Assert.areEqual(
      hrManagerId,
      row.reviewerId,
      'An explicit reviewer overrides the manager default'
    );
  }

  @isTest
  static void createRejectsOverlongNotes() {
    try {
      PWChrono_ProbationController.saveProbation(
        null,
        idFor(EMPLOYEE_EMAIL),
        Date.today(),
        Date.today().addDays(30),
        null,
        'x'.repeat(5001),
        null,
        adminId(),
        null
      );
      Assert.fail('Expected notes length validation');
    } catch (AuraHandledException e) {
      assertContains(e.getMessage(), 'Notes cannot be longer than 5000');
    }
  }

  // ---------------------------------------------------------------------------
  // Edit
  // ---------------------------------------------------------------------------

  @isTest
  static void editChangesDatesReviewerNotesAndKeepsOriginalEndDate() {
    Date firstEnd = Date.today().addDays(20);
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      firstEnd
    );
    Id employeeId = idFor(EMPLOYEE_EMAIL);
    Id hrManagerId = idFor(HR_MANAGER_EMAIL);

    String version = currentVersion(probation.Id);

    Test.startTest();
    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      probation.Id,
      employeeId,
      Date.today().addDays(-20),
      Date.today().addDays(40),
      hrManagerId,
      'Updated plan',
      version,
      adminId(),
      null
    );
    PWChrono_ProbationController.saveProbation(
      probation.Id,
      employeeId,
      null,
      Date.today().addDays(50),
      hrManagerId,
      null,
      row.recordVersion,
      adminId(),
      null
    );
    Test.stopTest();

    Assert.areEqual(Date.today().addDays(40), row.endDate);
    Assert.areEqual(firstEnd, row.originalEndDate);
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      row.status,
      'Saving never changes status'
    );

    PWChrono_Probation__c updated = reload(probation.Id);
    Assert.areEqual(Date.today().addDays(-20), updated.Start_Date__c);
    Assert.areEqual(Date.today().addDays(50), updated.End_Date__c);
    Assert.areEqual(
      firstEnd,
      updated.Original_End_Date__c,
      'The first end date is kept across later edits'
    );
    Assert.areEqual(hrManagerId, updated.Reviewer__c);
    Assert.areEqual(
      'Updated plan',
      updated.Review_Notes__c,
      'Null notes leave existing notes unchanged'
    );
  }

  @isTest
  static void editCanClearReviewerAndValidatesInput() {
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(20)
    );
    probation.Reviewer__c = idFor(MANAGER_EMAIL);
    update probation;
    String employeeId = String.valueOf(idFor(EMPLOYEE_EMAIL));

    assertContains(
      saveError(
        probation.Id,
        idFor(CONTACT_EMPLOYEE_EMAIL),
        Date.today(),
        Date.today().addDays(30),
        null
      ),
      'employee on a probation record cannot be changed'
    );
    assertContains(
      saveError(
        probation.Id,
        employeeId,
        Date.today(),
        Date.today().addDays(-5),
        null
      ),
      'cannot be before the start date'
    );
    assertContains(
      saveError(
        probation.Id,
        employeeId,
        Date.today(),
        Date.today().addDays(30),
        employeeId
      ),
      'cannot review their own probation'
    );
    String missingProbationId =
      PWChrono_Probation__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000000';
    assertContains(
      saveError(
        missingProbationId,
        employeeId,
        Date.today(),
        Date.today().addDays(30),
        null
      ),
      'not found'
    );

    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      probation.Id,
      employeeId,
      Date.today().addDays(-30),
      Date.today().addDays(20),
      null,
      '',
      currentVersion(probation.Id),
      adminId(),
      null
    );
    Assert.isNull(row.reviewerId, 'A blank reviewer clears the reviewer');
    Assert.isNull(row.originalEndDate, 'Unchanged end date is not recorded');
  }

  @isTest
  static void editRejectsTerminalRecords() {
    PWChrono_Probation__c completed = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_COMPLETED,
      Date.today().addDays(-1)
    );

    String error = saveError(
      completed.Id,
      null,
      Date.today(),
      Date.today().addDays(30),
      null
    );

    assertContains(error, 'can no longer be edited');
    Assert.areEqual(Date.today().addDays(-1), reload(completed.Id).End_Date__c);
  }

  @isTest
  static void staleEditIsRejectedAfterConcurrentExtension() {
    Date firstEnd = Date.today().addDays(20);
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      firstEnd
    );
    String hrManagerId = String.valueOf(idFor(HR_MANAGER_EMAIL));
    // The HR manager opens the edit form...
    String staleVersion = currentVersion(probation.Id);

    Test.startTest();
    // ...an administrator extends the probation meanwhile...
    PWChrono_ProbationController.updateProbationStatus(
      probation.Id,
      PWChrono_ProbationController.STATUS_EXTENDED,
      firstEnd.addDays(30),
      'Needs more time',
      adminId(),
      null
    );
    // ...and the HR manager then saves the values loaded earlier.
    String staleError = saveErrorAs(
      hrManagerId,
      probation.Id,
      idFor(EMPLOYEE_EMAIL),
      Date.today().addDays(-30),
      firstEnd,
      null,
      'Old notes',
      staleVersion
    );
    String missingVersionError = saveErrorAs(
      hrManagerId,
      probation.Id,
      null,
      null,
      null,
      null,
      'Old notes',
      null
    );
    Test.stopTest();

    Assert.areEqual(PWChrono_ProbationController.CONFLICT_MESSAGE, staleError);
    Assert.areEqual(
      PWChrono_ProbationController.CONFLICT_MESSAGE,
      missingVersionError
    );
    PWChrono_Probation__c current = reload(probation.Id);
    Assert.areEqual(
      firstEnd.addDays(30),
      current.End_Date__c,
      'The extension is kept'
    );
    Assert.areEqual(firstEnd, current.Original_End_Date__c);
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_EXTENDED,
      current.Status__c
    );
    assertContains(current.Review_Notes__c, 'Needs more time');

    // With the latest version, blank dates keep the extended end date.
    PWChrono_ProbationController.ProbationRecord saved = PWChrono_ProbationController.saveProbation(
      probation.Id,
      null,
      null,
      null,
      null,
      'Checked in with the reviewer',
      currentVersion(probation.Id),
      hrManagerId,
      null
    );
    Assert.areEqual(firstEnd.addDays(30), saved.endDate);
    assertContains(saved.notes, 'Needs more time');
    assertContains(saved.notes, 'Checked in with the reviewer');
  }

  @isTest
  static void versionChangesWhenAnyDecisionFieldChanges() {
    PWChrono_Probation__c base = new PWChrono_Probation__c(
      Status__c = PWChrono_ProbationController.STATUS_PENDING,
      End_Date__c = Date.today()
    );
    PWChrono_Probation__c extended = base.clone();
    extended.End_Date__c = Date.today().addDays(1);
    PWChrono_Probation__c noted = base.clone();
    noted.Review_Notes__c = 'Decision';

    String baseVersion = PWChrono_ProbationController.versionOf(base);
    Assert.areEqual(
      baseVersion,
      PWChrono_ProbationController.versionOf(base.clone()),
      'The same values give the same version'
    );
    Assert.areNotEqual(
      baseVersion,
      PWChrono_ProbationController.versionOf(extended)
    );
    Assert.areNotEqual(
      baseVersion,
      PWChrono_ProbationController.versionOf(noted)
    );
  }

  @isTest
  static void nonAdminCannotManageOwnProbation() {
    String hrManagerId = String.valueOf(idFor(HR_MANAGER_EMAIL));

    Assert.areEqual(
      PWChrono_ProbationController.SELF_MANAGE_MESSAGE,
      saveErrorAs(
        hrManagerId,
        null,
        hrManagerId,
        Date.today(),
        Date.today().addDays(90),
        null,
        null,
        null
      )
    );

    // An administrator may open the HR manager's own probation...
    PWChrono_ProbationController.ProbationRecord row = PWChrono_ProbationController.saveProbation(
      null,
      hrManagerId,
      Date.today(),
      Date.today().addDays(90),
      null,
      'Initial plan',
      null,
      adminId(),
      null
    );
    // ...but the HR manager still cannot move its dates or rewrite its notes.
    Assert.areEqual(
      PWChrono_ProbationController.SELF_MANAGE_MESSAGE,
      saveErrorAs(
        hrManagerId,
        row.id,
        null,
        null,
        Date.today().addDays(200),
        null,
        '',
        row.recordVersion
      )
    );
    PWChrono_Probation__c stored = reload(row.id);
    Assert.areEqual(Date.today().addDays(90), stored.End_Date__c);
    Assert.areEqual('Initial plan', stored.Review_Notes__c);

    // The HR manager can still manage other employees' probations.
    PWChrono_ProbationController.ProbationRecord other = PWChrono_ProbationController.saveProbation(
      null,
      idFor(EMPLOYEE_EMAIL),
      Date.today(),
      Date.today().addDays(90),
      null,
      null,
      null,
      hrManagerId,
      null
    );
    Assert.areEqual(PWChrono_ProbationController.STATUS_PENDING, other.status);
  }

  @isTest
  static void nonAdminNotesAreAppendedAndAdminNotesReplace() {
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      Date.today().addDays(20)
    );
    String decision = 'In Review (01/09/2026, Probation Admin): Decision entry';
    probation.Review_Notes__c = decision;
    update probation;
    String hrManagerId = String.valueOf(idFor(HR_MANAGER_EMAIL));

    PWChrono_ProbationController.ProbationRecord appended = PWChrono_ProbationController.saveProbation(
      probation.Id,
      null,
      null,
      null,
      null,
      '  Weekly check-in done  ',
      currentVersion(probation.Id),
      hrManagerId,
      null
    );
    Assert.isTrue(
      appended.notes.startsWith(decision),
      'Existing decision notes are kept'
    );
    Assert.isTrue(
      appended.notes.endsWith(
        'Note (' +
          Date.today().format() +
          ', Probation HR Manager): Weekly check-in done'
      ),
      'A non-admin note is appended with date and author: ' + appended.notes
    );

    PWChrono_ProbationController.ProbationRecord notCleared = PWChrono_ProbationController.saveProbation(
      probation.Id,
      null,
      null,
      null,
      null,
      '',
      appended.recordVersion,
      hrManagerId,
      null
    );
    Assert.areEqual(
      appended.notes,
      notCleared.notes,
      'A non-admin cannot clear the notes'
    );

    PWChrono_ProbationController.ProbationRecord replaced = PWChrono_ProbationController.saveProbation(
      probation.Id,
      null,
      null,
      null,
      null,
      'Rewritten summary',
      notCleared.recordVersion,
      adminId(),
      null
    );
    Assert.areEqual(
      'Rewritten summary',
      replaced.notes,
      'Administrators may rewrite the notes'
    );
  }

  // ---------------------------------------------------------------------------
  // Status transitions
  // ---------------------------------------------------------------------------

  @isTest
  static void statusMovesFromPendingToReviewToExtendedToCompleted() {
    Date firstEnd = Date.today().addDays(10);
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      firstEnd
    );

    Test.startTest();
    PWChrono_ProbationController.ProbationRecord inReview = PWChrono_ProbationController.updateProbationStatus(
      probation.Id,
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      null,
      'Review started',
      adminId(),
      null
    );
    assertContains(
      statusError(
        probation.Id,
        PWChrono_ProbationController.STATUS_IN_REVIEW,
        null,
        adminId()
      ),
      'Only a pending probation'
    );
    assertContains(
      statusError(
        probation.Id,
        PWChrono_ProbationController.STATUS_EXTENDED,
        null,
        adminId()
      ),
      'Enter the new end date'
    );
    assertContains(
      statusError(
        probation.Id,
        PWChrono_ProbationController.STATUS_EXTENDED,
        firstEnd,
        adminId()
      ),
      'must be later than the current end date'
    );
    PWChrono_ProbationController.ProbationRecord extended = PWChrono_ProbationController.updateProbationStatus(
      probation.Id,
      PWChrono_ProbationController.STATUS_EXTENDED,
      firstEnd.addDays(30),
      'Needs more time',
      adminId(),
      null
    );
    PWChrono_ProbationController.ProbationRecord extendedAgain = PWChrono_ProbationController.updateProbationStatus(
      probation.Id,
      PWChrono_ProbationController.STATUS_EXTENDED,
      firstEnd.addDays(45),
      null,
      adminId(),
      null
    );
    PWChrono_ProbationController.ProbationRecord completed = PWChrono_ProbationController.updateProbationStatus(
      probation.Id,
      PWChrono_ProbationController.STATUS_COMPLETED,
      null,
      'Confirmed',
      adminId(),
      null
    );
    Test.stopTest();

    Assert.areEqual(
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      inReview.status
    );
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_EXTENDED,
      extended.status
    );
    Assert.areEqual(firstEnd.addDays(30), extended.endDate);
    Assert.areEqual(firstEnd, extended.originalEndDate);
    Assert.areEqual(
      firstEnd,
      extendedAgain.originalEndDate,
      'A second extension keeps the original end date'
    );
    Assert.areEqual(firstEnd.addDays(45), extendedAgain.endDate);
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_COMPLETED,
      completed.status
    );
    Assert.areEqual(Date.today(), completed.confirmationDate);
    Assert.isNull(
      completed.daysRemaining,
      'Closed probations have no countdown'
    );

    String notes = reload(probation.Id).Review_Notes__c;
    assertContains(notes, 'In Review');
    assertContains(
      notes,
      'In Review (' +
        Date.today().format() +
        ', Probation Admin): Review started'
    );
    assertContains(notes, 'Needs more time');
    assertContains(notes, 'Confirmed');
    Assert.isTrue(
      notes.indexOf('Review started') < notes.indexOf('Confirmed'),
      'Status notes are appended in order'
    );
  }

  @isTest
  static void terminalStatusesCannotChangeAndInvalidStatusRejected() {
    PWChrono_Probation__c failedRecord = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      Date.today().addDays(3)
    );
    PWChrono_Probation__c completedRecord = insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_COMPLETED,
      Date.today().addDays(-3)
    );

    assertContains(
      statusError(failedRecord.Id, 'Pending', null, adminId()),
      'Choose a valid probation status'
    );
    PWChrono_ProbationController.ProbationRecord failed = PWChrono_ProbationController.updateProbationStatus(
      failedRecord.Id,
      PWChrono_ProbationController.STATUS_FAILED,
      null,
      null,
      adminId(),
      null
    );
    Assert.areEqual(PWChrono_ProbationController.STATUS_FAILED, failed.status);
    Assert.isNull(failed.confirmationDate);

    assertContains(
      statusError(
        failedRecord.Id,
        PWChrono_ProbationController.STATUS_COMPLETED,
        null,
        adminId()
      ),
      'is already Failed'
    );
    assertContains(
      statusError(
        completedRecord.Id,
        PWChrono_ProbationController.STATUS_EXTENDED,
        Date.today().addDays(30),
        adminId()
      ),
      'is already Completed'
    );
    assertContains(
      statusError(
        null,
        PWChrono_ProbationController.STATUS_FAILED,
        null,
        adminId()
      ),
      'A probation record is required'
    );
  }

  @isTest
  static void statusNotesKeepMostRecentTextWithinFieldLimit() {
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(10)
    );
    probation.Review_Notes__c = 'a'.repeat(4990);
    update probation;

    PWChrono_ProbationController.updateProbationStatus(
      probation.Id,
      PWChrono_ProbationController.STATUS_FAILED,
      null,
      'Final decision',
      adminId(),
      null
    );

    String notes = reload(probation.Id).Review_Notes__c;
    Assert.areEqual(5000, notes.length());
    Assert.isTrue(notes.endsWith('Final decision'));
  }

  // ---------------------------------------------------------------------------
  // Authorization
  // ---------------------------------------------------------------------------

  @isTest
  static void statusChangeAndDeleteAreAdminOnly() {
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(10)
    );
    String hrManagerId = String.valueOf(idFor(HR_MANAGER_EMAIL));

    // HR manager holds the feature: may read and edit but not decide or delete.
    Assert.areEqual(
      1,
      PWChrono_ProbationController.getProbations(hrManagerId, null).size()
    );
    PWChrono_ProbationController.ProbationOptions options = PWChrono_ProbationController.getProbationOptions(
      hrManagerId,
      null
    );
    Assert.isFalse(options.isAdmin);

    assertContains(
      statusError(
        probation.Id,
        PWChrono_ProbationController.STATUS_COMPLETED,
        null,
        hrManagerId
      ),
      'Only HR administrators can change probation status'
    );
    try {
      PWChrono_ProbationController.deleteProbations(
        new List<String>{ probation.Id },
        hrManagerId,
        null
      );
      Assert.fail('Non-admin delete should be rejected');
    } catch (AuraHandledException e) {
      assertContains(
        e.getMessage(),
        'Only HR administrators can delete probation records'
      );
    }
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_PENDING,
      reload(probation.Id).Status__c
    );
  }

  @isTest
  static void userWithoutFeatureIsDenied() {
    PWChrono_Probation__c probation = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(10)
    );
    String noProfileId = String.valueOf(idFor(NO_PROFILE_EMAIL));
    List<String> errors = new List<String>();
    try {
      PWChrono_ProbationController.getProbations(noProfileId, null);
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_ProbationController.getProbationOptions(noProfileId, null);
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_ProbationController.saveProbation(
        null,
        idFor(EMPLOYEE_EMAIL),
        Date.today(),
        Date.today().addDays(30),
        null,
        null,
        null,
        noProfileId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_ProbationController.updateProbationStatus(
        probation.Id,
        PWChrono_ProbationController.STATUS_COMPLETED,
        null,
        null,
        noProfileId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_ProbationController.deleteProbations(
        new List<String>{ probation.Id },
        noProfileId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }

    Assert.areEqual(5, errors.size(), 'Every call must be denied');
    for (String error : errors) {
      assertContains(error, 'Employee Lifecycle');
    }
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM PWChrono_Probation__c],
      'Nothing is created or deleted'
    );
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_PENDING,
      reload(probation.Id).Status__c,
      'The status is not changed'
    );
  }

  @isTest
  static void guestSessionIsVerified() {
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(10)
    );
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Assert.areEqual(
        1,
        PWChrono_ProbationController.getProbations(adminId(), GUEST_TOKEN)
          .size(),
        'A valid guest session is accepted'
      );
      try {
        PWChrono_ProbationController.getProbations(adminId(), 'wrong-token');
        Assert.fail('An invalid session token must be rejected');
      } catch (AuraHandledException e) {
        assertContains(e.getMessage(), 'Session invalid');
      }
      try {
        PWChrono_ProbationController.getProbations(adminId(), null);
        Assert.fail('A missing session token must be rejected');
      } catch (AuraHandledException e) {
        assertContains(e.getMessage(), 'Session invalid or expired');
      }
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  @isTest
  static void deleteRemovesPendingAndInReviewOnly() {
    PWChrono_Probation__c pending = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(10)
    );
    PWChrono_Probation__c inReview = insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      Date.today().addDays(12)
    );
    PWChrono_Probation__c completed = insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_COMPLETED,
      Date.today().addDays(-40)
    );
    String completedNumber = [
      SELECT Name
      FROM PWChrono_Probation__c
      WHERE Id = :completed.Id
    ]
    .Name;

    try {
      PWChrono_ProbationController.deleteProbations(
        new List<String>{ pending.Id, completed.Id },
        adminId(),
        null
      );
      Assert.fail('Deleting a completed probation must be blocked');
    } catch (AuraHandledException e) {
      assertContains(e.getMessage(), 'Only pending or in-review');
      assertContains(e.getMessage(), completedNumber);
      assertContains(e.getMessage(), 'Alice Probationer');
    }
    Assert.areEqual(
      3,
      [SELECT COUNT() FROM PWChrono_Probation__c],
      'A blocked delete removes nothing'
    );

    try {
      PWChrono_ProbationController.deleteProbations(
        new List<String>(),
        adminId(),
        null
      );
      Assert.fail('An empty selection must be rejected');
    } catch (AuraHandledException e) {
      assertContains(e.getMessage(), 'Select at least one');
    }

    Integer deleted = PWChrono_ProbationController.deleteProbations(
      new List<String>{ pending.Id, inReview.Id },
      adminId(),
      null
    );
    Assert.areEqual(2, deleted);
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Probation__c]);

    try {
      PWChrono_ProbationController.deleteProbations(
        new List<String>{ pending.Id },
        adminId(),
        null
      );
      Assert.fail('Deleting a missing record must fail');
    } catch (AuraHandledException e) {
      assertContains(e.getMessage(), 'no longer exist');
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  @isTest
  static void getProbationsOrdersBySoonestEndDate() {
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_COMPLETED,
      Date.today().addDays(-60)
    );
    insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(40)
    );
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(5)
    );
    PWChrono_Probation__c undated = insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_FAILED,
      null
    );
    PWChrono_Probation__c sameDay = insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_FAILED,
      Date.today().addDays(-60)
    );

    List<PWChrono_ProbationController.ProbationRecord> rows = PWChrono_ProbationController.getProbations(
      adminId(),
      null
    );

    Assert.areEqual(5, rows.size());
    Assert.areEqual(Date.today().addDays(-60), rows[0].endDate);
    Assert.areEqual(Date.today().addDays(-60), rows[1].endDate);
    Assert.areEqual(
      sameDay.Id,
      rows[1].id,
      'Same end date is ordered by probation number'
    );
    Assert.areEqual(Date.today().addDays(5), rows[2].endDate);
    Assert.areEqual(Date.today().addDays(40), rows[3].endDate);
    Assert.areEqual(undated.Id, rows[4].id, 'Blank end dates are listed last');
    Assert.areEqual(5, rows[2].daysRemaining);
    Assert.areEqual('Finance', rows[3].department);
    Assert.areEqual('Accountant', rows[3].designation);
    Assert.isNull(rows[0].recordVersion, 'Closed records carry no version');
    Assert.isNotNull(rows[2].recordVersion, 'Open records carry a version');
  }

  @isTest
  static void getProbationsKeepsOpenRecordsWhenRowLimitIsReached() {
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_COMPLETED,
      Date.today().addDays(-60)
    );
    insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_FAILED,
      Date.today().addDays(-5)
    );
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(40)
    );
    insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_EXTENDED,
      Date.today().addDays(5)
    );

    PWChrono_ProbationController.recordLimit = 3;
    List<PWChrono_ProbationController.ProbationRecord> rows = PWChrono_ProbationController.getProbations(
      adminId(),
      null
    );
    Assert.areEqual(3, rows.size());
    Assert.areEqual(
      Date.today().addDays(-5),
      rows[0].endDate,
      'The most recent closed record fills the remaining row'
    );
    Assert.areEqual(Date.today().addDays(5), rows[1].endDate);
    Assert.areEqual(Date.today().addDays(40), rows[2].endDate);

    PWChrono_ProbationController.recordLimit = 1;
    rows = PWChrono_ProbationController.getProbations(adminId(), null);
    Assert.areEqual(1, rows.size());
    Assert.areEqual(
      PWChrono_ProbationController.STATUS_EXTENDED,
      rows[0].status,
      'Open records are never pushed out by closed history'
    );
  }

  @isTest
  static void employeeIdsOnOpenProbationAreDistinctAndActive() {
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_PENDING,
      Date.today().addDays(10)
    );
    insertProbation(
      EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_EXTENDED,
      Date.today().addDays(20)
    );
    insertProbation(
      CONTACT_EMPLOYEE_EMAIL,
      PWChrono_ProbationController.STATUS_COMPLETED,
      Date.today().addDays(-5)
    );
    insertProbation(
      INACTIVE_EMAIL,
      PWChrono_ProbationController.STATUS_IN_REVIEW,
      Date.today().addDays(5)
    );

    Set<Id> ids = PWChrono_ProbationController.getEmployeeIdsOnOpenProbation();

    Assert.areEqual(new Set<Id>{ idFor(EMPLOYEE_EMAIL) }, ids);
  }

  @isTest
  static void optionsReturnActiveEmployeesAndDefaultDays() {
    PWChrono_ProbationController.ProbationOptions options = PWChrono_ProbationController.getProbationOptions(
      adminId(),
      null
    );

    PWChrono_Settings__mdt settings = PWChrono_Settings__mdt.getInstance(
      'Default_Organization_Settings'
    );
    Integer expectedDays = settings != null &&
      settings.Probation_Period_Days__c != null &&
      settings.Probation_Period_Days__c > 0
      ? settings.Probation_Period_Days__c.intValue()
      : PWChrono_ProbationController.FALLBACK_PROBATION_DAYS;
    Assert.areEqual(expectedDays, options.defaultProbationDays);
    Assert.areEqual(
      expectedDays,
      PWChrono_ProbationController.getDefaultProbationDays()
    );
    Assert.isTrue(options.isAdmin);

    Map<Id, PWChrono_ProbationController.EmployeeOption> byId = new Map<Id, PWChrono_ProbationController.EmployeeOption>();
    for (
      PWChrono_ProbationController.EmployeeOption option : options.employees
    ) {
      byId.put(option.id, option);
    }
    Assert.isFalse(
      byId.containsKey(idFor(INACTIVE_EMAIL)),
      'Inactive employees are not offered'
    );
    PWChrono_ProbationController.EmployeeOption alice = byId.get(
      idFor(EMPLOYEE_EMAIL)
    );
    Assert.areEqual('Alice Probationer', alice.name);
    Assert.areEqual('Software Engineer', alice.designation);
    Assert.areEqual('Engineering', alice.department);
    Assert.areEqual(Date.today().addDays(-10), alice.dateOfJoining);
    Assert.areEqual(idFor(MANAGER_EMAIL), alice.reportsToId);
    Assert.areEqual(
      'Finance',
      byId.get(idFor(CONTACT_EMPLOYEE_EMAIL)).department
    );
  }
}