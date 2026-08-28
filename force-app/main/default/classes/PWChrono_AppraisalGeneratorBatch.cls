/**
 * @description Batch class to generate Appraisals based on Performance Cycles
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class PWChrono_AppraisalGeneratorBatch implements Database.Batchable<SObject>, Schedulable {
  public void execute(SchedulableContext sc) {
    Database.executeBatch(new PWChrono_AppraisalGeneratorBatch(), 200);
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    // Get today's month and day
    Date today = Date.today();
    Integer currentDay = today.day();

    // Convert month number to name (1 -> January)
    String currentMonth = getMonthName(today.month());

    // Find active cycles starting today
    // Note: We query Cycles first to get the IDs, but the Batch iterates over Employees
    // This is a pattern where we pass the eligible cycles to the query or process logic
    // However, standard Batch iterates over one object.
    // Strategy: Iterate over Portal_Users__c (Active) and in execute(), check if they match any active cycle.

    return Database.getQueryLocator(
      [
        SELECT Id, Name, Date_of_Joining__c, Reports_To__c
        FROM Portal_Users__c
        WHERE Is_Active__c = TRUE
      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<SObject> scope) {
    List<Portal_Users__c> employees = (List<Portal_Users__c>) scope;
    try {
      Date today = Date.today();
      Integer currentDay = today.day();
      String currentMonth = getMonthName(today.month());

      // Get active cycles for today
      List<PWChrono_Performance_Cycle__c> activeCycles = [
        SELECT
          Id,
          Name,
          Type__c,
          Minimum_Tenure_Months__c,
          Start_Month__c,
          Start_Day__c,
          End_Month__c,
          End_Day__c
        FROM PWChrono_Performance_Cycle__c
        WHERE
          Is_Active__c = TRUE
          AND Start_Month__c = :currentMonth
          AND Start_Day__c = :currentDay
      ];

      if (activeCycles.isEmpty()) {
        return; // No cycles start today
      }

      // Check for existing appraisals to prevent duplicates
      Set<Id> employeeIds = new Map<Id, Portal_Users__c>(employees).keySet();
      Set<Id> cycleIds = new Map<Id, PWChrono_Performance_Cycle__c>(
          activeCycles
        )
        .keySet();

      List<PWChrono_Appraisal__c> existingAppraisals = [
        SELECT Id, Employees__c, Performance_Cycle__c
        FROM PWChrono_Appraisal__c
        WHERE Employees__c IN :employeeIds AND Performance_Cycle__c IN :cycleIds
      ];

      Set<String> existingKeys = new Set<String>();
      for (PWChrono_Appraisal__c app : existingAppraisals) {
        existingKeys.add(app.Employees__c + '-' + app.Performance_Cycle__c);
      }

      List<PWChrono_Appraisal__c> appraisalsToCreate = new List<PWChrono_Appraisal__c>();

      for (Portal_Users__c employee : employees) {
        for (PWChrono_Performance_Cycle__c cycle : activeCycles) {
          // Check if already exists
          if (existingKeys.contains(employee.Id + '-' + cycle.Id)) {
            continue;
          }

          // Check Tenure Eligibility
          if (isEligible(employee, cycle)) {
            PWChrono_Appraisal__c appraisal = new PWChrono_Appraisal__c();
            appraisal.Employees__c = employee.Id;
            appraisal.Reviewers__c = employee.Reports_To__c; // Default to manager
            appraisal.Performance_Cycle__c = cycle.Id;
            appraisal.Status__c = PWChrono_Constants.STATUS_DRAFT;
            appraisal.Type__c = cycle.Type__c;
            appraisal.Appraisal_Period__c = cycle.Name; // e.g., "Q1 2025"
            appraisal.Start_Date__c = today;

            // Calculate End Date based on Cycle config
            if (cycle.End_Month__c != null && cycle.End_Day__c != null) {
              Integer endMonth = getMonthNumber(cycle.End_Month__c);
              Integer startMonthNum = today.month();
              Integer endYear = today.year();
              if (endMonth != null && endMonth < startMonthNum) {
                endYear++;
              }
              if (endMonth != null) {
                appraisal.End_Date__c = Date.newInstance(
                  endYear,
                  endMonth,
                  (Integer) cycle.End_Day__c
                );
              } else {
                appraisal.End_Date__c = today.addDays(30);
              }
            } else {
              appraisal.End_Date__c = today.addDays(30);
            }

            appraisalsToCreate.add(appraisal);
          }
        }
      }

      if (!appraisalsToCreate.isEmpty()) {
        insert appraisalsToCreate;
      }
    } catch (Exception e) {
      PWChrono_Logger.error(
        'Error in Appraisal Generator Batch: ' + e.getMessage()
      );
      // In a real system, log to an Error Log object
    }
  }

  public void finish(Database.BatchableContext bc) {
    // Optional: Send email to HR Admin
    PWChrono_Logger.info('Appraisal Generator Batch finished.');
  }

  // Helper to check eligibility
  private Boolean isEligible(
    Portal_Users__c employee,
    PWChrono_Performance_Cycle__c cycle
  ) {
    if (
      cycle.Minimum_Tenure_Months__c == null ||
      cycle.Minimum_Tenure_Months__c <= 0
    ) {
      return true;
    }

    if (employee.Date_of_Joining__c == null) {
      return false; // Cannot determine tenure
    }

    Integer monthsEmployed = employee.Date_of_Joining__c.monthsBetween(
      Date.today()
    );
    return monthsEmployed >= cycle.Minimum_Tenure_Months__c;
  }

  // Helper to get month name
  private String getMonthName(Integer month) {
    Map<Integer, String> monthMap = new Map<Integer, String>{
      1 => 'January',
      2 => 'February',
      3 => 'March',
      4 => 'April',
      5 => 'May',
      6 => 'June',
      7 => 'July',
      8 => 'August',
      9 => 'September',
      10 => 'October',
      11 => 'November',
      12 => 'December'
    };
    return monthMap.get(month);
  }

  private Integer getMonthNumber(String monthName) {
    Map<String, Integer> monthMap = new Map<String, Integer>{
      'January' => 1,
      'February' => 2,
      'March' => 3,
      'April' => 4,
      'May' => 5,
      'June' => 6,
      'July' => 7,
      'August' => 8,
      'September' => 9,
      'October' => 10,
      'November' => 11,
      'December' => 12
    };
    return monthMap.get(monthName);
  }
}