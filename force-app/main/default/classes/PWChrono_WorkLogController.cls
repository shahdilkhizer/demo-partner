/**
 * Persistent WFH, overtime, and timesheet operations with portal RBAC.
 */
public inherited sharing class PWChrono_WorkLogController {
  private static final Set<String> WORK_TYPES = new Set<String>{
    'Work From Home',
    'Overtime',
    'Timesheet'
  };

  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Work_Log__c> getWorkLogs(
    String workType,
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    Id actorId = resolveActor(portalUserId, sessionToken);
    requireAttendance(actorId);
    validateWorkType(workType);

    Set<Id> employeeIds = new Set<Id>{ actorId };
    if (
      PWChrono_AccessController.hasFeature(
        actorId,
        PWChrono_AccessController.FEATURE_ATTENDANCE_TEAM
      ) ||
      PWChrono_AccessController.hasFeature(
        actorId,
        PWChrono_AccessController.FEATURE_ATTENDANCE_ADMIN
      )
    ) {
      employeeIds = PWChrono_AccessController.getVisibleEmployeeIds(actorId);
    }

    if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
      return [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee__r.Name,
          Employee__r.Designation__c,
          Employee__r.Department__c,
          Employee__r.Photo_Url__c,
          Work_Type__c,
          Work_Date__c,
          End_Date__c,
          Hours__c,
          Planned_Hours__c,
          Project__c,
          Project__r.Name,
          Description__c,
          Status__c,
          Approver__c,
          Approver__r.Name,
          Decision_Comments__c,
          Decision_Date__c,
          CreatedDate
        FROM PWChrono_Work_Log__c
        WHERE
          Work_Type__c = :workType
          AND Employee__c IN :employeeIds
          AND Status__c = :statusFilter
        ORDER BY Work_Date__c DESC, CreatedDate DESC
        LIMIT 500
      ];
    }
    return [
      SELECT
        Id,
        Name,
        Employee__c,
        Employee__r.Name,
        Employee__r.Designation__c,
        Employee__r.Department__c,
        Employee__r.Photo_Url__c,
        Work_Type__c,
        Work_Date__c,
        End_Date__c,
        Hours__c,
        Planned_Hours__c,
        Project__c,
        Project__r.Name,
        Description__c,
        Status__c,
        Approver__c,
        Approver__r.Name,
        Decision_Comments__c,
        Decision_Date__c,
        CreatedDate
      FROM PWChrono_Work_Log__c
      WHERE Work_Type__c = :workType AND Employee__c IN :employeeIds
      ORDER BY Work_Date__c DESC, CreatedDate DESC
      LIMIT 500
    ];
  }

  @AuraEnabled(cacheable=false)
  public static List<Portal_Users__c> getAssignableEmployees(
    String portalUserId,
    String sessionToken
  ) {
    Id actorId = resolveActor(portalUserId, sessionToken);
    PWChrono_AccessController.requireFeature(
      actorId,
      PWChrono_AccessController.FEATURE_ATTENDANCE_TEAM
    );
    Set<Id> visibleIds = PWChrono_AccessController.getVisibleEmployeeIds(
      actorId
    );
    return [
      SELECT Id, Name, Designation__c, Department__c
      FROM Portal_Users__c
      WHERE Id IN :visibleIds AND Is_Active__c = TRUE
      ORDER BY Name
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Project__c> getActiveProjects(
    String portalUserId,
    String sessionToken
  ) {
    Id actorId = resolveActor(portalUserId, sessionToken);
    requireAttendance(actorId);
    return [
      SELECT Id, Name
      FROM PWChrono_Project__c
      WHERE Status__c = 'Active'
      ORDER BY Name
      LIMIT 500
    ];
  }

  @AuraEnabled
  public static PWChrono_Work_Log__c saveWorkLog(
    PWChrono_Work_Log__c workLog,
    String portalUserId,
    String sessionToken
  ) {
    if (workLog == null) {
      throw handled('A work record is required.');
    }
    Id actorId = resolveActor(portalUserId, sessionToken);
    requireAttendance(actorId);
    validateWorkType(workLog.Work_Type__c);
    validateRecord(workLog);

    if (workLog.Id == null) {
      Id targetEmployeeId = workLog.Employee__c == null
        ? actorId
        : workLog.Employee__c;
      if (
        targetEmployeeId != actorId &&
        !PWChrono_AccessController.canViewEmployee(actorId, targetEmployeeId)
      ) {
        throw handled('Access denied for the selected employee.');
      }
      workLog.Employee__c = targetEmployeeId;
      workLog.Status__c = 'Submitted';
      if (workLog.Approver__c == null) {
        workLog.Approver__c = resolveApprover(targetEmployeeId);
      }
      insert workLog;
    } else {
      PWChrono_Work_Log__c existing = [
        SELECT Employee__c, Work_Type__c, Status__c
        FROM PWChrono_Work_Log__c
        WHERE Id = :workLog.Id
        LIMIT 1
      ];
      Boolean isOwner = existing.Employee__c == actorId;
      Boolean canManage = PWChrono_AccessController.hasFeature(
        actorId,
        PWChrono_AccessController.FEATURE_ATTENDANCE_ADMIN
      );
      if (!isOwner && !canManage) {
        throw handled(
          'Only the owner or an attendance administrator can edit this record.'
        );
      }
      if (
        !canManage &&
        existing.Status__c != 'Draft' &&
        existing.Status__c != 'Rejected'
      ) {
        throw handled('Only draft or rejected records can be edited.');
      }
      workLog.Employee__c = existing.Employee__c;
      workLog.Work_Type__c = existing.Work_Type__c;
      workLog.Status__c = canManage ? workLog.Status__c : 'Submitted';
      update workLog;
    }
    return getById(workLog.Id);
  }

  @AuraEnabled
  public static PWChrono_Work_Log__c decideWorkLog(
    Id workLogId,
    String decision,
    String comments,
    String portalUserId,
    String sessionToken
  ) {
    Id actorId = resolveActor(portalUserId, sessionToken);
    PWChrono_AccessController.requireFeature(
      actorId,
      PWChrono_AccessController.FEATURE_ATTENDANCE_TEAM
    );
    if (decision != 'Approve' && decision != 'Reject') {
      throw handled('Decision must be Approve or Reject.');
    }
    PWChrono_Work_Log__c record = [
      SELECT Employee__c, Approver__c, Status__c
      FROM PWChrono_Work_Log__c
      WHERE Id = :workLogId
      LIMIT 1
      FOR UPDATE
    ];
    if (record.Status__c != 'Submitted') {
      throw handled('Only submitted records can be approved or rejected.');
    }
    if (
      !PWChrono_AccessController.canApproveForEmployee(
        actorId,
        record.Employee__c,
        record.Approver__c
      )
    ) {
      throw handled('Access denied for this approval.');
    }
    record.Status__c = decision == 'Approve' ? 'Approved' : 'Rejected';
    record.Approver__c = actorId;
    record.Decision_Comments__c = comments;
    record.Decision_Date__c = System.now();
    update record;
    return getById(workLogId);
  }

  @AuraEnabled
  public static void deleteWorkLog(
    Id workLogId,
    String portalUserId,
    String sessionToken
  ) {
    Id actorId = resolveActor(portalUserId, sessionToken);
    requireAttendance(actorId);
    PWChrono_Work_Log__c record = [
      SELECT Employee__c, Status__c
      FROM PWChrono_Work_Log__c
      WHERE Id = :workLogId
      LIMIT 1
    ];
    Boolean canManage = PWChrono_AccessController.hasFeature(
      actorId,
      PWChrono_AccessController.FEATURE_ATTENDANCE_ADMIN
    );
    if (
      !canManage &&
      (record.Employee__c != actorId ||
      (record.Status__c != 'Draft' &&
      record.Status__c != 'Rejected'))
    ) {
      throw handled(
        'Only draft or rejected records can be deleted by their owner.'
      );
    }
    delete record;
  }

  private static Id resolveActor(String portalUserId, String sessionToken) {
    return PWChrono_RequestValidator.resolveEmployeeId(
      portalUserId,
      sessionToken
    );
  }

  private static void requireAttendance(Id actorId) {
    PWChrono_AccessController.requireFeature(actorId, 'Attendance Management');
  }

  private static void validateWorkType(String workType) {
    if (!WORK_TYPES.contains(workType)) {
      throw handled('A valid work type is required.');
    }
  }

  private static void validateRecord(PWChrono_Work_Log__c workLog) {
    if (workLog.Work_Date__c == null) {
      throw handled('Work date is required.');
    }
    if (
      workLog.End_Date__c != null &&
      workLog.End_Date__c < workLog.Work_Date__c
    ) {
      throw handled('End date must be on or after the work date.');
    }
    if (
      (workLog.Work_Type__c == 'Overtime' ||
      workLog.Work_Type__c == 'Timesheet') &&
      (workLog.Hours__c == null ||
      workLog.Hours__c <= 0 ||
      workLog.Hours__c > 24)
    ) {
      throw handled('Hours must be greater than 0 and no more than 24.');
    }
    if (workLog.Work_Type__c == 'Timesheet' && workLog.Project__c == null) {
      throw handled('Project is required for a timesheet entry.');
    }
    if (String.isBlank(workLog.Description__c)) {
      throw handled('Description is required.');
    }
  }

  private static Id resolveApprover(Id employeeId) {
    Portal_Users__c employee = [
      SELECT Reports_To__c
      FROM Portal_Users__c
      WHERE Id = :employeeId
      LIMIT 1
    ];
    return employee.Reports_To__c;
  }

  private static PWChrono_Work_Log__c getById(Id workLogId) {
    return [
      SELECT
        Id,
        Name,
        Employee__c,
        Employee__r.Name,
        Employee__r.Designation__c,
        Employee__r.Department__c,
        Employee__r.Photo_Url__c,
        Work_Type__c,
        Work_Date__c,
        End_Date__c,
        Hours__c,
        Planned_Hours__c,
        Project__c,
        Project__r.Name,
        Description__c,
        Status__c,
        Approver__c,
        Approver__r.Name,
        Decision_Comments__c,
        Decision_Date__c,
        CreatedDate
      FROM PWChrono_Work_Log__c
      WHERE Id = :workLogId
      LIMIT 1
    ];
  }

  private static AuraHandledException handled(String message) {
    AuraHandledException exceptionValue = new AuraHandledException(message);
    exceptionValue.setMessage(message);
    return exceptionValue;
  }
}