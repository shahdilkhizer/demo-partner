/**
 * @description DTO and validation layer for the Attendance module.
 *              Contains the AttendanceRequestDTO inner class and all
 *              business validation rules for attendance correction requests.
 *              Called by PWChrono_AttendanceService; reuses
 *              PWChrono_RequestValidator for shared rules.
 */
public inherited sharing class PWChrono_AttendanceValidator {

  /** Maximum days in the past an employee may submit a correction for. */
  @TestVisible
  private static final Integer BACKDATED_LIMIT_DAYS = 30;

  private static final Set<String> VALID_CORRECTION_TYPES = new Set<String>{
    'Check-In Missing', 'Check-Out Missing', 'Both Missing', 'Wrong Time', 'Other'
  };

  // ─────────────────────────── DTO ─────────────────────────────────────────

  /**
   * @description Data transfer object for attendance correction requests.
   *              Passed from LWC → Controller → Service → Validator.
   */
  public class AttendanceRequestDTO {
    @AuraEnabled public Id   requestId;          // null on new, Id on edit
    @AuraEnabled public Date attendanceDate;
    @AuraEnabled public String correctionType;   // Check-In Missing | Check-Out Missing | Both Missing | Wrong Time | Other
    @AuraEnabled public String requestedCheckIn; // HH:mm string, parsed to Time in service
    @AuraEnabled public String requestedCheckOut;
    @AuraEnabled public String actualCheckIn;    // optional context provided by employee
    @AuraEnabled public String actualCheckOut;
    @AuraEnabled public String reason;
  }

  // ─────────────────────── Aggregate validate() ────────────────────────────

  /**
   * @description Runs all validation rules for a correction request.
   *              Returns a non-empty list of errors if invalid; empty = valid.
   * @param dto  The request data transfer object.
   * @param employeeId The submitting employee's Portal_Users__c Id.
   * @return List<String> of error messages (empty means pass).
   */
  @SuppressWarnings('PMD.CognitiveComplexity')
  public static List<String> validate(AttendanceRequestDTO dto, Id employeeId) {
    List<String> errors = new List<String>();

    // ── Fatal: active employee ──────────────────────────────────────────────
    String activeError = PWChrono_RequestValidator.validateActiveEmployee(employeeId);
    if (activeError != null) { errors.add(activeError); return errors; }

    // ── Fatal: date required ─────────────────────────────────────────────────
    if (dto.attendanceDate == null) {
      errors.add('Attendance date is required.');
      return errors;
    }

    // ── Rule 1: not a future date ────────────────────────────────────────────
    String futureError = validateNotFuture(dto.attendanceDate);
    if (futureError != null) { errors.add(futureError); return errors; }

    // ── Rule 2: within backdated correction window ───────────────────────────
    String backdatedError = PWChrono_RequestValidator.validateBackdatedLimit(dto.attendanceDate, BACKDATED_LIMIT_DAYS);
    if (backdatedError != null) { errors.add(backdatedError); return errors; }

    // ── Rule 3: correction type valid ─────────────────────────────────────────
    String typeError = validateCorrectionType(dto.correctionType);
    if (typeError != null) { errors.add(typeError); }

    // ── Rule 4: reason required ───────────────────────────────────────────────
    if (String.isBlank(dto.reason)) { errors.add('Reason is required.'); }

    // ── Rule 5: time logic ────────────────────────────────────────────────────
    String timeError = validateTimeLogic(dto);
    if (timeError != null) { errors.add(timeError); }

    // Return early if fatal structural errors exist before record-level queries
    if (!errors.isEmpty()) { return errors; }

    // ── Rule 6: no conflicting active request for the same date ───────────────
    String dupError = validateNoDuplicate(dto, employeeId);
    if (dupError != null) { errors.add(dupError); }

    // ── Rule 7: not on approved leave on the attendance date ──────────────────
    String leaveError = validateNotOnApprovedLeave(dto.attendanceDate, employeeId);
    if (leaveError != null) { errors.add(leaveError); }

    return errors;
  }

  // ─────────────────────── Individual rules ────────────────────────────────

  /**
   * @description Validates that the attendance date is not in the future.
   */
  public static String validateNotFuture(Date attendanceDate) {
    if (attendanceDate > Date.today()) {
      return 'Attendance date cannot be in the future.';
    }
    return null;
  }

  /**
   * @description Validates that correctionType is a recognised value.
   */
  public static String validateCorrectionType(String correctionType) {
    if (String.isBlank(correctionType)) {
      return 'Correction type is required.';
    }
    if (!VALID_CORRECTION_TYPES.contains(correctionType)) {
      return 'Invalid correction type: ' + correctionType + '.';
    }
    return null;
  }

  /**
   * @description Validates time consistency.
   *              If both check-in and check-out are provided, check-in must be earlier.
   *              Validates that at least one time is provided for time-based correction types.
   */
  public static String validateTimeLogic(AttendanceRequestDTO dto) {
    if (String.isBlank(dto.correctionType)) { return null; }

    Boolean needsCheckIn  = dto.correctionType == 'Check-In Missing'  || dto.correctionType == 'Both Missing' || dto.correctionType == 'Wrong Time';
    Boolean needsCheckOut = dto.correctionType == 'Check-Out Missing' || dto.correctionType == 'Both Missing' || dto.correctionType == 'Wrong Time';

    if (needsCheckIn && String.isBlank(dto.requestedCheckIn)) {
      return 'Requested check-in time is required for correction type: ' + dto.correctionType + '.';
    }
    if (needsCheckOut && String.isBlank(dto.requestedCheckOut)) {
      return 'Requested check-out time is required for correction type: ' + dto.correctionType + '.';
    }

    // Both present — check order
    if (String.isNotBlank(dto.requestedCheckIn) && String.isNotBlank(dto.requestedCheckOut)) {
      Time checkIn  = parseTime(dto.requestedCheckIn);
      Time checkOut = parseTime(dto.requestedCheckOut);
      if (checkIn != null && checkOut != null && checkIn >= checkOut) {
        return 'Check-in time must be before check-out time.';
      }
    }

    return null;
  }

  /**
   * @description Validates there is no active (Submitted or Approved) request
   *              for the same employee and attendance date.
   *              On edit, excludes the request being edited.
   */
  public static String validateNoDuplicate(AttendanceRequestDTO dto, Id employeeId) {
    List<PWChrono_Attendance_Request__c> conflicts =
      PWChrono_AttendanceSelector.getActiveRequestsByEmployeeAndDate(
        employeeId, dto.attendanceDate, dto.requestId
      );
    if (!conflicts.isEmpty()) {
      return 'An active attendance correction request already exists for ' +
             dto.attendanceDate.format() + '. Please review your existing request.';
    }
    return null;
  }

  /**
   * @description Validates the employee is not on an approved leave on the given date.
   */
  public static String validateNotOnApprovedLeave(Date attendanceDate, Id employeeId) {
    List<Leave__c> leaves =
      PWChrono_AttendanceSelector.getApprovedLeaveCoveringDate(employeeId, attendanceDate);
    if (!leaves.isEmpty()) {
      return 'You are on approved leave on ' + attendanceDate.format() +
             '. Attendance corrections cannot be submitted for leave dates.';
    }
    return null;
  }

  // ─────────────────────── Utilities ───────────────────────────────────────

  /**
   * @description Parses an "HH:mm" string into a Salesforce Time value.
   *              Returns null if the string is blank or malformed.
   */
  public static Time parseTime(String timeStr) {
    if (String.isBlank(timeStr)) { return null; }
    try {
      List<String> parts = timeStr.trim().split(':');
      if (parts.size() < 2) { return null; }
      Integer h = Integer.valueOf(parts[0]);
      Integer m = Integer.valueOf(parts[1]);
      Integer s = (parts.size() > 2) ? Integer.valueOf(parts[2]) : 0;
      return Time.newInstance(h, m, s, 0);
    } catch (Exception e) {
      PWChrono_Logger.error('Failed to parse time string: ' + timeStr, e);
      return null;
    }
  }
}