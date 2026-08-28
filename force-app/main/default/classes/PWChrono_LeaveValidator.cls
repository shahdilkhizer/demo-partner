/**
 * @description Leave-specific validation rules. Pure validation — no DML.
 *              Delegates generic checks to PWChrono_RequestValidator.
 *              Returns a list of error strings; empty list = valid.
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public inherited sharing class PWChrono_LeaveValidator {

  /**
   * @description Validate a leave request before submission.
   * @param dto Leave data transfer object
   * @param employeeId Portal_Users__c Id
   * @return List of error messages (empty if valid)
   */
  @SuppressWarnings('PMD.NcssMethodCount')
  public static List<String> validate(LeaveDTO dto, Id employeeId) {
    List<String> errors = new List<String>();

    if (dto == null) {
      errors.add('Leave data is required.');
      return errors;
    }

    // 1. Active employee check (shared)
    String empError = PWChrono_RequestValidator.validateActiveEmployee(employeeId);
    if (empError != null) {
      errors.add(empError);
      return errors; // Fatal — no point continuing
    }

    // 2. Date range (shared)
    String dateError = PWChrono_RequestValidator.validateDateRange(dto.fromDate, dto.toDate);
    if (dateError != null) {
      errors.add(dateError);
    }

    if (String.isBlank(dto.reason)) {
      errors.add('Reason is required.');
    }

    // 3. Leave type required
    if (dto.leaveTypeId == null) {
      errors.add('Leave type is required.');
      return errors; // Need leave type for remaining checks
    }

    // 4. Load leave type config
    PWChrono_Leave_Type__c leaveType = PWChrono_LeaveSelector.getLeaveTypeById(dto.leaveTypeId);
    if (leaveType == null || leaveType.Is_Active__c != true) {
      errors.add('Selected leave type is not active.');
      return errors;
    }

    // 5. Half-day rules
    String halfDayError = validateHalfDayRules(dto, leaveType);
    if (halfDayError != null) {
      errors.add(halfDayError);
    }

    // Only proceed with date-dependent checks if dates are valid
    if (dto.fromDate != null && dto.toDate != null && dto.toDate >= dto.fromDate) {

      // 6. Backdated limit (shared)
      String backdatedError = PWChrono_RequestValidator.validateBackdatedLimit(dto.fromDate, 30);
      if (backdatedError != null) {
        errors.add(backdatedError);
      }

      // 7. Advance limit (shared)
      String advanceError = PWChrono_RequestValidator.validateAdvanceLimit(dto.toDate, 90);
      if (advanceError != null) {
        errors.add(advanceError);
      }

      // 7a. Blocked dates
      String blockedDateError = validateBlockedDates(employeeId, dto.fromDate, dto.toDate);
      if (blockedDateError != null) {
        errors.add(blockedDateError);
      }

      // 7b. Salary already processed
      String salaryProcessedError = validateSalaryProcessed(employeeId, dto.fromDate, dto.toDate);
      if (salaryProcessedError != null) {
        errors.add(salaryProcessedError);
      }

      // 8. Max consecutive days
      if (dto.totalDays != null) {
        String consecutiveError = validateMaxConsecutiveDays(leaveType, dto.totalDays);
        if (consecutiveError != null) {
          errors.add(consecutiveError);
        }

        String minDaysError = validateMinDays(leaveType, dto.totalDays);
        if (minDaysError != null) {
          errors.add(minDaysError);
        }

        if (dto.totalDays <= 0) {
          errors.add('Leave request must include at least one working day.');
        }
      }

      // 9. Leave balance
      if (dto.totalDays != null && dto.totalDays > 0) {
        String balanceError = PWChrono_LeaveBalanceService.checkSufficientBalance(
          employeeId, dto.leaveTypeId, dto.totalDays
        );
        if (balanceError != null) {
          errors.add(balanceError);
        }
      }

      // 10. Overlap check
      String overlapError = validateOverlap(employeeId, dto.fromDate, dto.toDate, dto.leaveId);
      if (overlapError != null) {
        errors.add(overlapError);
      }

      // 11. Max days allowed per year
      if (dto.totalDays != null) {
        String maxDaysError = validateMaxDaysAllowed(
          employeeId, dto.leaveTypeId, dto.totalDays, leaveType.Max_Days_Allowed__c
        );
        if (maxDaysError != null) {
          errors.add(maxDaysError);
        }
      }

      // 12. Applicable-after eligibility
      String eligibilityError = validateApplicableAfter(employeeId, leaveType);
      if (eligibilityError != null) {
        errors.add(eligibilityError);
      }

      // 13. Certificate flag
      if (leaveType.Requires_Certificate__c == true) {
        dto.certificateRequired = true;
      }

      String selfApprovalError = validateNotSelfApproval(employeeId);
      if (selfApprovalError != null) {
        errors.add(selfApprovalError);
      }
    }

    return errors;
  }

  /**
   * @description Validate that half-day is only selected for single-day requests
   *              and the leave type allows it.
   */
  public static String validateHalfDayRules(LeaveDTO dto, PWChrono_Leave_Type__c leaveType) {
    if (dto.halfDay != true) {
      return null;
    }

    if (leaveType.Allow_Half_Day__c != true) {
      return leaveType.Name + ' does not allow half-day requests.';
    }

    // Check single day
    if (dto.fromDate != null && dto.toDate != null && dto.fromDate != dto.toDate) {
      return 'Half day can only be applied for single-day requests.';
    }

    return null;
  }

  /**
   * @description Validate that the request doesn't overlap with existing approved/pending leaves.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static String validateOverlap(Id employeeId, Date fromDate, Date toDate, Id excludeLeaveId) {
    List<PWChrono_Leave__c> overlapping = PWChrono_LeaveSelector.getOverlappingLeaves(
      employeeId, fromDate, toDate, excludeLeaveId
    );

    if (!overlapping.isEmpty()) {
      PWChrono_Leave__c overlap = overlapping[0];
      return 'Leave request overlaps with existing ' +
             overlap.Leave_Type__r.Name + ' (' +
             overlap.From_Date__c.format() + ' - ' +
             overlap.To_Date__c.format() + ').';
    }

    return null;
  }

  /**
   * @description Validate max consecutive days per leave type.
   */
  public static String validateMaxConsecutiveDays(PWChrono_Leave_Type__c leaveType, Decimal totalDays) {
    if (leaveType.Max_Consecutive_Days__c == null) {
      return null;
    }

    if (totalDays > leaveType.Max_Consecutive_Days__c) {
      return 'Maximum ' + leaveType.Max_Consecutive_Days__c.intValue() +
             ' consecutive days allowed for ' + leaveType.Name + '.';
    }

    return null;
  }

  /**
   * @description Validate minimum days per request.
   */
  public static String validateMinDays(PWChrono_Leave_Type__c leaveType, Decimal totalDays) {
    if (leaveType.Min_Days_Per_Request__c == null || leaveType.Min_Days_Per_Request__c <= 0) {
      return null;
    }

    if (totalDays < leaveType.Min_Days_Per_Request__c) {
      return 'Minimum ' + leaveType.Min_Days_Per_Request__c.setScale(1) +
             ' day(s) required for ' + leaveType.Name + '.';
    }

    return null;
  }

  /**
   * @description Validate that total used + requested does not exceed yearly max.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static String validateMaxDaysAllowed(
    Id employeeId, Id leaveTypeId, Decimal requestedDays, Decimal maxDaysAllowed
  ) {
    if (maxDaysAllowed == null || maxDaysAllowed <= 0) {
      return null;
    }

    // Get total approved + submitted days for this leave type this year
    Date yearStart = Date.newInstance(Date.today().year(), 1, 1);
    Date yearEnd = Date.newInstance(Date.today().year(), 12, 31);

    List<AggregateResult> aggregates = [
      SELECT SUM(Total_Days__c) totalDays
      FROM PWChrono_Leave__c
      WHERE Employees__c = :employeeId
        AND Leave_Type__c = :leaveTypeId
        AND (Status__c = :PWChrono_Constants.STATUS_APPROVED
             OR Status__c = :PWChrono_Constants.STATUS_SUBMITTED)
        AND From_Date__c >= :yearStart
        AND From_Date__c <= :yearEnd
    ];

    Decimal totalUsedThisYear = 0;
    if (!aggregates.isEmpty() && aggregates[0].get('totalDays') != null) {
      totalUsedThisYear = (Decimal) aggregates[0].get('totalDays');
    }

    if (totalUsedThisYear + requestedDays > maxDaysAllowed) {
      Decimal remaining = maxDaysAllowed - totalUsedThisYear;
      return 'You have already used/requested ' + totalUsedThisYear.setScale(1) +
             ' days this year. Maximum allowed: ' + maxDaysAllowed.intValue() +
             ' days. Remaining: ' + Math.max(0, remaining).setScale(1) + ' days.';
    }

    return null;
  }

  /**
   * @description Validate that the employee has been employed long enough for this leave type.
   */
  public static String validateApplicableAfter(Id employeeId, PWChrono_Leave_Type__c leaveType) {
    if (leaveType.Applicable_After_Days__c == null || leaveType.Applicable_After_Days__c <= 0) {
      return null;
    }

    List<Portal_Users__c> employees = [
      SELECT Date_Of_Joining__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];

    if (employees.isEmpty() || employees[0].Date_Of_Joining__c == null) {
      return null; // Can't validate without DOJ
    }

    Integer daysEmployed = employees[0].Date_Of_Joining__c.daysBetween(Date.today());
    Integer requiredDays = leaveType.Applicable_After_Days__c.intValue();

    if (daysEmployed < requiredDays) {
      return leaveType.Name + ' is only available after ' + requiredDays +
             ' days of employment. You have been employed ' + daysEmployed + ' days.';
    }

    return null;
  }

  /**
   * @description Validate that none of the requested dates are blocked for leave.
   */
  public static String validateBlockedDates(Id employeeId, Date fromDate, Date toDate) {
    Id departmentId = PWChrono_LeaveSelector.getEmployeeDepartmentId(employeeId);
    Set<Date> blockedDates = PWChrono_LeaveSelector.getBlockedDateSet(fromDate, toDate, departmentId);

    if (blockedDates.isEmpty()) {
      return null;
    }

    List<String> blockedDateLabels = new List<String>();
    Date pointer = fromDate;
    while (pointer <= toDate) {
      if (blockedDates.contains(pointer)) {
        blockedDateLabels.add(pointer.format());
      }
      pointer = pointer.addDays(1);
    }

    return blockedDateLabels.isEmpty()
      ? null
      : 'Leave is blocked for the following date(s): ' + String.join(blockedDateLabels, ', ') + '.';
  }

  /**
   * @description Validate that salary has not already been processed for requested dates.
   */
  public static String validateSalaryProcessed(Id employeeId, Date fromDate, Date toDate) {
    if (PWChrono_LeaveSelector.hasPaidSalarySlipInRange(employeeId, fromDate, toDate)) {
      return 'Leave cannot be submitted because payroll has already been processed for at least one requested date.';
    }
    return null;
  }

  /**
   * @description Validate that an employee is not assigned to self-approve.
   */
  public static String validateNotSelfApproval(Id employeeId) {
    Id approverId = PWChrono_RequestService.resolveApprover(employeeId);
    if (approverId != null && approverId == employeeId) {
      return 'Self-approval is not allowed.';
    }
    return null;
  }

  // ── DTO ──

  public class LeaveDTO {
    @AuraEnabled public Id leaveId;
    @AuraEnabled public Id leaveTypeId;
    @AuraEnabled public String leaveTypeName;
    @AuraEnabled public Date fromDate;
    @AuraEnabled public Date toDate;
    @AuraEnabled public Decimal totalDays;
    @AuraEnabled public Boolean halfDay;
    @AuraEnabled public String halfDaySession;
    @AuraEnabled public String reason;
    @AuraEnabled public String status;
    @AuraEnabled public Id employeeId;
    @AuraEnabled public String employeeName;
    @AuraEnabled public Id approverId;
    @AuraEnabled public String approverName;
    @AuraEnabled public Date appliedDate;
    @AuraEnabled public Date approvalDate;
    @AuraEnabled public String rejectionReason;
    @AuraEnabled public String approverComments;
    @AuraEnabled public Boolean certificateRequired;
    @AuraEnabled public Boolean certificateUploaded;
  }
}