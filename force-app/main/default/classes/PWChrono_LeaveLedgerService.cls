/**
 * @description Service for leave ledger operations — audit trail of balance changes.
 *              Creates ledger entries for: balance used, cancelled (reversal),
 *              allocation, adjustment, carry-forward, encashment.
 *
 *              Persists balance movements into PWChrono_Leave_Ledger__c.
 */
public inherited sharing class PWChrono_LeaveLedgerService {

  // Transaction types
  public static final String TYPE_ALLOCATION   = 'Allocation';
  public static final String TYPE_USED         = 'Used';
  public static final String TYPE_CANCELLED    = 'Cancelled';
  public static final String TYPE_ADJUSTMENT   = 'Adjustment';
  public static final String TYPE_CARRY_FORWARD = 'Carry Forward';
  public static final String TYPE_ENCASHMENT   = 'Encashment';

  /**
   * @description Create a ledger entry when leave is approved (debit).
   * @param leave The approved leave record
   * @param approverId Who approved it
   */
  public static void recordLeaveUsed(Leave__c leave, Id approverId) {
    createEntry(
      leave.Employees__c,
      leave.Leave_Type__c,
      leave.Id,
      TYPE_USED,
      -leave.Total_Days__c,         // Negative = debit
      'Leave approved: ' + leave.Name,
      approverId
    );
  }

  /**
   * @description Create a reversal ledger entry when approved leave is cancelled (credit).
   * @param leave The cancelled leave record
   * @param cancelledBy Who cancelled it
   */
  public static void recordLeaveCancelled(Leave__c leave, Id cancelledBy) {
    createEntry(
      leave.Employees__c,
      leave.Leave_Type__c,
      leave.Id,
      TYPE_CANCELLED,
      leave.Total_Days__c,          // Positive = credit (reversal)
      'Approved leave cancelled: ' + leave.Name,
      cancelledBy
    );
  }

  /**
   * @description Create a ledger entry for initial allocation.
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId Leave type
   * @param days Days allocated (positive)
   * @param notes Description
   * @param createdBy Who created the allocation
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void recordAllocation(
    Id employeeId, Id leaveTypeId, Decimal days, String notes, Id createdBy
  ) {
    createEntry(employeeId, leaveTypeId, null, TYPE_ALLOCATION, days, notes, createdBy);
  }

  /**
   * @description Create a ledger entry for manual balance adjustment.
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId Leave type
   * @param days Positive = credit, Negative = debit
   * @param reason Reason for adjustment
   * @param adjustedBy Who made the adjustment
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void recordAdjustment(
    Id employeeId, Id leaveTypeId, Decimal days, String reason, Id adjustedBy
  ) {
    createEntry(employeeId, leaveTypeId, null, TYPE_ADJUSTMENT, days, reason, adjustedBy);
  }

  /**
   * @description Create a ledger entry for carry-forward.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void recordCarryForward(
    Id employeeId, Id leaveTypeId, Decimal days, Id processedBy
  ) {
    createEntry(
      employeeId, leaveTypeId, null, TYPE_CARRY_FORWARD, days,
      'Year-end carry forward', processedBy
    );
  }

  /**
   * @description Create a ledger entry for encashment.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void recordEncashment(
    Id employeeId, Id leaveTypeId, Decimal days, Id processedBy
  ) {
    createEntry(
      employeeId, leaveTypeId, null, TYPE_ENCASHMENT, -days,
      'Leave encashment', processedBy
    );
  }

  /**
   * @description Get ledger history for an employee/leave type.
   * @param employeeId Portal_Users__c Id
   * @param leaveTypeId Optional leave type filter
   * @return List of ledger entries
   */
  public static List<LedgerEntryDTO> getLedgerHistory(Id employeeId, Id leaveTypeId) {
    List<PWChrono_Leave_Ledger__c> entries;

    if (leaveTypeId != null) {
      entries = [
        SELECT Id, Transaction_Type__c, Days__c, Balance_After__c,
               Transaction_Date__c, Notes__c,
               Created_By__r.Name, Canonical_Leave__r.Name
        FROM PWChrono_Leave_Ledger__c
        WHERE Employee__c = :employeeId
          AND Leave_Type__c = :leaveTypeId
        ORDER BY Transaction_Date__c DESC, CreatedDate DESC
      ];
    } else {
      entries = [
        SELECT Id, Transaction_Type__c, Days__c, Balance_After__c,
               Transaction_Date__c, Notes__c,
               Created_By__r.Name, Canonical_Leave__r.Name
        FROM PWChrono_Leave_Ledger__c
        WHERE Employee__c = :employeeId
        ORDER BY Transaction_Date__c DESC, CreatedDate DESC
      ];
    }

    return mapEntries(entries);
  }

  /**
   * @description Get ledger entries for a specific leave request.
   */
  public static List<LedgerEntryDTO> getLedgerHistoryByLeave(Id leaveId) {
    return mapEntries([
      SELECT Id, Transaction_Type__c, Days__c, Balance_After__c,
             Transaction_Date__c, Notes__c,
             Created_By__r.Name, Canonical_Leave__r.Name
      FROM PWChrono_Leave_Ledger__c
      WHERE Canonical_Leave__c = :leaveId
      ORDER BY Transaction_Date__c DESC, CreatedDate DESC
    ]);
  }

  // ── Private ──

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private static void createEntry(
    Id employeeId, Id leaveTypeId, Id leaveId,
    String transactionType, Decimal days, String notes, Id createdBy
  ) {
    // Calculate running balance
    Decimal balanceAfter = calculateRunningBalance(employeeId, leaveTypeId);

    PWChrono_Leave_Ledger__c entry = new PWChrono_Leave_Ledger__c();
    entry.Employee__c = employeeId;
    entry.Leave_Type__c = leaveTypeId;
    entry.Canonical_Leave__c = leaveId;
    entry.Transaction_Type__c = transactionType;
    entry.Days__c = days;
    entry.Balance_After__c = balanceAfter;
    entry.Transaction_Date__c = Date.today();
    entry.Notes__c = notes;
    entry.Created_By__c = createdBy;
    insert entry;
  }

  private static Decimal calculateRunningBalance(Id employeeId, Id leaveTypeId) {
    PWChrono_LeaveBalanceService.LeaveBalanceWrapper balance =
      PWChrono_LeaveBalanceService.getBalanceForType(employeeId, leaveTypeId);

    if (balance == null) {
      return 0;
    }

    return balance.remaining;
  }

  private static List<LedgerEntryDTO> mapEntries(List<PWChrono_Leave_Ledger__c> entries) {
    List<LedgerEntryDTO> results = new List<LedgerEntryDTO>();

    for (PWChrono_Leave_Ledger__c entry : entries) {
      LedgerEntryDTO dto = new LedgerEntryDTO();
      dto.entryId = entry.Id;
      dto.transactionType = entry.Transaction_Type__c;
      dto.days = entry.Days__c;
      dto.balanceAfter = entry.Balance_After__c;
      dto.transactionDate = entry.Transaction_Date__c;
      dto.notes = entry.Notes__c;
      dto.createdByName = entry.Created_By__r != null ? entry.Created_By__r.Name : null;
      dto.leaveName = entry.Canonical_Leave__r != null
        ? entry.Canonical_Leave__r.Name
        : null;
      results.add(dto);
    }

    return results;
  }

  // ── DTO ──

  public class LedgerEntryDTO {
    @AuraEnabled public Id entryId;
    @AuraEnabled public String transactionType;
    @AuraEnabled public Decimal days;
    @AuraEnabled public Decimal balanceAfter;
    @AuraEnabled public Date transactionDate;
    @AuraEnabled public String notes;
    @AuraEnabled public String createdByName;
    @AuraEnabled public String leaveName;
  }
}