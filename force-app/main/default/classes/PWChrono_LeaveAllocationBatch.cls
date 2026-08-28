/**
 * @description Batch job to automatically allocate annual leave to employees
 * Can be scheduled to run at the beginning of each year
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class PWChrono_LeaveAllocationBatch implements Database.Batchable<sObject>, Database.Stateful {
  private Integer totalProcessed = 0;
  private Integer totalErrors = 0;
  private List<String> errors = new List<String>();

  /**
   * @description Query all Portal Users (employees)
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT Id, Name, Email__c, Departments__c
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
      ]
    );
  }

  /**
   * @description Process each batch of employees and create leave allocations
   */
  public void execute(
    Database.BatchableContext bc,
    List<Portal_Users__c> scope
  ) {
    List<PWChrono_Leave_Type__c> leaveTypes = [
      SELECT
        Id,
        Name,
        Max_Days_Allowed__c,
        Is_Carry_Forward__c,
        Max_Carry_Forward_Days__c
      FROM PWChrono_Leave_Type__c
      WHERE Is_Active__c = TRUE
      LIMIT 100
    ];
    Date startDate = getFiscalYearStartDate();
    Date endDate = startDate.addYears(1).addDays(-1);

    // Previous year dates for carry forward calculation
    Date prevStartDate = startDate.addYears(-1);
    Date prevEndDate = startDate.addDays(-1);

    Set<Id> employeeIds = new Map<Id, Portal_Users__c>(scope).keySet();
    Set<Id> leaveTypeIds = new Map<Id, PWChrono_Leave_Type__c>(leaveTypes)
      .keySet();
    Set<String> existingKeys = getExistingAllocationKeys(
      employeeIds,
      leaveTypeIds,
      startDate,
      endDate
    );

    // Fetch previous year's allocations and usage for carry forward calculation
    Map<String, Decimal> prevYearBalanceMap = getPreviousYearBalances(
      employeeIds,
      leaveTypeIds,
      prevStartDate,
      prevEndDate
    );

    List<PWChrono_Leave_Allocation__c> allocationsToInsert = new List<PWChrono_Leave_Allocation__c>();
    for (Portal_Users__c employee : scope) {
      for (PWChrono_Leave_Type__c leaveType : leaveTypes) {
        if (!existingKeys.contains(employee.Id + '-' + leaveType.Id)) {
          Decimal carryForward = 0;

          // Calculate Carry Forward if enabled
          if (leaveType.Is_Carry_Forward__c == true) {
            String key = employee.Id + '-' + leaveType.Id;
            if (prevYearBalanceMap.containsKey(key)) {
              Decimal remaining = prevYearBalanceMap.get(key);
              Decimal maxCarry = leaveType.Max_Carry_Forward_Days__c != null
                ? leaveType.Max_Carry_Forward_Days__c
                : 0;

              if (remaining > 0) {
                carryForward = (remaining > maxCarry) ? maxCarry : remaining;
              }
            }
          }

          allocationsToInsert.add(
            createAllocation(
              employee,
              leaveType,
              startDate,
              endDate,
              carryForward
            )
          );
        }
      }
    }

    if (!allocationsToInsert.isEmpty()) {
      processSaveResults(Database.insert(allocationsToInsert, false));
    }
  }

  private Date getFiscalYearStartDate() {
    Organization org = [SELECT FiscalYearStartMonth FROM Organization LIMIT 1];
    Integer startMonth = org.FiscalYearStartMonth != null
      ? org.FiscalYearStartMonth
      : 1;
    Integer currentYear = Date.today().year();
    Integer currentMonth = Date.today().month();

    Integer startYear = currentYear;
    if (currentMonth < startMonth) {
      startYear = currentYear - 1;
    }
    return Date.newInstance(startYear, startMonth, 1);
  }

  private Set<String> getExistingAllocationKeys(
    Set<Id> employeeIds,
    Set<Id> leaveTypeIds,
    Date startDate,
    Date endDate
  ) {
    Set<String> keys = new Set<String>();
    for (PWChrono_Leave_Allocation__c alloc : [
      SELECT Employees__c, Leave_Type__c
      FROM PWChrono_Leave_Allocation__c
      WHERE
        Employees__c IN :employeeIds
        AND Leave_Type__c IN :leaveTypeIds
        AND From_Date__c = :startDate
        AND To_Date__c = :endDate
    ]) {
      keys.add(alloc.Employees__c + '-' + alloc.Leave_Type__c);
    }
    return keys;
  }

  private PWChrono_Leave_Allocation__c createAllocation(
    Portal_Users__c employee,
    PWChrono_Leave_Type__c leaveType,
    Date startDate,
    Date endDate,
    Decimal carryForward
  ) {
    PWChrono_Leave_Allocation__c allocation = new PWChrono_Leave_Allocation__c();
    allocation.Employees__c = employee.Id;
    allocation.Leave_Type__c = leaveType.Id;
    allocation.Carry_Forwarded_Leaves__c = carryForward;

    Decimal baseAllocation = leaveType.Max_Days_Allowed__c != null
      ? leaveType.Max_Days_Allowed__c
      : 0;
    allocation.Total_Leaves_Allocated__c = baseAllocation + carryForward;
    allocation.Total_Leaves_Used__c = 0;
    allocation.Total_Leaves_Encashed__c = 0;
    allocation.From_Date__c = startDate;
    allocation.To_Date__c = endDate;
    return allocation;
  }

  private Map<String, Decimal> getPreviousYearBalances(
    Set<Id> employeeIds,
    Set<Id> leaveTypeIds,
    Date startDate,
    Date endDate
  ) {
    Map<String, Decimal> balanceMap = new Map<String, Decimal>();

    // 1. Get Allocations
    List<PWChrono_Leave_Allocation__c> prevAllocations = [
      SELECT
        Id,
        Employees__c,
        Leave_Type__c,
        Total_Leaves_Allocated__c,
        Total_Leaves_Encashed__c
      FROM PWChrono_Leave_Allocation__c
      WHERE
        Employees__c IN :employeeIds
        AND Leave_Type__c IN :leaveTypeIds
        AND From_Date__c = :startDate
        AND To_Date__c = :endDate
    ];

    Map<String, Decimal> allocatedMap = new Map<String, Decimal>();
    for (PWChrono_Leave_Allocation__c alloc : prevAllocations) {
      String key = alloc.Employees__c + '-' + alloc.Leave_Type__c;
      Decimal total = alloc.Total_Leaves_Allocated__c != null
        ? alloc.Total_Leaves_Allocated__c
        : 0;
      Decimal encashed = alloc.Total_Leaves_Encashed__c != null
        ? alloc.Total_Leaves_Encashed__c
        : 0;
      allocatedMap.put(key, total - encashed);
    }

    // 2. Get Usage (Approved Leaves)
    List<AggregateResult> usageResults = [
      SELECT
        Employees__c empId,
        Leave_Type__c typeId,
        SUM(Total_Days__c) totalUsed
      FROM PWChrono_Leave__c
      WHERE
        Employees__c IN :employeeIds
        AND Leave_Type__c IN :leaveTypeIds
        AND Status__c = :PWChrono_Constants.STATUS_APPROVED
        AND From_Date__c >= :startDate
        AND To_Date__c <= :endDate
      GROUP BY Employees__c, Leave_Type__c
    ];

    Map<String, Decimal> usageMap = new Map<String, Decimal>();
    for (AggregateResult ar : usageResults) {
      String key = (Id) ar.get('empId') + '-' + (Id) ar.get('typeId');
      usageMap.put(key, (Decimal) ar.get('totalUsed'));
    }

    // 3. Calculate Balance
    for (String key : allocatedMap.keySet()) {
      Decimal allocatedMinusEncash = allocatedMap.get(key);
      Decimal used = usageMap.containsKey(key) ? usageMap.get(key) : 0;
      balanceMap.put(key, allocatedMinusEncash - used);
    }

    return balanceMap;
  }

  private void processSaveResults(Database.SaveResult[] results) {
    for (Database.SaveResult result : results) {
      if (result.isSuccess()) {
        totalProcessed++;
      } else {
        totalErrors++;
        String errorMsg = 'Error creating allocation: ';
        for (Database.Error err : result.getErrors()) {
          errorMsg += err.getMessage() + '; ';
        }
        errors.add(errorMsg);
        PWChrono_Logger.error(errorMsg);
      }
    }
  }

  /**
   * @description Send summary email after batch completion
   */
  public void finish(Database.BatchableContext bc) {
    PWChrono_Logger.info('Leave Allocation Batch Completed');
    PWChrono_Logger.info('Total Processed: ' + totalProcessed);
    PWChrono_Logger.info('Total Errors: ' + totalErrors);

    if (totalErrors > 0) {
      PWChrono_Logger.error('Errors encountered: ' + String.join(errors, '\n'));
    }

    // Get batch job info
    AsyncApexJob job = [
      SELECT
        Id,
        Status,
        NumberOfErrors,
        JobItemsProcessed,
        TotalJobItems,
        CreatedById,
        CreatedBy.Email
      FROM AsyncApexJob
      WHERE Id = :bc.getJobId()
    ];

    // Send summary email using Lightning Email Template when available,
    // falling back to plain text for environments where the template is not deployed.
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ job.CreatedBy.Email });

    Id templateId = PWChrono_EmailHandler.getEmailTemplateId(
      'PWChrono_Leave_Allocation_Batch'
    );

    if (templateId != null) {
      email.setTemplateId(templateId);
      email.setTargetObjectId(job.CreatedById);
      email.setSaveAsActivity(true);
    } else {
      email.setSubject('PWChrono Leave Allocation Batch - Completion Status');
      email.setPlainTextBody(
        'Leave Allocation Batch has completed.\n\n' +
          'Status: ' +
          job.Status +
          '\n' +
          'Total Batches Processed: ' +
          job.TotalJobItems +
          '\n' +
          'Records Processed: ' +
          totalProcessed +
          '\n' +
          'Errors: ' +
          totalErrors +
          '\n\n' +
          'Check logs for details.'
      );
      email.setSaveAsActivity(false);
    }

    PWChrono_EmailHandler.applyOrgWideEmailAddress(email);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
  }
}