/**
 * @description Thin controller for Leave Management LWC Components.
 *              Delegates all business logic to service/selector/validator classes.
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessiveParameterList')
public inherited sharing class PWChrono_LeaveController {
  // ── READ Operations ──

  /**
   * @description Get current employee's leave balance
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_LeaveBalanceService.LeaveBalanceWrapper> getMyLeaveBalance(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveBalanceService.getLeaveBalance(empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leave balance', e);
      throw new AuraHandledException('Error fetching leave balance.');
    }
  }

  /**
   * @description Get leave applications for current employee
   */
  @AuraEnabled(cacheable=false)
  public static List<Leave__c> getMyLeaves(
    String statusFilter,
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id targetEmpId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveSelector.getLeavesByEmployee(
        targetEmpId,
        statusFilter,
        startDate,
        endDate,
        null
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leaves', e);
      throw new AuraHandledException('Error fetching leaves.');
    }
  }

  /**
   * @description Get a single leave record detail
   */
  @AuraEnabled(cacheable=false)
  public static Leave__c getLeaveDetail(
    Id leaveId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return requireAccessibleLeave(leaveId, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leave detail', e);
      throw new AuraHandledException('Error fetching leave detail.');
    }
  }

  /**
   * @description Get team leaves for manager approval
   */
  @AuraEnabled(cacheable=false)
  public static List<Leave__c> getTeamLeavesForApproval(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveSelector.getTeamPendingLeaves(empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team leaves', e);
      throw new AuraHandledException('Error fetching team leaves.');
    }
  }

  /**
   * @description Get team leaves with filters (approval workspace)
   */
  @AuraEnabled(cacheable=false)
  public static List<Leave__c> getTeamLeaves(
    String statusFilter,
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveSelector.getTeamLeaves(
        empId,
        statusFilter,
        startDate,
        endDate
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team leaves', e);
      throw new AuraHandledException('Error fetching team leaves.');
    }
  }

  /**
   * @description Get leave calendar data for team
   */
  @AuraEnabled(cacheable=true)
  public static List<Leave__c> getLeaveCalendarData(
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveSelector.getLeaveCalendar(empId, startDate, endDate);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching calendar data', e);
      throw new AuraHandledException('Error fetching calendar data.');
    }
  }

  /**
   * @description Get holidays for calendar
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Holiday__c> getHolidays(
    Date startDate,
    Date endDate
  ) {
    try {
      return PWChrono_LeaveSelector.getHolidaysInRange(startDate, endDate);
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching holidays', e);
      throw new AuraHandledException('Error fetching holidays.');
    }
  }

  /**
   * @description Get active leave types for dropdown
   */
  public static List<PWChrono_Leave_Type__c> getActiveLeaveTypes() {
    return getActiveLeaveTypes(false);
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Leave_Type__c> getActiveLeaveTypes(
    Boolean includeInactive
  ) {
    try {
      return PWChrono_LeaveSelector.getActiveLeaveTypes(includeInactive);
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leave types', e);
      throw new AuraHandledException('Error fetching leave types.');
    }
  }

  /**
   * @description Calculate working days for a date range (client preview)
   */
  @AuraEnabled
  public static Decimal calculateWorkingDays(
    Date startDate,
    Date endDate,
    Boolean isHalfDay,
    Id leaveTypeId
  ) {
    try {
      return PWChrono_LeaveService.calculateWorkingDays(
        startDate,
        endDate,
        isHalfDay,
        leaveTypeId
      );
    } catch (Exception e) {
      PWChrono_Logger.error('Error calculating working days', e);
      throw new AuraHandledException('Error calculating working days.');
    }
  }

  /**
   * @description Get files linked to a leave request.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_RequestAttachmentService.FileDescriptorDTO> getLeaveFiles(
    Id leaveId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      requireAccessibleLeave(leaveId, empId);
      return PWChrono_RequestAttachmentService.getFilesForRecord(leaveId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leave files', e);
      throw new AuraHandledException('Error fetching leave files.');
    }
  }

  /**
   * @description Upload a file to a leave request.
   */
  @AuraEnabled
  public static PWChrono_RequestAttachmentService.FileDescriptorDTO uploadLeaveFile(
    Id leaveId,
    String fileName,
    String base64Data,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      Leave__c leave = requireAccessibleLeave(leaveId, empId);
      if (
        leave.Employees__c != empId &&
        !PWChrono_RequestValidator.isCurrentUserAdmin(empId)
      ) {
        throw new AuraHandledException(
          'Only the employee or an admin can upload leave attachments.'
        );
      }

      PWChrono_RequestAttachmentService.FileDescriptorDTO fileDto = PWChrono_RequestAttachmentService.uploadFile(
        leaveId,
        fileName,
        base64Data
      );

      leave.Certificate_Uploaded__c = true;
      update new Leave__c(
        Id = leaveId,
        Certificate_Uploaded__c = true
      );

      PWChrono_RequestCommentService.addSystemComment(
        leaveId,
        'Leave__c',
        'Attachment uploaded: ' + fileDto.name,
        empId
      );

      return fileDto;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error uploading leave file', e);
      throw new AuraHandledException('Error uploading leave file.');
    }
  }

  /**
   * @description Get request comments and system history for a leave request.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_RequestCommentService.RequestCommentDTO> getLeaveComments(
    Id leaveId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      requireAccessibleLeave(leaveId, empId);
      return PWChrono_RequestCommentService.getComments(
        leaveId,
        'Leave__c'
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leave comments', e);
      throw new AuraHandledException('Error fetching leave comments.');
    }
  }

  /**
   * @description Add a user comment to a leave request.
   */
  @AuraEnabled
  public static PWChrono_RequestCommentService.RequestCommentDTO addLeaveComment(
    Id leaveId,
    String commentText,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      requireAccessibleLeave(leaveId, empId);
      return PWChrono_RequestCommentService.addComment(
        leaveId,
        'Leave__c',
        commentText,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error adding leave comment', e);
      throw new AuraHandledException('Error adding leave comment.');
    }
  }

  /**
   * @description Get leave ledger history for a request.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_LeaveLedgerService.LedgerEntryDTO> getLeaveLedgerHistory(
    Id leaveId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      requireAccessibleLeave(leaveId, empId);
      return PWChrono_LeaveLedgerService.getLedgerHistoryByLeave(leaveId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching leave ledger history', e);
      throw new AuraHandledException('Error fetching leave ledger history.');
    }
  }

  // ── WRITE Operations ──

  /**
   * @description Submit a leave application
   */
  @AuraEnabled
  public static Leave__c submitLeaveApplication(
    PWChrono_LeaveValidator.LeaveDTO leaveDTO,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveService.submitLeave(leaveDTO, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error submitting leave application', e);
      throw new AuraHandledException('Error submitting leave application.');
    }
  }

  /**
   * @description Cancel a leave request
   */
  @AuraEnabled
  public static Leave__c cancelLeave(
    Id leaveId,
    String reason,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveService.cancelLeave(leaveId, reason, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error cancelling leave', e);
      throw new AuraHandledException('Error cancelling leave.');
    }
  }

  /**
   * @description Approve or reject leave application
   */
  @AuraEnabled
  public static Leave__c processLeaveApproval(
    Id leaveId,
    String action,
    String comments,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveService.processApproval(
        leaveId,
        action,
        comments,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error processing leave approval', e);
      throw new AuraHandledException('Error processing leave approval.');
    }
  }

  // ── ADMIN Operations ──

  /**
   * @description Create a new leave type
   */
  @AuraEnabled
  public static PWChrono_Leave_Type__c createLeaveType(
    PWChrono_Leave_Type__c leaveType,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveService.createLeaveType(leaveType, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error creating leave type', e);
      throw new AuraHandledException('Error creating leave type.');
    }
  }

  /**
   * @description Update leave type settings
   */
  @AuraEnabled
  public static PWChrono_Leave_Type__c updateLeaveType(
    PWChrono_Leave_Type__c leaveType,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_LeaveService.updateLeaveType(leaveType, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error updating leave type', e);
      throw new AuraHandledException('Error updating leave type.');
    }
  }

  /**
   * @description Adjust leave balance manually (admin)
   */
  @AuraEnabled
  public static void adjustLeaveBalance(
    Id targetEmployeeId,
    Id leaveTypeId,
    Decimal days,
    String reason,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id adminId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_LeaveService.adjustLeaveBalance(
        targetEmployeeId,
        leaveTypeId,
        days,
        reason,
        adminId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error adjusting leave balance', e);
      throw new AuraHandledException('Error adjusting leave balance.');
    }
  }

  // ── Legacy Compatibility ──
  // These methods maintain backward compatibility with existing LWC components
  // that call the old method signatures. They can be removed once all LWCs are updated.

  /**
   * @description Legacy: Save leave application (old signature used by pwchronoLeaveApplication)
   */
  @AuraEnabled
  public static Leave__c saveLeaveApplication(
    Leave__c leaveRecord,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );

      // Convert SObject to DTO
      PWChrono_LeaveValidator.LeaveDTO dto = new PWChrono_LeaveValidator.LeaveDTO();
      dto.leaveId = leaveRecord.Id;
      dto.leaveTypeId = leaveRecord.Leave_Type__c;
      dto.fromDate = leaveRecord.From_Date__c;
      dto.toDate = leaveRecord.To_Date__c;
      dto.halfDay = leaveRecord.Half_Day__c;
      dto.reason = leaveRecord.Reason__c;
      dto.status = leaveRecord.Status__c;

      return PWChrono_LeaveService.submitLeave(dto, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error saving leave application', e);
      throw new AuraHandledException('Error saving leave application.');
    }
  }

  private static Leave__c requireAccessibleLeave(
    Id leaveId,
    Id employeeId
  ) {
    Leave__c leave = PWChrono_LeaveSelector.getLeaveById(leaveId);

    if (leave == null) {
      throw new AuraHandledException('Leave record not found.');
    }

    if (
      leave.Employees__c != employeeId &&
      leave.Approvers__c != employeeId &&
      !PWChrono_RequestValidator.isCurrentUserAdmin(employeeId)
    ) {
      throw new AuraHandledException('Access denied.');
    }

    return leave;
  }
}