/**
 * @description Thin controller for Attendance Management LWC components.
 *              All business logic is delegated to PWChrono_AttendanceService,
 *              PWChrono_AttendanceSelector, or the shared request framework.
 *              Every public method follows the pattern:
 *                resolveEmployeeId → Service/Selector → catch/rethrow.
 *
 *              Legacy methods (saveAttendanceRequest, processAttendanceApproval,
 *              getMyAttendanceRequests) are retained for backward compatibility
 *              with existing LWC components and are marked accordingly.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_AttendanceController {
  // ═══════════════════════════════════════════════════════════════════════════
  // READ  —  Employee
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Dashboard summary: request counts + 5 recent requests.
   */
  @AuraEnabled(cacheable=false)
  public static PWChrono_AttendanceService.AttendanceDashboardDTO getAttendanceDashboardSummary(
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
      return PWChrono_AttendanceService.getDashboardSummary(
        empId,
        startDate,
        endDate
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance dashboard summary', e);
      throw new AuraHandledException(
        'Error loading attendance dashboard. Please try again.'
      );
    }
  }

  /**
   * @description Paginated attendance request list for the employee.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Attendance_Request__c> getMyAttendanceRequestList(
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
      return PWChrono_AttendanceSelector.getRequestsByEmployee(
        empId,
        statusFilter,
        startDate,
        endDate
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance request list', e);
      throw new AuraHandledException(
        'Error loading attendance requests. Please try again.'
      );
    }
  }

  /**
   * @description Full detail of a single attendance request (employee or manager).
   */
  @AuraEnabled(cacheable=false)
  public static PWChrono_Attendance_Request__c getAttendanceRequestDetail(
    Id requestId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
        requestId
      );
      if (req == null) {
        throw new AuraHandledException('Attendance request not found.');
      }
      requireAccessibleRequest(req, empId);
      return req;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance request detail', e);
      throw new AuraHandledException(
        'Error loading request details. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WRITE  —  Employee
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Submit a new or re-submit a rejected correction request.
   */
  @AuraEnabled
  public static PWChrono_Attendance_Request__c submitAttendanceRequest(
    PWChrono_AttendanceValidator.AttendanceRequestDTO dto,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_AttendanceService.submitRequest(dto, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error submitting attendance request', e);
      throw new AuraHandledException(
        'Error submitting attendance request. Please try again.'
      );
    }
  }

  /**
   * @description Cancel a Draft or Submitted correction request.
   */
  @AuraEnabled
  public static PWChrono_Attendance_Request__c cancelAttendanceRequest(
    Id requestId,
    String cancelReason,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_AttendanceService.cancelRequest(
        requestId,
        cancelReason,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error cancelling attendance request', e);
      throw new AuraHandledException(
        'Error cancelling request. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // READ/WRITE  —  Manager / Approver
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Team correction requests pending approval for the current manager.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Attendance_Request__c> getTeamAttendanceRequestsForApproval(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_AttendanceSelector.getTeamRequestsForApproval(empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team attendance requests', e);
      throw new AuraHandledException(
        'Error loading team requests. Please try again.'
      );
    }
  }

  /**
   * @description All team requests (all statuses) — for manager history view.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Attendance_Request__c> getTeamAttendanceRequests(
    String statusFilter,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_AttendanceSelector.getTeamRequests(empId, statusFilter);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team attendance requests', e);
      throw new AuraHandledException(
        'Error loading team requests. Please try again.'
      );
    }
  }

  /**
   * @description Approve or reject an attendance correction request.
   */
  @AuraEnabled
  public static PWChrono_Attendance_Request__c processAttendanceCorrectionApproval(
    Id requestId,
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
      return PWChrono_AttendanceService.processApproval(
        requestId,
        action,
        comments,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error processing attendance approval', e);
      throw new AuraHandledException(
        'Error processing approval. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMENTS & FILES  —  Shared framework
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Returns the full comments/history thread for a request.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_RequestCommentService.RequestCommentDTO> getAttendanceComments(
    Id requestId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
        requestId
      );
      if (req == null) {
        throw new AuraHandledException('Request not found.');
      }
      requireAccessibleRequest(req, empId);
      return PWChrono_RequestCommentService.getComments(
        requestId,
        'PWChrono_Attendance_Request__c'
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance comments', e);
      throw new AuraHandledException(
        'Error loading comments. Please try again.'
      );
    }
  }

  /**
   * @description Adds a user comment to the request's comment thread.
   */
  @AuraEnabled
  public static PWChrono_RequestCommentService.RequestCommentDTO addAttendanceComment(
    Id requestId,
    String commentText,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
        requestId
      );
      if (req == null) {
        throw new AuraHandledException('Request not found.');
      }
      requireAccessibleRequest(req, empId);
      if (String.isBlank(commentText)) {
        throw new AuraHandledException('Comment cannot be empty.');
      }
      return PWChrono_RequestCommentService.addComment(
        requestId,
        'PWChrono_Attendance_Request__c',
        commentText,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error adding attendance comment', e);
      throw new AuraHandledException('Error adding comment. Please try again.');
    }
  }

  /**
   * @description Returns file descriptors attached to the request.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_RequestAttachmentService.FileDescriptorDTO> getAttendanceFiles(
    Id requestId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
        requestId
      );
      if (req == null) {
        throw new AuraHandledException('Request not found.');
      }
      requireAccessibleRequest(req, empId);
      return PWChrono_RequestAttachmentService.getFilesForRecord(requestId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance files', e);
      throw new AuraHandledException('Error loading files. Please try again.');
    }
  }

  /**
   * @description Uploads a supporting file for the request.
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static PWChrono_RequestAttachmentService.FileDescriptorDTO uploadAttendanceFile(
    Id requestId,
    String fileName,
    String base64Data,
    String contentType,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Attendance_Request__c req = PWChrono_AttendanceSelector.getRequestById(
        requestId
      );
      if (req == null) {
        throw new AuraHandledException('Request not found.');
      }
      requireAccessibleRequest(req, empId);
      return PWChrono_RequestAttachmentService.uploadFile(
        requestId,
        fileName,
        base64Data,
        contentType
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error uploading attendance file', e);
      throw new AuraHandledException('Error uploading file. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRACKER  —  Day-by-day attendance view (retained from original)
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Wrapper for daily attendance status — used by tracker and calendar.
   */
  public class AttendanceDayWrapper {
    @AuraEnabled
    public Date attendanceDate;
    @AuraEnabled
    public String dayName;
    @AuraEnabled
    public String status; // Present|Absent|Late|Leave|Holiday|Weekend|Future
    @AuraEnabled
    public String shiftName;
    @AuraEnabled
    public Time shiftStart;
    @AuraEnabled
    public Time shiftEnd;
    @AuraEnabled
    public Time checkIn;
    @AuraEnabled
    public Time checkOut;
    @AuraEnabled
    public Id attendanceRequestId;
    @AuraEnabled
    public String correctionType;
    @AuraEnabled
    public String leaveType;
    @AuraEnabled
    public String holidayName;
    @AuraEnabled
    public Boolean isLate;
    @AuraEnabled
    public Boolean isEarlyLeave;
    @AuraEnabled
    public String employeeName;
  }

  /**
   * @description Returns day-by-day attendance status for a date range.
   *              Layers: shifts → holidays → leaves → correction requests → weekends.
   */
  @AuraEnabled(cacheable=false)
  public static List<AttendanceDayWrapper> getAttendanceTrackerData(
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
      return buildTrackerData(empId, startDate, endDate);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance tracker data', e);
      throw new AuraHandledException(
        'Error loading attendance data. Please try again.'
      );
    }
  }

  /**
   * @description Returns tracker data for a selected employee. The caller's
   *              portal identity is verified separately from the employee
   *              being viewed so an administrator never impersonates them.
   */
  @AuraEnabled(cacheable=false)
  public static List<AttendanceDayWrapper> getAttendanceTrackerDataForEmployee(
    Date startDate,
    Date endDate,
    String targetEmployeeId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id actorEmployeeId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );
      Id effectiveEmployeeId = resolveAttendanceViewEmployeeId(
        actorEmployeeId,
        targetEmployeeId,
        sessionToken
      );
      Portal_Users__c employee = [
        SELECT Name, Contact__r.Name
        FROM Portal_Users__c
        WHERE Id = :effectiveEmployeeId
        LIMIT 1
      ];
      String employeeName = employee.Contact__r != null
        ? employee.Contact__r.Name
        : employee.Name;
      List<AttendanceDayWrapper> days = buildTrackerData(
        effectiveEmployeeId,
        startDate,
        endDate
      );
      for (AttendanceDayWrapper day : days) {
        day.employeeName = employeeName;
      }
      return days;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching selected employee attendance', e);
      throw new AuraHandledException(
        'Error loading employee attendance data. Please try again.'
      );
    }
  }

  /**
   * @description Internal tracker builder — also callable from tests.
   */
  @TestVisible
  static List<AttendanceDayWrapper> buildTrackerData(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    List<PWChrono_Shift_Assignment__c> shifts = [
      SELECT
        Id,
        Shift_Type__r.Name,
        Shift_Type__r.Start_Time__c,
        Shift_Type__r.End_Time__c,
        From_Date__c,
        To_Date__c
      FROM PWChrono_Shift_Assignment__c
      WHERE
        Employees__c = :employeeId
        AND From_Date__c <= :endDate
        AND To_Date__c >= :startDate
    ];

    Map<Date, PWChrono_Attendance_Request__c> requestsMap = new Map<Date, PWChrono_Attendance_Request__c>();
    for (PWChrono_Attendance_Request__c req : [
      SELECT
        Id,
        Attendance_Date__c,
        From_Time__c,
        To_Time__c,
        Correction_Type__c,
        Status__c
      FROM PWChrono_Attendance_Request__c
      WHERE
        Employees__c = :employeeId
        AND Attendance_Date__c >= :startDate
        AND Attendance_Date__c <= :endDate
        AND Status__c IN (
          :PWChrono_Constants.STATUS_APPROVED,
          :PWChrono_Constants.STATUS_SUBMITTED
        )
    ]) {
      requestsMap.put(req.Attendance_Date__c, req);
    }

    List<Leave__c> leaves = [
      SELECT From_Date__c, To_Date__c, Leave_Type__r.Name
      FROM Leave__c
      WHERE
        Employees__c = :employeeId
        AND Status__c = :PWChrono_Constants.STATUS_APPROVED
        AND From_Date__c <= :endDate
        AND To_Date__c >= :startDate
    ];

    Map<Date, String> holidaysMap = new Map<Date, String>();
    for (PWChrono_Holiday__c hol : [
      SELECT Holiday_Date__c, Name
      FROM PWChrono_Holiday__c
      WHERE Holiday_Date__c >= :startDate AND Holiday_Date__c <= :endDate
    ]) {
      holidaysMap.put(hol.Holiday_Date__c, hol.Name);
    }

    List<AttendanceDayWrapper> result = new List<AttendanceDayWrapper>();
    Date d = startDate;
    while (d <= endDate) {
      result.add(buildDayWrapper(d, shifts, requestsMap, leaves, holidaysMap));
      d = d.addDays(1);
    }
    return result;
  }

  private static AttendanceDayWrapper buildDayWrapper(
    Date d,
    List<PWChrono_Shift_Assignment__c> shifts,
    Map<Date, PWChrono_Attendance_Request__c> reqMap,
    List<Leave__c> leaves,
    Map<Date, String> holidays
  ) {
    AttendanceDayWrapper day = new AttendanceDayWrapper();
    day.attendanceDate = d;
    day.dayName = DateTime.newInstance(d.year(), d.month(), d.day())
      .format('EEEE');
    day.status = (d > Date.today()) ? 'Future' : 'Absent';

    // Apply shift context
    for (PWChrono_Shift_Assignment__c s : shifts) {
      if (d >= s.From_Date__c && d <= s.To_Date__c) {
        day.shiftName = s.Shift_Type__r.Name;
        day.shiftStart = s.Shift_Type__r.Start_Time__c;
        day.shiftEnd = s.Shift_Type__r.End_Time__c;
        break;
      }
    }

    // Holiday overrides absent/future
    if (holidays.containsKey(d)) {
      day.status = 'Holiday';
      day.holidayName = holidays.get(d);
    }

    // Approved leave overrides
    for (Leave__c lv : leaves) {
      if (d >= lv.From_Date__c && d <= lv.To_Date__c) {
        day.status = 'Leave';
        day.leaveType = lv.Leave_Type__r.Name;
        break;
      }
    }

    // A correction request can establish attendance on a working day, but it
    // must not overwrite an approved leave or company holiday.
    if (
      reqMap.containsKey(d) &&
      day.status != 'Holiday' &&
      day.status != 'Leave'
    ) {
      PWChrono_Attendance_Request__c req = reqMap.get(d);
      day.attendanceRequestId = req.Id;
      day.checkIn = req.From_Time__c;
      day.checkOut = req.To_Time__c;
      day.correctionType = req.Correction_Type__c;
      day.status = 'Present';
      if (
        day.shiftStart != null &&
        req.From_Time__c != null &&
        req.From_Time__c > day.shiftStart
      ) {
        day.isLate = true;
        day.status = 'Late';
      }
      if (
        day.shiftEnd != null &&
        req.To_Time__c != null &&
        req.To_Time__c < day.shiftEnd
      ) {
        day.isEarlyLeave = true;
      }
    }

    // Weekend (only if not already Holiday/Leave)
    if (
      (day.dayName == 'Saturday' || day.dayName == 'Sunday') &&
      day.status == 'Absent'
    ) {
      day.status = 'Weekend';
    }

    return day;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHIFT  — support
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Returns active shift types for the correction form.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Shift_Type__c> getActiveShiftTypes() {
    try {
      return [
        SELECT
          Id,
          Name,
          Start_Time__c,
          End_Time__c,
          Working_Hours__c,
          Grace_Period_Minutes__c
        FROM PWChrono_Shift_Type__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name
      ];
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching shift types', e);
      throw new AuraHandledException(
        'Error loading shift types. Please try again.'
      );
    }
  }

  /**
   * @description Current employee's shift assignments in a date range.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Shift_Assignment__c> getMyShiftAssignments(
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
      return [
        SELECT
          Id,
          Name,
          Shift_Type__c,
          Shift_Type__r.Name,
          Shift_Type__r.Start_Time__c,
          Shift_Type__r.End_Time__c,
          Shift_Type__r.Working_Hours__c,
          From_Date__c,
          To_Date__c,
          Status__c
        FROM PWChrono_Shift_Assignment__c
        WHERE
          Employees__c = :empId
          AND From_Date__c <= :endDate
          AND To_Date__c >= :startDate
        ORDER BY From_Date__c
      ];
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching shift assignments', e);
      throw new AuraHandledException(
        'Error loading shift assignments. Please try again.'
      );
    }
  }

  /**
   * @description Team shift assignments for the manager's roster view.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Shift_Assignment__c> getTeamShiftAssignments(
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
      List<Portal_Users__c> team = [
        SELECT Id
        FROM Portal_Users__c
        WHERE Reports_To__c = :empId
      ];
      Set<Id> teamIds = new Set<Id>();
      for (Portal_Users__c p : team) {
        teamIds.add(p.Id);
      }
      if (teamIds.isEmpty()) {
        return new List<PWChrono_Shift_Assignment__c>();
      }
      return [
        SELECT
          Id,
          Name,
          Employees__c,
          Employees__r.Name,
          Shift_Type__c,
          Shift_Type__r.Name,
          Shift_Type__r.Start_Time__c,
          Shift_Type__r.End_Time__c,
          From_Date__c,
          To_Date__c,
          Status__c
        FROM PWChrono_Shift_Assignment__c
        WHERE
          Employees__c IN :teamIds
          AND From_Date__c <= :endDate
          AND To_Date__c >= :startDate
        ORDER BY Employees__r.Name, From_Date__c
      ];
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team shift assignments', e);
      throw new AuraHandledException(
        'Error loading team shifts. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN
  // ═══════════════════════════════════════════════════════════════════════════

  public class AttendanceAdminRow {
    @AuraEnabled
    public Id employeeId;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public String role;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public Id attendanceRecordId;
    @AuraEnabled
    public Date attendanceDate;
    @AuraEnabled
    public Time checkIn;
    @AuraEnabled
    public Time checkOut;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Boolean isLate;
  }

  /**
   * @description One row per active employee for the selected date. This keeps
   *              employees visible even when they have no attendance request.
   */
  @AuraEnabled(cacheable=false)
  public static List<AttendanceAdminRow> getAttendanceAdminRows(
    Date dateFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        requireAttendanceAdminAccess(portalUserId, sessionToken);
      }

      Date targetDate = dateFilter != null ? dateFilter : Date.today();
      List<Portal_Users__c> employees = [
        SELECT
          Id,
          Name,
          Role__c,
          Department__c,
          Designation__c,
          Contact__r.Name,
          Contact__r.Title,
          Contact__r.Department
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
      ];
      Set<Id> employeeIds = new Map<Id, Portal_Users__c>(employees).keySet();

      Map<Id, List<PWChrono_Shift_Assignment__c>> shiftsByEmployee = new Map<Id, List<PWChrono_Shift_Assignment__c>>();
      for (PWChrono_Shift_Assignment__c shift : [
        SELECT
          Employees__c,
          Shift_Type__r.Name,
          Shift_Type__r.Start_Time__c,
          Shift_Type__r.End_Time__c,
          From_Date__c,
          To_Date__c
        FROM PWChrono_Shift_Assignment__c
        WHERE
          Employees__c IN :employeeIds
          AND From_Date__c <= :targetDate
          AND To_Date__c >= :targetDate
      ]) {
        if (!shiftsByEmployee.containsKey(shift.Employees__c)) {
          shiftsByEmployee.put(
            shift.Employees__c,
            new List<PWChrono_Shift_Assignment__c>()
          );
        }
        shiftsByEmployee.get(shift.Employees__c).add(shift);
      }

      Map<Id, Map<Date, PWChrono_Attendance_Request__c>> requestsByEmployee = new Map<Id, Map<Date, PWChrono_Attendance_Request__c>>();
      for (PWChrono_Attendance_Request__c request : [
        SELECT
          Id,
          Employees__c,
          Attendance_Date__c,
          From_Time__c,
          To_Time__c,
          Correction_Type__c,
          Status__c
        FROM PWChrono_Attendance_Request__c
        WHERE
          Employees__c IN :employeeIds
          AND Attendance_Date__c = :targetDate
          AND Status__c IN (
            :PWChrono_Constants.STATUS_APPROVED,
            :PWChrono_Constants.STATUS_SUBMITTED
          )
        ORDER BY LastModifiedDate DESC
      ]) {
        if (!requestsByEmployee.containsKey(request.Employees__c)) {
          requestsByEmployee.put(
            request.Employees__c,
            new Map<Date, PWChrono_Attendance_Request__c>()
          );
        }
        Map<Date, PWChrono_Attendance_Request__c> employeeRequests = requestsByEmployee.get(
          request.Employees__c
        );
        if (!employeeRequests.containsKey(request.Attendance_Date__c)) {
          employeeRequests.put(request.Attendance_Date__c, request);
        }
      }

      Map<Id, List<Leave__c>> leavesByEmployee = new Map<Id, List<Leave__c>>();
      for (Leave__c leaveRecord : [
        SELECT Employees__c, From_Date__c, To_Date__c, Leave_Type__r.Name
        FROM Leave__c
        WHERE
          Employees__c IN :employeeIds
          AND Status__c = :PWChrono_Constants.STATUS_APPROVED
          AND From_Date__c <= :targetDate
          AND To_Date__c >= :targetDate
      ]) {
        if (!leavesByEmployee.containsKey(leaveRecord.Employees__c)) {
          leavesByEmployee.put(leaveRecord.Employees__c, new List<Leave__c>());
        }
        leavesByEmployee.get(leaveRecord.Employees__c).add(leaveRecord);
      }

      Map<Date, String> holidays = new Map<Date, String>();
      for (PWChrono_Holiday__c holiday : [
        SELECT Holiday_Date__c, Name
        FROM PWChrono_Holiday__c
        WHERE Holiday_Date__c = :targetDate
      ]) {
        holidays.put(holiday.Holiday_Date__c, holiday.Name);
      }

      List<AttendanceAdminRow> rows = new List<AttendanceAdminRow>();
      for (Portal_Users__c employee : employees) {
        List<PWChrono_Shift_Assignment__c> employeeShifts = shiftsByEmployee.containsKey(
            employee.Id
          )
          ? shiftsByEmployee.get(employee.Id)
          : new List<PWChrono_Shift_Assignment__c>();
        Map<Date, PWChrono_Attendance_Request__c> employeeRequests = requestsByEmployee.containsKey(
            employee.Id
          )
          ? requestsByEmployee.get(employee.Id)
          : new Map<Date, PWChrono_Attendance_Request__c>();
        List<Leave__c> employeeLeaves = leavesByEmployee.containsKey(
            employee.Id
          )
          ? leavesByEmployee.get(employee.Id)
          : new List<Leave__c>();
        AttendanceDayWrapper day = buildDayWrapper(
          targetDate,
          employeeShifts,
          employeeRequests,
          employeeLeaves,
          holidays
        );

        AttendanceAdminRow row = new AttendanceAdminRow();
        row.employeeId = employee.Id;
        row.employeeName = employee.Contact__r != null
          ? employee.Contact__r.Name
          : employee.Name;
        row.role = employee.Contact__r != null &&
          String.isNotBlank(employee.Contact__r.Title)
          ? employee.Contact__r.Title
          : (String.isNotBlank(employee.Designation__c)
              ? employee.Designation__c
              : employee.Role__c);
        row.department = employee.Contact__r != null &&
          String.isNotBlank(employee.Contact__r.Department)
          ? employee.Contact__r.Department
          : employee.Department__c;
        row.attendanceRecordId = day.attendanceRequestId;
        row.attendanceDate = day.attendanceDate;
        row.checkIn = day.checkIn;
        row.checkOut = day.checkOut;
        row.status = day.status;
        row.isLate = day.isLate;
        rows.add(row);
      }
      return rows;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching admin attendance rows', e);
      throw new AuraHandledException(
        'Error loading employee attendance. Please try again.'
      );
    }
  }

  /**
   * @description All attendance records for a given date (admin view).
   */
  @AuraEnabled(cacheable=false)
  @SuppressWarnings('PMD.ApexSOQLInjection')
  public static List<PWChrono_Attendance_Request__c> getAllAttendance(
    Date dateFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        requireAttendanceAdminAccess(portalUserId, sessionToken);
      }
      Date targetDate = dateFilter != null ? dateFilter : Date.today();
      return Database.query(
        'SELECT Id, Name, Employees__c, Employees__r.Name, Employees__r.Role__c, ' +
          'Attendance_Date__c, From_Time__c, To_Time__c, Status__c, ' +
          'Correction_Type__c, Reason__c ' +
          'FROM PWChrono_Attendance_Request__c ' +
          'WHERE Attendance_Date__c = :targetDate ' +
          'ORDER BY Employees__r.Name ASC'
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching all attendance', e);
      throw new AuraHandledException(
        'Error loading attendance records. Please try again.'
      );
    }
  }

  /**
   * @description Create a shift type (admin/HR only).
   */
  @AuraEnabled
  public static PWChrono_Shift_Type__c createShiftType(
    PWChrono_Shift_Type__c shiftType,
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        requireAttendanceAdminAccess(portalUserId, sessionToken);
      }
      insert shiftType;
      return shiftType;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error creating shift type', e);
      throw new AuraHandledException(
        'Error creating shift type. Please try again.'
      );
    }
  }

  /**
   * @description Update a shift type (admin/HR only).
   */
  @AuraEnabled
  public static PWChrono_Shift_Type__c updateShiftType(
    PWChrono_Shift_Type__c shiftType,
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        requireAttendanceAdminAccess(portalUserId, sessionToken);
      }
      update shiftType;
      return shiftType;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error updating shift type', e);
      throw new AuraHandledException(
        'Error updating shift type. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY  —  Backward compatibility for existing LWC components
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Legacy list method for pwchronoAttendanceRequest component.
   *              New code should use getMyAttendanceRequestList.
   */
  @AuraEnabled(cacheable=true)
  @SuppressWarnings('PMD.ApexSOQLInjection')
  public static List<PWChrono_Attendance_Request__c> getMyAttendanceRequests(
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
      return PWChrono_AttendanceSelector.getRequestsByEmployee(
        empId,
        statusFilter,
        startDate,
        endDate
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching attendance requests (legacy)', e);
      throw new AuraHandledException('Error loading attendance requests.');
    }
  }

  /**
   * @description Legacy save method for pwchronoAttendanceRequest.
   *              New code should use submitAttendanceRequest.
   */
  @AuraEnabled
  public static PWChrono_Attendance_Request__c saveAttendanceRequest(
    PWChrono_Attendance_Request__c attendanceRequest,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );
      attendanceRequest.Employees__c = empId;
      upsert attendanceRequest;
      return PWChrono_AttendanceSelector.getRequestById(attendanceRequest.Id);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error saving attendance request (legacy)', e);
      throw new AuraHandledException('Error saving attendance request.');
    }
  }

  /**
   * @description Legacy approval method for pwchronoAttendanceAdmin.
   *              New code should use processAttendanceCorrectionApproval.
   */
  @AuraEnabled
  public static PWChrono_Attendance_Request__c processAttendanceApproval(
    Id requestId,
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
      return PWChrono_AttendanceService.processApproval(
        requestId,
        action,
        comments,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error processing attendance approval (legacy)', e);
      throw new AuraHandledException('Error processing approval.');
    }
  }

  /**
   * @description Legacy team queue method for pwchronoAttendanceAdmin.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Attendance_Request__c> getTeamAttendanceForApproval(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_AttendanceSelector.getTeamRequestsForApproval(empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team attendance (legacy)', e);
      throw new AuraHandledException('Error loading team requests.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Enforces that the requesting employee may access the record.
   *              Employee may view their own; approver may view their team's; admin may view all.
   */
  private static void requireAccessibleRequest(
    PWChrono_Attendance_Request__c req,
    Id employeeId
  ) {
    Boolean isOwner = req.Employees__c == employeeId;
    Boolean isApprover = req.Approvers__c == employeeId;
    Boolean isAdmin = PWChrono_RequestValidator.isCurrentUserAdmin(employeeId);
    if (!isOwner && !isApprover && !isAdmin) {
      throw new AuraHandledException(
        'Access denied: You are not authorized to view this request.'
      );
    }
  }

  private static Id resolveAttendanceViewEmployeeId(
    Id actorEmployeeId,
    String targetEmployeeId,
    String sessionToken
  ) {
    if (String.isBlank(targetEmployeeId)) {
      return actorEmployeeId;
    }

    Id targetId;
    try {
      targetId = (Id) targetEmployeeId;
    } catch (Exception e) {
      throw new AuraHandledException('Invalid employee selection.');
    }

    if (targetId == actorEmployeeId) {
      return actorEmployeeId;
    }

    if (UserInfo.getUserType() == 'Guest') {
      requireAttendanceAdminAccess((String) actorEmployeeId, sessionToken);
    } else if (!PWChrono_RequestValidator.isCurrentUserAdmin(actorEmployeeId)) {
      throw new AuraHandledException(
        'Access denied: Admin privileges required.'
      );
    }

    List<Portal_Users__c> targets = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Id = :targetId AND Is_Active__c = TRUE
      LIMIT 1
    ];
    if (targets.isEmpty()) {
      throw new AuraHandledException('Employee is inactive or unavailable.');
    }
    return targets[0].Id;
  }

  /**
   * @description Verifies the guest session holder has HR Admin or System Admin role,
   *              or the "Admin Settings" feature access bit.
   */
  private static void requireAttendanceAdminAccess(
    String portalUserId,
    String sessionToken
  ) {
    Id verifiedId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    Portal_Users__c pu = [
      SELECT Id, Is_Active__c, Role__c, Access_Features__c
      FROM Portal_Users__c
      WHERE Id = :verifiedId
      LIMIT 1
    ];
    if (pu == null || pu.Is_Active__c != true) {
      throw new AuraHandledException('Unauthorized.');
    }
    Boolean isAdmin = pu.Role__c == 'HR Admin' || pu.Role__c == 'System Admin';
    Boolean hasFeature =
      String.isNotBlank(pu.Access_Features__c) &&
      pu.Access_Features__c.contains('Admin Settings');
    if (!isAdmin && !hasFeature) {
      throw new AuraHandledException(
        'Access denied: Admin privileges required.'
      );
    }
  }
}