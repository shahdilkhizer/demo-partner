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
    PWChrono_LeaveService.validateLeaveBalance(leaves);
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