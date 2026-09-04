/**
 * @description Handler for salary slip trigger to maintain salary history
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_SalarySlipTriggerHandler {
  /**
   * @description Create salary history records when new slips are generated
   * This helps track compensation changes over time
   */
  public static void createSalaryHistory(
    List<PWChrono_Salary_Slip__c> salarySlips
  ) {
    List<PWChrono_Salary_History__c> historyRecords = new List<PWChrono_Salary_History__c>();
    Set<Id> slipIds = new Set<Id>();

    for (PWChrono_Salary_Slip__c slip : salarySlips) {
      if (slip.Id != null) {
        slipIds.add(slip.Id);
      }
    }

    Set<Id> existingHistorySlipIds = new Set<Id>();
    if (!slipIds.isEmpty()) {
      for (PWChrono_Salary_History__c history : [
        SELECT Salary_Slip__c
        FROM PWChrono_Salary_History__c
        WHERE Salary_Slip__c IN :slipIds
      ]) {
        existingHistorySlipIds.add(history.Salary_Slip__c);
      }
    }

    for (PWChrono_Salary_Slip__c slip : salarySlips) {
      // Only create history for paid slips with valid amounts
      if (
        slip.Status__c == PWChrono_Constants.STATUS_PAID &&
        slip.Net_Pay__c != null &&
        slip.Net_Pay__c > 0 &&
        !existingHistorySlipIds.contains(slip.Id)
      ) {
        PWChrono_Salary_History__c history = new PWChrono_Salary_History__c();
        history.Contact__c = slip.Contact__c;
        // Retained only during the Portal User relationship migration.
        history.Employee__c = slip.Employees__c;
        history.Effective_Date__c = slip.Payroll_Period__c != null
          ? slip.Payroll_Period__c
          : Date.today();
        history.Basic_Salary__c = slip.Gross_Pay__c; // Use Gross as Basic not available
        history.Gross_Salary__c = slip.Gross_Pay__c;
        history.Net_Salary__c = slip.Net_Pay__c;
        history.Total_Deductions__c = 0; // Calculate from details if needed
        history.Total_Allowances__c = 0; // Calculate from details if needed
        history.Currency_Code__c = PWChrono_Constants.getEffectiveCurrencyCode();
        history.Change_Reason__c = 'Salary Slip Generated';
        history.Salary_Slip__c = slip.Id;

        historyRecords.add(history);
      }
    }

    if (!historyRecords.isEmpty()) {
      try {
        insert historyRecords;
      } catch (Exception e) {
        PWChrono_Logger.error(
          'Error creating salary history: ' + e.getMessage()
        );
        PWChrono_Logger.error('Stack trace: ' + e.getStackTraceString());
        if (salarySlips != null && !salarySlips.isEmpty()) {
          for (PWChrono_Salary_Slip__c slip : salarySlips) {
            slip.addError(
              'Unable to create salary history for one or more salary slips. Please contact your administrator.'
            );
          }
        }
      }
    }
  }
}