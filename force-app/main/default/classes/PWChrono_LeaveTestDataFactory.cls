/**
 * @description Test data factory for Leave module tests.
 *              Creates the base records needed across all leave test classes.
 */
@IsTest
public class PWChrono_LeaveTestDataFactory {

  public static Portal_Users__c createEmployee(String name, Boolean isActive) {
    Portal_Users__c emp = new Portal_Users__c(
      Name = name,
      Email__c = name.deleteWhitespace().toLowerCase() + '@test.com',
      Is_Active__c = isActive,
      Role__c = 'Employee',
      User__c = UserInfo.getUserId()
    );
    insert emp;
    return emp;
  }

  public static Portal_Users__c createAdmin(String name) {
    Portal_Users__c admin = new Portal_Users__c(
      Name = name,
      Email__c = name.deleteWhitespace().toLowerCase() + '@test.com',
      Is_Active__c = true,
      Role__c = 'HR Admin',
      User__c = UserInfo.getUserId()
    );
    insert admin;
    return admin;
  }

  public static Portal_Users__c createManager(String name) {
    Portal_Users__c mgr = new Portal_Users__c(
      Name = name,
      Email__c = name.deleteWhitespace().toLowerCase() + '@test.com',
      Is_Active__c = true,
      Role__c = 'Manager'
    );
    insert mgr;
    return mgr;
  }

  public static PWChrono_Leave_Type__c createLeaveType(String name, Decimal maxDays) {
    PWChrono_Leave_Type__c lt = new PWChrono_Leave_Type__c(
      Name = name,
      Max_Days_Allowed__c = maxDays,
      Is_Active__c = true,
      Requires_Approval__c = true,
      Requires_Certificate__c = false,
      Is_Carry_Forward__c = false,
      Is_Unpaid__c = false,
      Allow_Negative_Balance__c = false,
      Allow_Half_Day__c = true
    );
    insert lt;
    return lt;
  }

  public static PWChrono_Leave_Block_Date__c createBlockedDate(Date blockDate) {
    PWChrono_Leave_Block_Date__c blockedDate = new PWChrono_Leave_Block_Date__c(
      Block_Date__c = blockDate,
      Reason__c = 'Month-end close',
      Is_Active__c = true,
      Allow_Exceptions__c = false
    );
    insert blockedDate;
    return blockedDate;
  }

  public static PWChrono_Salary_Slip__c createPaidSalarySlip(Id employeeId, Date payrollPeriod) {
    PWChrono_Salary_Slip__c salarySlip = new PWChrono_Salary_Slip__c(
      Employees__c = employeeId,
      Payroll_Period__c = payrollPeriod,
      Status__c = 'Paid',
      Gross_Pay__c = 1000,
      Net_Pay__c = 900,
      Total_Deductions__c = 100
    );
    insert salarySlip;
    return salarySlip;
  }

  public static PWChrono_Leave_Allocation__c createAllocation(
    Id employeeId, Id leaveTypeId, Decimal allocated
  ) {
    PWChrono_Leave_Allocation__c alloc = new PWChrono_Leave_Allocation__c(
      Employees__c = employeeId,
      Leave_Type__c = leaveTypeId,
      Total_Leaves_Allocated__c = allocated,
      Total_Leaves_Used__c = 0,
      Total_Leaves_Encashed__c = 0,
      Carry_Forwarded_Leaves__c = 0,
      From_Date__c = Date.today().toStartOfMonth(),
      To_Date__c = Date.today().addMonths(12)
    );
    insert alloc;
    return alloc;
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static PWChrono_Leave__c createLeave(
    Id employeeId, Id leaveTypeId, Id approverId,
    Date fromDate, Date toDate, String status
  ) {
    PWChrono_Leave__c leave = new PWChrono_Leave__c(
      Employees__c = employeeId,
      Leave_Type__c = leaveTypeId,
      Approvers__c = approverId,
      From_Date__c = fromDate,
      To_Date__c = toDate,
      Total_Days__c = fromDate.daysBetween(toDate) + 1,
      Reason__c = 'Test leave',
      Status__c = status,
      Applied_Date__c = Date.today(),
      Half_Day__c = false
    );
    insert leave;
    return leave;
  }

  public static TestDataBundle setupStandardTestData() {
    TestDataBundle bundle = new TestDataBundle();

    bundle.manager = createManager('Test Manager');
    bundle.employee = new Portal_Users__c(
      Name = 'Test Employee',
      Email__c = 'testemployee@test.com',
      Is_Active__c = true,
      Role__c = 'Employee',
      Reports_To__c = bundle.manager.Id,
      User__c = UserInfo.getUserId()
    );
    insert bundle.employee;

    bundle.admin = createAdmin('Test HRAdmin');
    bundle.annualLeave = createLeaveType('Annual Leave', 20);
    bundle.sickLeave = createLeaveType('Sick Leave', 10);
    bundle.annualAllocation = createAllocation(
      bundle.employee.Id, bundle.annualLeave.Id, 20
    );
    bundle.sickAllocation = createAllocation(
      bundle.employee.Id, bundle.sickLeave.Id, 10
    );

    return bundle;
  }

  public class TestDataBundle {
    public Portal_Users__c employee;
    public Portal_Users__c manager;
    public Portal_Users__c admin;
    public PWChrono_Leave_Type__c annualLeave;
    public PWChrono_Leave_Type__c sickLeave;
    public PWChrono_Leave_Allocation__c annualAllocation;
    public PWChrono_Leave_Allocation__c sickAllocation;
  }
}