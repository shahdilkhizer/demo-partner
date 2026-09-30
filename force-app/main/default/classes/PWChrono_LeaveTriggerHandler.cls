/**
 * @description Handler class for Leave__c trigger
 * Updates leave allocation used days when leaves are approved/rejected
 */
public inherited sharing class PWChrono_LeaveTriggerHandler {
  public static Boolean isExecuting = false;

  /**
   * @description Validate leave balance before insert/update
   */
  public static void validateLeaveBalance(
    List<Leave__c> leaves,
    Map<Id, Leave__c> oldMap
  ) {
    if (leaves == null || leaves.isEmpty()) {
      return;
    }
    List<Leave__c> toValidate = new List<Leave__c>();
    for (Leave__c l : leaves) {
      if (l.Status__c == PWChrono_Constants.STATUS_APPROVED ||
          l.Status__c == PWChrono_Constants.STATUS_REJECTED ||
          l.Status__c == PWChrono_Constants.STATUS_CANCELLED ||
          l.Status__c == PWChrono_Constants.STATUS_DRAFT) {
        continue;
      }
      if (l.Status__c == PWChrono_Constants.STATUS_SUBMITTED) {
        if (oldMap != null && oldMap.containsKey(l.Id)) {
          Leave__c oldLeave = oldMap.get(l.Id);
          if (oldLeave.Status__c == PWChrono_Constants.STATUS_SUBMITTED &&
              oldLeave.From_Date__c == l.From_Date__c &&
              oldLeave.To_Date__c == l.To_Date__c &&
              oldLeave.Total_Days__c == l.Total_Days__c &&
              oldLeave.Leave_Type__c == l.Leave_Type__c) {
            continue;
          }
        }
        toValidate.add(l);
      }
    }
    if (!toValidate.isEmpty()) {
      PWChrono_LeaveService.validateLeaveBalance(toValidate);
    }
  }

  /**
   * @description Update leave allocation based on approved leaves
   */
  public static void updateLeaveAllocation(
    List<Leave__c> leaves,
    Map<Id, Leave__c> oldMap
  ) {
    if (isExecuting) {
      return;
    }
    isExecuting = true;
    try {
      List<Leave__c> combined = new List<Leave__c>();
      if (leaves != null && !leaves.isEmpty()) {
        combined.addAll(leaves);
        if (oldMap != null && !oldMap.isEmpty()) {
          for (Leave__c l : leaves) {
            if (oldMap.containsKey(l.Id)) {
              combined.add(oldMap.get(l.Id));
            }
          }
        }
      }
      PWChrono_LeaveAllocationService.updateLeaveAllocation(combined);
    } finally {
      isExecuting = false;
    }
  }
}