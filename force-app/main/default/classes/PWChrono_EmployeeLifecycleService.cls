/**
 * @description Applies approved employee lifecycle outcomes (promotion,
 *              transfer, separation) to the employee's portal record and the
 *              linked Contact used by the directory and payroll.
 *
 *              Runs without sharing because portal requests execute as the
 *              site guest user and employee records use a private external
 *              sharing model. Callers must verify the portal session, the
 *              Employee Lifecycle feature and administrator authority before
 *              invoking any method in this class.
 */
public without sharing class PWChrono_EmployeeLifecycleService {
  public static final String CHECKLIST_STATUS_PENDING = 'Pending';

  public class LifecycleException extends Exception {
  }

  /**
   * @description Rejects an action whose effective date is still in the
   *              future. A blank date is treated as effective today.
   * @param effectiveDate Date the change takes effect
   * @param actionLabel Human-readable action, e.g. 'This promotion'
   */
  public static void requireEffectiveDate(
    Date effectiveDate,
    String actionLabel
  ) {
    if (effectiveDate != null && effectiveDate > Date.today()) {
      throw new LifecycleException(
        actionLabel +
          ' takes effect on ' +
          effectiveDate.format() +
          '. Complete this step on or after that date.'
      );
    }
  }

  /**
   * @description Applies a new department, designation and reporting manager
   *              to an employee. A null argument leaves that value unchanged.
   *              Updates both the portal record and the linked Contact
   *              (department, title and reporting manager) so the directory,
   *              access scope and approvals stay consistent.
   */
  public static void applyAssignmentChange(
    Id employeeId,
    Id newDepartmentId,
    Id newDesignationId,
    Id newReportsToId
  ) {
    Portal_Users__c employee = getEmployee(employeeId);
    if (employee.Is_Active__c != true) {
      throw new LifecycleException(
        'Changes cannot be applied to an inactive employee.'
      );
    }

    Contact linkedContact = employee.Contact__c == null
      ? null
      : new Contact(Id = employee.Contact__c);
    Boolean contactChanged = false;

    if (newDepartmentId != null) {
      String departmentName = getDepartmentName(newDepartmentId);
      employee.Department__c = departmentName;
      if (linkedContact != null) {
        linkedContact.Department = departmentName.left(80);
        contactChanged = true;
      }
    }

    if (newDesignationId != null) {
      String designationName = getDesignationName(newDesignationId);
      employee.Designation__c = designationName;
      if (linkedContact != null) {
        linkedContact.Title = designationName.left(128);
        contactChanged = true;
      }
    }

    if (newReportsToId != null) {
      if (newReportsToId == employeeId) {
        throw new LifecycleException(
          'An employee cannot report to themselves.'
        );
      }
      List<Portal_Users__c> managers = [
        SELECT Id, Contact__c
        FROM Portal_Users__c
        WHERE Id = :newReportsToId AND Is_Active__c = TRUE
        LIMIT 1
      ];
      if (managers.isEmpty()) {
        throw new LifecycleException(
          'The new reporting manager must be an active employee.'
        );
      }
      employee.Reports_To__c = newReportsToId;
      // The directory shows the manager from Contact.ReportsTo. Point it at the
      // new manager's Contact, or clear it so the old manager is not shown.
      if (linkedContact != null) {
        Id managerContactId = managers[0].Contact__c;
        linkedContact.ReportsToId = managerContactId == employee.Contact__c
          ? null
          : managerContactId;
        contactChanged = true;
      }
    }

    update employee;
    if (contactChanged) {
      update linkedContact;
    }
  }

  /**
   * @description Deactivates an employee and ends any active portal session
   *              or pending one-time password, so the person can no longer
   *              sign in.
   */
  public static void deactivateEmployee(Id employeeId) {
    Portal_Users__c employee = getEmployee(employeeId);
    employee.Is_Active__c = false;
    employee.Session_Token__c = null;
    employee.Session_Expires_At__c = null;
    employee.One_Time_Password__c = null;
    employee.OTP_Generated_Time__c = null;
    update employee;
  }

  /**
   * @description Creates checklist items for a separation from its
   *              template's activities. Does nothing when the separation
   *              already has checklist items or no template is given.
   * @return Number of checklist items created
   */
  public static Integer createChecklistFromTemplate(
    Id separationId,
    Id templateId
  ) {
    if (separationId == null || templateId == null) {
      return 0;
    }
    List<PWChrono_Separation_Checklist__c> existing = [
      SELECT Id
      FROM PWChrono_Separation_Checklist__c
      WHERE Separation__c = :separationId
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return 0;
    }

    List<PWChrono_Separation_Checklist__c> items = new List<PWChrono_Separation_Checklist__c>();
    for (PWChrono_Separation_Template_Activity__c activity : [
      SELECT Name, Assigned_To__c, Is_Required__c, Begin_On_Day__c, Duration__c
      FROM PWChrono_Separation_Template_Activity__c
      WHERE Separation_Template__c = :templateId
      ORDER BY Begin_On_Day__c ASC NULLS LAST, Name ASC
    ]) {
      items.add(
        new PWChrono_Separation_Checklist__c(
          Name = activity.Name,
          Separation__c = separationId,
          Assigned_To__c = activity.Assigned_To__c,
          Is_Required__c = activity.Is_Required__c == true,
          Status__c = CHECKLIST_STATUS_PENDING,
          Notes__c = describeSchedule(activity)
        )
      );
    }
    if (!items.isEmpty()) {
      insert items;
    }
    return items.size();
  }

  private static String describeSchedule(
    PWChrono_Separation_Template_Activity__c activity
  ) {
    if (activity.Begin_On_Day__c == null) {
      return null;
    }
    String note = 'Starts on day ' + activity.Begin_On_Day__c.intValue();
    if (activity.Duration__c != null) {
      note += '; takes ' + activity.Duration__c.intValue() + ' day(s)';
    }
    return note;
  }

  private static Portal_Users__c getEmployee(Id employeeId) {
    if (employeeId == null) {
      throw new LifecycleException('An employee is required.');
    }
    List<Portal_Users__c> employees = [
      SELECT Id, Contact__c, Is_Active__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    if (employees.isEmpty()) {
      throw new LifecycleException('Employee was not found.');
    }
    return employees[0];
  }

  private static String getDepartmentName(Id departmentId) {
    List<PWChrono_Department__c> departments = [
      SELECT Name
      FROM PWChrono_Department__c
      WHERE Id = :departmentId
      LIMIT 1
    ];
    if (departments.isEmpty()) {
      throw new LifecycleException('The new department was not found.');
    }
    return departments[0].Name;
  }

  private static String getDesignationName(Id designationId) {
    List<PWChrono_Designation__c> designations = [
      SELECT Name
      FROM PWChrono_Designation__c
      WHERE Id = :designationId
      LIMIT 1
    ];
    if (designations.isEmpty()) {
      throw new LifecycleException('The new designation was not found.');
    }
    return designations[0].Name;
  }
}