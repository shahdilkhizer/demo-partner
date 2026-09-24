/**
 * Portal entry boundary for manually authenticated Experience Cloud users.
 * Guest session proof is checked before entering system sharing context.
 * Delegated controllers retain feature, role, record-owner and transition checks.
 * This avoids using the site's Guest user's record visibility as the employee's
 * authorization policy. Never add an endpoint without auditing those checks.
 */
public without sharing class PWChrono_PortalApi {
  @AuraEnabled(cacheable=true)
  public static PWChrono_OpportunityService.OpportunityPage getProjectOpportunities(
    String portalUserId,
    String sessionToken,
    String searchTerm,
    String stage,
    Id afterId
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_OpportunityService.listRecords(
      portalUserId,
      sessionToken,
      searchTerm,
      stage,
      afterId
    );
  }
  @AuraEnabled(cacheable=true)
  public static Opportunity getProjectOpportunity(
    String portalUserId,
    String sessionToken,
    Id opportunityId
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_OpportunityService.detail(
      portalUserId,
      sessionToken,
      opportunityId
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<Contact> getEmployeesForDropdown(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.getEmployeesForDropdown(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Salary_Slip__c> getMySalarySlips(
    Integer year,
    Integer month,
    String contactId,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.getMySalarySlips(
      year,
      month,
      contactId,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getSalarySlipDetails(
    Id salarySlipId,
    String contactId,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.getSalarySlipDetails(
      salarySlipId,
      contactId,
      portalUserId,
      sessionToken
    );
  }

  /**
   * Payroll administration runs through this verified, system-sharing boundary
   * because the Experience Cloud application uses a manually authenticated
   * guest session. The delegated controller still enforces the Payroll feature
   * and administrator role before returning or changing payroll data.
   */
  @AuraEnabled(cacheable=false)
  public static PWChrono_PayrollRunService.PayrollWorkspaceDTO getPayrollWorkspace(
    Date payrollPeriod,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.getPayrollWorkspace(
      payrollPeriod,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_PayrollRunService.PayrollMutationResult saveSalaryAssignment(
    Id contactId,
    Decimal baseSalary,
    Date effectiveDate,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.saveSalaryAssignment(
      contactId,
      baseSalary,
      effectiveDate,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_PayrollRunService.PayrollMutationResult generatePayrollDrafts(
    Date payrollPeriod,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.generatePayrollDrafts(
      payrollPeriod,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_PayrollRunService.PayrollMutationResult submitPayroll(
    Date payrollPeriod,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.submitPayroll(
      payrollPeriod,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_PayrollRunService.PayrollMutationResult markPayrollPaid(
    Date payrollPeriod,
    Date paymentDate,
    String paymentMethod,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    return PWChrono_PayrollController.markPayrollPaid(
      payrollPeriod,
      paymentDate,
      paymentMethod,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getDashboardSummaryForPortal(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_DashboardController.getDashboardSummaryForPortal(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static PWChrono_AdminController.AdminDashboardDTO getAdminDashboardStats(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getAdminDashboardStats(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_AdminController.ChartPoint> getEmployeesByDepartment(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getEmployeesByDepartment(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static PWChrono_AdminController.AttendanceOverview getAttendanceOverview(
    Date forDate,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getAttendanceOverview(
      forDate,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Project__c> getProjects(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getProjects(portalUserId, sessionToken);
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Applicant__c> getJobApplicants(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getJobApplicants(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<Account> getProjectClients(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getProjectClients(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static Id saveProject(
    Map<String, Object> projectData,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.saveProject(
      projectData,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static Id uploadProjectLogo(
    Id projectId,
    String fileName,
    String base64Data,
    String contentType,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.uploadProjectLogo(
      projectId,
      fileName,
      base64Data,
      contentType,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static void deleteProject(
    Id projectId,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    PWChrono_AdminController.deleteProject(
      projectId,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static List<Leave__c> getTeamLeaves(
    String statusFilter,
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_LeaveController.getTeamLeaves(
      statusFilter,
      startDate,
      endDate,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static List<Leave__c> getTeamLeavesForApproval(
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_LeaveController.getTeamLeavesForApproval(
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static Leave__c processLeaveApproval(
    Id leaveId,
    String action,
    String comments,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_LeaveController.processLeaveApproval(
      leaveId,
      action,
      comments,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Leave_Type__c createLeaveType(
    PWChrono_Leave_Type__c leaveType,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_LeaveController.createLeaveType(
      leaveType,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Leave_Type__c updateLeaveType(
    PWChrono_Leave_Type__c leaveType,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_LeaveController.updateLeaveType(
      leaveType,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Attendance_Request__c> getTeamAttendanceForApproval(
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_AttendanceController.getTeamAttendanceForApproval(
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Attendance_Request__c processAttendanceApproval(
    Id requestId,
    String action,
    String comments,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_AttendanceController.processAttendanceApproval(
      requestId,
      action,
      comments,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static List<PWChrono_AttendanceController.AttendanceDayWrapper> getAttendanceTrackerDataForEmployee(
    Date startDate,
    Date endDate,
    String targetEmployeeId,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AttendanceController.getAttendanceTrackerDataForEmployee(
      startDate,
      endDate,
      targetEmployeeId,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static List<PWChrono_AttendanceController.AttendanceAdminRow> getAttendanceAdminRows(
    Date dateFilter,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AttendanceController.getAttendanceAdminRows(
      dateFilter,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Shift_Assignment__c> getMyShiftAssignments(
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_AttendanceController.getMyShiftAssignments(
      startDate,
      endDate,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Attendance_Request__c saveAttendanceRequest(
    PWChrono_Attendance_Request__c attendanceRequest,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AttendanceController.saveAttendanceRequest(
      attendanceRequest,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Shift_Type__c createShiftType(
    PWChrono_Shift_Type__c shiftType,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AttendanceController.createShiftType(
      shiftType,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Shift_Type__c updateShiftType(
    PWChrono_Shift_Type__c shiftType,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AttendanceController.updateShiftType(
      shiftType,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Goal__c> getMyGoals(
    String statusFilter,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_PerformanceController.getMyGoals(
      statusFilter,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Goal__c saveGoal(
    PWChrono_Goal__c goal,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_PerformanceController.saveGoal(
      goal,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Goal__c updateGoalProgress(
    Id goalId,
    Decimal progressPercentage,
    String status,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_PerformanceController.updateGoalProgress(
      goalId,
      progressPercentage,
      status,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Appraisal__c> getMyAppraisals(
    String statusFilter,
    String employeeId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) employeeId,
      sessionToken
    );
    return PWChrono_PerformanceController.getMyAppraisals(
      statusFilter,
      employeeId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Appraisal__c saveAppraisal(
    PWChrono_Appraisal__c appraisal,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_PerformanceController.saveAppraisal(
      appraisal,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Training_Attendance__c> getMyRegistrations(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_TrainingController.getMyRegistrations(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static void registerForTraining(
    Id eventId,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    PWChrono_TrainingController.registerForTraining(
      eventId,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static void cancelRegistration(
    Id attendanceId,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    PWChrono_TrainingController.cancelRegistration(
      attendanceId,
      portalUserId,
      sessionToken
    );
  }

  // Admin Settings: PWChrono_AdminController inherits sharing, so direct guest
  // calls cannot read the caller's private portal record and always deny
  // access. These entry points verify the session, then delegate so the
  // existing Admin Settings feature check runs in the portal data context.

  @AuraEnabled
  public static PWChrono_Feature_Settings__c getFeatureSettings(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getFeatureSettings(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Feature_Settings__c saveFeatureSettings(
    PWChrono_Feature_Settings__c settings,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.saveFeatureSettings(
      settings,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static PWChrono_Settings__mdt getGlobalSettings(
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.getGlobalSettings(
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static List<Portal_Users__c> searchPortalUsers(
    String searchTerm,
    String portalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) portalUserId,
      sessionToken
    );
    return PWChrono_AdminController.searchPortalUsers(
      searchTerm,
      portalUserId,
      sessionToken
    );
  }

  @AuraEnabled
  public static void updatePortalUserAccess(
    Id portalUserId,
    String role,
    List<String> features,
    String callerPortalUserId,
    String sessionToken
  ) {
    PWChrono_GuestSession.requireVerifiedPortalUserId(
      (String) callerPortalUserId,
      sessionToken
    );
    PWChrono_AdminController.updatePortalUserAccess(
      portalUserId,
      role,
      features,
      callerPortalUserId,
      sessionToken
    );
  }
}