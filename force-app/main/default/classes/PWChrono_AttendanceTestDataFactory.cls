/**
 * @description Test data factory for Attendance module tests.
 *              Mirrors PWChrono_LeaveTestDataFactory pattern.
 *              All inserts are done in setupStandardTestData() or helpers.
 */
@IsTest
public class PWChrono_AttendanceTestDataFactory {

  // ─────────────────────── Record builders ─────────────────────────────────

  public static Portal_Users__c createEmployee(String name, Boolean isActive) {
    Portal_Users__c emp = new Portal_Users__c(
      Name       = name,
      Is_Active__c = isActive,
      Role__c    = 'Employee',
      Date_Of_Joining__c = Date.today().addYears(-1)
    );
    insert emp;
    return emp;
  }

  public static Portal_Users__c createManager(String name) {
    Portal_Users__c mgr = new Portal_Users__c(
      Name         = name,
      Is_Active__c = true,
      Role__c      = 'Manager',
      Date_Of_Joining__c = Date.today().addYears(-2)
    );
    insert mgr;
    return mgr;
  }

  public static Portal_Users__c createAdmin(String name) {
    Portal_Users__c admin = new Portal_Users__c(
      Name         = name,
      Is_Active__c = true,
      Role__c      = 'HR Admin',
      Date_Of_Joining__c = Date.today().addYears(-3)
    );
    insert admin;
    return admin;
  }

  public static PWChrono_Shift_Type__c createShiftType(String name, Time startTime, Time endTime) {
    PWChrono_Shift_Type__c st = new PWChrono_Shift_Type__c(
      Name          = name,
      Start_Time__c = startTime,
      End_Time__c   = endTime,
      Working_Hours__c = 9,
      Is_Active__c  = true,
      Grace_Period_Minutes__c = 15
    );
    insert st;
    return st;
  }

  public static PWChrono_Shift_Assignment__c createShiftAssignment(
    Id employeeId, Id shiftTypeId, Date fromDate, Date toDate
  ) {
    PWChrono_Shift_Assignment__c sa = new PWChrono_Shift_Assignment__c(
      Employees__c  = employeeId,
      Shift_Type__c = shiftTypeId,
      From_Date__c  = fromDate,
      To_Date__c    = toDate,
      Status__c     = 'Active'
    );
    insert sa;
    return sa;
  }

  /**
   * @description Creates an attendance correction request.
   */
  public static PWChrono_Attendance_Request__c createAttendanceRequest(
    Id employeeId, Id approverId, Date attendanceDate,
    String correctionType, String status
  ) {
    PWChrono_Attendance_Request__c req = new PWChrono_Attendance_Request__c(
      Employees__c      = employeeId,
      Approvers__c      = approverId,
      Attendance_Date__c = attendanceDate,
      Correction_Type__c = correctionType,
      From_Time__c      = Time.newInstance(9, 0, 0, 0),
      To_Time__c        = Time.newInstance(18, 0, 0, 0),
      Reason__c         = 'Test reason for ' + correctionType,
      Status__c         = status,
      Applied_Date__c   = Date.today()
    );
    insert req;
    return req;
  }

  // ─────────────────────── Standard bundle ─────────────────────────────────

  public class TestDataBundle {
    public Portal_Users__c manager;
    public Portal_Users__c employee;
    public Portal_Users__c admin;
    public PWChrono_Shift_Type__c morningShift;
    public PWChrono_Shift_Assignment__c shiftAssignment;
    public PWChrono_Attendance_Request__c submittedRequest;
    public PWChrono_Attendance_Request__c approvedRequest;
  }

  public static TestDataBundle setupStandardTestData() {
    TestDataBundle bundle = new TestDataBundle();

    bundle.manager  = createManager('Test Manager');
    bundle.employee = createEmployee('Test Employee', true);
    bundle.admin    = createAdmin('Test Admin');

    // Link employee to manager
    bundle.employee.Reports_To__c = bundle.manager.Id;
    update bundle.employee;

    bundle.morningShift = createShiftType(
      'Morning', Time.newInstance(9,0,0,0), Time.newInstance(18,0,0,0)
    );
    bundle.shiftAssignment = createShiftAssignment(
      bundle.employee.Id, bundle.morningShift.Id,
      Date.today().addDays(-30), Date.today().addDays(30)
    );

    bundle.submittedRequest = createAttendanceRequest(
      bundle.employee.Id, bundle.manager.Id,
      Date.today().addDays(-3), 'Check-Out Missing', 'Submitted'
    );

    bundle.approvedRequest = createAttendanceRequest(
      bundle.employee.Id, bundle.manager.Id,
      Date.today().addDays(-10), 'Wrong Time', 'Approved'
    );

    return bundle;
  }

  // ─────────────────────── DTO builder ─────────────────────────────────────

  public static PWChrono_AttendanceValidator.AttendanceRequestDTO buildDTO(
    Date attendanceDate, String correctionType
  ) {
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto =
      new PWChrono_AttendanceValidator.AttendanceRequestDTO();
    dto.attendanceDate    = attendanceDate;
    dto.correctionType    = correctionType;
    dto.requestedCheckIn  = '09:00';
    dto.requestedCheckOut = '18:30';
    dto.reason            = 'Test correction reason.';
    return dto;
  }
}