/**
 * @description All SOQL for the Expense Claims module.
 *              No DML in this class. All queries use bind variables.
 *              Called by PWChrono_ExpenseService and
 *              PWChrono_ExpenseController only.
 */
public inherited sharing class PWChrono_ExpenseSelector {
  // ── Field sets (DRY — avoid repeating field lists) ───────────────────────

  private static final String CLAIM_FIELDS =
    'Id, Name, Employees__c, Employees__r.Name, ' +
    'Approvers__c, Approvers__r.Name, ' +
    'Claim_Date__c, Description__c, Business_Purpose__c, Total_Amount__c, ' +
    'Status__c, Applied_Date__c, Approval_Date__c, ' +
    'Approver_Comments__c, Rejection_Reason__c, ' +
    'Cancelled_Date__c, Cancelled_Reason__c, CreatedDate ';

  private static final String ITEM_FIELDS =
    'Id, Date__c, Type__c, Description__c, Merchant__c, ' +
    'Amount__c, Receipt_Reference__c, Expense_Claim__c, CreatedDate ';

  // ── By Id ─────────────────────────────────────────────────────────────────

  /**
   * @description Full claim detail including sub-queried line items.
   */
  public static PWChrono_Expense_Claim__c getClaimById(Id claimId) {
    if (claimId == null) {
      return null;
    }
    List<PWChrono_Expense_Claim__c> claims = [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Approvers__c,
        Approvers__r.Name,
        Claim_Date__c,
        Description__c,
        Business_Purpose__c,
        Total_Amount__c,
        Status__c,
        Applied_Date__c,
        Approval_Date__c,
        Approver_Comments__c,
        Rejection_Reason__c,
        Cancelled_Date__c,
        Cancelled_Reason__c,
        CreatedDate,
        (
          SELECT
            Id,
            Date__c,
            Type__c,
            Description__c,
            Merchant__c,
            Amount__c,
            Receipt_Reference__c
          FROM PWChrono_Expense_Items__r
          ORDER BY Date__c ASC
        )
      FROM PWChrono_Expense_Claim__c
      WHERE Id = :claimId
      LIMIT 1
    ];
    return claims.isEmpty() ? null : claims[0];
  }

  // ── Employee queries ──────────────────────────────────────────────────────

  /**
   * @description Filtered, ordered list of claims for an employee.
   *              statusFilter = null/'' returns all statuses.
   *              Date filters are optional (null = no date filter).
   */
  @SuppressWarnings('PMD.ApexSOQLInjection')
  public static List<PWChrono_Expense_Claim__c> getClaimsByEmployee(
    Id employeeId,
    String statusFilter,
    Date startDate,
    Date endDate
  ) {
    String q =
      'SELECT ' +
      CLAIM_FIELDS +
      'FROM PWChrono_Expense_Claim__c ' +
      'WHERE Employees__c = :employeeId ';

    if (String.isNotBlank(statusFilter)) {
      q += 'AND Status__c = :statusFilter ';
    }
    if (startDate != null) {
      q += 'AND Claim_Date__c >= :startDate ';
    }
    if (endDate != null) {
      q += 'AND Claim_Date__c <= :endDate ';
    }
    q +=
      'ORDER BY Claim_Date__c DESC, CreatedDate DESC ' +
      'LIMIT ' +
      PWChrono_Constants.DEFAULT_QUERY_LIMIT;

    return Database.query(q);
  }

  /**
   * @description 5 most recent claims for dashboard recent-claims strip.
   */
  public static List<PWChrono_Expense_Claim__c> getRecentClaimsByEmployee(
    Id employeeId
  ) {
    return [
      SELECT
        Id,
        Name,
        Claim_Date__c,
        Description__c,
        Total_Amount__c,
        Status__c,
        Applied_Date__c
      FROM PWChrono_Expense_Claim__c
      WHERE Employees__c = :employeeId
      ORDER BY CreatedDate DESC
      LIMIT 5
    ];
  }

  // ── Manager / team queries ────────────────────────────────────────────────

  /**
   * @description Submitted claims assigned to this manager — the approval queue.
   */
  public static List<PWChrono_Expense_Claim__c> getTeamClaimsForApproval(
    Id managerId
  ) {
    return [
      SELECT
        Id,
        Name,
        Employees__c,
        Employees__r.Name,
        Approvers__c,
        Claim_Date__c,
        Description__c,
        Total_Amount__c,
        Status__c,
        Applied_Date__c
      FROM PWChrono_Expense_Claim__c
      WHERE
        Approvers__c = :managerId
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
      ORDER BY Applied_Date__c ASC
      LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
    ];
  }

  /**
   * @description All team claims with optional status filter.
   */
  @SuppressWarnings('PMD.ApexSOQLInjection')
  public static List<PWChrono_Expense_Claim__c> getTeamClaims(
    Id managerId,
    String statusFilter
  ) {
    // Resolve team members
    List<Portal_Users__c> team = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Reports_To__c = :managerId
    ];
    if (team.isEmpty()) {
      return new List<PWChrono_Expense_Claim__c>();
    }
    Set<Id> teamIds = new Set<Id>();
    for (Portal_Users__c pu : team) {
      teamIds.add(pu.Id);
    }

    String q =
      'SELECT ' +
      CLAIM_FIELDS +
      'FROM PWChrono_Expense_Claim__c ' +
      'WHERE Employees__c IN :teamIds ';

    if (String.isNotBlank(statusFilter)) {
      q += 'AND Status__c = :statusFilter ';
    }
    q +=
      'ORDER BY Applied_Date__c DESC, CreatedDate DESC ' +
      'LIMIT ' +
      PWChrono_Constants.DEFAULT_QUERY_LIMIT;

    return Database.query(q);
  }

  // ── Item queries ──────────────────────────────────────────────────────────

  /**
   * @description All line items for a given claim, ordered by date.
   */
  public static List<PWChrono_Expense_Item__c> getItemsByClaimId(Id claimId) {
    if (claimId == null) {
      return new List<PWChrono_Expense_Item__c>();
    }
    return [
      SELECT
        Id,
        Date__c,
        Type__c,
        Description__c,
        Merchant__c,
        Amount__c,
        Receipt_Reference__c,
        Expense_Claim__c
      FROM PWChrono_Expense_Item__c
      WHERE Expense_Claim__c = :claimId
      ORDER BY Date__c ASC
    ];
  }

  // ── Dashboard / counts ────────────────────────────────────────────────────

  /**
   * @description Returns a map of Status → count for a given employee and date range.
   *              Used by getDashboardSummary to build metric cards.
   */
  public static Map<String, Integer> getMonthlyClaimCounts(
    Id employeeId,
    Date startDate,
    Date endDate
  ) {
    Map<String, Integer> counts = new Map<String, Integer>();
    for (AggregateResult ar : [
      SELECT Status__c status, COUNT(Id) cnt
      FROM PWChrono_Expense_Claim__c
      WHERE
        Employees__c = :employeeId
        AND Claim_Date__c >= :startDate
        AND Claim_Date__c <= :endDate
      GROUP BY Status__c
    ]) {
      counts.put((String) ar.get('status'), (Integer) ar.get('cnt'));
    }
    return counts;
  }
}