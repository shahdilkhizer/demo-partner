/**
 * @description Shared service for request-based modules (Leave, Attendance, Expense, etc.).
 *              Handles status transitions, notification dispatch, and common orchestration.
 */
public inherited sharing class PWChrono_RequestService {

  /**
   * @description Transition a request record's status with validation.
   * @param currentStatus Current status value
   * @param newStatus Desired status value
   * @return The validated new status
   */
  public static String transitionStatus(String currentStatus, String newStatus) {
    String error = PWChrono_RequestValidator.validateStatusTransition(currentStatus, newStatus);
    if (error != null) {
      throw new AuraHandledException(error);
    }
    return newStatus;
  }

  /**
   * @description Auto-assign approver based on employee's Reports_To field.
   * @param employeeId The employee submitting the request
   * @return The approver's Portal_Users__c Id, or null if no manager found
   */
  public static Id resolveApprover(Id employeeId) {
    if (employeeId == null) {
      return null;
    }

    List<Portal_Users__c> employees = [
      SELECT Reports_To__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    if (employees.isEmpty() || employees[0].Reports_To__c == null) {
      return null;
    }

    return employees[0].Reports_To__c;
  }

  /**
   * @description Build a notification payload for a request action.
   *              Uses the existing TLG_Task_Notifications__c object.
   *              The recipient is set via OwnerId (User__c from Portal_Users__c).
   * @param recipientEmployeeId Portal_Users__c Id of the recipient
   * @param requestType e.g., "Leave", "Attendance", "Expense"
   * @param requestName e.g., "LV-00042"
   * @param action e.g., "Submitted", "Approved", "Rejected", "Cancelled"
   * @param actorName Name of the person who performed the action
   * @param relatedRecordId Optional related record Id for navigation
   * @return Notification record ready for insert (not inserted)
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static TLG_Task_Notifications__c buildNotification(
    Id recipientEmployeeId,
    String requestType,
    String requestName,
    String action,
    String actorName,
    Id relatedRecordId
  ) {
    String title = requestType + ' Request ' + action;
    String message = actorName + ' has ' + action.toLowerCase() + ' ' +
                     requestType.toLowerCase() + ' request ' + requestName + '.';

    // Resolve the User Id from Portal_Users__c for OwnerId
    Id ownerId = resolveUserId(recipientEmployeeId);

    TLG_Task_Notifications__c notif = new TLG_Task_Notifications__c();
    if (ownerId != null) {
      notif.OwnerId = ownerId;
    }
    notif.TLG_Notification_Title__c = title;
    notif.TLG_Task_Detail__c = message;
    notif.TLG_Notified__c = false;
    if (relatedRecordId != null) {
      notif.TLG_Tasks__c = relatedRecordId;
    }
    return notif;
  }

  /**
   * @description Send a single notification (insert).
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void sendNotification(
    Id recipientEmployeeId,
    String requestType,
    String requestName,
    String action,
    String actorName,
    Id relatedRecordId
  ) {
    try {
      TLG_Task_Notifications__c notif = buildNotification(
        recipientEmployeeId, requestType, requestName, action, actorName, relatedRecordId
      );
      insert notif;
    } catch (Exception e) {
      PWChrono_Logger.warn('Failed to send notification: ' + e.getMessage());
    }
  }

  /**
   * @description Send notifications in bulk.
   */
  public static void sendNotifications(List<TLG_Task_Notifications__c> notifications) {
    if (notifications == null || notifications.isEmpty()) {
      return;
    }
    try {
      insert notifications;
    } catch (Exception e) {
      PWChrono_Logger.warn('Failed to send bulk notifications: ' + e.getMessage());
    }
  }

  /**
   * @description Resolve the SF User Id from a Portal_Users__c record for assignment.
   */
  private static Id resolveUserId(Id employeeId) {
    if (employeeId == null) {
      return null;
    }
    List<Portal_Users__c> employees = [
      SELECT User__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    return employees.isEmpty() ? null : employees[0].User__c;
  }

  /**
   * @description Get the display name for an employee by Id.
   */
  public static String getEmployeeName(Id employeeId) {
    if (employeeId == null) {
      return 'Unknown';
    }

    List<Portal_Users__c> employees = [
      SELECT Name
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    return employees.isEmpty() ? 'Unknown' : employees[0].Name;
  }
}