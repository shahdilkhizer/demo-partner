/**
 * @description Handler for PWChrono_AppraisalTrigger
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_AppraisalTriggerHandler {
  public static Boolean isExecuting = false;

  public static void handleAfterUpdate(
    List<PWChrono_Appraisal__c> newRecords,
    Map<Id, PWChrono_Appraisal__c> oldMap
  ) {
    if (isExecuting) {
      return;
    }
    isExecuting = true;
    try {
      List<PWChrono_Appraisal__c> approvedIncrements = new List<PWChrono_Appraisal__c>();
      List<PWChrono_Appraisal__c> approvedBonuses = new List<PWChrono_Appraisal__c>();
      List<PWChrono_Appraisal__c> completedAppraisals = new List<PWChrono_Appraisal__c>();

      for (PWChrono_Appraisal__c appraisal : newRecords) {
        PWChrono_Appraisal__c oldAppraisal = oldMap.get(appraisal.Id);

        // Check if status changed to Completed
        if (
          appraisal.Status__c == PWChrono_Constants.STATUS_COMPLETED &&
          oldAppraisal.Status__c != PWChrono_Constants.STATUS_COMPLETED
        ) {
          completedAppraisals.add(appraisal);

          // Handle Salary Increment
          if (
            appraisal.Outcome_Type__c == 'Salary Increment' &&
            appraisal.Proposed_Amount__c != null &&
            appraisal.Proposed_Amount__c > 0
          ) {
            approvedIncrements.add(appraisal);
          }
          // Handle Performance Bonus
          else if (
            appraisal.Outcome_Type__c == 'Performance Bonus' &&
            appraisal.Proposed_Amount__c != null &&
            appraisal.Proposed_Amount__c > 0
          ) {
            approvedBonuses.add(appraisal);
          }
        }
      }

      if (!approvedIncrements.isEmpty()) {
        processSalaryIncrements(approvedIncrements);
      }

      if (!approvedBonuses.isEmpty()) {
        processBonuses(approvedBonuses);
      }

      if (!completedAppraisals.isEmpty()) {
        PWChrono_EmailHandler.sendAppraisalNotifications(completedAppraisals);
      }
    } finally {
      isExecuting = false;
    }
  }

  /**
   * @description Creates new Salary Assignment records for approved increments
   */
  private static void processSalaryIncrements(
    List<PWChrono_Appraisal__c> appraisals
  ) {
    List<PWChrono_Salary_Assignment__c> newAssignments = new List<PWChrono_Salary_Assignment__c>();
    Set<Id> employeeIds = new Set<Id>();
    for (PWChrono_Appraisal__c appraisal : appraisals) {
      employeeIds.add(appraisal.Employees__c);
    }

    // Lock active salary assignments for affected employees to reduce update contention.
    Map<Id, PWChrono_Salary_Assignment__c> currentAssignments = new Map<Id, PWChrono_Salary_Assignment__c>();
    for (PWChrono_Salary_Assignment__c sa : [
      SELECT Id, Name, Employees__c, Base_Salary__c, From_Date__c
      FROM PWChrono_Salary_Assignment__c
      WHERE Employees__c IN :employeeIds AND Is_Active__c = TRUE
      FOR UPDATE
    ]) {
      currentAssignments.put(sa.Employees__c, sa);
    }

    for (PWChrono_Appraisal__c appraisal : appraisals) {
      PWChrono_Salary_Assignment__c currentSA = currentAssignments.get(
        appraisal.Employees__c
      );
      Decimal newSalary =
        (currentSA != null ? currentSA.Base_Salary__c : 0) +
        appraisal.Proposed_Amount__c;

      PWChrono_Salary_Assignment__c newSA = new PWChrono_Salary_Assignment__c(
        Employees__c = appraisal.Employees__c,
        Base_Salary__c = newSalary,
        From_Date__c = appraisal.Effective_Date__c != null
          ? appraisal.Effective_Date__c
          : Date.today(),
        Change_Reason__c = 'Annual Increment',
        Is_Active__c = true
      );
      newAssignments.add(newSA);

      // Mark old one as not current
      if (currentSA != null) {
        currentSA.Is_Active__c = false;
        newAssignments.add(currentSA);
      }
    }

    if (!newAssignments.isEmpty()) {
      upsert newAssignments;
    }
  }

  /**
   * @description Creates Bonus records for approved performance bonuses
   */
  private static void processBonuses(List<PWChrono_Appraisal__c> appraisals) {
    List<PWChrono_Bonus__c> bonusesToCreate = new List<PWChrono_Bonus__c>();
    for (PWChrono_Appraisal__c appraisal : appraisals) {
      PWChrono_Bonus__c bonus = new PWChrono_Bonus__c(
        Employees__c = appraisal.Employees__c,
        Amount__c = appraisal.Proposed_Amount__c,
        Bonus_Date__c = appraisal.Effective_Date__c != null
          ? appraisal.Effective_Date__c
          : Date.today(),
        Reason__c = 'Performance Bonus - ' + appraisal.Appraisal_Period__c,
        Appraisal__c = appraisal.Id
      );
      bonusesToCreate.add(bonus);
    }

    if (!bonusesToCreate.isEmpty()) {
      insert bonusesToCreate;
    }
  }
}