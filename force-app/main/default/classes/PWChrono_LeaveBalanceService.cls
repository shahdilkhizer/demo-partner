/**
 * @description Service for leave balance operations.
 *              Calculates remaining balances, handles allocation updates,
 *              and produces balance DTOs for the UI.
 *              This was a missing dependency — referenced by PWChrono_LeaveController.
 */
public inherited sharing class PWChrono_LeaveBalanceService {

  /**
   * @description Get leave balances for an employee across all active leave types.
   *              Returns one LeaveBalanceWrapper per leave type that has an allocation.
   * @param employeeId Portal_Users__c Id
   * @return List of leave balance wrappers
   */
  public static List<LeaveBalanceWrapper> getLeaveBalance(Id employeeId) {
    if (employeeId == null) {
      return new List<LeaveBalanceWrapper>();
    }

    // Get all active leave types for ordering / color
    Map<Id, PWChrono_Leave_Type__c> leaveTypeMap = new Map<Id, PWChrono_Leave_Type__c>([
      SELECT Id, Name, Max_Days_Allowed__c, Is_Unpaid__c,
             Requires_Certificate__c, Allow_Negative_Balance__c
      FROM PWChrono_Leave_Type__c
      WHERE Is_Active__c = TRUE
      ORDER BY Name
    ]);

    // Get allocations for current period
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id, Leave_Type__c, Leave_Type__r.Name,
             Total_Leaves_Allocated__c, Total_Leaves_Used__c,
             Total_Leaves_Encashed__c, Carry_Forwarded_Leaves__c,
             New_Leaves_Allocated__c, From_Date__c, To_Date__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employeeId
        AND To_Date__c >= TODAY
      ORDER BY Leave_Type__r.Name
    ];

    // Get pending request days per leave type
    Map<Id, Decimal> pendingDaysMap = getPendingRequestDays(employeeId);

    List<LeaveBalanceWrapper> balances = new List<LeaveBalanceWrapper>();
    Set<Id> allocatedTypeIds = new Set<Id>();

    for (PWChrono_Leave_Allocation__c alloc : allocations) {
      allocatedTypeIds.add(alloc.Leave_Type__c);
      LeaveBalanceWrapper wrapper = new LeaveBalanceWrapper();
      wrapper.leaveTypeId = alloc.Leave_Type__c;
      wrapper.leaveType = alloc.Leave_Type__r.Name;
      wrapper.allocationId = alloc.Id;

      Decimal allocated = safeDecimal(alloc.Total_Leaves_Allocated__c);
      Decimal used = safeDecimal(alloc.Total_Leaves_Used__c);
      Decimal encashed = safeDecimal(alloc.Total_Leaves_Encashed__c);
      Decimal carryForwarded = safeDecimal(alloc.Carry_Forwarded_Leaves__c);

      wrapper.totalAllocated = allocated;
      wrapper.totalUsed = used;
      wrapper.totalEncashed = encashed;
      wrapper.carryForwarded = carryForwarded;
      wrapper.remaining = allocated - used - encashed;
      wrapper.pendingRequests = pendingDaysMap.containsKey(alloc.Leave_Type__c)
        ? pendingDaysMap.get(alloc.Leave_Type__c)
        : 0;

      PWChrono_Leave_Type__c lt = leaveTypeMap.get(alloc.Leave_Type__c);
      wrapper.isUnpaid = lt != null && lt.Is_Unpaid__c == true;
      wrapper.allowNegative = lt != null && lt.Allow_Negative_Balance__c == true;

      balances.add(wrapper);
    }

    // Include leave types with no allocation (show 0/0)
    for (PWChrono_Leave_Type__c lt : leaveTypeMap.values()) {
      if (!allocatedTypeIds.contains(lt.Id)) {
        LeaveBalanceWrapper wrapper = new LeaveBalanceWrapper();
        wrapper.leaveTypeId = lt.Id;
        wrapper.leaveType = lt.Name;
        wrapper.totalAllocated = 0;
        wrapper.totalUsed = 0;
        wrapper.totalEncashed = 0;
        wrapper.carryForwarded = 0;
        wrapper.remaining = 0;
        wrapper.pendingRequests = pendingDaysMap.containsKey(lt.Id)
          ? pendingDaysMap.get(lt.Id)
          : 0;
        wrapper.isUnpaid = lt.Is_Unpaid__c == true;
        wrapper.allowNegative = lt.Allow_Negative_Balance__c == true;
        balances.add(wrapper);
      }
    }

    return balances;
  }

  /**
   * @description Get the balance for a specific leave type / employee.
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId PWChrono_Leave_Type__c Id
   * @return Single balance wrapper, or null if no allocation found
   */
  public static LeaveBalanceWrapper getBalanceForType(Id employeeId, Id leaveTypeId) {
    if (employeeId == null || leaveTypeId == null) {
      return null;
    }

    List<PWChrono_Leave_Allocation__c> allocations = [
          SELECT Id, Leave_Type__c, Leave_Type__r.Name,
            Leave_Type__r.Allow_Negative_Balance__c,
             Total_Leaves_Allocated__c, Total_Leaves_Used__c,
             Total_Leaves_Encashed__c, Carry_Forwarded_Leaves__c,
             From_Date__c, To_Date__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employeeId
        AND Leave_Type__c = :leaveTypeId
        AND To_Date__c >= TODAY
      LIMIT 1
    ];

    if (allocations.isEmpty()) {
      return null;
    }

    PWChrono_Leave_Allocation__c alloc = allocations[0];
    LeaveBalanceWrapper wrapper = new LeaveBalanceWrapper();
    wrapper.leaveTypeId = alloc.Leave_Type__c;
    wrapper.leaveType = alloc.Leave_Type__r.Name;
    wrapper.allocationId = alloc.Id;
    wrapper.totalAllocated = safeDecimal(alloc.Total_Leaves_Allocated__c);
    wrapper.totalUsed = safeDecimal(alloc.Total_Leaves_Used__c);
    wrapper.totalEncashed = safeDecimal(alloc.Total_Leaves_Encashed__c);
    wrapper.carryForwarded = safeDecimal(alloc.Carry_Forwarded_Leaves__c);
    wrapper.remaining = wrapper.totalAllocated - wrapper.totalUsed - wrapper.totalEncashed;
    wrapper.allowNegative = alloc.Leave_Type__r != null &&
      alloc.Leave_Type__r.Allow_Negative_Balance__c == true;

    Map<Id, Decimal> pendingMap = getPendingRequestDays(employeeId);
    wrapper.pendingRequests = pendingMap.containsKey(leaveTypeId)
      ? pendingMap.get(leaveTypeId)
      : 0;

    return wrapper;
  }

  /**
   * @description Check if an employee has sufficient balance for a leave request.
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId Leave type Id
   * @param requestedDays Number of days being requested
   * @return Error message or null if sufficient
   */
  public static String checkSufficientBalance(Id employeeId, Id leaveTypeId, Decimal requestedDays) {
    LeaveBalanceWrapper balance = getBalanceForType(employeeId, leaveTypeId);

    if (balance == null) {
      return 'No leave allocation found for this leave type.';
    }

    if (balance.allowNegative == true) {
      return null;
    }

    Decimal effectiveRemaining = balance.remaining - balance.pendingRequests;
    if (requestedDays > effectiveRemaining) {
      return 'Insufficient leave balance. Available: ' +
             effectiveRemaining.setScale(1) +
             ' days, Requested: ' + requestedDays.setScale(1) + ' days.';
    }

    return null;
  }

  /**
   * @description Deduct leave days from allocation (called on approval).
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId Leave type Id
   * @param days Days to deduct (positive number)
   */
  public static void deductBalance(Id employeeId, Id leaveTypeId, Decimal days) {
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id, Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employeeId
        AND Leave_Type__c = :leaveTypeId
        AND To_Date__c >= TODAY
      LIMIT 1
    ];

    if (allocations.isEmpty()) {
      throw new AuraHandledException('No leave allocation found to deduct from.');
    }

    PWChrono_Leave_Allocation__c alloc = allocations[0];
    alloc.Total_Leaves_Used__c = safeDecimal(alloc.Total_Leaves_Used__c) + days;
    update alloc;
  }

  /**
   * @description Reverse a balance deduction (called on cancellation of approved leave).
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId Leave type Id
   * @param days Days to reverse (positive number — will be subtracted from used)
   */
  public static void reverseBalance(Id employeeId, Id leaveTypeId, Decimal days) {
    List<PWChrono_Leave_Allocation__c> allocations = [
      SELECT Id, Total_Leaves_Used__c
      FROM PWChrono_Leave_Allocation__c
      WHERE Employees__c = :employeeId
        AND Leave_Type__c = :leaveTypeId
        AND To_Date__c >= TODAY
      LIMIT 1
    ];

    if (allocations.isEmpty()) {
      throw new AuraHandledException('No leave allocation found to reverse.');
    }

    PWChrono_Leave_Allocation__c alloc = allocations[0];
    Decimal currentUsed = safeDecimal(alloc.Total_Leaves_Used__c);
    alloc.Total_Leaves_Used__c = Math.max(0, currentUsed - days);
    update alloc;
  }

  // ── Private Helpers ──

  /**
   * @description Get total pending (Submitted) leave days grouped by leave type
   */
  private static Map<Id, Decimal> getPendingRequestDays(Id employeeId) {
    Map<Id, Decimal> result = new Map<Id, Decimal>();

    List<AggregateResult> pending = [
      SELECT Leave_Type__c leaveType, SUM(Total_Days__c) totalDays
      FROM Leave__c
      WHERE Employees__c = :employeeId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
      GROUP BY Leave_Type__c
    ];

    for (AggregateResult ar : pending) {
      Id leaveTypeId = (Id) ar.get('leaveType');
      Decimal totalDays = (Decimal) ar.get('totalDays');
      result.put(leaveTypeId, totalDays != null ? totalDays : 0);
    }

    return result;
  }

  private static Decimal safeDecimal(Decimal value) {
    return value != null ? value : 0;
  }

  // ── DTO ──

  public class LeaveBalanceWrapper {
    @AuraEnabled public Id leaveTypeId;
    @AuraEnabled public String leaveType;
    @AuraEnabled public Id allocationId;
    @AuraEnabled public Decimal totalAllocated;
    @AuraEnabled public Decimal totalUsed;
    @AuraEnabled public Decimal totalEncashed;
    @AuraEnabled public Decimal carryForwarded;
    @AuraEnabled public Decimal remaining;
    @AuraEnabled public Decimal pendingRequests;
    @AuraEnabled public Boolean isUnpaid;
    @AuraEnabled public Boolean allowNegative;
  }
}