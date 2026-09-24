/**
 * @description Tests for PWChrono_EmployeeTransferController: session and
 *              feature checks, administrator-only status changes and deletes,
 *              the status workflow, approval side effects on the employee,
 *              self-management guards, the employee snapshot and safe saving
 *              of client input.
 */
@isTest
private class PWChrono_EmployeeTransferController_Test {
  private static final String EMPLOYEE_EMAIL = 'xfer.employee@test.com';
  private static final String ADMIN_EMAIL = 'xfer.hradmin@test.com';
  private static final String HR_MANAGER_EMAIL = 'xfer.hrmanager@test.com';
  private static final String MANAGER_EMAIL = 'xfer.manager@test.com';
  private static final String OUTSIDER_EMAIL = 'xfer.outsider@test.com';
  private static final String INACTIVE_EMAIL = 'xfer.inactive@test.com';

  @testSetup
  static void setup() {
    Contact employeeContact = new Contact(
      LastName = 'Transfer Employee',
      Department = 'Engineering',
      Title = 'Developer'
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
      Name = 'Transfer HR Admin',
      Email__c = ADMIN_EMAIL,
      Role__c = PWChrono_Constants.ROLE_HR_ADMIN,
      Is_Active__c = true
    );
    Portal_Users__c hrManager = new Portal_Users__c(
      Name = 'Transfer HR Manager',
      Email__c = HR_MANAGER_EMAIL,
      Role__c = 'HR Manager',
      Department__c = 'Engineering',
      Portal_User_Profile__c = hrManagerProfile.Id,
      Is_Active__c = true
    );
    Portal_Users__c manager = new Portal_Users__c(
      Name = 'Transfer New Manager',
      Email__c = MANAGER_EMAIL,
      Role__c = 'Manager',
      Department__c = 'Operations',
      Is_Active__c = true
    );
    Portal_Users__c outsider = new Portal_Users__c(
      Name = 'Transfer Outsider',
      Email__c = OUTSIDER_EMAIL,
      Role__c = 'Employee',
      Department__c = 'Sales',
      Is_Active__c = true
    );
    Portal_Users__c inactive = new Portal_Users__c(
      Name = 'Transfer Inactive',
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
      Name = 'Transfer Employee',
      Email__c = EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Department__c = 'Engineering',
      Designation__c = 'Developer',
      Reports_To__c = admin.Id,
      Contact__c = employeeContact.Id,
      Is_Active__c = true
    );
    insert employee;

    PWChrono_Department__c engineering = new PWChrono_Department__c(
      Name = 'Engineering',
      Is_Active__c = true
    );
    PWChrono_Department__c operations = new PWChrono_Department__c(
      Name = 'Operations',
      Is_Active__c = true
    );
    insert new List<PWChrono_Department__c>{ engineering, operations };

    PWChrono_Designation__c developer = new PWChrono_Designation__c(
      Name = 'Developer',
      Is_Active__c = true
    );
    PWChrono_Designation__c analyst = new PWChrono_Designation__c(
      Name = 'Operations Analyst',
      Is_Active__c = true
    );
    insert new List<PWChrono_Designation__c>{ developer, analyst };

    insert new PWChrono_Employee_Transfer__c(
      Employee__c = employee.Id,
      Employee_Name__c = employee.Name,
      Company__c = 'PWChrono Corp',
      Transfer_Date__c = Date.today(),
      Current_Branch__c = 'HQ',
      New_Branch__c = 'North Office',
      Current_Department__c = engineering.Id,
      New_Department__c = operations.Id,
      Current_Designation__c = developer.Id,
      New_Designation__c = analyst.Id,
      Current_Reports_To__c = admin.Id,
      New_Reports_To__c = manager.Id,
      Status__c = 'Draft'
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

  private static PWChrono_Employee_Transfer__c getTransfer() {
    return [
      SELECT Id, Status__c, Company__c, Transfer_Date__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Employee__c = :userId(EMPLOYEE_EMAIL)
      LIMIT 1
    ];
  }

  private static void setStatus(Id transferId, String status) {
    update new PWChrono_Employee_Transfer__c(
      Id = transferId,
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
    Id transferId,
    String newStatus,
    String actorEmail
  ) {
    try {
      PWChrono_EmployeeTransferController.updateTransferStatus(
        transferId,
        newStatus,
        userId(actorEmail),
        null
      );
      return null;
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
  }

  private static String saveError(String transferJson, String actorEmail) {
    try {
      PWChrono_EmployeeTransferController.saveTransfer(
        transferJson,
        userId(actorEmail),
        null
      );
      return null;
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
  }

  private static String deleteError(Id transferId, String actorEmail) {
    try {
      PWChrono_EmployeeTransferController.deleteTransfer(
        transferId,
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
  static void adminSeesAllTransfersAndCanFilterByStatus() {
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    List<PWChrono_Employee_Transfer__c> all = PWChrono_EmployeeTransferController.getTransfers(
      'All',
      adminId,
      null
    );
    List<PWChrono_Employee_Transfer__c> drafts = PWChrono_EmployeeTransferController.getTransfers(
      'Draft',
      adminId,
      null
    );
    List<PWChrono_Employee_Transfer__c> approved = PWChrono_EmployeeTransferController.getTransfers(
      'Approved',
      adminId,
      null
    );
    Test.stopTest();
    Assert.areEqual(1, all.size());
    Assert.areEqual(1, drafts.size());
    Assert.areEqual(0, approved.size());
    Assert.areEqual('Transfer Employee', all[0].Employee__r.Name);
  }

  @isTest
  static void nonAdminSeesOnlyTransfersInScope() {
    insert new PWChrono_Employee_Transfer__c(
      Employee__c = userId(OUTSIDER_EMAIL),
      Transfer_Date__c = Date.today(),
      Status__c = 'Draft'
    );
    Test.startTest();
    List<PWChrono_Employee_Transfer__c> scoped = PWChrono_EmployeeTransferController.getTransfers(
      null,
      userId(HR_MANAGER_EMAIL),
      null
    );
    List<PWChrono_Employee_Transfer__c> all = PWChrono_EmployeeTransferController.getTransfers(
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
    Assert.areEqual(2, all.size(), 'Administrators see every transfer');
  }

  @isTest
  static void getTransferByIdHonoursScope() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    PWChrono_Employee_Transfer__c outOfScope = new PWChrono_Employee_Transfer__c(
      Employee__c = userId(OUTSIDER_EMAIL),
      Status__c = 'Draft'
    );
    insert outOfScope;

    Test.startTest();
    PWChrono_Employee_Transfer__c result = PWChrono_EmployeeTransferController.getTransferById(
      transfer.Id,
      userId(HR_MANAGER_EMAIL),
      null
    );
    String scopeError;
    try {
      PWChrono_EmployeeTransferController.getTransferById(
        outOfScope.Id,
        userId(HR_MANAGER_EMAIL),
        null
      );
    } catch (AuraHandledException e) {
      scopeError = e.getMessage();
    }
    String unknownError;
    try {
      PWChrono_EmployeeTransferController.getTransferById(
        'not-an-id',
        userId(ADMIN_EMAIL),
        null
      );
    } catch (AuraHandledException e) {
      unknownError = e.getMessage();
    }
    Test.stopTest();
    Assert.areEqual('PWChrono Corp', result.Company__c);
    assertContains(scopeError, 'not found');
    assertContains(unknownError, 'not found');
  }

  @isTest
  static void lookupsReturnActiveRecordsForFeatureHolders() {
    Id hrManagerId = userId(HR_MANAGER_EMAIL);
    Test.startTest();
    List<PWChrono_Designation__c> designations = PWChrono_EmployeeTransferController.getActiveDesignations(
      hrManagerId,
      null
    );
    List<PWChrono_Department__c> departments = PWChrono_EmployeeTransferController.getActiveDepartments(
      hrManagerId,
      null
    );
    List<Portal_Users__c> employees = PWChrono_EmployeeTransferController.getActiveEmployees(
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
      PWChrono_EmployeeTransferController.getTransfers('All', employeeId, null);
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeeTransferController.getTransferById(
        getTransfer().Id,
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeeTransferController.getActiveEmployees(employeeId, null);
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeeTransferController.getActiveDepartments(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    try {
      PWChrono_EmployeeTransferController.getActiveDesignations(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      errors.add(e.getMessage());
    }
    errors.add(
      saveError(
        JSON.serialize(new Map<String, Object>{ 'Employee__c' => employeeId }),
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
      [SELECT COUNT() FROM PWChrono_Employee_Transfer__c],
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
    admin.Session_Token__c = 'guest_transfer_token';
    admin.Session_Expires_At__c = System.now().addHours(1);
    update admin;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Employee_Transfer__c> results = PWChrono_EmployeeTransferController.getTransfers(
        'All',
        String.valueOf(admin.Id),
        'guest_transfer_token'
      );
      String error;
      try {
        PWChrono_EmployeeTransferController.getActiveEmployees(
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
    Map<String, Object> record = new Map<String, Object>{
      'Employee__c' => userId(EMPLOYEE_EMAIL),
      'Transfer_Date__c' => String.valueOf(Date.today()),
      'Company__c' => 'New Corp',
      'Current_Branch__c' => 'HQ',
      'New_Branch__c' => 'South Office',
      'New_Department__c' => departmentId('Operations'),
      'Status__c' => 'Approved',
      'Employee_Name__c' => 'Forged name',
      'Current_Department__c' => departmentId('Operations'),
      'Current_Designation__c' => designationId('Operations Analyst'),
      'Current_Reports_To__c' => userId(MANAGER_EMAIL)
    };

    Test.startTest();
    String newId = PWChrono_EmployeeTransferController.saveTransfer(
      JSON.serialize(record),
      userId(HR_MANAGER_EMAIL),
      null
    );
    Test.stopTest();

    PWChrono_Employee_Transfer__c saved = [
      SELECT
        Status__c,
        Employee_Name__c,
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c,
        New_Department__c,
        New_Branch__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :newId
    ];
    Assert.areEqual('Draft', saved.Status__c, 'Client cannot set the status');
    Assert.areEqual(
      'Transfer Employee',
      saved.Employee_Name__c,
      'The name comes from the employee record'
    );
    Assert.areEqual(departmentId('Engineering'), saved.Current_Department__c);
    Assert.areEqual(designationId('Developer'), saved.Current_Designation__c);
    Assert.areEqual(userId(ADMIN_EMAIL), saved.Current_Reports_To__c);
    Assert.areEqual(departmentId('Operations'), saved.New_Department__c);
    Assert.areEqual('South Office', saved.New_Branch__c);
  }

  @isTest
  static void editKeepsStatus() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    setStatus(transfer.Id, 'Submitted');
    Map<String, Object> record = new Map<String, Object>{
      'Id' => transfer.Id,
      'Company__c' => 'Updated Corp',
      'Status__c' => 'Approved'
    };
    Test.startTest();
    String savedId = PWChrono_EmployeeTransferController.saveTransfer(
      JSON.serialize(record),
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    PWChrono_Employee_Transfer__c updated = getTransfer();
    Assert.areEqual(transfer.Id, savedId);
    Assert.areEqual('Updated Corp', updated.Company__c);
    Assert.areEqual('Submitted', updated.Status__c, 'Save keeps the status');
  }

  @isTest
  static void approvedAndCancelledTransfersCannotBeEdited() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    String recordJson = JSON.serialize(
      new Map<String, Object>{ 'Id' => transfer.Id, 'Company__c' => 'Changed' }
    );
    Test.startTest();
    setStatus(transfer.Id, 'Approved');
    String approvedError = saveError(recordJson, ADMIN_EMAIL);
    setStatus(transfer.Id, 'Cancelled');
    String cancelledError = saveError(recordJson, ADMIN_EMAIL);
    Test.stopTest();
    assertContains(approvedError, 'Approved transfers cannot be edited');
    assertContains(cancelledError, 'Cancelled transfers cannot be edited');
    Assert.areEqual('PWChrono Corp', getTransfer().Company__c);
  }

  @isTest
  static void saveValidatesInput() {
    Id employeeId = userId(EMPLOYEE_EMAIL);
    Test.startTest();
    String missingEmployee = saveError(
      JSON.serialize(new Map<String, Object>{ 'Company__c' => 'X' }),
      ADMIN_EMAIL
    );
    String inactiveEmployee = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Employee__c' => userId(INACTIVE_EMAIL) }
      ),
      ADMIN_EMAIL
    );
    String wrongLookupType = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'New_Designation__c' => departmentId('Operations')
        }
      ),
      ADMIN_EMAIL
    );
    String badDate = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'Transfer_Date__c' => '31/31/2020'
        }
      ),
      ADMIN_EMAIL
    );
    String selfManager = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'New_Reports_To__c' => employeeId
        }
      ),
      ADMIN_EMAIL
    );
    String outOfScope = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Employee__c' => userId(OUTSIDER_EMAIL) }
      ),
      HR_MANAGER_EMAIL
    );
    String unknownRecord = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => employeeId,
          'Employee__c' => employeeId
        }
      ),
      ADMIN_EMAIL
    );
    String blankJson = saveError(null, ADMIN_EMAIL);
    String malformedJson = saveError('[1, 2', ADMIN_EMAIL);
    String tooLong = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => employeeId,
          'Transfer_Date__c' => today(),
          'New_Branch__c' => 'x'.repeat(300)
        }
      ),
      ADMIN_EMAIL
    );
    Test.stopTest();

    assertContains(missingEmployee, 'Employee is required');
    assertContains(inactiveEmployee, 'active employee');
    assertContains(wrongLookupType, 'Invalid value');
    assertContains(badDate, 'Invalid value');
    assertContains(selfManager, 'themselves');
    assertContains(outOfScope, 'access scope');
    assertContains(unknownRecord, 'not found');
    assertContains(blankJson, 'required');
    assertContains(malformedJson, 'Unable to save');
    Assert.isNotNull(tooLong, 'Over-length text must be rejected');
    Assert.isFalse(
      tooLong.contains('required'),
      'The over-length check must be reached: ' + tooLong
    );
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Employee_Transfer__c]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void approvalAppliesAssignmentToEmployeeAndContact() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Id adminId = userId(ADMIN_EMAIL);
    // A stale snapshot on the record is replaced at approval.
    update new PWChrono_Employee_Transfer__c(
      Id = transfer.Id,
      Current_Department__c = departmentId('Operations'),
      Current_Reports_To__c = null
    );

    Test.startTest();
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Submitted',
      adminId,
      null
    );
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Approved',
      adminId,
      null
    );
    Test.stopTest();

    Assert.areEqual('Approved', getTransfer().Status__c);
    Portal_Users__c employee = getEmployee();
    Assert.areEqual('Operations', employee.Department__c);
    Assert.areEqual('Operations Analyst', employee.Designation__c);
    Assert.areEqual(userId(MANAGER_EMAIL), employee.Reports_To__c);
    Contact linked = [
      SELECT Department, Title
      FROM Contact
      WHERE Id = :employee.Contact__c
    ];
    Assert.areEqual('Operations', linked.Department);
    Assert.areEqual('Operations Analyst', linked.Title);

    PWChrono_Employee_Transfer__c approved = [
      SELECT
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :transfer.Id
    ];
    Assert.areEqual(
      departmentId('Engineering'),
      approved.Current_Department__c,
      'The transfer records the assignment it replaced'
    );
    Assert.areEqual(
      designationId('Developer'),
      approved.Current_Designation__c
    );
    Assert.areEqual(adminId, approved.Current_Reports_To__c);
  }

  @isTest
  static void futureDatedApprovalIsRejectedAndNothingChanges() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    update new PWChrono_Employee_Transfer__c(
      Id = transfer.Id,
      Status__c = 'Submitted',
      Transfer_Date__c = Date.today().addDays(7)
    );

    Test.startTest();
    String error = statusError(transfer.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();

    assertContains(error, 'takes effect on');
    Assert.areEqual('Submitted', getTransfer().Status__c);
    Portal_Users__c employee = getEmployee();
    Assert.areEqual('Engineering', employee.Department__c);
    Assert.areEqual('Developer', employee.Designation__c);
    Assert.areEqual(userId(ADMIN_EMAIL), employee.Reports_To__c);
  }

  @isTest
  static void inactiveNewManagerIsRejectedOnApproval() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    setStatus(transfer.Id, 'Submitted');
    update new Portal_Users__c(
      Id = userId(MANAGER_EMAIL),
      Is_Active__c = false
    );

    Test.startTest();
    String error = statusError(transfer.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();

    assertContains(error, 'reporting manager must be an active employee');
    Assert.areEqual('Submitted', getTransfer().Status__c);
    Assert.areEqual('Engineering', getEmployee().Department__c);
  }

  @isTest
  static void allowedTransitionsSucceed() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Submitted',
      adminId,
      null
    );
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Draft',
      adminId,
      null
    );
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Submitted',
      adminId,
      null
    );
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Cancelled',
      adminId,
      null
    );
    Test.stopTest();
    Assert.areEqual('Cancelled', getTransfer().Status__c);
    Assert.areEqual(
      'Engineering',
      getEmployee().Department__c,
      'Only approval changes the employee'
    );
  }

  @isTest
  static void invalidTransitionsAreRejected() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    String draftToApproved = statusError(transfer.Id, 'Approved', ADMIN_EMAIL);
    String draftToDraft = statusError(transfer.Id, 'Draft', ADMIN_EMAIL);
    String unknownStatus = statusError(transfer.Id, '', ADMIN_EMAIL);
    String unknownRecord = statusError(null, 'Submitted', ADMIN_EMAIL);
    Test.stopTest();
    assertContains(draftToApproved, 'Submit it for approval first');
    assertContains(draftToDraft, 'already Draft');
    assertContains(unknownStatus, 'valid transfer status');
    assertContains(unknownRecord, 'not found');
    Assert.areEqual('Draft', getTransfer().Status__c);
  }

  @isTest
  static void approvedAndCancelledAreTerminal() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    setStatus(transfer.Id, 'Approved');
    String fromApproved = statusError(transfer.Id, 'Submitted', ADMIN_EMAIL);
    String approvedToCancelled = statusError(
      transfer.Id,
      'Cancelled',
      ADMIN_EMAIL
    );
    setStatus(transfer.Id, 'Cancelled');
    String fromCancelled = statusError(transfer.Id, 'Draft', ADMIN_EMAIL);
    Test.stopTest();
    assertContains(fromApproved, 'can no longer be changed');
    assertContains(approvedToCancelled, 'can no longer be changed');
    assertContains(fromCancelled, 'can no longer be changed');
  }

  @isTest
  static void nonAdminCannotChangeStatusOrDelete() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    String statusByManager = statusError(
      transfer.Id,
      'Submitted',
      HR_MANAGER_EMAIL
    );
    String deleteByManager = deleteError(transfer.Id, HR_MANAGER_EMAIL);
    String deleteByEmployee = deleteError(transfer.Id, EMPLOYEE_EMAIL);
    Test.stopTest();
    assertContains(statusByManager, 'Only HR administrators');
    assertContains(deleteByManager, 'Only HR administrators');
    assertContains(deleteByEmployee, 'Employee Lifecycle');
    Assert.areEqual('Draft', getTransfer().Status__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Caller access
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void accessInfoReportsTheServerAdminFlag() {
    Test.startTest();
    Map<String, Object> adminInfo = PWChrono_EmployeeTransferController.getAccessInfo(
      userId(ADMIN_EMAIL),
      null
    );
    Map<String, Object> managerInfo = PWChrono_EmployeeTransferController.getAccessInfo(
      userId(HR_MANAGER_EMAIL),
      null
    );
    String deniedError;
    try {
      PWChrono_EmployeeTransferController.getAccessInfo(
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
  static void newTransferAfterApprovalUsesTheUpdatedAssignment() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    setStatus(transfer.Id, 'Submitted');
    Id adminId = userId(ADMIN_EMAIL);
    Test.startTest();
    PWChrono_EmployeeTransferController.updateTransferStatus(
      transfer.Id,
      'Approved',
      adminId,
      null
    );
    // The screen may still hold the old assignment; the server ignores it.
    String newId = PWChrono_EmployeeTransferController.saveTransfer(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => userId(EMPLOYEE_EMAIL),
          'Transfer_Date__c' => today(),
          'Current_Department__c' => departmentId('Engineering'),
          'Current_Designation__c' => designationId('Developer'),
          'Current_Reports_To__c' => adminId
        }
      ),
      adminId,
      null
    );
    Test.stopTest();
    PWChrono_Employee_Transfer__c saved = [
      SELECT
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :newId
    ];
    Assert.areEqual(departmentId('Operations'), saved.Current_Department__c);
    Assert.areEqual(
      designationId('Operations Analyst'),
      saved.Current_Designation__c
    );
    Assert.areEqual(userId(MANAGER_EMAIL), saved.Current_Reports_To__c);
  }

  @isTest
  static void changingTheEmployeeOnEditRefreshesTheSnapshot() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    PWChrono_EmployeeTransferController.saveTransfer(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => transfer.Id,
          'Employee__c' => userId(OUTSIDER_EMAIL)
        }
      ),
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    PWChrono_Employee_Transfer__c saved = [
      SELECT
        Employee__c,
        Employee_Name__c,
        Current_Department__c,
        Current_Designation__c,
        Current_Reports_To__c
      FROM PWChrono_Employee_Transfer__c
      WHERE Id = :transfer.Id
    ];
    Assert.areEqual(userId(OUTSIDER_EMAIL), saved.Employee__c);
    Assert.areEqual('Transfer Outsider', saved.Employee_Name__c);
    Assert.isNull(saved.Current_Department__c, 'Sales has no department');
    Assert.isNull(saved.Current_Designation__c);
    Assert.isNull(saved.Current_Reports_To__c);
  }

  @isTest
  static void saveRequiresATransferDate() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    String missingDate = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Employee__c' => userId(EMPLOYEE_EMAIL) }
      ),
      ADMIN_EMAIL
    );
    String clearedDate = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => transfer.Id,
          'Transfer_Date__c' => null
        }
      ),
      ADMIN_EMAIL
    );
    Test.stopTest();
    assertContains(missingDate, 'Transfer Date is required');
    assertContains(clearedDate, 'Transfer Date is required');
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Employee_Transfer__c]);
    Assert.areEqual(Date.today(), getTransfer().Transfer_Date__c);
  }

  @isTest
  static void nonAdminCannotEditSubmittedOrOutOfScopeTransfers() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    setStatus(transfer.Id, 'Submitted');
    PWChrono_Employee_Transfer__c outOfScope = new PWChrono_Employee_Transfer__c(
      Employee__c = userId(OUTSIDER_EMAIL),
      Transfer_Date__c = Date.today(),
      Company__c = 'Outside Corp',
      Status__c = 'Draft'
    );
    insert outOfScope;
    Test.startTest();
    String submittedError = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Id' => transfer.Id, 'Company__c' => 'X' }
      ),
      HR_MANAGER_EMAIL
    );
    String scopeError = saveError(
      JSON.serialize(
        new Map<String, Object>{ 'Id' => outOfScope.Id, 'Company__c' => 'X' }
      ),
      HR_MANAGER_EMAIL
    );
    Test.stopTest();
    assertContains(submittedError, 'Only an HR administrator can change it');
    assertContains(scopeError, 'not found');
    Assert.areEqual('PWChrono Corp', getTransfer().Company__c);
    Assert.areEqual(
      'Outside Corp',
      [
        SELECT Company__c
        FROM PWChrono_Employee_Transfer__c
        WHERE Id = :outOfScope.Id
      ]
      .Company__c
    );
  }

  @isTest
  static void nobodyCanManageTheirOwnTransfer() {
    Id adminId = userId(ADMIN_EMAIL);
    PWChrono_Employee_Transfer__c own = new PWChrono_Employee_Transfer__c(
      Employee__c = adminId,
      Transfer_Date__c = Date.today(),
      New_Department__c = departmentId('Operations'),
      Status__c = 'Submitted'
    );
    insert own;
    Test.startTest();
    String approveOwn = statusError(own.Id, 'Approved', ADMIN_EMAIL);
    String editOwn = saveError(
      JSON.serialize(new Map<String, Object>{ 'Id' => own.Id }),
      ADMIN_EMAIL
    );
    setStatus(own.Id, 'Draft');
    String deleteOwn = deleteError(own.Id, ADMIN_EMAIL);
    String createOwnAsAdmin = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => adminId,
          'Transfer_Date__c' => today()
        }
      ),
      ADMIN_EMAIL
    );
    String createOwnAsManager = saveError(
      JSON.serialize(
        new Map<String, Object>{
          'Employee__c' => userId(HR_MANAGER_EMAIL),
          'Transfer_Date__c' => today()
        }
      ),
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
      [SELECT Status__c FROM PWChrono_Employee_Transfer__c WHERE Id = :own.Id]
      .Status__c
    );
    Assert.isNull(
      [SELECT Department__c FROM Portal_Users__c WHERE Id = :adminId]
      .Department__c,
      'A self-approval must not change the employee'
    );
    Assert.areEqual(2, [SELECT COUNT() FROM PWChrono_Employee_Transfer__c]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Approval rollback and further transitions
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void failureAfterApplyRollsBackEmployeeAndContact() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    setStatus(transfer.Id, 'Submitted');
    PWChrono_EmployeeTransferController.simulateFailureAfterApply = true;
    Test.startTest();
    String error = statusError(transfer.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();

    assertContains(error, 'Unable to update the transfer status');
    Assert.areEqual('Submitted', getTransfer().Status__c);
    Portal_Users__c employee = getEmployeeWithContact();
    Assert.areEqual('Engineering', employee.Department__c);
    Assert.areEqual('Developer', employee.Designation__c);
    Assert.areEqual(userId(ADMIN_EMAIL), employee.Reports_To__c);
    Assert.areEqual('Engineering', employee.Contact__r.Department);
    Assert.areEqual('Developer', employee.Contact__r.Title);
  }

  @isTest
  static void undatedTransferCannotBeApproved() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    update new PWChrono_Employee_Transfer__c(
      Id = transfer.Id,
      Status__c = 'Submitted',
      Transfer_Date__c = null
    );
    Test.startTest();
    String error = statusError(transfer.Id, 'Approved', ADMIN_EMAIL);
    Test.stopTest();
    assertContains(error, 'Set the transfer date');
    Assert.areEqual('Submitted', getTransfer().Status__c);
    Assert.areEqual('Engineering', getEmployee().Department__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminDeletesDraftTransfer() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    PWChrono_EmployeeTransferController.deleteTransfer(
      transfer.Id,
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Transfer__c]);
  }

  @isTest
  static void deleteIsLimitedToDraftOrCancelled() {
    PWChrono_Employee_Transfer__c transfer = getTransfer();
    Test.startTest();
    setStatus(transfer.Id, 'Submitted');
    String submittedError = deleteError(transfer.Id, ADMIN_EMAIL);
    setStatus(transfer.Id, 'Approved');
    String approvedError = deleteError(transfer.Id, ADMIN_EMAIL);
    setStatus(transfer.Id, 'Cancelled');
    String cancelledError = deleteError(transfer.Id, ADMIN_EMAIL);
    Test.stopTest();
    assertContains(submittedError, 'Only Draft or Cancelled');
    assertContains(approvedError, 'Only Draft or Cancelled');
    Assert.isNull(cancelledError, 'Cancelled transfers can be deleted');
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Transfer__c]);
  }
}