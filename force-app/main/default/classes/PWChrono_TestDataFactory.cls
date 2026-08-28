@isTest
public inherited sharing class PWChrono_TestDataFactory {
  public static Portal_Users__c createPortalUser(
    String name,
    String email,
    String role
  ) {
    Portal_Users__c user = new Portal_Users__c(
      Name = name,
      Email__c = email,
      Role__c = role,
      Is_Active__c = true
    );
    insert user;
    return user;
  }

  public static PWChrono_Feature_Settings__c createFeatureSettings() {
    PWChrono_Feature_Settings__c settings = new PWChrono_Feature_Settings__c(
      Name = 'Default Settings',
      Enable_Leave_Encashment__c = true,
      Enable_Manager_Delegation__c = true,
      Enable_Payroll_Module__c = true,
      Enable_Performance_Module__c = true,
      Enable_Recruitment_Module__c = true,
      Enable_Self_Service_Portal__c = true,
      Enable_Training_Module__c = true,
      Auto_Approve_Attendance_Request__c = false
    );
    insert settings;
    return settings;
  }

  public static PWChrono_Leave_Type__c createLeaveType(
    String name,
    Integer maxDays
  ) {
    PWChrono_Leave_Type__c leaveType = new PWChrono_Leave_Type__c(
      Name = name,
      Max_Days_Allowed__c = maxDays,
      Is_Active__c = true
    );
    insert leaveType;
    return leaveType;
  }

  public static PWChrono_Leave_Allocation__c createLeaveAllocation(
    Id employeeId,
    Id leaveTypeId,
    Decimal allocated
  ) {
    PWChrono_Leave_Allocation__c allocation = new PWChrono_Leave_Allocation__c(
      Employees__c = employeeId,
      Leave_Type__c = leaveTypeId,
      Total_Leaves_Allocated__c = allocated,
      From_Date__c = Date.newInstance(Date.today().year(), 1, 1),
      To_Date__c = Date.newInstance(Date.today().year(), 12, 31)
    );
    insert allocation;
    return allocation;
  }

  public static PWChrono_Shift_Type__c createShiftType(
    String name,
    Time startTime,
    Time endTime
  ) {
    PWChrono_Shift_Type__c shiftType = new PWChrono_Shift_Type__c(
      Name = name,
      Start_Time__c = startTime,
      End_Time__c = endTime,
      Is_Active__c = true
    );
    insert shiftType;
    return shiftType;
  }

  public static PWChrono_Department__c createDepartment(String name) {
    PWChrono_Department__c dept = new PWChrono_Department__c(
      Name = name,
      Is_Active__c = true
    );
    insert dept;
    return dept;
  }

  public static PWChrono_Designation__c createDesignation(String name) {
    PWChrono_Designation__c desig = new PWChrono_Designation__c(
      Name = name,
      Is_Active__c = true
    );
    insert desig;
    return desig;
  }

  public static User createTestUser(String lastName) {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    User u = new User(
      Alias = ('tuser' + lastName.deleteWhitespace()).left(8),
      Email = 'standarduser' + lastName.deleteWhitespace() + '@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = lastName,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'tuser' +
        lastName.deleteWhitespace() +
        DateTime.now().getTime() +
        '@testorg.com'
    );
    insert u;
    return u;
  }

  public static void createTestUsers() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    User u = new User(
      Alias = 'tuser',
      Email = 'standarduser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'tuser' + DateTime.now().getTime() + '@testorg.com'
    );
    insert u;

    User admin = new User(
      Alias = 'admin',
      Email = 'admin@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Admin',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator']
      .Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'admin' + DateTime.now().getTime() + '@testorg.com'
    );
    insert admin;
  }

  public static Portal_Users__c createTestEmployee(Id userId) {
    Portal_Users__c pu = new Portal_Users__c(
      Name = 'Test Employee',
      Email__c = 'testemployee@example.com',
      Role__c = 'Employee',
      User__c = userId,
      Is_Active__c = true
    );
    insert pu;
    return pu;
  }

  public static void assignPermissionSet(Id userId, String permissionSetName) {
    // Permission Sets are no longer used. This method is kept for backward compatibility but does nothing.
  }
}