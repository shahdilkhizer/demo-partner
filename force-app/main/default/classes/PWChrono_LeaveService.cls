/**
 * @description Core business logic for the Leave module.
 *              Orchestrates validation, calculation, DML, balance updates,
 *              ledger entries, and notifications.
 *              Called by PWChrono_LeaveController (thin controller pattern).
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_LeaveService {

  /**
   * @description Submit a new leave application or update a draft.
   * @param dto Leave data from the LWC form
   * @param employeeId Verified Portal_Users__c Id
   * @return The saved leave record
   */
  public static Leave__c submitLeave(
    PWChrono_LeaveValidator.LeaveDTO dto, Id employeeId
  ) {
    // Calculate working days
    dto.totalDays = calculateWorkingDays(
      dto.fromDate, dto.toDate, dto.halfDay, dto.leaveTypeId
    );

    // Validate
    List<String> errors = PWChrono_LeaveValidator.validate(dto, employeeId);
    if (!errors.isEmpty()) {
      throw new AuraHandledException(String.join(errors, '\n'));
    }

    // Build the SObject
    Leave__c leave;
    if (dto.leaveId != null) {
      leave = PWChrono_LeaveSelector.getLeaveById(dto.leaveId);
      if (leave == null) {
        throw new AuraHandledException('Leave record not found.');
      }
      // Ownership check
      if (leave.Employees__c != employeeId) {
        throw new AuraHandledException('Unauthorized access to this leave record.');
      }
    } else {
      leave = new Leave__c();
      leave.Employees__c = employeeId;
      leave.Applied_Date__c = Date.today();
    }

    leave.Leave_Type__c = dto.leaveTypeId;
    leave.From_Date__c = dto.fromDate;
    leave.To_Date__c = dto.toDate;
    leave.Total_Days__c = dto.totalDays;
    leave.Half_Day__c = dto.halfDay == true;
    leave.Half_Day_Session__c = dto.halfDay == true ? dto.halfDaySession : null;
    leave.Reason__c = dto.reason;
    leave.Status__c = PWChrono_Constants.STATUS_SUBMITTED;
    leave.Certificate_Required__c = dto.certificateRequired == true;
    leave.Certificate_Uploaded__c = dto.certificateUploaded == true;

    Decimal calendarDays = dto.fromDate.daysBetween(dto.toDate) + 1;
    leave.Working_Days_Excluded__c = calendarDays - dto.totalDays;

    // Auto-assign approver
    Id approverId = PWChrono_RequestService.resolveApprover(employeeId);
    if (approverId != null) {
      leave.Approvers__c = approverId;
    }

    upsert leave;

    // Send notification to approver
    if (leave.Approvers__c != null) {
      String empName = PWChrono_RequestService.getEmployeeName(employeeId);
      PWChrono_RequestService.sendNotification(
        leave.Approvers__c, 'Leave', leave.Name,
        'Submitted', empName, leave.Id
      );
    }

    PWChrono_RequestCommentService.addSystemComment(
      leave.Id,
      'Leave__c',
      'Leave request submitted for ' + leave.Total_Days__c.setScale(1) + ' day(s).',
      employeeId
    );

    return PWChrono_LeaveSelector.getLeaveById(leave.Id);
  }

  /**
   * @description Backward-compatible trigger hook for legacy org handlers.
   */
  public static void validateLeaveBalance(List<Leave__c> leaves) {
    if (leaves == null || leaves.isEmpty()) {
      return;
    }

    for (Leave__c leaveRecord : leaves) {
      if (leaveRecord == null ||
          leaveRecord.Employees__c == null ||
          leaveRecord.Leave_Type__c == null ||
          leaveRecord.Total_Days__c == null) {
        continue;
      }

      String balanceError = PWChrono_LeaveBalanceService.checkSufficientBalance(
        leaveRecord.Employees__c,
        leaveRecord.Leave_Type__c,
        leaveRecord.Total_Days__c
      );

      if (balanceError != null) {
        leaveRecord.addError(balanceError);
      }
    }
  }

  /**
   * @description Process approval action (Approve/Reject).
   * @param leaveId Leave record Id
   * @param action "Approve" or "Reject"
   * @param comments Optional comments (required for rejection)
   * @param approverId The employee performing the action
   * @return Updated leave record
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static Leave__c processApproval(
    Id leaveId, String action, String comments, Id approverId
  ) {
    Leave__c leave = PWChrono_LeaveSelector.getLeaveById(leaveId);
    if (leave == null) {
      throw new AuraHandledException('Leave record not found.');
    }

    // Security: must be the assigned approver or an admin
    if (leave.Approvers__c != approverId &&
        !PWChrono_RequestValidator.isCurrentUserAdmin(approverId)) {
      throw new AuraHandledException('Access denied: Not authorized to process this request.');
    }

    // Validate status transition
    if (leave.Status__c != PWChrono_Constants.STATUS_SUBMITTED) {
      throw new AuraHandledException(
        'Only submitted requests can be approved/rejected. Current status: ' + leave.Status__c
      );
    }

    String approverName = PWChrono_RequestService.getEmployeeName(approverId);

    String normalizedAction = normalizeAction(action);

    if (leave.Employees__c == approverId) {
      throw new AuraHandledException('Self-approval is not allowed.');
    }

    if (normalizedAction == 'Approve') {
      leave.Status__c = PWChrono_Constants.STATUS_APPROVED;
      leave.Approval_Date__c = Date.today();
      leave.Approver_Comments__c = String.isNotBlank(comments) ? comments.trim() : null;

      update leave;

      // Deduct balance
      PWChrono_LeaveBalanceService.deductBalance(
        leave.Employees__c, leave.Leave_Type__c, leave.Total_Days__c
      );

      // Create ledger entry
      PWChrono_LeaveLedgerService.recordLeaveUsed(leave, approverId);

      // Notify employee
      PWChrono_RequestService.sendNotification(
        leave.Employees__c, 'Leave', leave.Name,
        'Approved', approverName, leave.Id
      );

      PWChrono_RequestCommentService.addSystemComment(
        leave.Id,
        'Leave__c',
        String.isNotBlank(comments)
          ? 'Leave request approved. ' + comments.trim()
          : 'Leave request approved.',
        approverId
      );

    } else if (normalizedAction == 'Reject') {
      if (String.isBlank(comments)) {
        throw new AuraHandledException('Rejection reason is required.');
      }

      leave.Status__c = PWChrono_Constants.STATUS_REJECTED;
      leave.Rejection_Reason__c = comments;
      leave.Approver_Comments__c = comments;
      leave.Approval_Date__c = Date.today();

      update leave;

      // Notify employee
      PWChrono_RequestService.sendNotification(
        leave.Employees__c, 'Leave', leave.Name,
        'Rejected', approverName, leave.Id
      );

      PWChrono_RequestCommentService.addSystemComment(
        leave.Id,
        'Leave__c',
        'Leave request rejected. ' + comments.trim(),
        approverId
      );

    } else {
      throw new AuraHandledException('Invalid action. Must be Approve or Reject.');
    }

    return PWChrono_LeaveSelector.getLeaveById(leave.Id);
  }

  /**
   * @description Cancel a leave request (by the employee).
   * @param leaveId Leave record Id
   * @param reason Cancellation reason
   * @param employeeId The requesting employee
   * @return Updated leave record
   */
  public static Leave__c cancelLeave(
    Id leaveId, String reason, Id employeeId
  ) {
    Leave__c leave = PWChrono_LeaveSelector.getLeaveById(leaveId);
    if (leave == null) {
      throw new AuraHandledException('Leave record not found.');
    }

    // Ownership check
    if (leave.Employees__c != employeeId &&
        !PWChrono_RequestValidator.isCurrentUserAdmin(employeeId)) {
      throw new AuraHandledException('Unauthorized: Can only cancel your own requests.');
    }

    // Only Submitted or Approved can be cancelled
    String error = PWChrono_RequestValidator.validateStatusTransition(
      leave.Status__c, 'Cancelled'
    );
    if (error != null) {
      throw new AuraHandledException(error);
    }

    Boolean wasApproved = leave.Status__c == PWChrono_Constants.STATUS_APPROVED;
    leave.Status__c = 'Cancelled';
    leave.Cancelled_Date__c = Date.today();
    leave.Cancelled_Reason__c = reason;

    update leave;

    // If was approved, reverse the balance deduction
    if (wasApproved) {
      PWChrono_LeaveBalanceService.reverseBalance(
        leave.Employees__c, leave.Leave_Type__c, leave.Total_Days__c
      );
      PWChrono_LeaveLedgerService.recordLeaveCancelled(leave, employeeId);
    }

    // Notify approver about cancellation
    if (leave.Approvers__c != null) {
      String empName = PWChrono_RequestService.getEmployeeName(employeeId);
      PWChrono_RequestService.sendNotification(
        leave.Approvers__c, 'Leave', leave.Name,
        'Cancelled', empName, leave.Id
      );
    }

    PWChrono_RequestCommentService.addSystemComment(
      leave.Id,
      'Leave__c',
      String.isNotBlank(reason)
        ? 'Leave request cancelled. ' + reason.trim()
        : 'Leave request cancelled.',
      employeeId
    );

    return PWChrono_LeaveSelector.getLeaveById(leave.Id);
  }

  // ── Admin Operations ──

  /**
   * @description Create a new leave type (admin only).
   */
  public static PWChrono_Leave_Type__c createLeaveType(
    PWChrono_Leave_Type__c leaveType, Id adminId
  ) {
    if (!PWChrono_RequestValidator.isCurrentUserAdmin(adminId)) {
      throw new AuraHandledException('Access denied: Admin privileges required.');
    }

    PWChrono_Logger.info('Creating leave type: ' + leaveType.Name);
    insert leaveType;
    return leaveType;
  }

  /**
   * @description Update an existing leave type (admin only).
   */
  public static PWChrono_Leave_Type__c updateLeaveType(
    PWChrono_Leave_Type__c leaveType, Id adminId
  ) {
    if (!PWChrono_RequestValidator.isCurrentUserAdmin(adminId)) {
      throw new AuraHandledException('Access denied: Admin privileges required.');
    }

    PWChrono_Logger.info('Updating leave type: ' + leaveType.Id);
    update leaveType;
    return leaveType;
  }

  /**
   * @description Adjust leave balance manually (admin only).
   * @param employeeId Target employee
   * @param leaveTypeId Leave type
   * @param days Positive = credit, Negative = debit
   * @param reason Reason for adjustment
   * @param adminId Admin performing the adjustment
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void adjustLeaveBalance(
    Id employeeId, Id leaveTypeId, Decimal days, String reason, Id adminId
  ) {
    if (days == null || days == 0) {
      throw new AuraHandledException('Adjustment days must be non-zero.');
    }

    if (!PWChrono_RequestValidator.isCurrentUserAdmin(adminId)) {
      throw new AuraHandledException('Access denied: Admin privileges required.');
    }

    // Get current allocation
    List<PWChrono_Leave_Allocation__c> allocations =
      PWChrono_LeaveSelector.getAllocationsByEmployee(employeeId, leaveTypeId);

    if (allocations.isEmpty()) {
      throw new AuraHandledException('No allocation found for this employee/leave type.');
    }

    PWChrono_Leave_Allocation__c alloc = allocations[0];
    Decimal currentAllocated = alloc.Total_Leaves_Allocated__c != null
      ? alloc.Total_Leaves_Allocated__c : 0;

    alloc.Total_Leaves_Allocated__c = currentAllocated + days;
    update alloc;

    // Ledger entry
    PWChrono_LeaveLedgerService.recordAdjustment(
      employeeId, leaveTypeId, days, reason, adminId
    );
  }

  // ── Working Day Calculation ──

  /**
   * @description Calculate working days between two dates, excluding weekends and holidays.
   *              Respects leave type settings for Include_Holidays / Include_Weekends
   *              (when those fields exist on the leave type).
   * @param startDate From date
   * @param endDate To date
   * @param isHalfDay Whether this is a half-day request
   * @param leaveTypeId Optional — to check include weekend/holiday flags
   * @return Number of working days
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static Decimal calculateWorkingDays(
    Date startDate, Date endDate, Boolean isHalfDay, Id leaveTypeId
  ) {
    if (startDate == null || endDate == null) {
      return 0;
    }

    if (isHalfDay == true) {
      return 0.5;
    }

    Boolean includeWeekends = false;
    Boolean includeHolidays = false;
    if (leaveTypeId != null) {
      PWChrono_Leave_Type__c leaveType = PWChrono_LeaveSelector.getLeaveTypeById(leaveTypeId);
      if (leaveType != null) {
        includeWeekends = leaveType.Include_Weekends__c == true;
        includeHolidays = leaveType.Include_Holidays__c == true;
      }
    }

    // Get weekend config
    List<String> weekendDays = PWChrono_LeaveSelector.getWeekendDays();
    String weekend1 = weekendDays[0];
    String weekend2 = weekendDays[1];

    // Get holidays in range
    Set<Date> holidayDates = PWChrono_LeaveSelector.getHolidayDateSet(startDate, endDate);

    Integer days = 0;
    Date d = startDate;
    while (d <= endDate) {
      DateTime dt = DateTime.newInstance(d.year(), d.month(), d.day());
      String dayOfWeek = dt.format('EEEE');

      Boolean isWeekend = dayOfWeek == weekend1 || dayOfWeek == weekend2;
      Boolean isHoliday = holidayDates.contains(d);

      if ((!isWeekend || includeWeekends) && (!isHoliday || includeHolidays)) {
        days++;
      }

      d = d.addDays(1);
    }

    return days;
  }

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
}