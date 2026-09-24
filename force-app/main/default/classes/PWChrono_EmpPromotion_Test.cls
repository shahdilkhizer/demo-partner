/**
 * @description Tests for PWChrono_EmployeePromotionController: session and
 *              feature checks, administrator-only status changes and deletes,
 *              the status workflow, approval side effects on the employee,
 *              self-management guards, the employee snapshot and safe saving
 *              of client input.
 */
@isTest
private class PWChrono_EmpPromotion_Test {
  private static final String EMPLOYEE_EMAIL = 'promo.employee@test.com';
  private static final String ADMIN_EMAIL = 'promo.hradmin@test.com';
  private static final String HR_MANAGER_EMAIL = 'promo.hrmanager@test.com';
  private static final String MANAGER_EMAIL = 'promo.manager@test.com';
  private static final String OUTSIDER_EMAIL = 'promo.outsider@test.com';
  private static final String INACTIVE_EMAIL = 'promo.inactive@test.com';

  @testSetup
  static void setup() {
    Contact employeeContact = new Contact(
      LastName = 'Promotion Employee',
      Department = 'Engineering',
      Title = 'Junior Developer'
    );
    insert employeeContact;

    Portal_User_Profile__c hrManagerProfile = new Portal_User_Profile__c(
      Profile_Type__c = 'HR Manager',
      Approval_Scope__c = 'Department',
      Can_Approve__c = true,
      Is_Active__c = true
    );
    insert hrManagerProfile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = hrManagerProfile.Id,
      Feature_Key__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Feature_Label__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Is_Enabled__c = true
    );

    Portal_Users__c admin = new Portal_Users__c(
      Name = 'Promotion HR Admin',
      Email__c = ADMIN_EMAIL,
      Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
      Is_Active__c = true
    );
    Portal_Users__c hrManager = new Portal_Users__c(
      Name = 'Promotion HR Manager',
      Email__c = HR_MANAGER_EMAIL,
      Role__c = 'HR Manager',
      Department__c = 'Engineering',
      Portal_User_Profile__c = hrManagerProfile.Id,
      Is_Active__c = true
    );
    Portal_Users__c manager = new Portal_Users__c(
      Name = 'Promotion New Manager',
      Email__c = MANAGER_EMAIL,
      Role__c = 'Manager',
      Department__c = 'Product',
      Is_Active__c = true
    );
    Portal_Users__c outsider = new Portal_Users__c(
      Name = 'Promotion Outsider',
      Email__c = OUTSIDER_EMAIL,
      Role__c = 'Employee',
      Department__c = 'Sales',
      Is_Active__c = true
    );
    Portal_Users__c inactive = new Portal_Users__c(
      Name = 'Promotion Inactive',
      Email__c = INACTIVE_EMAIL,
      Role__c = 'Employee',
      Department__c = 'Engineering',
      Is_Active__c = false
    );
    insert new List<Portal_Users__c>{
      admin,
      hrManager,
      manager,
      outsider,
      inactive
    };

    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Promotion Employee',
      Email__c = EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Department__c = 'Engineering',
      Designation__c = 'Junior Developer',
      Reports_To__c = admin.Id,
      Contact__c = employeeContact.Id,
      Is_Active__c = true
    );
    insert employee;

    PWChrono_Department__c engineering = new PWChrono_Department__c(
      Name = 'Engineering',
      Is_Active__c = true
    );
    PWChrono_Department__c product = new PWChrono_Department__c(
      Name = 'Product',
      Is_Active__c = true
    );
    insert new List<PWChrono_Department__c>{ engineering, product };

    PWChrono_Designation__c junior = new PWChrono_Designation__c(
      Name = 'Junior Developer',
      Is_Active__c = true
    );
    PWChrono_Designation__c senior = new PWChrono_Designation__c(
      Name = 'Senior Developer',
      Is_Active__c = true
    );
    insert new List<PWChrono_Designation__c>{ junior, senior };

    PWChrono_Employee_Promotion__c promotion = new PWChrono_Employee_Promotion__c(
      Employee__c = employee.Id,
      Employee_Name__c = employee.Name,
      Company__c = 'PWChrono Corp',
      Promotion_Date__c = Date.today(),
      Current_Designation__c = junior.Id,
      New_Designation__c = senior.Id,
      Current_Department__c = engineering.Id,
      New_Department__c = product.Id,
      Current_Reports_To__c = admin.Id,
      New_Reports_To__c = manager.Id,
      Current_Grade__c = 'L2',
      New_Grade__c = 'L3',
      Current_Salary__c = 60000,
      New_Salary__c = 75000,
      Status__c = 'Draft'
    );
    insert promotion;

    insert new PWChrono_Promotion_Detail__c(
      Promotion__c = promotion.Id,
      Property__c = 'Designation',
      Current_Value__c = 'Junior Developer',
      New_Value__c = 'Senior Developer'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Id userId(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  private static Id departmentId(String name) {
    return [SELECT Id FROM PWChrono_Department__c WHERE Name = :name LIMIT 1]
    .Id;
  }

  private static Id designationId(String name) {
    return [SELECT Id FROM PWChrono_Designation__c WHERE Name = :name LIMIT 1]
    .Id;
  }

  private static PWChrono_Employee_Promotion__c getPromotion() {
    return [
      SELECT Id, Status__c, Company__c, Promotion_Date__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Employee__c = :userId(EMPLOYEE_EMAIL)
      LIMIT 1
    ];
  }

  private static void setStatus(Id promotionId, String status) {
    update new PWChrono_Employee_Promotion__c(
      Id = promotionId,
      Status__c = status
    );
  }

  private static Portal_Users__c getEmployee() {
    return [
      SELECT Id, Department__c, Designation__c, Reports_To__c, Contact__c
      FROM Portal_Users__c
      WHERE Email__c = :EMPLOYEE_EMAIL
      LIMIT 1
    ];
  }

  private static String statusError(
    Id promotionId,
    String newStatus,
    String actorEmail
  ) {
    try {
      PWChrono_EmployeePromotionController.updatePromotionStatus(
        promotionId,
        newStatus,
        userId(actorEmail),
        null
      );
      return null;
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
  }

  private static String saveError(
    String promotionJson,
    String detailsJson,
    String actorEmail
  ) {
    try {
      PWChrono_EmployeePromotionController.savePromotion(
        promotionJson,
        detailsJson,
        userId(actorEmail),
        null
      );
      return null;
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
  }

  private static String deleteError(Id promotionId, String actorEmail) {
    try {
      PWChrono_EmployeePromotionController.deletePromotion(
        promotionId,
        userId(actorEmail),
        null
      );
      return null;
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
  }

  private static String today() {
    return String.valueOf(Date.today());
  }

  private static Portal_Users__c getEmployeeWithContact() {
    return [
      SELECT
        Id,
        Department__c,
        Designation__c,
        Reports_To__c,
        Contact__r.Department,
        Contact__r.Title
      FROM Portal_Users__c
      WHERE Email__c = :EMPLOYEE_EMAIL
      LIMIT 1
    ];
  }

  private static void assertContains(String message, String expected) {
    Assert.isNotNull(message, 'Expected an error containing: ' + expected);
    Assert.isTrue(
      message.contains(expected),
      'Expected "' + expected + '" in: ' + message
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reads
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminSeesAllPromotionsAndCanFilterByStatus() {
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    List<PWChrono_Employee_Promotion__c> all = PWChrono_EmployeePromotionController.getPromotions(
      'All',
      adminId,
      null
    );
    List<PWChrono_Employee_Promotion__c> drafts = PWChrono_EmployeePromotionController.getPromotions(
      'Draft',
      adminId,
      null
    );
    List<PWChrono_Employee_Promotion__c> approved = PWChrono_EmployeePromotionController.getPromotions(
      'Approved',
      adminId,
      null
    );
    Test.stopTest();
    Assert.areEqual(1, all.size());
    Assert.areEqual(1, drafts.size());
    Assert.areEqual(0, approved.size());
    Assert.areEqual('Promotion Employee', all[0].Employee__r.Name);
  }

  @isTest
  static void nonAdminSeesOnlyPromotionsInScope() {
    insert new PWChrono_Employee_Promotion__c(
      Employee__c = userId(OUTSIDER_EMAIL),
      Promotion_Date__c = Date.today(),
      Status__c = 'Draft'
    );
    Test.startTest();
    List<PWChrono_Employee_Promotion__c> scoped = PWChrono_EmployeePromotionController.getPromotions(
      null,
      userId(HR_MANAGER_EMAIL),
      null
    );
    List<PWChrono_Employee_Promotion__c> all = PWChrono_EmployeePromotionController.getPromotions(
      null,
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(
      1,
      scoped.size(),
      'Only the department employee is in scope'
    );
    Assert.areEqual(userId(EMPLOYEE_EMAIL), scoped[0].Employee__c);
    Assert.areEqual(2, all.size(), 'Administrators see every promotion');
  }

  @isTest
  static void getPromotionByIdAndDetails() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    PWChrono_Employee_Promotion__c result = PWChrono_EmployeePromotionController.getPromotionById(
      promotion.Id,
      adminId,
      null
    );
    List<PWChrono_Promotion_Detail__c> details = PWChrono_EmployeePromotionController.getPromotionDetails(
      promotion.Id,
      userId(HR_MANAGER_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual('PWChrono Corp', result.Company__c);
    Assert.areEqual(1, details.size());
    Assert.areEqual('Designation', details[0].Property__c);
  }

  @isTest
  static void getPromotionByIdRejectsUnknownAndOutOfScopeRecords() {
    PWChrono_Employee_Promotion__c outOfScope = new PWChrono_Employee_Promotion__c(
      Employee__c = userId(OUTSIDER_EMAIL),
      Status__c = 'Draft'
    );
    insert outOfScope;
    Id adminId = userId(ADMIN_EMAIL);

    Test.startTest();
    String unknownError;
    try {
      PWChrono_EmployeePromotionController.getPromotionById(
        'not-an-id',
        adminId,
        null
      );
    } catch (AuraHandledException e) {
      unknownError = e.getMessage();
    }
    String scopeError;
    try {
      PWChrono_EmployeePromotionController.getPromotionDetails(
        outOfScope.Id,
        userId(HR_MANAGER_EMAIL),
        null
      );
    } catch (AuraHandledException e) {
      scopeError = e.getMessage();
    }
    Test.stopTest();
    assertContains(unknownError, 'not found');
    assertContains(scopeError, 'not found');
  }

  @isTest
  static void lookupsReturnActiveRecordsForFeatureHolders() {
    Id hrManagerId = userId(HR_MANAGER_EMAIL);
    Test.startTest();
    List<PWChrono_Designation__c> designations = PWChrono_EmployeePromotionController.getActiveDesignations(
      hrManagerId,
      null
    );
    List<PWChrono_Department__c> departments = PWChrono_EmployeePromotionController.getActiveDepartments(
      hrManagerId,
      null
    );
    List<Portal_Users__c> employees = PWChrono_EmployeePromotionController.getActiveEmployees(
      hrManagerId,
      null
    );
    Test.stopTest();
    Assert.areEqual(2, designations.size());
    Assert.areEqual(2, departments.size());
    Assert.areEqual(5, employees.size(), 'Inactive employees are excluded');
  }

  @isTest
  static void userWithoutFeatureIsDeniedOnReadSaveAndLookups() {
    Id employeeId = userId(EMPLOYEE_EMAIL);
    List<String> errors = new List<String>();
    Test.startTest();
    try {
      PWChrono_EmployeePromotionController.getPromotions(
        'All',
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeePromotionController.getPromotionById(
        getPromotion().Id,
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeePromotionController.getActiveEmployees(employeeId, null);
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeePromotionController.getActiveDepartments(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeePromotionController.getActiveDesignations(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    errors.add(
      saveError(
        JSON.serialize(new Map<String, Object>{ 'Employee__c' => employeeId }),
        null,
        EMPLOYEE_EMAIL
      )
    );
    Test.stopTest();

    Assert.areEqual(6, errors.size());
    for (String message : errors) {
      assertContains(message, 'Employee Lifecycle');
    }
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM PWChrono_Employee_Promotion__c],
      'Nothing is saved without the feature'
    );
  }

  @isTest
  static void guestSessionIsVerified() {
    Portal_Users__c admin = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = :ADMIN_EMAIL
      LIMIT 1
    ];
    admin.Session_Token__c = 'guest_promotion_token';
    admin.Session_Expires_At__c = System.now().addHours(1);
    update admin;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Employee_Promotion__c> results = PWChrono_EmployeePromotionController.getPromotions(
        'All',
        String.valueOf(admin.Id),
        'guest_promotion_token'
      );
      String error;
      try {
        PWChrono_EmployeePromotionController.getActiveEmployees(
          String.valueOf(admin.Id),
          'wrong_token'
        );
      } catch (AuraHandledException e) {
        error = e.getMessage();
      }
      Test.stopTest();
      Assert.areEqual(1, results.size());
      assertContains(error, 'Session invalid');
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void createStartsAsDraftIgnoresStatusAndDefaultsCurrentValues() {
    Id employeeId = userId(EMPLOYEE_EMAIL);
    Map<String, Object> record = new Map<String, Object>{
      'Employee__c' => employeeId,
      'Promotion_Date__c' => String.valueOf(Date.today()),
      'Company__c' => 'Test Corp',
      'New_Designation__c' => designationId('Senior Developer'),
      'New_Salary__c' => '82000.50',
      'Status__c' => 'Approved',
      'Name' => 'Injected name',
      'Employee_Name__c' => 'Forged name',
      'Current_Department__c' => departmentId('Product'),
      'Current_Designation__c' => designationId('Senior Developer'),
      'Current_Reports_To__c' => userId(MANAGER_EMAIL)
    };
    List<Map<String, Object>> details = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Property__c' => 'Grade',
        'Current_Value__c' => 'L2',
        'New_Value__c' => 'L3'
      },
      new Map<String, Object>{ 'Property__c' => '  ' }
    };

    Test.startTest();
    String newId = PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(record),
      JSON.serialize(details),
      userId(HR_MANAGER_EMAIL),
      null
    );
    Test.stopTest();

    PWChrono_Employee_Promotion__c saved = [
      SELECT
        Status__c,
        Employee_Name__c,
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c,
        New_Salary__c,
        (SELECT Property__c FROM Promotion_Details__r)
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :newId
    ];
    Assert.areEqual('Draft', saved.Status__c, 'Client cannot set the status');
    Assert.areEqual(
      'Promotion Employee',
      saved.Employee_Name__c,
      'The name comes from the employee record'
    );
    Assert.areEqual(departmentId('Engineering'), saved.Current_Department__c);
    Assert.areEqual(
      designationId('Junior Developer'),
      saved.Current_Designation__c
    );
    Assert.areEqual(userId(ADMIN_EMAIL), saved.Current_Reports_To__c);
    Assert.areEqual(82000.50, saved.New_Salary__c);
    Assert.areEqual(
      1,
      saved.Promotion_Details__r.size(),
      'Blank lines are skipped'
    );
  }

  @isTest
  static void editKeepsStatusAndManagesDetailLines() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    setStatus(promotion.Id, 'Submitted');
    Map<String, Object> record = new Map<String, Object>{
      'Id' => promotion.Id,
      'Company__c' => 'Updated Corp',
      'Status__c' => 'Approved'
    };

    Test.startTest();
    String savedId = PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(record),
      null,
      userId(ADMIN_EMAIL),
      null
    );
    Integer linesAfterUnchanged = [
      SELECT COUNT()
      FROM PWChrono_Promotion_Detail__c
      WHERE Promotion__c = :promotion.Id
    ];
    PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(new Map<String, Object>{ 'Id' => promotion.Id }),
      '[]',
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();

    PWChrono_Employee_Promotion__c updated = getPromotion();
    Assert.areEqual(promotion.Id, savedId);
    Assert.areEqual('Updated Corp', updated.Company__c);
    Assert.areEqual('Submitted', updated.Status__c, 'Save keeps the status');
    Assert.areEqual(1, linesAfterUnchanged, 'Blank details keep lines');
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM PWChrono_Promotion_Detail__c
        WHERE Promotion__c = :promotion.Id
      ],
      'An empty list removes all lines'
    );
  }

  @isTest
  static void approvedAndCancelledPromotionsCannotBeEdited() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    String recordJson = JSON.serialize(
      new Map<String, Object>{ 'Id' => promotion.Id, 'Company__c' => 'Changed' }
    );
    Test.startTest();
    setStatus(promotion.Id, 'Approved');
    String approvedError = saveError(recordJson, null, ADMIN_EMAIL);
    setStatus(promotion.Id, 'Cancelled');
    String cancelledError = saveError(recordJson, null, ADMIN_EMAIL);
    Test.stopTest();
    assertContains(approvedError, 'Approved promotions cannot be edited');
    assertContains(cancelledError, 'Cancelled promotions cannot be edited');
    Assert.areEqual('PWChrono Corp', getPromotion().Company__c);
  }

  @isTest
  static void saveValidatesInput() {
    Id employeeId = userId(EMPLOYEE_EMAIL);
    List<Map<String, Object>> tooManyLines = new List<Map<String, Object>>();
    for (Integer i = 0; i < 101; i++) {
      tooManyLines.add(new Map<String, Object>{ 'Property__c' => 'P' + i });
    }

    Test.startTest();
    String missingEmployee = saveError(
      JSON.serialize(new Map<String, Object>{ 'Company__c' => 'X' }),
      null,
      ADMIN_EMAIL
    );
    String inactiveEmployee = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Employee__c' => userId(INACTIVE_EMAIL) }
      ),
      null,
      ADMIN_EMAIL
    );
    String wrongLookupType = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'New_Department__c' => designationId('Senior Developer')
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String badDate = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'Promotion_Date__c' => 'not a date'
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String selfManager = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'New_Reports_To__c' => employeeId
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String outOfScope = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Employee__c' => userId(OUTSIDER_EMAIL) }
      ),
      null,
      HR_MANAGER_EMAIL
    );
    String blankJson = saveError('', null, ADMIN_EMAIL);
    String malformedJson = saveError('{not json', null, ADMIN_EMAIL);
    String tooLong = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'Promotion_Date__c' => today(),
          'Company__c' => 'x'.repeat(300)
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String tooManyDetails = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'Promotion_Date__c' => today()
        }
      ),
      JSON.serialize(tooManyLines),
      ADMIN_EMAIL
    );
    Test.stopTest();

    assertContains(missingEmployee, 'Employee is required');
    assertContains(inactiveEmployee, 'active employee');
    assertContains(wrongLookupType, 'Invalid value');
    assertContains(badDate, 'Invalid value');
    assertContains(selfManager, 'themselves');
    assertContains(outOfScope, 'access scope');
    assertContains(blankJson, 'required');
    assertContains(malformedJson, 'Unable to save');
    Assert.isNotNull(tooLong, 'Over-length text must be rejected');
    Assert.isFalse(
      tooLong.contains('required'),
      'The over-length check must be reached: ' + tooLong
    );
    assertContains(tooManyDetails, 'at most');
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Employee_Promotion__c]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void approvalAppliesAssignmentToEmployeeAndContact() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Id adminId = userId(ADMIN_EMAIL);
    // A stale snapshot on the record is replaced at approval.
    update new PWChrono_Employee_Promotion__c(
      Id = promotion.Id,
      Current_Department__c = departmentId('Product'),
      Current_Reports_To__c = null
    );

    Test.startTest();
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Submitted',
      adminId,
      null
    );
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Approved',
      adminId,
      null
    );
    Test.stopTest();

    Assert.areEqual('Approved', getPromotion().Status__c);
    Portal_Users__c employee = getEmployee();
    Assert.areEqual('Product', employee.Department__c);
    Assert.areEqual('Senior Developer', employee.Designation__c);
    Assert.areEqual(userId(MANAGER_EMAIL), employee.Reports_To__c);
    Contact linked = [
      SELECT Department, Title
      FROM Contact
      WHERE Id = :employee.Contact__c
    ];
    Assert.areEqual('Product', linked.Department);
    Assert.areEqual('Senior Developer', linked.Title);

    PWChrono_Employee_Promotion__c approved = [
      SELECT
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :promotion.Id
    ];
    Assert.areEqual(
      departmentId('Engineering'),
      approved.Current_Department__c,
      'The promotion records the assignment it replaced'
    );
    Assert.areEqual(
      designationId('Junior Developer'),
      approved.Current_Designation__c
    );
    Assert.areEqual(adminId, approved.Current_Reports_To__c);
  }

  @isTest
  static void futureDatedApprovalIsRejectedAndNothingChanges() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    update new PWChrono_Employee_Promotion__c(
      Id = promotion.Id,
      Status__c = 'Submitted',
      Promotion_Date__c = Date.today().addDays(10)
    );

    Test.startTest();
    String error = statusError(promotion.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();

    assertContains(error, 'takes effect on');
    Assert.areEqual('Submitted', getPromotion().Status__c);
    Portal_Users__c employee = getEmployee();
    Assert.areEqual('Engineering', employee.Department__c);
    Assert.areEqual('Junior Developer', employee.Designation__c);
    Assert.areEqual(userId(ADMIN_EMAIL), employee.Reports_To__c);
  }

  @isTest
  static void inactiveNewManagerIsRejectedOnApproval() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    setStatus(promotion.Id, 'Submitted');
    update new Portal_Users__c(
      Id = userId(MANAGER_EMAIL),
      Is_Active__c = false
    );

    Test.startTest();
    String error = statusError(promotion.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();

    assertContains(error, 'reporting manager must be an active employee');
    Assert.areEqual('Submitted', getPromotion().Status__c);
    Assert.areEqual('Engineering', getEmployee().Department__c);
  }

  @isTest
  static void allowedTransitionsSucceed() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Submitted',
      adminId,
      null
    );
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Draft',
      adminId,
      null
    );
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Cancelled',
      adminId,
      null
    );
    Test.stopTest();
    Assert.areEqual('Cancelled', getPromotion().Status__c);
    Assert.areEqual(
      'Engineering',
      getEmployee().Department__c,
      'Only approval changes the employee'
    );
  }

  @isTest
  static void invalidTransitionsAreRejected() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Test.startTest();
    String draftToApproved = statusError(promotion.Id, 'Approved', ADMIN_EMAIL);
    String draftToDraft = statusError(promotion.Id, 'Draft', ADMIN_EMAIL);
    String unknownStatus = statusError(promotion.Id, 'Bogus', ADMIN_EMAIL);
    String unknownRecord = statusError(null, 'Submitted', ADMIN_EMAIL);
    Test.stopTest();
    assertContains(draftToApproved, 'Submit it for approval first');
    assertContains(draftToDraft, 'already Draft');
    assertContains(unknownStatus, 'valid promotion status');
    assertContains(unknownRecord, 'not found');
    Assert.areEqual('Draft', getPromotion().Status__c);
  }

  @isTest
  static void approvedAndCancelledAreTerminal() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Test.startTest();
    setStatus(promotion.Id, 'Approved');
    String fromApproved = statusError(promotion.Id, 'Draft', ADMIN_EMAIL);
    String approvedToCancelled = statusError(
      promotion.Id,
      'Cancelled',
      ADMIN_EMAIL
    );
    setStatus(promotion.Id, 'Cancelled');
    String fromCancelled = statusError(promotion.Id, 'Submitted', ADMIN_EMAIL);
    Test.stopTest();
    assertContains(fromApproved, 'can no longer be changed');
    assertContains(approvedToCancelled, 'can no longer be changed');
    assertContains(fromCancelled, 'can no longer be changed');
  }

  @isTest
  static void nonAdminCannotChangeStatusOrDelete() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Test.startTest();
    String statusByManager = statusError(
      promotion.Id,
      'Submitted',
      HR_MANAGER_EMAIL
    );
    String deleteByManager = deleteError(promotion.Id, HR_MANAGER_EMAIL);
    String statusByEmployee = statusError(
      promotion.Id,
      'Submitted',
      EMPLOYEE_EMAIL
    );
    Test.stopTest();
    assertContains(statusByManager, 'Only HR administrators');
    assertContains(deleteByManager, 'Only HR administrators');
    assertContains(statusByEmployee, 'Employee Lifecycle');
    Assert.areEqual('Draft', getPromotion().Status__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Caller access
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void accessInfoReportsTheServerAdminFlag() {
    Test.startTest();
    Map<String, Object> adminInfo = PWChrono_EmployeePromotionController.getAccessInfo(
      userId(ADMIN_EMAIL),
      null
    );
    Map<String, Object> managerInfo = PWChrono_EmployeePromotionController.getAccessInfo(
      userId(HR_MANAGER_EMAIL),
      null
    );
    String deniedError;
    try {
      PWChrono_EmployeePromotionController.getAccessInfo(
        userId(EMPLOYEE_EMAIL),
        null
      );
    } catch (AuraHandledException e) {
      deniedError = e.getMessage();
    }
    Test.stopTest();
    Assert.areEqual(true, adminInfo.get('isAdmin'));
    Assert.areEqual(userId(ADMIN_EMAIL), adminInfo.get('portalUserId'));
    Assert.areEqual(false, managerInfo.get('isAdmin'));
    assertContains(deniedError, 'Employee Lifecycle');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Snapshot, required values and edit restrictions
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void newPromotionAfterApprovalUsesTheUpdatedAssignment() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    setStatus(promotion.Id, 'Submitted');
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Approved',
      adminId,
      null
    );
    // The screen may still hold the old assignment; the server ignores it.
    String newId = PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => userId(EMPLOYEE_EMAIL),
          'Promotion_Date__c' => today(),
          'Current_Department__c' => departmentId('Engineering'),
          'Current_Designation__c' => designationId('Junior Developer'),
          'Current_Reports_To__c' => adminId
        }
      ),
      null,
      adminId,
      null
    );
    Test.stopTest();
    PWChrono_Employee_Promotion__c saved = [
      SELECT
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :newId
    ];
    Assert.areEqual(departmentId('Product'), saved.Current_Department__c);
    Assert.areEqual(
      designationId('Senior Developer'),
      saved.Current_Designation__c
    );
    Assert.areEqual(userId(MANAGER_EMAIL), saved.Current_Reports_To__c);
  }

  @isTest
  static void changingTheEmployeeOnEditRefreshesTheSnapshot() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Test.startTest();
    PWChrono_EmployeePromotionController.savePromotion(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => promotion.Id,
          'Employee__c' => userId(OUTSIDER_EMAIL)
        }
      ),
      null,
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    PWChrono_Employee_Promotion__c saved = [
      SELECT
        Employee__c,
        Employee_Name__c,
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c
      FROM PWChrono_Employee_Promotion__c
      WHERE Id = :promotion.Id
    ];
    Assert.areEqual(userId(OUTSIDER_EMAIL), saved.Employee__c);
    Assert.areEqual('Promotion Outsider', saved.Employee_Name__c);
    Assert.isNull(saved.Current_Department__c, 'Sales has no department');
    Assert.isNull(saved.Current_Designation__c);
    Assert.isNull(saved.Current_Reports_To__c);
  }

  @isTest
  static void saveRequiresADateAndNonNegativeSalary() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Id employeeId = userId(EMPLOYEE_EMAIL);
    Test.startTest();
    String missingDate = saveError(
      JSON.serialize(new Map<String, Object>{ 'Employee__c' => employeeId }),
      null,
      ADMIN_EMAIL
    );
    String clearedDate = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => promotion.Id,
          'Promotion_Date__c' => null
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String negativeSalary = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'Promotion_Date__c' => today(),
          'New_Salary__c' => -1
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String negativeCurrentSalary = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => promotion.Id,
          'Current_Salary__c' => '-500'
        }
      ),
      null,
      ADMIN_EMAIL
    );
    Test.stopTest();
    assertContains(missingDate, 'Promotion Date is required');
    assertContains(clearedDate, 'Promotion Date is required');
    assertContains(negativeSalary, 'cannot be negative');
    assertContains(negativeCurrentSalary, 'cannot be negative');
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Employee_Promotion__c]);
    Assert.areEqual(Date.today(), getPromotion().Promotion_Date__c);
  }

  @isTest
  static void nonAdminCannotEditSubmittedOrOutOfScopePromotions() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    setStatus(promotion.Id, 'Submitted');
    PWChrono_Employee_Promotion__c outOfScope = new PWChrono_Employee_Promotion__c(
      Employee__c = userId(OUTSIDER_EMAIL),
      Promotion_Date__c = Date.today(),
      Company__c = 'Outside Corp',
      Status__c = 'Draft'
    );
    insert outOfScope;
    Test.startTest();
    String submittedError = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Id' => promotion.Id, 'Company__c' => 'X' }
      ),
      null,
      HR_MANAGER_EMAIL
    );
    String scopeError = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Id' => outOfScope.Id, 'Company__c' => 'X' }
      ),
      null,
      HR_MANAGER_EMAIL
    );
    Test.stopTest();
    assertContains(submittedError, 'Only an HR administrator can change it');
    assertContains(scopeError, 'not found');
    Assert.areEqual('PWChrono Corp', getPromotion().Company__c);
    Assert.areEqual(
      'Outside Corp',
      [
        SELECT Company__c
        FROM PWChrono_Employee_Promotion__c
        WHERE Id = :outOfScope.Id
      ]
      .Company__c
    );
  }

  @isTest
  static void nobodyCanManageTheirOwnPromotion() {
    Id adminId = userId(ADMIN_EMAIL);
    PWChrono_Employee_Promotion__c own = new PWChrono_Employee_Promotion__c(
      Employee__c = adminId,
      Promotion_Date__c = Date.today(),
      New_Department__c = departmentId('Product'),
      Status__c = 'Submitted'
    );
    insert own;
    Test.startTest();
    String approveOwn = statusError(own.Id, 'Approved', ADMIN_EMAIL);
    String editOwn = saveError(
      JSON.serialize(new Map<String, Object>{ 'Id' => own.Id }),
      null,
      ADMIN_EMAIL
    );
    setStatus(own.Id, 'Draft');
    String deleteOwn = deleteError(own.Id, ADMIN_EMAIL);
    String createOwnAsAdmin = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => adminId,
          'Promotion_Date__c' => today()
        }
      ),
      null,
      ADMIN_EMAIL
    );
    String createOwnAsManager = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => userId(HR_MANAGER_EMAIL),
          'Promotion_Date__c' => today()
        }
      ),
      null,
      HR_MANAGER_EMAIL
    );
    Test.stopTest();
    for (
      String message : new List<String>{
        approveOwn,
        editOwn,
        deleteOwn,
        createOwnAsAdmin,
        createOwnAsManager
      }
    ) {
      assertContains(message, 'for yourself');
    }
    Assert.areEqual(
      'Draft',
      [SELECT Status__c FROM PWChrono_Employee_Promotion__c WHERE Id = :own.Id]
      .Status__c
    );
    Assert.isNull(
      [SELECT Department__c FROM Portal_Users__c WHERE Id = :adminId]
      .Department__c,
      'A self-approval must not change the employee'
    );
    Assert.areEqual(2, [SELECT COUNT() FROM PWChrono_Employee_Promotion__c]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Approval rollback and further transitions
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void failureAfterApplyRollsBackEmployeeAndContact() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    setStatus(promotion.Id, 'Submitted');
    PWChrono_EmployeePromotionController.simulateFailureAfterApply = true;
    Test.startTest();
    String error = statusError(promotion.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();

    assertContains(error, 'Unable to update the promotion status');
    Assert.areEqual('Submitted', getPromotion().Status__c);
    Portal_Users__c employee = getEmployeeWithContact();
    Assert.areEqual('Engineering', employee.Department__c);
    Assert.areEqual('Junior Developer', employee.Designation__c);
    Assert.areEqual(userId(ADMIN_EMAIL), employee.Reports_To__c);
    Assert.areEqual('Engineering', employee.Contact__r.Department);
    Assert.areEqual('Junior Developer', employee.Contact__r.Title);
  }

  @isTest
  static void undatedPromotionCannotBeApproved() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    update new PWChrono_Employee_Promotion__c(
      Id = promotion.Id,
      Status__c = 'Submitted',
      Promotion_Date__c = null
    );
    Test.startTest();
    String error = statusError(promotion.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();
    assertContains(error, 'Set the promotion date');
    Assert.areEqual('Submitted', getPromotion().Status__c);
    Assert.areEqual('Engineering', getEmployee().Department__c);
  }

  @isTest
  static void submittedPromotionCanBeCancelled() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    setStatus(promotion.Id, 'Submitted');
    Test.startTest();
    PWChrono_EmployeePromotionController.updatePromotionStatus(
      promotion.Id,
      'Cancelled',
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual('Cancelled', getPromotion().Status__c);
    Assert.areEqual('Engineering', getEmployee().Department__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminDeletesDraftPromotionWithDetails() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Test.startTest();
    PWChrono_EmployeePromotionController.deletePromotion(
      promotion.Id,
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Promotion__c]);
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Promotion_Detail__c]);
  }

  @isTest
  static void deleteIsLimitedToDraftOrCancelled() {
    PWChrono_Employee_Promotion__c promotion = getPromotion();
    Test.startTest();
    setStatus(promotion.Id, 'Submitted');
    String submittedError = deleteError(promotion.Id, ADMIN_EMAIL);
    setStatus(promotion.Id, 'Approved');
    String approvedError = deleteError(promotion.Id, ADMIN_EMAIL);
    setStatus(promotion.Id, 'Cancelled');
    String cancelledError = deleteError(promotion.Id, ADMIN_EMAIL);
    Test.stopTest();
    assertContains(submittedError, 'Only Draft or Cancelled');
    assertContains(approvedError, 'Only Draft or Cancelled');
    Assert.isNull(cancelledError, 'Cancelled promotions can be deleted');
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Promotion__c]);
  }
}