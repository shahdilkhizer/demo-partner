@isTest
private class PWChrono_EmployeeLifecycleService_Test {
  @testSetup
  static void setup() {
    Contact employeeContact = new Contact(
      LastName = 'Lifecycle Employee',
      Department = 'Old Department',
      Title = 'Old Title'
    );
    insert employeeContact;

    Portal_Users__c manager = new Portal_Users__c(
      Name = 'Lifecycle Manager',
      Email__c = 'lifecycle.manager@test.com',
      Role__c = 'Manager',
      Is_Active__c = true
    );
    Portal_Users__c inactiveManager = new Portal_Users__c(
      Name = 'Inactive Manager',
      Email__c = 'inactive.manager@test.com',
      Role__c = 'Manager',
      Is_Active__c = false
    );
    insert new List<Portal_Users__c>{ manager, inactiveManager };

    Portal_Users__c employee = new Portal_Users__c(
      Name = 'Lifecycle Employee',
      Email__c = 'lifecycle.employee@test.com',
      Role__c = 'Employee',
      Is_Active__c = true,
      Contact__c = employeeContact.Id,
      Department__c = 'Old Department',
      Designation__c = 'Old Title',
      Session_Token__c = 'token-value',
      Session_Expires_At__c = System.now().addHours(1),
      One_Time_Password__c = '123456',
      OTP_Generated_Time__c = System.now()
    );
    insert employee;

    insert new PWChrono_Department__c(
      Name = 'Engineering',
      Is_Active__c = true
    );
    insert new PWChrono_Designation__c(
      Name = 'Senior Developer',
      Is_Active__c = true
    );
  }

  private static Portal_Users__c getEmployee() {
    return [
      SELECT
        Id,
        Contact__c,
        Department__c,
        Designation__c,
        Reports_To__c,
        Is_Active__c,
        Session_Token__c,
        Session_Expires_At__c,
        One_Time_Password__c,
        OTP_Generated_Time__c
      FROM Portal_Users__c
      WHERE Email__c = 'lifecycle.employee@test.com'
      LIMIT 1
    ];
  }

  private static Id getManagerId(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  @isTest
  static void applyAssignmentChangeUpdatesEmployeeAndContact() {
    Portal_Users__c employee = getEmployee();
    Id departmentId = [SELECT Id FROM PWChrono_Department__c LIMIT 1].Id;
    Id designationId = [SELECT Id FROM PWChrono_Designation__c LIMIT 1].Id;
    Id managerId = getManagerId('lifecycle.manager@test.com');

    Test.startTest();
    PWChrono_EmployeeLifecycleService.applyAssignmentChange(
      employee.Id,
      departmentId,
      designationId,
      managerId
    );
    Test.stopTest();

    Portal_Users__c updated = getEmployee();
    Assert.areEqual('Engineering', updated.Department__c);
    Assert.areEqual('Senior Developer', updated.Designation__c);
    Assert.areEqual(managerId, updated.Reports_To__c);

    Contact updatedContact = [
      SELECT Department, Title, ReportsToId
      FROM Contact
      WHERE Id = :employee.Contact__c
    ];
    Assert.areEqual('Engineering', updatedContact.Department);
    Assert.areEqual('Senior Developer', updatedContact.Title);
    Assert.isNull(
      updatedContact.ReportsToId,
      'A manager without a Contact clears the directory manager'
    );
  }

  @isTest
  static void applyAssignmentChangeUpdatesDirectoryManager() {
    Portal_Users__c employee = getEmployee();
    Contact oldManagerContact = new Contact(LastName = 'Old Manager');
    Contact newManagerContact = new Contact(LastName = 'New Manager');
    insert new List<Contact>{ oldManagerContact, newManagerContact };
    update new Contact(
      Id = employee.Contact__c,
      ReportsToId = oldManagerContact.Id
    );
    Portal_Users__c manager = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Email__c = 'lifecycle.manager@test.com'
    ];
    manager.Contact__c = newManagerContact.Id;
    update manager;

    PWChrono_EmployeeLifecycleService.applyAssignmentChange(
      employee.Id,
      null,
      null,
      manager.Id
    );

    Assert.areEqual(manager.Id, getEmployee().Reports_To__c);
    Assert.areEqual(
      newManagerContact.Id,
      [SELECT ReportsToId FROM Contact WHERE Id = :employee.Contact__c]
      .ReportsToId,
      'The directory shows the new manager'
    );
  }

  @isTest
  static void applyAssignmentChangeLeavesNullValuesUnchanged() {
    Portal_Users__c employee = getEmployee();
    Id designationId = [SELECT Id FROM PWChrono_Designation__c LIMIT 1].Id;

    PWChrono_EmployeeLifecycleService.applyAssignmentChange(
      employee.Id,
      null,
      designationId,
      null
    );

    Portal_Users__c updated = getEmployee();
    Assert.areEqual('Old Department', updated.Department__c);
    Assert.areEqual('Senior Developer', updated.Designation__c);
    Assert.isNull(updated.Reports_To__c);
  }

  @isTest
  static void applyAssignmentChangeRejectsInvalidManagers() {
    Portal_Users__c employee = getEmployee();
    Id inactiveManagerId = getManagerId('inactive.manager@test.com');

    try {
      PWChrono_EmployeeLifecycleService.applyAssignmentChange(
        employee.Id,
        null,
        null,
        employee.Id
      );
      Assert.fail('An employee must not report to themselves.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(e.getMessage().contains('themselves'));
    }

    try {
      PWChrono_EmployeeLifecycleService.applyAssignmentChange(
        employee.Id,
        null,
        null,
        inactiveManagerId
      );
      Assert.fail('An inactive manager must be rejected.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(e.getMessage().contains('active employee'));
    }

    Assert.isNull(getEmployee().Reports_To__c);
  }

  @isTest
  static void applyAssignmentChangeRejectsInactiveOrMissingEmployee() {
    Portal_Users__c employee = getEmployee();
    employee.Is_Active__c = false;
    update employee;

    try {
      PWChrono_EmployeeLifecycleService.applyAssignmentChange(
        employee.Id,
        null,
        null,
        null
      );
      Assert.fail('Changes must not apply to an inactive employee.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(e.getMessage().contains('inactive'));
    }

    try {
      PWChrono_EmployeeLifecycleService.applyAssignmentChange(
        null,
        null,
        null,
        null
      );
      Assert.fail('A missing employee must be rejected.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(e.getMessage().contains('required'));
    }
  }

  @isTest
  static void applyAssignmentChangeRejectsUnknownDepartmentAndDesignation() {
    Portal_Users__c employee = getEmployee();
    PWChrono_Department__c department = [
      SELECT Id
      FROM PWChrono_Department__c
      LIMIT 1
    ];
    PWChrono_Designation__c designation = [
      SELECT Id
      FROM PWChrono_Designation__c
      LIMIT 1
    ];
    Id departmentId = department.Id;
    Id designationId = designation.Id;
    delete department;
    delete designation;

    try {
      PWChrono_EmployeeLifecycleService.applyAssignmentChange(
        employee.Id,
        departmentId,
        null,
        null
      );
      Assert.fail('A deleted department must be rejected.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(e.getMessage().contains('department'));
    }

    try {
      PWChrono_EmployeeLifecycleService.applyAssignmentChange(
        employee.Id,
        null,
        designationId,
        null
      );
      Assert.fail('A deleted designation must be rejected.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(e.getMessage().contains('designation'));
    }
  }

  @isTest
  static void deactivateEmployeeEndsAccess() {
    Portal_Users__c employee = getEmployee();

    PWChrono_EmployeeLifecycleService.deactivateEmployee(employee.Id);

    Portal_Users__c updated = getEmployee();
    Assert.isFalse(updated.Is_Active__c);
    Assert.isNull(updated.Session_Token__c);
    Assert.isNull(updated.Session_Expires_At__c);
    Assert.isNull(updated.One_Time_Password__c);
    Assert.isNull(updated.OTP_Generated_Time__c);
  }

  @isTest
  static void requireEffectiveDateBlocksFutureDates() {
    PWChrono_EmployeeLifecycleService.requireEffectiveDate(
      Date.today(),
      'This promotion'
    );
    PWChrono_EmployeeLifecycleService.requireEffectiveDate(
      null,
      'This promotion'
    );

    try {
      PWChrono_EmployeeLifecycleService.requireEffectiveDate(
        Date.today().addDays(3),
        'This promotion'
      );
      Assert.fail('A future effective date must be rejected.');
    } catch (PWChrono_EmployeeLifecycleService.LifecycleException e) {
      Assert.isTrue(
        e.getMessage().startsWith('This promotion takes effect on')
      );
    }
  }

  @isTest
  static void createChecklistFromTemplateCopiesActivitiesOnce() {
    Portal_Users__c employee = getEmployee();
    Id managerId = getManagerId('lifecycle.manager@test.com');

    PWChrono_Separation_Template__c template = new PWChrono_Separation_Template__c(
      Name = 'Standard Exit',
      Is_Active__c = true
    );
    insert template;
    insert new List<PWChrono_Separation_Template_Activity__c>{
      new PWChrono_Separation_Template_Activity__c(
        Name = 'Return laptop',
        Separation_Template__c = template.Id,
        Assigned_To__c = managerId,
        Is_Required__c = true,
        Begin_On_Day__c = 1,
        Duration__c = 2
      ),
      new PWChrono_Separation_Template_Activity__c(
        Name = 'Knowledge transfer',
        Separation_Template__c = template.Id,
        Is_Required__c = false
      )
    };

    PWChrono_Employee_Separation__c separation = new PWChrono_Employee_Separation__c(
      Employee__c = employee.Id,
      Separation_Template__c = template.Id,
      Status__c = 'Pending'
    );
    insert separation;

    Test.startTest();
    Integer created = PWChrono_EmployeeLifecycleService.createChecklistFromTemplate(
      separation.Id,
      template.Id
    );
    Integer createdAgain = PWChrono_EmployeeLifecycleService.createChecklistFromTemplate(
      separation.Id,
      template.Id
    );
    Test.stopTest();

    Assert.areEqual(2, created);
    Assert.areEqual(
      0,
      createdAgain,
      'Existing checklists must not be duplicated.'
    );

    List<PWChrono_Separation_Checklist__c> items = [
      SELECT Name, Assigned_To__c, Is_Required__c, Status__c, Notes__c
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :separation.Id
      ORDER BY Name
    ];
    Assert.areEqual(2, items.size());
    Assert.areEqual('Knowledge transfer', items[0].Name);
    Assert.isNull(items[0].Notes__c);
    Assert.areEqual('Return laptop', items[1].Name);
    Assert.areEqual(managerId, items[1].Assigned_To__c);
    Assert.isTrue(items[1].Is_Required__c);
    Assert.areEqual('Pending', items[1].Status__c);
    Assert.areEqual('Starts on day 1; takes 2 day(s)', items[1].Notes__c);

    Assert.areEqual(
      0,
      PWChrono_EmployeeLifecycleService.createChecklistFromTemplate(
        null,
        template.Id
      )
    );
  }
}