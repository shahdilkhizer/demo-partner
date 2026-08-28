/**
 * @description Core business logic for the Attendance module.
 *              Orchestrates validation, DML, system comments, and notifications.
 *              Called exclusively by PWChrono_AttendanceController.
 *              Reuses the shared request framework (RequestService,
 *              RequestValidator, RequestCommentService, RequestAttachmentService).
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_AttendanceService {
  private static final String OBJECT_API_NAME = 'PWChrono_Attendance_Request__c';
  private static final String MODULE_LABEL = 'Attendance';

  // ─────────────────────── Submit / Save ───────────────────────────────────

  /**
   * @description Submits a new or updated attendance correction request.
   *              - Validates the DTO
   *              - Upserts the record
   *              - Auto-assigns approver
   *              - Sends notification
   *              - Records system comment
   * @param dto        Correction request data from the LWC form.
   * @param employeeId Portal_Users__c Id of the submitting employee.
   * @return The freshly-queried record.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static PWChrono_Attendance_Request__c submitRequest(
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto,
    Id employeeId
  ) {
    List<String> errors = PWChrono_AttendanceValidator.validate(
      dto,
      employeeId
    );
    if (!errors.isEmpty()) {
      throw handledException(String.join(errors, '\n'));
    }

    PWChrono_Attendance_Request__c req;

    if (dto.requestId != null) {
      req = PWChrono_AttendanceSelector.getRequestById(dto.requestId);
      if (req == null) {
        throw handledException('Attendance request not found.');
      }
      if (req.Employees__c != employeeId) {
        throw handledException(
          'Unauthorized access to this attendance record.'
        );
      }
      if (
        req.Status__c != 'Draft' &&
        req.Status__c != PWChrono_Constants.STATUS_REJECTED
      ) {
        throw handledException(
          'Only Draft or Rejected requests can be re-submitted.'
        );
      }
    } else {
      req = new PWChrono_Attendance_Request__c();
      req.Employees__c = employeeId;
      req.Applied_Date__c = Date.today();
    }

    req.Attendance_Date__c = dto.attendanceDate;
    req.Correction_Type__c = dto.correctionType;
    req.From_Time__c = PWChrono_AttendanceValidator.parseTime(
      dto.requestedCheckIn
    );
    req.To_Time__c = PWChrono_AttendanceValidator.parseTime(
      dto.requestedCheckOut
    );
    req.Actual_Check_In__c = PWChrono_AttendanceValidator.parseTime(
      dto.actualCheckIn
    );
    req.Actual_Check_Out__c = PWChrono_AttendanceValidator.parseTime(
      dto.actualCheckOut
    );
    req.Reason__c = dto.reason;
    req.Status__c = PWChrono_Constants.STATUS_SUBMITTED;

    // Carry shift context if available
    PWChrono_Shift_Assignment__c shift = PWChrono_AttendanceSelector.getShiftForDate(
      employeeId,
      dto.attendanceDate
    );
    if (shift != null && req.Shift_Assignment__c == null) {
      req.Shift_Assignment__c = shift.Id;
    }

    // Auto-assign approver
    Id approverId = PWChrono_RequestService.resolveApprover(employeeId);
    if (approverId != null) {
      req.Approvers__c = approverId;
    }

    upsert req;

    if (req.Approvers__c != null) {
      String empName = PWChrono_RequestService.getEmployeeName(employeeId);
      PWChrono_RequestService.sendNotification(
        req.Approvers__c,
        MODULE_LABEL,
        req.Name,
        'Submitted',
        empName,
        req.Id
      );
    }

    PWChrono_RequestCommentService.addSystemComment(
      req.Id,
      OBJECT_API_NAME,
      'Attendance correction request submitted for ' +
        dto.attendanceDate.format() +
        '.',
      employeeId
    );

    return PWChrono_AttendanceSelector.getRequestById(req.Id);
  }

  // ─────────────────────── Approve / Reject ────────────────────────────────

  /**
   * @description Processes an approval action (Approve or Reject) for a request.
   *              Only the assigned approver or an admin may act.
   *              Self-approval is blocked.
   * @param requestId  The attendance request Id.
   * @param action     'Approve' or 'Reject'.
   * @param comments   Required for Reject; optional for Approve.
   * @param approverId The acting Portal_Users__c Id.
   * @return The updated record.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static PWChrono_Attendance_Request__c processApproval(
    Id requestId,
    String action,
    String comments,
    Id approverId
  ) {
    PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
      requestId
    );
    if (req == null) {
      throw handledException('Attendance request not found.');
    }

    if (req.Employees__c == approverId) {
      throw handledException('Self-approval is not allowed.');
    }
    if (req.Approvers__c != approverId && !isPortalAdmin(approverId)) {
      throw handledException(
        'Access denied: Not authorized to process this request.'
      );
    }
    if (req.Status__c != PWChrono_Constants.STATUS_SUBMITTED) {
      throw handledException(
        'Only submitted requests can be approved or rejected. Current status: ' +
        req.Status__c
      );
    }

    String approverName = PWChrono_RequestService.getEmployeeName(approverId);
    String normalizedAction = normalizeAction(action);

    if (normalizedAction == 'Approve') {
      req.Status__c = PWChrono_Constants.STATUS_APPROVED;
      req.Approval_Date__c = Date.today();
      req.Approver_Comments__c = String.isNotBlank(comments)
        ? comments.trim()
        : null;
      update req;

      PWChrono_RequestService.sendNotification(
        req.Employees__c,
        MODULE_LABEL,
        req.Name,
        'Approved',
        approverName,
        req.Id
      );
      String commentText = String.isNotBlank(comments)
        ? 'Attendance correction approved. ' + comments.trim()
        : 'Attendance correction approved.';
      PWChrono_RequestCommentService.addSystemComment(
        req.Id,
        OBJECT_API_NAME,
        commentText,
        approverId
      );
    } else if (normalizedAction == 'Reject') {
      if (String.isBlank(comments)) {
        throw handledException('Rejection reason is required.');
      }
      req.Status__c = PWChrono_Constants.STATUS_REJECTED;
      req.Rejection_Reason__c = comments.trim();
      req.Approver_Comments__c = comments.trim();
      req.Approval_Date__c = Date.today();
      update req;

      PWChrono_RequestService.sendNotification(
        req.Employees__c,
        MODULE_LABEL,
        req.Name,
        'Rejected',
        approverName,
        req.Id
      );
      PWChrono_RequestCommentService.addSystemComment(
        req.Id,
        OBJECT_API_NAME,
        'Attendance correction rejected. ' + comments.trim(),
        approverId
      );
    } else {
      throw handledException('Invalid action. Must be Approve or Reject.');
    }

    return PWChrono_AttendanceSelector.getRequestById(req.Id);
  }

  // ─────────────────────── Cancel ──────────────────────────────────────────

  /**
   * @description Cancels a request.  Only the owning employee or an admin may cancel.
   *              Only Draft or Submitted requests can be cancelled.
   */
  public static PWChrono_Attendance_Request__c cancelRequest(
    Id requestId,
    String reason,
    Id employeeId
  ) {
    PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
      requestId
    );
    if (req == null) {
      throw handledException('Attendance request not found.');
    }

    if (req.Employees__c != employeeId && !isPortalAdmin(employeeId)) {
      throw handledException(
        'Unauthorized: You can only cancel your own requests.'
      );
    }

    String transitionError = PWChrono_RequestValidator.validateStatusTransition(
      req.Status__c,
      'Cancelled'
    );
    if (transitionError != null) {
      throw handledException(transitionError);
    }

    req.Status__c = 'Cancelled';
    req.Cancelled_Date__c = Date.today();
    req.Cancelled_Reason__c = reason;
    update req;

    if (req.Approvers__c != null) {
      String empName = PWChrono_RequestService.getEmployeeName(employeeId);
      PWChrono_RequestService.sendNotification(
        req.Approvers__c,
        MODULE_LABEL,
        req.Name,
        'Cancelled',
        empName,
        req.Id
      );
    }

    PWChrono_RequestCommentService.addSystemComment(
      req.Id,
      OBJECT_API_NAME,
      String.isNotBlank(reason)
        ? 'Attendance correction cancelled. ' + reason.trim()
        : 'Attendance correction cancelled.',
      employeeId
    );

    return PWChrono_AttendanceSelector.getRequestById(req.Id);
  }

  // ─────────────────────── Dashboard summary ───────────────────────────────

  /**
   * @description Builds an attendance dashboard summary for the employee.
   *              Returns request counts (by status) for the given month,
   *              plus the 5 most recent requests.
   *              The full day-by-day tracker metrics are loaded separately
   *              by the LWC via getAttendanceTrackerData (parallel call).
   * @param employeeId Portal_Users__c Id.
   * @param startDate  First day of the target month.
   * @param endDate    Last day of the target month.
   * @return AttendanceDashboardDTO with counts and recent requests.
   */
  public static AttendanceDashboardDTO getDashboardSummary(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    AttendanceDashboardDTO dto = new AttendanceDashboardDTO();
    dto.summaryMonth = startDate;

    // Request status counts for the month
    Map<String, Integer> counts = PWChrono_AttendanceSelector.getMonthlyRequestCounts(
      employeeId,
      startDate,
      endDate
    );
    dto.submittedCount = counts.containsKey('Submitted')
      ? counts.get('Submitted')
      : 0;
    dto.approvedCount = counts.containsKey('Approved')
      ? counts.get('Approved')
      : 0;
    dto.rejectedCount = counts.containsKey('Rejected')
      ? counts.get('Rejected')
      : 0;
    dto.cancelledCount = counts.containsKey('Cancelled')
      ? counts.get('Cancelled')
      : 0;
    dto.totalRequests =
      dto.submittedCount +
      dto.approvedCount +
      dto.rejectedCount +
      dto.cancelledCount;

    dto.recentRequests = PWChrono_AttendanceSelector.getRecentRequestsByEmployee(
      employeeId
    );
    return dto;
  }

  // ─────────────────────── DTO ─────────────────────────────────────────────

  /** Dashboard summary wrapper returned to the LWC. */
  public class AttendanceDashboardDTO {
    @AuraEnabled
    public Date summaryMonth;
    @AuraEnabled
    public Integer submittedCount = 0;
    @AuraEnabled
    public Integer approvedCount = 0;
    @AuraEnabled
    public Integer rejectedCount = 0;
    @AuraEnabled
    public Integer cancelledCount = 0;
    @AuraEnabled
    public Integer totalRequests = 0;
    @AuraEnabled
    public List<PWChrono_Attendance_Request__c> recentRequests;
  }

  // ─────────────────────── Helpers ─────────────────────────────────────────

  private static String normalizeAction(String action) {
    if (String.isBlank(action)) {
      return action;
    }
    if (action == 'Approved') {
      return 'Approve';
    }
    if (action == 'Rejected') {
      return 'Reject';
    }
    return action;
  }

  private static AuraHandledException handledException(String message) {
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(message);
    return ex;
  }

  private static Boolean isPortalAdmin(Id employeeId) {
    if (employeeId == null) {
      return false;
    }

    List<Portal_Users__c> users = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    if (users.isEmpty()) {
      return false;
    }

    return users[0].Role__c == PWChrono_Constants.ROLE_HR_ADMIN ||
      users[0].Role__c == 'System Admin';
  }
}