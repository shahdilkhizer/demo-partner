@isTest
private class PWChrono_FFSettlement_Test {
  private static final String EMPLOYEE_EMAIL = 'semp@test.com';
  private static final String LEAVER_EMAIL = 'leaver@test.com';
  private static final String HR_ADMIN_EMAIL = 'hr@test.com';
  private static final String HR_MANAGER_EMAIL = 'hr.manager@test.com';

  @testSetup
  static void setupData() {
    Portal_User_Profile__c hrManagerProfile = new Portal_User_Profile__c(
      Profile_Type__c = 'HR Manager',
      Is_Active__c = true
    );
    insert hrManagerProfile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = hrManagerProfile.Id,
      Feature_Key__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Feature_Label__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Is_Enabled__c = true
    );

    Portal_Users__c hrAdmin = new Portal_Users__c(
      Name = 'HR Admin',
      Email__c = HR_ADMIN_EMAIL,
      Role__c = PWChrono_AccessController.ROLE_HR_ADMIN,
      Is_Active__c = true
    );
    Portal_Users__c hrManager = new Portal_Users__c(
      Name = 'HR Manager',
      Email__c = HR_MANAGER_EMAIL,
      Role__c = PWChrono_AccessController.ROLE_HR_MANAGER,
      Portal_User_Profile__c = hrManagerProfile.Id,
      Is_Active__c = true
    );
    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Settlement Employee',
      Email__c = EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true
    );
    Portal_Users__c leaver = new Portal_Users__c(
      Name = 'Departed Leaver',
      Email__c = LEAVER_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = false,
      Date_of_Joining__c = Date.newInstance(2020, 1, 15)
    );
    insert new List<Portal_Users__c>{ hrAdmin, hrManager, employee, leaver };

    PWChrono_Department__c dept = new PWChrono_Department__c(
      Name = 'Finance',
      Is_Active__c = true
    );
    insert dept;
    PWChrono_Designation__c desig = new PWChrono_Designation__c(
      Name = 'Accountant',
      Is_Active__c = true
    );
    insert desig;

    PWChrono_Employee_Separation__c sep = new PWChrono_Employee_Separation__c(
      Employee__c = employee.Id,
      Status__c = 'Pending',
      Resignation_Letter_Date__c = Date.today()
    );
    PWChrono_Employee_Separation__c leaverSep = new PWChrono_Employee_Separation__c(
      Employee__c = leaver.Id,
      Employee_Name__c = 'Departed Leaver',
      Company__c = 'PulseWork',
      Department__c = dept.Id,
      Designation__c = desig.Id,
      Status__c = 'Completed',
      Resignation_Letter_Date__c = Date.today().addDays(-30),
      Relieving_Date__c = Date.today().addDays(-1)
    );
    insert new List<PWChrono_Employee_Separation__c>{ sep, leaverSep };

    PWChrono_Full_Final_Settlement__c settlement = new PWChrono_Full_Final_Settlement__c(
      Employee__c = employee.Id,
      Employee_Name__c = 'Settlement Employee',
      Company__c = 'PulseWork',
      Department__c = dept.Id,
      Designation__c = desig.Id,
      Separation__c = sep.Id,
      Date_of_Joining__c = Date.today().addYears(-3),
      Relieving_Date__c = Date.today(),
      Status__c = 'Draft',
      Total_Payable__c = 5000,
      Total_Receivable__c = 2000,
      Net_Payable__c = 3000
    );
    insert settlement;

    insert new PWChrono_Settlement_Payable__c(
      Settlement__c = settlement.Id,
      Name = 'Salary Payable',
      Component__c = 'Basic Salary',
      Amount__c = 5000,
      Status__c = 'Pending'
    );
    insert new PWChrono_Settlement_Receivable__c(
      Settlement__c = settlement.Id,
      Name = 'Loan Recovery',
      Component__c = 'Personal Loan',
      Amount__c = 2000,
      Status__c = 'Pending'
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Id userId(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  private static PWChrono_Full_Final_Settlement__c getSettlement() {
    return [
      SELECT
        Id,
        Status__c,
        Company__c,
        Employee__c,
        Separation__c,
        Total_Payable__c,
        Total_Receivable__c,
        Net_Payable__c
      FROM PWChrono_Full_Final_Settlement__c
      WHERE Employee__r.Email__c = :EMPLOYEE_EMAIL
      LIMIT 1
    ];
  }

  private static PWChrono_Employee_Separation__c getLeaverSeparation() {
    return [
      SELECT Id, Employee__c, Department__c, Designation__c, Relieving_Date__c
      FROM PWChrono_Employee_Separation__c
      WHERE Employee__r.Email__c = :LEAVER_EMAIL
      LIMIT 1
    ];
  }

  private static Id missingSettlementId() {
    return Id.valueOf(
      PWChrono_Full_Final_Settlement__c.SObjectType.getDescribe()
        .getKeyPrefix() + '000000000001'
    );
  }

  private static void setStatus(Id settlementId, String status) {
    update new PWChrono_Full_Final_Settlement__c(
      Id = settlementId,
      Status__c = status
    );
  }

  private static Map<String, Object> line(
    String component,
    Object amount,
    String status
  ) {
    return new Map<String, Object>{
      'Component__c' => component,
      'Amount__c' => amount,
      'Status__c' => status
    };
  }

  private static String saveError(
    Map<String, Object> rec,
    Object payables,
    Object receivables,
    Id actorId
  ) {
    try {
      PWChrono_FullFinalSettlementController.saveSettlement(
        JSON.serialize(rec),
        payables == null ? null : JSON.serialize(payables),
        receivables == null ? null : JSON.serialize(receivables),
        actorId,
        ''
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('saveSettlement should have failed.');
    return null;
  }

  private static String statusError(
    Id settlementId,
    String status,
    Id actorId
  ) {
    try {
      PWChrono_FullFinalSettlementController.updateSettlementStatus(
        settlementId,
        status,
        actorId,
        ''
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('updateSettlementStatus should have failed.');
    return null;
  }

  private static String deleteError(String settlementId, Id actorId) {
    try {
      PWChrono_FullFinalSettlementController.deleteSettlement(
        settlementId,
        actorId,
        ''
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('deleteSettlement should have failed.');
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reads and access
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void getSettlementsReturnsAllAndFilters() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    List<PWChrono_Full_Final_Settlement__c> all = PWChrono_FullFinalSettlementController.getSettlements(
      'All',
      hrId,
      ''
    );
    List<PWChrono_Full_Final_Settlement__c> drafts = PWChrono_FullFinalSettlementController.getSettlements(
      'Draft',
      userId(HR_MANAGER_EMAIL),
      ''
    );
    List<PWChrono_Full_Final_Settlement__c> paid = PWChrono_FullFinalSettlementController.getSettlements(
      'Paid',
      hrId,
      ''
    );
    Test.stopTest();
    Assert.areEqual(1, all.size());
    Assert.areEqual('Settlement Employee', all[0].Employee__r.Name);
    Assert.areEqual(1, drafts.size());
    Assert.areEqual(0, paid.size());
  }

  @isTest
  static void getSettlementDetailAndLines() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Id settlementId = getSettlement().Id;
    String missing;
    Test.startTest();
    PWChrono_Full_Final_Settlement__c result = PWChrono_FullFinalSettlementController.getSettlementById(
      settlementId,
      hrId,
      ''
    );
    List<PWChrono_Settlement_Payable__c> payables = PWChrono_FullFinalSettlementController.getPayables(
      settlementId,
      hrId,
      ''
    );
    List<PWChrono_Settlement_Receivable__c> receivables = PWChrono_FullFinalSettlementController.getReceivables(
      settlementId,
      hrId,
      ''
    );
    try {
      PWChrono_FullFinalSettlementController.getSettlementById(
        missingSettlementId(),
        hrId,
        ''
      );
    } catch (AuraHandledException e) {
      missing = e.getMessage();
    }
    Test.stopTest();
    Assert.areEqual(settlementId, result.Id);
    Assert.areEqual(1, payables.size());
    Assert.areEqual(1, receivables.size());
    Assert.areEqual('Settlement not found.', missing);
  }

  @isTest
  static void userWithoutFeatureIsDenied() {
    Id employeeId = userId(EMPLOYEE_EMAIL);
    Id settlementId = getSettlement().Id;
    Integer denied = 0;
    Test.startTest();
    try {
      PWChrono_FullFinalSettlementController.getSettlements(
        'All',
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Employee Lifecycle'));
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getSettlementById(
        settlementId,
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getPayables(
        settlementId,
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getReceivables(
        settlementId,
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.saveSettlement(
        JSON.serialize(new Map<String, Object>{ 'Id' => settlementId }),
        null,
        null,
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getActiveDesignations(
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getActiveDepartments(
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getActiveEmployees(employeeId, '');
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_FullFinalSettlementController.getActiveSeparations(
        employeeId,
        ''
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    Test.stopTest();
    Assert.areEqual(9, denied);
  }

  @isTest
  static void guestSessionIsVerified() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = :HR_ADMIN_EMAIL
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_ffs_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    String denied;
    try {
      Test.startTest();
      List<PWChrono_Full_Final_Settlement__c> results = PWChrono_FullFinalSettlementController.getSettlements(
        'All',
        String.valueOf(hr.Id),
        'guest_ffs_token'
      );
      try {
        PWChrono_FullFinalSettlementController.getSettlements(
          'All',
          String.valueOf(hr.Id),
          'stolen'
        );
      } catch (AuraHandledException e) {
        denied = e.getMessage();
      }
      Test.stopTest();
      Assert.areEqual(1, results.size());
      Assert.isTrue(denied.startsWith('Session invalid'), denied);
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void saveInsertStartsDraftAndComputesTotals() {
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => userId(LEAVER_EMAIL),
      'Company__c' => 'PW Corp',
      'Relieving_Date__c' => String.valueOf(Date.today()),
      'Status__c' => 'Paid',
      'Total_Payable__c' => 999999
    };
    List<Object> payables = new List<Object>{
      line('Leave Encashment', 1000, 'Pending'),
      line('Bonus', '250.50', 'Paid'),
      line('Waived Allowance', 400, 'Waived')
    };
    List<Object> receivables = new List<Object>{
      line('Laptop', 500, null),
      line('Advance', 100, 'Waived')
    };

    Test.startTest();
    String newId = PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(rec),
      JSON.serialize(payables),
      JSON.serialize(receivables),
      userId(HR_MANAGER_EMAIL),
      ''
    );
    Test.stopTest();

    PWChrono_Full_Final_Settlement__c created = [
      SELECT
        Status__c,
        Total_Payable__c,
        Total_Receivable__c,
        Net_Payable__c,
        Employee_Name__c,
        Date_of_Joining__c
      FROM PWChrono_Full_Final_Settlement__c
      WHERE Id = :newId
    ];
    Assert.areEqual('Draft', created.Status__c, 'Status is server-owned.');
    Assert.areEqual(1250.50, created.Total_Payable__c);
    Assert.areEqual(500, created.Total_Receivable__c);
    Assert.areEqual(750.50, created.Net_Payable__c);
    Assert.areEqual('Departed Leaver', created.Employee_Name__c);
    Assert.areEqual(Date.newInstance(2020, 1, 15), created.Date_of_Joining__c);
    List<PWChrono_Settlement_Payable__c> savedPayables = [
      SELECT Name, Status__c
      FROM PWChrono_Settlement_Payable__c
      WHERE Settlement__c = :newId
      ORDER BY Name
    ];
    Assert.areEqual(3, savedPayables.size());
    Assert.areEqual('Bonus', savedPayables[0].Name);
    Assert.areEqual(
      'Pending',
      [
        SELECT Status__c
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :newId AND Name = 'Laptop'
      ]
      .Status__c
    );
  }

  @isTest
  static void saveInsertDefaultsFromSeparation() {
    PWChrono_Employee_Separation__c sep = getLeaverSeparation();
    Map<String, Object> rec = new Map<String, Object>{
      'Separation__c' => sep.Id,
      'Employee__c' => '',
      'Relieving_Date__c' => ''
    };
    Test.startTest();
    String newId = PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(rec),
      '[]',
      '[]',
      userId(HR_ADMIN_EMAIL),
      ''
    );
    Test.stopTest();

    PWChrono_Full_Final_Settlement__c created = [
      SELECT
        Employee__c,
        Employee_Name__c,
        Company__c,
        Department__c,
        Designation__c,
        Relieving_Date__c,
        Date_of_Joining__c,
        Total_Payable__c,
        Net_Payable__c
      FROM PWChrono_Full_Final_Settlement__c
      WHERE Id = :newId
    ];
    Assert.areEqual(sep.Employee__c, created.Employee__c);
    Assert.areEqual('Departed Leaver', created.Employee_Name__c);
    Assert.areEqual('PulseWork', created.Company__c);
    Assert.areEqual(sep.Department__c, created.Department__c);
    Assert.areEqual(sep.Designation__c, created.Designation__c);
    Assert.areEqual(sep.Relieving_Date__c, created.Relieving_Date__c);
    Assert.areEqual(Date.newInstance(2020, 1, 15), created.Date_of_Joining__c);
    Assert.areEqual(0, created.Total_Payable__c);
    Assert.areEqual(0, created.Net_Payable__c);
  }

  @isTest
  static void saveEnforcesSeparationRules() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    PWChrono_Full_Final_Settlement__c existing = getSettlement();
    PWChrono_Employee_Separation__c leaverSep = getLeaverSeparation();

    Test.startTest();
    String duplicate = saveError(
      new Map<String, Object>{ 'Separation__c' => existing.Separation__c },
      new List<Object>(),
      new List<Object>(),
      hrId
    );
    String mismatch = saveError(
      new Map<String, Object>{
        'Separation__c' => leaverSep.Id,
        'Employee__c' => existing.Employee__c
      },
      new List<Object>(),
      new List<Object>(),
      hrId
    );
    update new PWChrono_Employee_Separation__c(
      Id = leaverSep.Id,
      Status__c = 'Cancelled'
    );
    String cancelled = saveError(
      new Map<String, Object>{ 'Separation__c' => leaverSep.Id },
      new List<Object>(),
      new List<Object>(),
      hrId
    );
    String missingSeparation = saveError(
      new Map<String, Object>{ 'Separation__c' => existing.Id },
      new List<Object>(),
      new List<Object>(),
      hrId
    );
    String noEmployee = saveError(
      new Map<String, Object>{ 'Company__c' => 'X' },
      new List<Object>(),
      new List<Object>(),
      hrId
    );
    String unknownEmployee = saveError(
      new Map<String, Object>{ 'Employee__c' => existing.Id },
      new List<Object>(),
      new List<Object>(),
      hrId
    );
    Test.stopTest();

    Assert.isTrue(duplicate.contains('already has settlement'), duplicate);
    Assert.isTrue(mismatch.contains('does not match'), mismatch);
    Assert.isTrue(cancelled.contains('cancelled'), cancelled);
    Assert.isTrue(missingSeparation.contains('not found'), missingSeparation);
    Assert.isTrue(noEmployee.contains('Select the employee'), noEmployee);
    Assert.isTrue(unknownEmployee.contains('not found'), unknownEmployee);
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Full_Final_Settlement__c]);
  }

  @isTest
  static void saveUpdateKeepsStatusAndRecomputesTotals() {
    PWChrono_Full_Final_Settlement__c existing = getSettlement();
    Id managerId = userId(HR_MANAGER_EMAIL);
    Map<String, Object> rec = new Map<String, Object>{
      'Id' => existing.Id,
      'Company__c' => 'Updated Co',
      'Status__c' => 'Paid',
      'Net_Payable__c' => 1
    };

    Test.startTest();
    PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(rec),
      null,
      null,
      managerId,
      ''
    );
    PWChrono_Full_Final_Settlement__c afterKeep = getSettlement();
    PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(rec),
      JSON.serialize(new List<Object>{ line('Gratuity', 800, 'Pending') }),
      JSON.serialize(new List<Object>()),
      managerId,
      ''
    );
    Test.stopTest();

    Assert.areEqual('Draft', afterKeep.Status__c, 'Save cannot set status.');
    Assert.areEqual('Updated Co', afterKeep.Company__c);
    Assert.areEqual(5000, afterKeep.Total_Payable__c);
    Assert.areEqual(2000, afterKeep.Total_Receivable__c);
    Assert.areEqual(3000, afterKeep.Net_Payable__c);

    PWChrono_Full_Final_Settlement__c afterReplace = getSettlement();
    Assert.areEqual(800, afterReplace.Total_Payable__c);
    Assert.areEqual(0, afterReplace.Total_Receivable__c);
    Assert.areEqual(800, afterReplace.Net_Payable__c);
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM PWChrono_Settlement_Payable__c
        WHERE Settlement__c = :existing.Id
      ]
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :existing.Id
      ]
    );
  }

  @isTest
  static void paidAndCancelledSettlementsCannotBeEdited() {
    PWChrono_Full_Final_Settlement__c existing = getSettlement();
    Id hrId = userId(HR_ADMIN_EMAIL);
    Map<String, Object> rec = new Map<String, Object>{
      'Id' => existing.Id,
      'Company__c' => 'Changed'
    };
    Test.startTest();
    setStatus(existing.Id, 'Paid');
    String paid = saveError(rec, null, null, hrId);
    setStatus(existing.Id, 'Cancelled');
    String cancelled = saveError(rec, null, null, hrId);
    Test.stopTest();
    Assert.isTrue(paid.contains('paid and can no longer be edited'), paid);
    Assert.isTrue(cancelled.contains('can no longer be edited'), cancelled);
    Assert.areEqual('PulseWork', getSettlement().Company__c);
  }

  @isTest
  static void submittedSettlementRemainsEditable() {
    PWChrono_Full_Final_Settlement__c existing = getSettlement();
    setStatus(existing.Id, 'Submitted');
    Test.startTest();
    PWChrono_FullFinalSettlementController.saveSettlement(
      JSON.serialize(
        new Map<String, Object>{ 'Id' => existing.Id, 'Company__c' => 'Sub Co' }
      ),
      null,
      null,
      userId(HR_ADMIN_EMAIL),
      ''
    );
    Test.stopTest();
    PWChrono_Full_Final_Settlement__c updated = getSettlement();
    Assert.areEqual('Sub Co', updated.Company__c);
    Assert.areEqual('Submitted', updated.Status__c);
  }

  @isTest
  static void saveValidatesLinesAndPayload() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Map<String, Object> rec = new Map<String, Object>{
      'Id' => getSettlement().Id
    };
    Test.startTest();
    String negative = saveError(
      rec,
      new List<Object>{ line('Bonus', -1, 'Pending') },
      null,
      hrId
    );
    String notNumber = saveError(
      rec,
      new List<Object>{ line('Bonus', 'ten', 'Pending') },
      null,
      hrId
    );
    String badPayableStatus = saveError(
      rec,
      new List<Object>{ line('Bonus', 1, 'Recovered') },
      null,
      hrId
    );
    String badReceivableStatus = saveError(
      rec,
      null,
      new List<Object>{ line('Laptop', 1, 'Paid') },
      hrId
    );
    String notList = saveError(rec, new Map<String, Object>(), null, hrId);
    String notLine = saveError(rec, new List<Object>{ 'text' }, null, hrId);
    String badDate = saveError(
      new Map<String, Object>{
        'Id' => getSettlement().Id,
        'Relieving_Date__c' => 'tomorrow'
      },
      null,
      null,
      hrId
    );
    String badId = saveError(
      new Map<String, Object>{ 'Id' => 'not-an-id' },
      null,
      null,
      hrId
    );
    String malformed;
    try {
      PWChrono_FullFinalSettlementController.saveSettlement(
        '{bad json',
        '[]',
        '[]',
        hrId,
        ''
      );
    } catch (AuraHandledException e) {
      malformed = e.getMessage();
    }
    String blank;
    try {
      PWChrono_FullFinalSettlementController.saveSettlement(
        '',
        '[]',
        '[]',
        hrId,
        ''
      );
    } catch (AuraHandledException e) {
      blank = e.getMessage();
    }
    Test.stopTest();

    Assert.isTrue(negative.contains('cannot be negative'), negative);
    Assert.isTrue(notNumber.contains('as a number'), notNumber);
    Assert.isTrue(badPayableStatus.contains('not valid'), badPayableStatus);
    Assert.isTrue(
      badReceivableStatus.contains('not valid'),
      badReceivableStatus
    );
    Assert.isTrue(notList.contains('line data is not valid'), notList);
    Assert.isTrue(notLine.contains('line data is not valid'), notLine);
    Assert.isTrue(badDate.contains('YYYY-MM-DD'), badDate);
    Assert.isTrue(badId.contains('not valid'), badId);
    Assert.areEqual('The request data is not valid.', malformed);
    Assert.areEqual('The request data is missing.', blank);
    Assert.areEqual(5000, getSettlement().Total_Payable__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminSubmitsThenPaysSettlement() {
    Id settlementId = getSettlement().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    PWChrono_FullFinalSettlementController.updateSettlementStatus(
      settlementId,
      'Submitted',
      hrId,
      ''
    );
    String afterSubmit = getSettlement().Status__c;
    PWChrono_FullFinalSettlementController.updateSettlementStatus(
      settlementId,
      'Paid',
      hrId,
      ''
    );
    Test.stopTest();
    Assert.areEqual('Submitted', afterSubmit);
    Assert.areEqual('Paid', getSettlement().Status__c);
  }

  @isTest
  static void adminCancelsDraftAndSubmittedSettlements() {
    Id settlementId = getSettlement().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    PWChrono_FullFinalSettlementController.updateSettlementStatus(
      settlementId,
      'Cancelled',
      hrId,
      ''
    );
    String fromDraft = getSettlement().Status__c;
    setStatus(settlementId, 'Submitted');
    PWChrono_FullFinalSettlementController.updateSettlementStatus(
      settlementId,
      'Cancelled',
      hrId,
      ''
    );
    Test.stopTest();
    Assert.areEqual('Cancelled', fromDraft);
    Assert.areEqual('Cancelled', getSettlement().Status__c);
  }

  @isTest
  static void invalidTransitionsAreRejected() {
    Id settlementId = getSettlement().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    String unknown = statusError(settlementId, 'Archived', hrId);
    String skipSubmit = statusError(settlementId, 'Paid', hrId);
    setStatus(settlementId, 'Paid');
    String fromPaid = statusError(settlementId, 'Cancelled', hrId);
    setStatus(settlementId, 'Cancelled');
    String fromCancelled = statusError(settlementId, 'Draft', hrId);
    String missing = statusError(missingSettlementId(), 'Submitted', hrId);
    Test.stopTest();
    Assert.isTrue(unknown.contains('valid settlement status'), unknown);
    Assert.isTrue(skipSubmit.contains('draft settlement'), skipSubmit);
    Assert.isTrue(fromPaid.contains('paid settlement'), fromPaid);
    Assert.isTrue(
      fromCancelled.contains('cancelled settlement'),
      fromCancelled
    );
    Assert.areEqual('Settlement not found.', missing);
  }

  @isTest
  static void nonAdminCannotChangeStatusOrDelete() {
    Id settlementId = getSettlement().Id;
    Id managerId = userId(HR_MANAGER_EMAIL);
    Test.startTest();
    String statusMessage = statusError(settlementId, 'Submitted', managerId);
    String deleteMessage = deleteError(settlementId, managerId);
    Test.stopTest();
    Assert.isTrue(statusMessage.contains('HR administrators'), statusMessage);
    Assert.isTrue(deleteMessage.contains('HR administrators'), deleteMessage);
    Assert.areEqual('Draft', getSettlement().Status__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminDeletesDraftSettlementWithLines() {
    Id settlementId = getSettlement().Id;
    Test.startTest();
    PWChrono_FullFinalSettlementController.deleteSettlement(
      settlementId,
      userId(HR_ADMIN_EMAIL),
      ''
    );
    Test.stopTest();
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Full_Final_Settlement__c]);
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Settlement_Payable__c]);
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Settlement_Receivable__c]);
  }

  @isTest
  static void deleteAllowsCancelledButRejectsSubmittedAndPaid() {
    Id settlementId = getSettlement().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    setStatus(settlementId, 'Submitted');
    String submitted = deleteError(settlementId, hrId);
    setStatus(settlementId, 'Paid');
    String paid = deleteError(settlementId, hrId);
    String invalid = deleteError('', hrId);
    setStatus(settlementId, 'Cancelled');
    PWChrono_FullFinalSettlementController.deleteSettlement(
      settlementId,
      hrId,
      ''
    );
    Test.stopTest();
    Assert.isTrue(submitted.contains('draft or cancelled'), submitted);
    Assert.isTrue(paid.contains('draft or cancelled'), paid);
    Assert.areEqual('A settlement is required.', invalid);
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Full_Final_Settlement__c]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void lookupHelpersReturnSelectableRecords() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    List<PWChrono_Designation__c> designations = PWChrono_FullFinalSettlementController.getActiveDesignations(
      hrId,
      ''
    );
    List<PWChrono_Department__c> departments = PWChrono_FullFinalSettlementController.getActiveDepartments(
      hrId,
      ''
    );
    List<Portal_Users__c> employees = PWChrono_FullFinalSettlementController.getActiveEmployees(
      hrId,
      ''
    );
    List<PWChrono_Employee_Separation__c> separations = PWChrono_FullFinalSettlementController.getActiveSeparations(
      hrId,
      ''
    );
    Test.stopTest();
    Assert.areEqual(1, designations.size());
    Assert.areEqual(1, departments.size());
    Set<String> names = new Set<String>();
    for (Portal_Users__c employee : employees) {
      names.add(employee.Name);
    }
    Assert.isTrue(
      names.contains('Departed Leaver'),
      'Inactive employees with a separation must remain selectable.'
    );
    Assert.areEqual(4, employees.size());
    Assert.areEqual(2, separations.size());
  }
}