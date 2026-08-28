/**
 * @description Service class for Leave Allocation updates
 */
public without sharing class PWChrono_LeaveAllocationService {
  /**
   * @description Update leave allocation based on approved leaves
   */
  public static void updateLeaveAllocation(List<PWChrono_Leave__c> leaves) {
    try {
      Set<Id> allocationIds = collectAllocationIds(leaves);

      if (allocationIds.isEmpty()) {
        return;
      }

      Map<Id, Decimal> usedDaysByAllocation = getUsedDaysByAllocationId(
        allocationIds
      );
      List<PWChrono_Leave_Allocation__c> allocationsToUpdate = prepareAllocationsUpdate(
        allocationIds,
        usedDaysByAllocation
      );

      if (!allocationsToUpdate.isEmpty()) {
        update allocationsToUpdate;
      }
    } catch (Exception e) {
      PWChrono_Logger.error(
        'Error updating leave allocations: ' + e.getMessage()
      );
      PWChrono_Logger.error('Stack trace: ' + e.getStackTraceString());
      if (leaves != null && !leaves.isEmpty()) {
        leaves[0].addError('Error updating leave balance: ' + e.getMessage());
      }
    }
  }

  private static Set<Id> collectAllocationIds(List<PWChrono_Leave__c> leaves) {
    Set<Id> allocationIds = new Set<Id>();
    for (PWChrono_Leave__c leave : leaves) {
      if (leave.Leave_Allocation__c != null) {
        allocationIds.add(leave.Leave_Allocation__c);
      }
    }
    return allocationIds;
  }

  private static Map<Id, Decimal> getUsedDaysByAllocationId(
    Set<Id> allocationIds
  ) {
    Map<Id, Decimal> usedByAllocation = new Map<Id, Decimal>();
    if (allocationIds.isEmpty()) {
      return usedByAllocation;
    }

    List<AggregateResult> results = [
      SELECT Leave_Allocation__c allocationId, SUM(Total_Days__c) used
      FROM PWChrono_Leave__c
      WHERE
        Leave_Allocation__c IN :allocationIds
        AND Status__c = :PWChrono_Constants.STATUS_APPROVED
      GROUP BY Leave_Allocation__c
    ];

    for (AggregateResult ar : results) {
      usedByAllocation.put(
        (Id) ar.get('allocationId'),
        (Decimal) ar.get('used')
      );
    }

    return usedByAllocation;
  }

  private static List<PWChrono_Leave_Allocation__c> prepareAllocationsUpdate(
    Set<Id> allocationIds,
    Map<Id, Decimal> usedDaysByAllocation
  ) {
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id, Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Id IN :allocationIds
    ];

    List<PWChrono_Leave_Allocation__c> allocationsToUpdate = new List<PWChrono_Leave_Allocation__c>();
    for (PWChrono_Leave_Allocation__c allocation : allocations) {
      Decimal usedDays = usedDaysByAllocation.containsKey(allocation.Id)
        ? usedDaysByAllocation.get(allocation.Id)
        : 0;

      if (allocation.Total_Leaves_Used__c != usedDays) {
        allocation.Total_Leaves_Used__c = usedDays;
        allocationsToUpdate.add(allocation);
      }
    }
    return allocationsToUpdate;
  }
}