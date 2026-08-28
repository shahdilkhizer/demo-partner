/**
 * @description Shared validation utilities for all request-based modules
 *              (Leave, Attendance, Expense, Shift, Advance).
 *              Contains reusable checks that are common across request types.
 *              Pure validation — no DML.
 */
public inherited sharing class PWChrono_RequestValidator {

  /**
   * @description Validate that the employee record is active
   * @param employeeId Portal_Users__c Id
   * @return Error message or null if valid
   */
  public static String validateActiveEmployee(Id employeeId) {
    if (employeeId == null) {
      return 'Employee ID is required.';
    }

    List<Portal_Users__c> employees = [
      SELECT Id, Is_Active__c, Name
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    if (employees.isEmpty()) {
      return 'Employee record not found.';
    }

    if (employees[0].Is_Active__c != true) {
      return 'Only active employees can submit requests.';
    }

    return null;
  }

  /**
   * @description Validate that a date range is logically valid
   * @param fromDate Start date
   * @param toDate End date
   * @return Error message or null if valid
   */
  public static String validateDateRange(Date fromDate, Date toDate) {
    if (fromDate == null) {
      return 'Start date is required.';
    }
    if (toDate == null) {
      return 'End date is required.';
    }
    if (toDate < fromDate) {
      return 'End date must be on or after the start date.';
    }
    return null;
  }

  /**
   * @description Validate that a request date is not too far in the past
   * @param requestDate The date to check
   * @param maxBackdatedDays Maximum allowed days in the past (0 = no backdated allowed)
   * @return Error message or null if valid
   */
  public static String validateBackdatedLimit(Date requestDate, Integer maxBackdatedDays) {
    if (requestDate == null || maxBackdatedDays == null) {
      return null;
    }

    Date cutoff = Date.today().addDays(-maxBackdatedDays);
    if (requestDate < cutoff) {
      return 'Requests cannot be backdated more than ' + maxBackdatedDays + ' days.';
    }

    return null;
  }

  /**
   * @description Validate that a request date is not too far in the future
   * @param requestDate The date to check
   * @param maxAdvanceDays Maximum allowed days in the future (0 = no advance allowed)
   * @return Error message or null if valid
   */
  public static String validateAdvanceLimit(Date requestDate, Integer maxAdvanceDays) {
    if (requestDate == null || maxAdvanceDays == null) {
      return null;
    }

    Date cutoff = Date.today().addDays(maxAdvanceDays);
    if (requestDate > cutoff) {
      return 'Requests cannot be more than ' + maxAdvanceDays + ' days in advance.';
    }

    return null;
  }

  /**
   * @description Valid status transitions for request-based objects.
   *              Returns true if the transition from → to is allowed.
   */
  public static Boolean isValidStatusTransition(String fromStatus, String toStatus) {
    if (String.isBlank(fromStatus) || String.isBlank(toStatus)) {
      return false;
    }

    Map<String, Set<String>> allowed = new Map<String, Set<String>>{
      'Draft'     => new Set<String>{ 'Submitted', 'Cancelled' },
      'Submitted' => new Set<String>{ 'Approved', 'Rejected', 'Cancelled' },
      'Approved'  => new Set<String>{ 'Cancelled' },
      'Rejected'  => new Set<String>{ 'Draft' },
      'Cancelled' => new Set<String>()
    };

    Set<String> targets = allowed.get(fromStatus);
    return targets != null && targets.contains(toStatus);
  }

  /**
   * @description Validate status transition and return error message if invalid
   */
  public static String validateStatusTransition(String fromStatus, String toStatus) {
    if (!isValidStatusTransition(fromStatus, toStatus)) {
      return 'Invalid status transition from ' + fromStatus + ' to ' + toStatus + '.';
    }
    return null;
  }

  /**
   * @description Resolve the employee ID from either a portal user or SF internal user context.
   *              Handles guest vs internal user branching.
   * @param portalUserId Explicit Portal_Users__c Id (for guest users)
   * @param sessionToken Session token (for guest users)
   * @return Verified Portal_Users__c Id
   */
  public static Id resolveEmployeeId(String portalUserId, String sessionToken) {
    if (UserInfo.getUserType() == 'Guest') {
      return PWChrono_GuestSession.requireVerifiedPortalUserId(portalUserId, sessionToken);
    }

    if (String.isNotBlank(portalUserId)) {
      return (Id) portalUserId;
    }

    Id sfUserId = UserInfo.getUserId();
    Id empId = PWChrono_Utils.getCurrentEmployeeId(sfUserId);
    if (empId == null) {
      throw new AuraHandledException('No employee record found for current user.');
    }
    return empId;
  }

  /**
   * @description Check if the requesting user has admin privileges
   */
  public static Boolean isCurrentUserAdmin(Id employeeId) {
    return PWChrono_AccessController.isAdmin(employeeId);
  }

  /**
   * @description Check that the current employee can view another employee's data.
   *              Admins can view anyone; non-admins can only view own data.
   * @return The effective target employee ID (enforced to own if not admin)
   */
  public static Id enforceDataAccess(Id currentEmployeeId, Id targetEmployeeId) {
    if (targetEmployeeId == null || targetEmployeeId == currentEmployeeId) {
      return currentEmployeeId;
    }

    if (PWChrono_AccessController.isAdmin(currentEmployeeId)) {
      return targetEmployeeId;
    }

    return currentEmployeeId;
  }
}