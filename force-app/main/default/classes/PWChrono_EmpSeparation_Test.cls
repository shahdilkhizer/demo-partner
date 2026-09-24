@isTest
private class PWChrono_EmpSeparation_Test {
  private static final String EMPLOYEE_EMAIL = 'emp@test.com';
  private static final String NEW_LEAVER_EMAIL = 'leaver@test.com';
  private static final String HR_ADMIN_EMAIL = 'hr@test.com';
  private static final String HR_MANAGER_EMAIL = 'hr.manager@test.com';

  @testSetup
  static void setup() {
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

    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Test Employee',
      Email__c = EMPLOYEE_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true,
      Session_Token__c = 'employee-session',
      Session_Expires_At__c = System.now().addHours(4),
      One_Time_Password__c = '123456',
      OTP_Generated_Time__c = System.now()
    );
    Portal_Users__c leaver = new Portal_Users__c(
      Name = 'New Leaver',
      Email__c = NEW_LEAVER_EMAIL,
      Role__c = 'Employee',
      Is_Active__c = true
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
    insert new List<Portal_Users__c>{ employee, leaver, hrAdmin, hrManager };

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

    PWChrono_Separation_Template__c tmpl = new PWChrono_Separation_Template__c(
      Name = 'Standard Exit',
      Is_Active__c = true
    );
    insert tmpl;
    insert new List<PWChrono_Separation_Template_Activity__c>{
      new PWChrono_Separation_Template_Activity__c(
        Name = 'Return Laptop',
        Separation_Template__c = tmpl.Id,
        Is_Required__c = true,
        Begin_On_Day__c = 1,
        Duration__c = 1
      ),
      new PWChrono_Separation_Template_Activity__c(
        Name = 'Knowledge Transfer',
        Separation_Template__c = tmpl.Id,
        Is_Required__c = false
      )
    };

    PWChrono_Employee_Separation__c sep = new PWChrono_Employee_Separation__c(
      Employee__c = employee.Id,
      Employee_Name__c = employee.Name,
      Company__c = 'PWChrono Corp',
      Department__c = dept.Id,
      Designation__c = desig.Id,
      Resignation_Letter_Date__c = Date.today(),
      Relieving_Date__c = Date.today().addDays(30),
      Status__c = 'Pending',
      Separation_Template__c = tmpl.Id
    );
    insert sep;

    insert new PWChrono_Separation_Checklist__c(
      Name = 'Return Laptop',
      Separation__c = sep.Id,
      Status__c = 'Pending',
      Is_Required__c = true
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static Id userId(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  private static PWChrono_Employee_Separation__c getSeparation() {
    return [
      SELECT
        Id,
        Status__c,
        Company__c,
        Employee__c,
        Relieving_Date__c,
        Separation_Template__c
      FROM PWChrono_Employee_Separation__c
      WHERE Employee__r.Email__c = :EMPLOYEE_EMAIL
      LIMIT 1
    ];
  }

  private static PWChrono_Separation_Checklist__c getChecklistItem(Id sepId) {
    return [
      SELECT Id, Name, Status__c, Is_Required__c
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :sepId
      LIMIT 1
    ];
  }

  private static String expectError(Callable action) {
    try {
      action.call(null, null);
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('An AuraHandledException was expected.');
    return null;
  }

  private static String missingId(Schema.SObjectType objectType) {
    return String.valueOf(
      Id.valueOf(objectType.getDescribe().getKeyPrefix() + '000000000001')
    );
  }

  private static void setStatus(Id sepId, String status) {
    update new PWChrono_Employee_Separation__c(Id = sepId, Status__c = status);
  }

  // Invokes a controller call so each negative case can share expectError.
  private class Invocation implements Callable {
    private String method;
    private List<Object> args;
    Invocation(String method, List<Object> args) {
      this.method = method;
      this.args = args;
    }
    public Object call(String action, Map<String, Object> ignored) {
      switch on method {
        when 'getSeparations' {
          return PWChrono_EmployeeSeparationController.getSeparations(
            (String) args[0],
            (String) args[1],
            (String) args[2]
          );
        }
        when 'saveSeparation' {
          return PWChrono_EmployeeSeparationController.saveSeparation(
            (String) args[0],
            (String) args[1],
            (String) args[2],
            null
          );
        }
        when 'updateSeparationStatus' {
          PWChrono_EmployeeSeparationController.updateSeparationStatus(
            (String) args[0],
            (String) args[1],
            (String) args[2],
            null
          );
        }
        when 'deleteSeparation' {
          PWChrono_EmployeeSeparationController.deleteSeparation(
            (String) args[0],
            (String) args[1],
            null
          );
        }
        when 'updateChecklistItemStatus' {
          PWChrono_EmployeeSeparationController.updateChecklistItemStatus(
            (String) args[0],
            (String) args[1],
            (String) args[2],
            null
          );
        }
        when 'getSeparationById' {
          return PWChrono_EmployeeSeparationController.getSeparationById(
            (String) args[0],
            (String) args[1],
            null
          );
        }
        when 'saveExitRecord' {
          return PWChrono_EmployeeSeparationController.saveExitRecord(
            (String) args[0],
            (String) args[1],
            null
          );
        }
      }
      return null;
    }
  }

  private static Callable invoke(String method, List<Object> args) {
    return new Invocation(method, args);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reads and access
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void getSeparationsReturnsRecordsWithChecklistForAdmin() {
    Test.startTest();
    List<PWChrono_Employee_Separation__c> results = PWChrono_EmployeeSeparationController.getSeparations(
      'All',
      userId(HR_ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(1, results.size());
    Assert.areEqual(1, results[0].Checklist_Items__r.size());
  }

  @isTest
  static void getSeparationsFiltersByStatus() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    Integer pending = PWChrono_EmployeeSeparationController.getSeparations(
        'Pending',
        hrId,
        null
      )
      .size();
    Integer completed = PWChrono_EmployeeSeparationController.getSeparations(
        'Completed',
        hrId,
        null
      )
      .size();
    Test.stopTest();
    Assert.areEqual(1, pending);
    Assert.areEqual(0, completed);
  }

  @isTest
  static void featureHolderCanReadButUserWithoutFeatureIsDenied() {
    Test.startTest();
    List<PWChrono_Employee_Separation__c> managerView = PWChrono_EmployeeSeparationController.getSeparations(
      'All',
      userId(HR_MANAGER_EMAIL),
      null
    );
    String message = expectError(
      invoke(
        'getSeparations',
        new List<Object>{
          'All',
          String.valueOf(userId(NEW_LEAVER_EMAIL)),
          null
        }
      )
    );
    Test.stopTest();
    Assert.areEqual(1, managerView.size());
    Assert.isTrue(message.contains('Employee Lifecycle'), message);
  }

  @isTest
  static void userWithoutFeatureCannotSave() {
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => userId(NEW_LEAVER_EMAIL)
    };
    Test.startTest();
    String message = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(rec),
          '[]',
          String.valueOf(userId(EMPLOYEE_EMAIL))
        }
      )
    );
    Test.stopTest();
    Assert.isTrue(message.startsWith('Access denied'), message);
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM PWChrono_Employee_Separation__c
        WHERE Employee__r.Email__c = :NEW_LEAVER_EMAIL
      ]
    );
  }

  @isTest
  static void getSeparationByIdHandlesFoundMissingAndInvalid() {
    String hrId = String.valueOf(userId(HR_ADMIN_EMAIL));
    Id sepId = getSeparation().Id;
    Test.startTest();
    PWChrono_Employee_Separation__c result = PWChrono_EmployeeSeparationController.getSeparationById(
      sepId,
      hrId,
      null
    );
    String missing = expectError(
      invoke(
        'getSeparationById',
        new List<Object>{
          missingId(PWChrono_Employee_Separation__c.SObjectType),
          hrId
        }
      )
    );
    String invalid = expectError(
      invoke('getSeparationById', new List<Object>{ 'not-an-id', hrId })
    );
    Test.stopTest();
    Assert.areEqual('PWChrono Corp', result.Company__c);
    Assert.areEqual('Separation record not found.', missing);
    Assert.isTrue(invalid.contains('not valid'), invalid);
  }

  @isTest
  static void getChecklistItemsReturnsItems() {
    Test.startTest();
    List<PWChrono_Separation_Checklist__c> items = PWChrono_EmployeeSeparationController.getChecklistItems(
      getSeparation().Id,
      userId(HR_ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(1, items.size());
    Assert.areEqual('Return Laptop', items[0].Name);
  }

  @isTest
  static void guestSessionIsVerified() {
    Portal_Users__c hr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = :HR_ADMIN_EMAIL
      LIMIT 1
    ];
    hr.Session_Token__c = 'guest_separation_token';
    hr.Session_Expires_At__c = System.now().addHours(1);
    update hr;

    PWChrono_GuestSession.testUserTypeOverride = 'Guest';
    try {
      Test.startTest();
      List<PWChrono_Employee_Separation__c> results = PWChrono_EmployeeSeparationController.getSeparations(
        'All',
        String.valueOf(hr.Id),
        'guest_separation_token'
      );
      String message = expectError(
        invoke(
          'getSeparations',
          new List<Object>{ 'All', String.valueOf(hr.Id), 'wrong-token' }
        )
      );
      Test.stopTest();
      Assert.areEqual(1, results.size());
      Assert.isTrue(message.startsWith('Session invalid'), message);
    } finally {
      PWChrono_GuestSession.testUserTypeOverride = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void saveInsertStartsPendingWithManualChecklist() {
    Id leaverId = userId(NEW_LEAVER_EMAIL);
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => leaverId,
      'Company__c' => 'New Corp',
      'Resignation_Letter_Date__c' => String.valueOf(Date.today()),
      'Relieving_Date__c' => String.valueOf(Date.today().addDays(30)),
      'Status__c' => 'Completed',
      'Separation_Template__c' => getSeparation().Separation_Template__c
    };
    List<Map<String, Object>> checklist = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Name' => 'Return Badge',
        'Status__c' => 'Pending',
        'Is_Required__c' => true,
        'Assigned_To__c' => userId(HR_ADMIN_EMAIL)
      }
    };
    Test.startTest();
    String newId = PWChrono_EmployeeSeparationController.saveSeparation(
      JSON.serialize(rec),
      JSON.serialize(checklist),
      userId(HR_MANAGER_EMAIL),
      null
    );
    Test.stopTest();

    PWChrono_Employee_Separation__c created = [
      SELECT Status__c, Employee_Name__c, Company__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :newId
    ];
    Assert.areEqual('Pending', created.Status__c, 'Status is server-owned.');
    Assert.areEqual('New Leaver', created.Employee_Name__c);
    Assert.areEqual('New Corp', created.Company__c);
    List<PWChrono_Separation_Checklist__c> items = [
      SELECT Name, Is_Required__c
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :newId
    ];
    Assert.areEqual(1, items.size(), 'Manual rows replace the template.');
    Assert.areEqual('Return Badge', items[0].Name);
    Assert.isTrue(items[0].Is_Required__c);
  }

  @isTest
  static void saveInsertGeneratesChecklistFromTemplate() {
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => userId(NEW_LEAVER_EMAIL),
      'Separation_Template__c' => getSeparation().Separation_Template__c
    };
    Test.startTest();
    String newId = PWChrono_EmployeeSeparationController.saveSeparation(
      JSON.serialize(rec),
      '[]',
      userId(HR_ADMIN_EMAIL),
      null
    );
    Test.stopTest();

    List<PWChrono_Separation_Checklist__c> items = [
      SELECT Name, Is_Required__c, Status__c
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :newId
      ORDER BY Name
    ];
    Assert.areEqual(2, items.size());
    Assert.areEqual('Knowledge Transfer', items[0].Name);
    Assert.isFalse(items[0].Is_Required__c);
    Assert.areEqual('Return Laptop', items[1].Name);
    Assert.isTrue(items[1].Is_Required__c);
    Assert.areEqual('Pending', items[1].Status__c);
  }

  @isTest
  static void saveRejectsDuplicateOpenSeparation() {
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => userId(EMPLOYEE_EMAIL)
    };
    Test.startTest();
    String message = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(rec),
          null,
          String.valueOf(userId(HR_ADMIN_EMAIL))
        }
      )
    );
    Test.stopTest();
    Assert.isTrue(message.contains('already has an open separation'), message);
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM PWChrono_Employee_Separation__c
        WHERE Employee__r.Email__c = :EMPLOYEE_EMAIL
      ]
    );
  }

  @isTest
  static void saveRejectsMissingOrInactiveEmployeeAndBadDates() {
    String hrId = String.valueOf(userId(HR_ADMIN_EMAIL));
    Portal_Users__c leaver = [
      SELECT Id, Is_Active__c
      FROM Portal_Users__c
      WHERE Email__c = :NEW_LEAVER_EMAIL
    ];
    leaver.Is_Active__c = false;
    update leaver;

    Test.startTest();
    String missing = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(new Map<String, Object>()),
          null,
          hrId
        }
      )
    );
    String inactive = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(new Map<String, Object>{ 'Employee__c' => leaver.Id }),
          null,
          hrId
        }
      )
    );
    String badDates = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Id' => getSeparation().Id,
              'Resignation_Letter_Date__c' => String.valueOf(Date.today()),
              'Relieving_Date__c' => String.valueOf(Date.today().addDays(-1))
            }
          ),
          null,
          hrId
        }
      )
    );
    String unknownEmployee = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{ 'Employee__c' => getSeparation().Id }
          ),
          null,
          hrId
        }
      )
    );
    Test.stopTest();
    Assert.areEqual('Select the employee who is leaving.', missing);
    Assert.isTrue(inactive.contains('no longer active'), inactive);
    Assert.isTrue(badDates.contains('relieving date'), badDates);
    Assert.isTrue(unknownEmployee.contains('not found'), unknownEmployee);
  }

  @isTest
  static void saveUpdateIgnoresStatusAndSyncsChecklist() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    Map<String, Object> rec = new Map<String, Object>{
      'Id' => sep.Id,
      'Company__c' => 'Updated Corp',
      'Status__c' => 'Completed'
    };
    List<Map<String, Object>> checklist = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => item.Id,
        'Name' => 'Return Laptop',
        'Status__c' => 'Completed',
        'Is_Required__c' => true
      },
      new Map<String, Object>{
        'Name' => 'Exit Survey',
        'Is_Required__c' => 'false'
      }
    };

    Test.startTest();
    String savedId = PWChrono_EmployeeSeparationController.saveSeparation(
      JSON.serialize(rec),
      JSON.serialize(checklist),
      userId(HR_MANAGER_EMAIL),
      null
    );
    Test.stopTest();

    Assert.areEqual(sep.Id, savedId);
    PWChrono_Employee_Separation__c updated = getSeparation();
    Assert.areEqual('Updated Corp', updated.Company__c);
    Assert.areEqual('Pending', updated.Status__c, 'Save cannot set status.');
    Map<String, PWChrono_Separation_Checklist__c> byName = new Map<String, PWChrono_Separation_Checklist__c>();
    for (PWChrono_Separation_Checklist__c row : [
      SELECT Id, Name, Status__c, Is_Required__c
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :sep.Id
    ]) {
      byName.put(row.Name, row);
    }
    Assert.areEqual(2, byName.size());
    Assert.areEqual(item.Id, byName.get('Return Laptop').Id);
    Assert.areEqual(
      'Pending',
      byName.get('Return Laptop').Status__c,
      'Checklist status is changed only through updateChecklistItemStatus.'
    );
    Assert.isTrue(byName.get('Return Laptop').Is_Required__c);
    Assert.areEqual('Pending', byName.get('Exit Survey').Status__c);
    Assert.isFalse(byName.get('Exit Survey').Is_Required__c);
  }

  @isTest
  static void nonAdminCannotRemoveOrUnrequireChecklistItemsThroughSave() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    update new PWChrono_Employee_Separation__c(
      Id = sep.Id,
      Relieving_Date__c = Date.today()
    );
    String managerId = String.valueOf(userId(HR_MANAGER_EMAIL));
    String payload = JSON.serialize(new Map<String, Object>{ 'Id' => sep.Id });

    Test.startTest();
    String removeMessage = expectError(
      invoke('saveSeparation', new List<Object>{ payload, '[]', managerId })
    );
    PWChrono_EmployeeSeparationController.saveSeparation(
      payload,
      JSON.serialize(
        new List<Object>{
          new Map<String, Object>{
            'Id' => item.Id,
            'Name' => 'Return Laptop',
            'Is_Required__c' => false,
            'Status__c' => 'Completed'
          }
        }
      ),
      managerId,
      null
    );
    String completeMessage = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{
          String.valueOf(sep.Id),
          'Completed',
          String.valueOf(userId(HR_ADMIN_EMAIL))
        }
      )
    );
    Test.stopTest();

    Assert.areEqual(
      'Only HR administrators can remove checklist items: Return Laptop.',
      removeMessage
    );
    PWChrono_Separation_Checklist__c stored = getChecklistItem(sep.Id);
    Assert.areEqual(item.Id, stored.Id, 'The item must not be deleted.');
    Assert.isTrue(stored.Is_Required__c, 'A non-admin cannot un-require.');
    Assert.areEqual('Pending', stored.Status__c, 'Save cannot set status.');
    Assert.isTrue(completeMessage.contains('Return Laptop'), completeMessage);
    Assert.areEqual('Pending', getSeparation().Status__c);
    Assert.isTrue(
      [
        SELECT Is_Active__c
        FROM Portal_Users__c
        WHERE Email__c = :EMPLOYEE_EMAIL
      ]
      .Is_Active__c
    );
  }

  @isTest
  static void adminCanChangeRequiredFlagButNewItemsStartPending() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    List<Map<String, Object>> checklist = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => item.Id,
        'Name' => 'Return Laptop',
        'Is_Required__c' => false,
        'Status__c' => 'Completed',
        'Notes__c' => 'Laptop returned to IT'
      },
      new Map<String, Object>{
        'Name' => 'Return Badge',
        'Is_Required__c' => true,
        'Status__c' => 'Completed'
      }
    };

    Test.startTest();
    PWChrono_EmployeeSeparationController.saveSeparation(
      JSON.serialize(new Map<String, Object>{ 'Id' => sep.Id }),
      JSON.serialize(checklist),
      userId(HR_ADMIN_EMAIL),
      null
    );
    Test.stopTest();

    Map<String, PWChrono_Separation_Checklist__c> byName = new Map<String, PWChrono_Separation_Checklist__c>();
    for (PWChrono_Separation_Checklist__c row : [
      SELECT Name, Status__c, Is_Required__c, Notes__c
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :sep.Id
    ]) {
      byName.put(row.Name, row);
    }
    Assert.isFalse(byName.get('Return Laptop').Is_Required__c);
    Assert.areEqual('Pending', byName.get('Return Laptop').Status__c);
    Assert.areEqual(
      'Laptop returned to IT',
      byName.get('Return Laptop').Notes__c
    );
    Assert.isTrue(byName.get('Return Badge').Is_Required__c);
    Assert.areEqual('Pending', byName.get('Return Badge').Status__c);
  }

  @isTest
  static void saveUpdateWithEmptyChecklistRemovesItemsButNullKeepsThem() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    String payload = JSON.serialize(
      new Map<String, Object>{ 'Id' => sep.Id, 'Company__c' => 'Kept' }
    );
    Id hrId = userId(HR_ADMIN_EMAIL);

    Test.startTest();
    PWChrono_EmployeeSeparationController.saveSeparation(
      payload,
      null,
      hrId,
      null
    );
    Integer afterNull = [
      SELECT COUNT()
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :sep.Id
    ];
    PWChrono_EmployeeSeparationController.saveSeparation(
      payload,
      '[]',
      hrId,
      null
    );
    Test.stopTest();

    Assert.areEqual(1, afterNull);
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM PWChrono_Separation_Checklist__c
        WHERE Separation__c = :sep.Id
      ]
    );
  }

  @isTest
  static void saveRejectsInvalidChecklistRows() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    String hrId = String.valueOf(userId(HR_ADMIN_EMAIL));
    String payload = JSON.serialize(new Map<String, Object>{ 'Id' => sep.Id });

    Test.startTest();
    String blankName = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          payload,
          JSON.serialize(
            new List<Object>{ new Map<String, Object>{ 'Name' => ' ' } }
          ),
          hrId
        }
      )
    );
    String foreignRow = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          payload,
          JSON.serialize(
            new List<Object>{
              new Map<String, Object>{ 'Id' => sep.Id, 'Name' => 'X' }
            }
          ),
          hrId
        }
      )
    );
    String notAList = expectError(
      invoke('saveSeparation', new List<Object>{ payload, '{}', hrId })
    );
    String malformed = expectError(
      invoke('saveSeparation', new List<Object>{ '{bad json', null, hrId })
    );
    Test.stopTest();

    Assert.isTrue(blankName.contains('activity name'), blankName);
    Assert.isTrue(foreignRow.contains('does not belong'), foreignRow);
    Assert.isTrue(notAList.contains('not valid'), notAList);
    Assert.areEqual('The request data is not valid.', malformed);
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Separation_Checklist__c]);
  }

  @isTest
  static void terminalSeparationsCannotBeEdited() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    setStatus(sep.Id, 'Cancelled');
    Test.startTest();
    String message = expectError(
      invoke(
        'saveSeparation',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{ 'Id' => sep.Id, 'Company__c' => 'X' }
          ),
          null,
          String.valueOf(userId(HR_ADMIN_EMAIL))
        }
      )
    );
    Test.stopTest();
    Assert.isTrue(message.contains('can no longer be edited'), message);
    Assert.areEqual('PWChrono Corp', getSeparation().Company__c);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminMovesSeparationToInProcessThenCancelled() {
    Id sepId = getSeparation().Id;
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    PWChrono_EmployeeSeparationController.updateSeparationStatus(
      sepId,
      'In Process',
      hrId,
      null
    );
    String afterStart = getSeparation().Status__c;
    PWChrono_EmployeeSeparationController.updateSeparationStatus(
      sepId,
      'Cancelled',
      hrId,
      null
    );
    Test.stopTest();
    Assert.areEqual('In Process', afterStart);
    Assert.areEqual('Cancelled', getSeparation().Status__c);
    Assert.isTrue(
      [
        SELECT Is_Active__c
        FROM Portal_Users__c
        WHERE Email__c = :EMPLOYEE_EMAIL
      ]
      .Is_Active__c,
      'Cancelling must not deactivate the employee.'
    );
  }

  @isTest
  static void invalidTransitionsAreRejected() {
    Id sepId = getSeparation().Id;
    String hrId = String.valueOf(userId(HR_ADMIN_EMAIL));
    Test.startTest();
    String unknownStatus = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{ String.valueOf(sepId), 'Archived', hrId }
      )
    );
    String sameStatus = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{ String.valueOf(sepId), 'Pending', hrId }
      )
    );
    setStatus(sepId, 'Cancelled');
    String fromTerminal = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{ String.valueOf(sepId), 'In Process', hrId }
      )
    );
    String missing = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{
          missingId(PWChrono_Employee_Separation__c.SObjectType),
          'Cancelled',
          hrId
        }
      )
    );
    String blankId = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{ '', 'Cancelled', hrId }
      )
    );
    Test.stopTest();
    Assert.isTrue(unknownStatus.contains('valid separation status'));
    Assert.isTrue(
      sameStatus.contains('cannot be moved to Pending'),
      sameStatus
    );
    Assert.isTrue(fromTerminal.contains('cancelled separation'), fromTerminal);
    Assert.areEqual('Separation record not found.', missing);
    Assert.isTrue(blankId.contains('required'), blankId);
  }

  @isTest
  static void nonAdminCannotChangeStatusOrDelete() {
    Id sepId = getSeparation().Id;
    String managerId = String.valueOf(userId(HR_MANAGER_EMAIL));
    Test.startTest();
    String statusMessage = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{ String.valueOf(sepId), 'Cancelled', managerId }
      )
    );
    String deleteMessage = expectError(
      invoke(
        'deleteSeparation',
        new List<Object>{ String.valueOf(sepId), managerId }
      )
    );
    Test.stopTest();
    Assert.isTrue(statusMessage.contains('HR administrators'), statusMessage);
    Assert.isTrue(deleteMessage.contains('HR administrators'), deleteMessage);
    Assert.areEqual('Pending', getSeparation().Status__c);
  }

  @isTest
  static void completionDeactivatesEmployeeAndClearsSession() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    update new PWChrono_Employee_Separation__c(
      Id = sep.Id,
      Relieving_Date__c = Date.today(),
      Status__c = 'In Process'
    );
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    item.Status__c = 'Completed';
    update item;

    Test.startTest();
    PWChrono_EmployeeSeparationController.updateSeparationStatus(
      sep.Id,
      'Completed',
      userId(HR_ADMIN_EMAIL),
      null
    );
    Test.stopTest();

    Assert.areEqual('Completed', getSeparation().Status__c);
    Portal_Users__c employee = [
      SELECT
        Is_Active__c,
        Session_Token__c,
        Session_Expires_At__c,
        One_Time_Password__c
      FROM Portal_Users__c
      WHERE Email__c = :EMPLOYEE_EMAIL
    ];
    Assert.isFalse(employee.Is_Active__c);
    Assert.isNull(employee.Session_Token__c);
    Assert.isNull(employee.Session_Expires_At__c);
    Assert.isNull(employee.One_Time_Password__c);
  }

  @isTest
  static void failedCompletionRollsBackTheDeactivation() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    update new PWChrono_Employee_Separation__c(
      Id = sep.Id,
      Relieving_Date__c = Date.today(),
      Status__c = 'In Process'
    );
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    item.Status__c = 'Completed';
    update item;
    PWChrono_EmployeeSeparationController.simulateCompletionFailure = true;

    Test.startTest();
    String message = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{
          String.valueOf(sep.Id),
          'Completed',
          String.valueOf(userId(HR_ADMIN_EMAIL))
        }
      )
    );
    Test.stopTest();

    Assert.areEqual('Simulated failure after deactivation.', message);
    Assert.areEqual('In Process', getSeparation().Status__c);
    Portal_Users__c employee = [
      SELECT Is_Active__c, Session_Token__c, One_Time_Password__c
      FROM Portal_Users__c
      WHERE Email__c = :EMPLOYEE_EMAIL
    ];
    Assert.isTrue(employee.Is_Active__c, 'Deactivation must be rolled back.');
    Assert.areEqual('employee-session', employee.Session_Token__c);
    Assert.areEqual('123456', employee.One_Time_Password__c);
  }

  @isTest
  static void futureRelievingDateBlocksCompletion() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    item.Status__c = 'Completed';
    update item;

    Test.startTest();
    String message = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{
          String.valueOf(sep.Id),
          'Completed',
          String.valueOf(userId(HR_ADMIN_EMAIL))
        }
      )
    );
    Test.stopTest();
    Assert.isTrue(
      message.startsWith('This separation takes effect on'),
      message
    );
    Assert.areEqual('Pending', getSeparation().Status__c);
    Assert.isTrue(
      [
        SELECT Is_Active__c
        FROM Portal_Users__c
        WHERE Email__c = :EMPLOYEE_EMAIL
      ]
      .Is_Active__c
    );
  }

  @isTest
  static void incompleteRequiredChecklistBlocksCompletion() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    update new PWChrono_Employee_Separation__c(
      Id = sep.Id,
      Relieving_Date__c = Date.today().addDays(-1)
    );
    insert new PWChrono_Separation_Checklist__c(
      Name = 'Optional Survey',
      Separation__c = sep.Id,
      Status__c = 'Pending',
      Is_Required__c = false
    );

    Test.startTest();
    String message = expectError(
      invoke(
        'updateSeparationStatus',
        new List<Object>{
          String.valueOf(sep.Id),
          'Completed',
          String.valueOf(userId(HR_ADMIN_EMAIL))
        }
      )
    );
    Test.stopTest();
    Assert.isTrue(message.contains('Return Laptop'), message);
    Assert.isFalse(message.contains('Optional Survey'), message);
    Assert.areEqual('Pending', getSeparation().Status__c);
    Assert.isTrue(
      [
        SELECT Is_Active__c
        FROM Portal_Users__c
        WHERE Email__c = :EMPLOYEE_EMAIL
      ]
      .Is_Active__c
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist item status
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void checklistItemStatusUpdatesWhileOpenOnly() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    String managerId = String.valueOf(userId(HR_MANAGER_EMAIL));

    Test.startTest();
    PWChrono_EmployeeSeparationController.updateChecklistItemStatus(
      item.Id,
      'In Progress',
      managerId,
      null
    );
    String afterUpdate = getChecklistItem(sep.Id).Status__c;
    String badStatus = expectError(
      invoke(
        'updateChecklistItemStatus',
        new List<Object>{ String.valueOf(item.Id), 'Done', managerId }
      )
    );
    String missing = expectError(
      invoke(
        'updateChecklistItemStatus',
        new List<Object>{
          missingId(PWChrono_Separation_Checklist__c.SObjectType),
          'Completed',
          managerId
        }
      )
    );
    setStatus(sep.Id, 'Cancelled');
    String closed = expectError(
      invoke(
        'updateChecklistItemStatus',
        new List<Object>{ String.valueOf(item.Id), 'Completed', managerId }
      )
    );
    Test.stopTest();

    Assert.areEqual('In Progress', afterUpdate);
    Assert.isTrue(badStatus.contains('valid checklist status'));
    Assert.areEqual('Checklist item not found.', missing);
    Assert.isTrue(closed.contains('cannot be changed'), closed);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void adminDeletesPendingSeparationWithChecklist() {
    Id sepId = getSeparation().Id;
    Test.startTest();
    PWChrono_EmployeeSeparationController.deleteSeparation(
      sepId,
      userId(HR_ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM PWChrono_Employee_Separation__c WHERE Id = :sepId]
    );
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Separation_Checklist__c]);
  }

  @isTest
  static void deleteAllowsCancelledButRejectsInProcessAndCompleted() {
    Id sepId = getSeparation().Id;
    String hrId = String.valueOf(userId(HR_ADMIN_EMAIL));
    Test.startTest();
    setStatus(sepId, 'In Process');
    String inProcess = expectError(
      invoke(
        'deleteSeparation',
        new List<Object>{ String.valueOf(sepId), hrId }
      )
    );
    setStatus(sepId, 'Completed');
    String completed = expectError(
      invoke(
        'deleteSeparation',
        new List<Object>{ String.valueOf(sepId), hrId }
      )
    );
    setStatus(sepId, 'Cancelled');
    PWChrono_EmployeeSeparationController.deleteSeparation(sepId, hrId, null);
    Test.stopTest();
    Assert.isTrue(inProcess.contains('pending or cancelled'), inProcess);
    Assert.isTrue(completed.contains('pending or cancelled'), completed);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM PWChrono_Employee_Separation__c WHERE Id = :sepId]
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Employee exit records
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void exitRecordsCanBeSavedAndListed() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Map<String, Object> rec = new Map<String, Object>{
      'Employee__c' => userId(EMPLOYEE_EMAIL),
      'Resignation_Date__c' => String.valueOf(Date.today()),
      'Relieving_Date__c' => String.valueOf(Date.today().addDays(30)),
      'Exit_Type__c' => 'Resignation',
      'Separation__c' => getSeparation().Id,
      'OwnerId' => hrId
    };
    Test.startTest();
    String newId = PWChrono_EmployeeSeparationController.saveExitRecord(
      JSON.serialize(rec),
      hrId,
      null
    );
    List<PWChrono_Employee_Exit__c> results = PWChrono_EmployeeSeparationController.getExitRecords(
      hrId,
      null
    );
    String missingEmployee = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{ 'Exit_Type__c' => 'Resignation' }
          ),
          String.valueOf(hrId)
        }
      )
    );
    String badDate = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Employee__c' => userId(EMPLOYEE_EMAIL),
              'Relieving_Date__c' => '24/09/2026'
            }
          ),
          String.valueOf(hrId)
        }
      )
    );
    String malformed = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{ '{bad json', String.valueOf(hrId) }
      )
    );
    String notAnObject = expectError(
      invoke('saveExitRecord', new List<Object>{ '[]', String.valueOf(hrId) })
    );
    Test.stopTest();

    Assert.isNotNull(newId);
    Assert.areEqual(1, results.size());
    Assert.areEqual('Resignation', results[0].Exit_Type__c);
    Assert.isTrue(missingEmployee.contains('employee'), missingEmployee);
    Assert.isTrue(badDate.contains('YYYY-MM-DD'), badDate);
    Assert.areEqual('The request data is not valid.', malformed);
    Assert.areEqual('The request data is not valid.', notAnObject);
  }

  @isTest
  static void nonAdminCannotSaveExitRecordDecisions() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Employee_Exit__c exitRecord = new PWChrono_Employee_Exit__c(
      Employee__c = sep.Employee__c,
      Separation__c = sep.Id,
      Final_Decision__c = 'Pending',
      Full_and_Final_Status__c = 'Pending'
    );
    insert exitRecord;
    String managerId = String.valueOf(userId(HR_MANAGER_EMAIL));

    Test.startTest();
    String updateMessage = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Id' => exitRecord.Id,
              'Final_Decision__c' => 'Accepted',
              'Full_and_Final_Status__c' => 'Completed'
            }
          ),
          managerId
        }
      )
    );
    String createMessage = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Employee__c' => sep.Employee__c,
              'Final_Decision__c' => 'Accepted'
            }
          ),
          managerId
        }
      )
    );
    Test.stopTest();

    Assert.isTrue(updateMessage.contains('HR administrators'), updateMessage);
    Assert.isTrue(createMessage.contains('HR administrators'), createMessage);
    PWChrono_Employee_Exit__c stored = [
      SELECT Final_Decision__c, Full_and_Final_Status__c
      FROM PWChrono_Employee_Exit__c
      WHERE Id = :exitRecord.Id
    ];
    Assert.areEqual('Pending', stored.Final_Decision__c);
    Assert.areEqual('Pending', stored.Full_and_Final_Status__c);
    Assert.areEqual(1, [SELECT COUNT() FROM PWChrono_Employee_Exit__c]);
  }

  @isTest
  static void exitRecordFollowsItsSeparation() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    Id leaverId = userId(NEW_LEAVER_EMAIL);
    PWChrono_Employee_Separation__c cancelled = new PWChrono_Employee_Separation__c(
      Employee__c = leaverId,
      Status__c = 'Cancelled'
    );
    insert cancelled;
    String hrId = String.valueOf(userId(HR_ADMIN_EMAIL));

    Test.startTest();
    String newId = PWChrono_EmployeeSeparationController.saveExitRecord(
      JSON.serialize(new Map<String, Object>{ 'Separation__c' => sep.Id }),
      hrId,
      null
    );
    PWChrono_EmployeeSeparationController.saveExitRecord(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => newId,
          'Final_Decision__c' => 'Accepted'
        }
      ),
      hrId,
      null
    );
    String mismatch = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{ 'Id' => newId, 'Employee__c' => leaverId }
          ),
          hrId
        }
      )
    );
    String cancelledLink = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Employee__c' => leaverId,
              'Separation__c' => cancelled.Id
            }
          ),
          hrId
        }
      )
    );
    String missingSeparation = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Separation__c' => missingId(
                PWChrono_Employee_Separation__c.SObjectType
              )
            }
          ),
          hrId
        }
      )
    );
    String missingRecord = expectError(
      invoke(
        'saveExitRecord',
        new List<Object>{
          JSON.serialize(
            new Map<String, Object>{
              'Id' => missingId(PWChrono_Employee_Exit__c.SObjectType)
            }
          ),
          hrId
        }
      )
    );
    Test.stopTest();

    PWChrono_Employee_Exit__c saved = [
      SELECT
        Employee__c,
        Employee_Name__c,
        Department__c,
        Designation__c,
        Resignation_Date__c,
        Relieving_Date__c,
        Final_Decision__c
      FROM PWChrono_Employee_Exit__c
      WHERE Id = :newId
    ];
    Assert.areEqual(sep.Employee__c, saved.Employee__c);
    Assert.areEqual('Test Employee', saved.Employee_Name__c);
    Assert.isNotNull(saved.Department__c);
    Assert.isNotNull(saved.Designation__c);
    Assert.areEqual(Date.today(), saved.Resignation_Date__c);
    Assert.areEqual(sep.Relieving_Date__c, saved.Relieving_Date__c);
    Assert.areEqual('Accepted', saved.Final_Decision__c);
    Assert.isTrue(mismatch.contains('does not match'), mismatch);
    Assert.isTrue(cancelledLink.contains('is cancelled'), cancelledLink);
    Assert.areEqual('The linked separation was not found.', missingSeparation);
    Assert.areEqual('Exit record not found.', missingRecord);
  }

  @isTest
  static void userWithoutFeatureIsDeniedAndNothingChanges() {
    PWChrono_Employee_Separation__c sep = getSeparation();
    PWChrono_Separation_Checklist__c item = getChecklistItem(sep.Id);
    String noFeatureId = String.valueOf(userId(NEW_LEAVER_EMAIL));

    Test.startTest();
    List<String> messages = new List<String>{
      expectError(
        invoke(
          'updateChecklistItemStatus',
          new List<Object>{ String.valueOf(item.Id), 'Completed', noFeatureId }
        )
      ),
      expectError(
        invoke(
          'getSeparationById',
          new List<Object>{ String.valueOf(sep.Id), noFeatureId }
        )
      ),
      expectError(
        invoke(
          'saveExitRecord',
          new List<Object>{
            JSON.serialize(
              new Map<String, Object>{
                'Employee__c' => sep.Employee__c,
                'Final_Decision__c' => 'Accepted'
              }
            ),
            noFeatureId
          }
        )
      ),
      expectError(
        invoke(
          'updateSeparationStatus',
          new List<Object>{ String.valueOf(sep.Id), 'Cancelled', noFeatureId }
        )
      ),
      expectError(
        invoke(
          'deleteSeparation',
          new List<Object>{ String.valueOf(sep.Id), noFeatureId }
        )
      )
    };
    Test.stopTest();

    for (String message : messages) {
      Assert.areEqual(
        'Access denied: Employee Lifecycle access is required.',
        message
      );
    }
    Assert.areEqual('Pending', getChecklistItem(sep.Id).Status__c);
    Assert.areEqual('Pending', getSeparation().Status__c);
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Exit__c]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookup helpers
  // ─────────────────────────────────────────────────────────────────────────

  @isTest
  static void lookupHelpersRequireSessionAndReturnActiveRecords() {
    Id hrId = userId(HR_ADMIN_EMAIL);
    Test.startTest();
    List<PWChrono_Designation__c> designations = PWChrono_EmployeeSeparationController.getActiveDesignations(
      hrId,
      null
    );
    List<PWChrono_Department__c> departments = PWChrono_EmployeeSeparationController.getActiveDepartments(
      hrId,
      null
    );
    List<Portal_Users__c> employees = PWChrono_EmployeeSeparationController.getActiveEmployees(
      hrId,
      null
    );
    List<PWChrono_Separation_Template__c> templates = PWChrono_EmployeeSeparationController.getActiveSeparationTemplates(
      hrId,
      null
    );
    Test.stopTest();
    Assert.areEqual(1, designations.size());
    Assert.areEqual(1, departments.size());
    Assert.areEqual(4, employees.size());
    Assert.areEqual(1, templates.size());
  }

  @isTest
  static void lookupHelpersDenyUsersWithoutFeature() {
    Id employeeId = userId(NEW_LEAVER_EMAIL);
    Integer denied = 0;
    Test.startTest();
    try {
      PWChrono_EmployeeSeparationController.getActiveDesignations(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_EmployeeSeparationController.getActiveDepartments(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_EmployeeSeparationController.getActiveEmployees(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_EmployeeSeparationController.getActiveSeparationTemplates(
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_EmployeeSeparationController.getChecklistItems(
        getSeparation().Id,
        employeeId,
        null
      );
    } catch (AuraHandledException e) {
      denied++;
    }
    try {
      PWChrono_EmployeeSeparationController.getExitRecords(employeeId, null);
    } catch (AuraHandledException e) {
      denied++;
    }
    Test.stopTest();
    Assert.areEqual(6, denied);
  }
}