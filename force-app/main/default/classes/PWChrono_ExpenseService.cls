/**
 * @description Core business logic for the Expense Claims module.
 *              Orchestrates validation, DML, system comments, and notifications.
 *              Called exclusively by PWChrono_ExpenseController.
 *              Reuses the shared request framework (RequestService,
 *              RequestValidator, RequestCommentService, RequestAttachmentService).
 *
 *              Legacy bridge methods (saveClaim/sObject, submitClaim, deleteClaim)
 *              preserve the existing PWChrono_ExpenseController wiring.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_ExpenseService {

  private static final String OBJECT_API_NAME = 'PWChrono_Expense_Claim__c';
  private static final String MODULE_LABEL    = 'Expense';

  // ─────────────────────── Save Draft ──────────────────────────────────────

  /**
   * @description Creates or updates a claim in Draft status.
   *              Validates the DTO, upserts the header, replaces child items.
   *              Total_Amount__c is a Roll-Up Summary auto-updated by Salesforce.
   * @param dto        Claim data + line items from the LWC form.
   * @param employeeId Portal_Users__c Id of the owner employee.
   * @return The freshly-queried claim with sub-queried items.
   */
  public static PWChrono_Expense_Claim__c saveClaim(
    PWChrono_ExpenseValidator.ExpenseClaimDTO dto, Id employeeId
  ) {
    List<String> errors = PWChrono_ExpenseValidator.validate(dto, employeeId);
    if (!errors.isEmpty()) { throw new AuraHandledException(String.join(errors, '\n')); }

    PWChrono_Expense_Claim__c claim = resolveClaimForEdit(dto.claimId, employeeId);

    claim.Claim_Date__c       = dto.claimDate;
    claim.Description__c      = dto.description;
    claim.Business_Purpose__c = dto.businessPurpose;
    claim.Employees__c        = employeeId;
    claim.Status__c           = PWChrono_Constants.STATUS_DRAFT;

    upsert claim;

    // Replace line items atomically
    replaceItems(claim.Id, dto.items);

    // Total_Amount__c is a Roll-Up Summary — auto-computed by Salesforce after items insert.
    return PWChrono_ExpenseSelector.getClaimById(claim.Id);
  }

  // ─────────────────────── Submit ──────────────────────────────────────────

  /**
   * @description Submits a Draft or Rejected claim for manager approval.
   *              Validates the full claim, resolves approver, transitions status,
   *              sends notification, and posts a system comment.
   * @param claimId    Id of the claim to submit.
   * @param employeeId Portal_Users__c Id of the requesting employee.
   * @return The updated claim record.
   */
  public static PWChrono_Expense_Claim__c submitClaim(Id claimId, Id employeeId) {
    PWChrono_Expense_Claim__c claim = requireClaim(claimId);
    requireOwnership(claim, employeeId);

    if (claim.Status__c != PWChrono_Constants.STATUS_DRAFT &&
        claim.Status__c != PWChrono_Constants.STATUS_REJECTED) {
      throw new AuraHandledException(
        'Only Draft or Rejected claims can be submitted. Current status: ' + claim.Status__c
      );
    }

    // Re-validate items exist before submitting
    List<PWChrono_Expense_Item__c> items = PWChrono_ExpenseSelector.getItemsByClaimId(claimId);
    if (items.isEmpty()) {
      throw new AuraHandledException('Cannot submit a claim with no expense items.');
    }

    claim.Status__c     = PWChrono_Constants.STATUS_SUBMITTED;
    claim.Applied_Date__c = Date.today();

    // Auto-assign approver
    Id approverId = PWChrono_RequestService.resolveApprover(employeeId);
    if (approverId != null) { claim.Approvers__c = approverId; }

    update claim;

    if (claim.Approvers__c != null) {
      String empName = PWChrono_RequestService.getEmployeeName(employeeId);
      PWChrono_RequestService.sendNotification(
        claim.Approvers__c, MODULE_LABEL, claim.Name, 'Submitted', empName, claim.Id
      );
    }

    PWChrono_RequestCommentService.addSystemComment(
      claim.Id, OBJECT_API_NAME,
      'Expense claim submitted for approval with ' + items.size() +
        ' item(s) totalling ' + claim.Total_Amount__c + '.',
      employeeId
    );

    return PWChrono_ExpenseSelector.getClaimById(claim.Id);
  }

  // ─────────────────────── Approve / Reject ────────────────────────────────

  /**
   * @description Processes an approval action for a Submitted claim.
   *              Only the assigned approver or an admin may act.
   *              Self-approval is blocked.
   * @param claimId    Expense claim Id.
   * @param action     'Approve' or 'Reject'.
   * @param comments   Required for Reject; optional for Approve.
   * @param approverId Acting Portal_Users__c Id.
   * @return Updated claim record.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static PWChrono_Expense_Claim__c processApproval(
    Id claimId, String action, String comments, Id approverId
  ) {
    PWChrono_Expense_Claim__c claim = requireClaim(claimId);

    if (claim.Approvers__c != approverId &&
        !PWChrono_RequestValidator.isCurrentUserAdmin(approverId)) {
      throw new AuraHandledException('Access denied: Not authorized to process this claim.');
    }
    if (claim.Status__c != PWChrono_Constants.STATUS_SUBMITTED) {
      throw new AuraHandledException(
        'Only Submitted claims can be approved or rejected. Current status: ' + claim.Status__c
      );
    }
    if (claim.Employees__c == approverId) {
      throw new AuraHandledException('Self-approval is not allowed.');
    }

    String approverName = PWChrono_RequestService.getEmployeeName(approverId);
    String normalizedAction = normalizeAction(action);

    if (normalizedAction == 'Approve') {
      claim.Status__c            = PWChrono_Constants.STATUS_APPROVED;
      claim.Approval_Date__c     = Date.today();
      claim.Approver_Comments__c = String.isNotBlank(comments) ? comments.trim() : null;
      update claim;

      PWChrono_RequestService.sendNotification(
        claim.Employees__c, MODULE_LABEL, claim.Name, 'Approved', approverName, claim.Id
      );
      String commentText = String.isNotBlank(comments)
        ? 'Expense claim approved. ' + comments.trim()
        : 'Expense claim approved.';
      PWChrono_RequestCommentService.addSystemComment(
        claim.Id, OBJECT_API_NAME, commentText, approverId
      );

    } else if (normalizedAction == 'Reject') {
      if (String.isBlank(comments)) {
        throw new AuraHandledException('Rejection reason is required.');
      }
      claim.Status__c            = PWChrono_Constants.STATUS_REJECTED;
      claim.Rejection_Reason__c  = comments.trim();
      claim.Approver_Comments__c = comments.trim();
      claim.Approval_Date__c     = Date.today();
      update claim;

      PWChrono_RequestService.sendNotification(
        claim.Employees__c, MODULE_LABEL, claim.Name, 'Rejected', approverName, claim.Id
      );
      PWChrono_RequestCommentService.addSystemComment(
        claim.Id, OBJECT_API_NAME,
        'Expense claim rejected. ' + comments.trim(), approverId
      );

    } else {
      throw new AuraHandledException('Invalid action. Must be Approve or Reject.');
    }

    return PWChrono_ExpenseSelector.getClaimById(claim.Id);
  }

  // ─────────────────────── Cancel ──────────────────────────────────────────

  /**
   * @description Cancels a claim. Only the owner or an admin may cancel.
   *              Draft, Submitted, or Approved claims may be cancelled.
   * @param claimId    Expense claim Id.
   * @param reason     Optional cancellation reason.
   * @param employeeId Requesting Portal_Users__c Id.
   * @return Updated claim record.
   */
  public static PWChrono_Expense_Claim__c cancelClaim(
    Id claimId, String reason, Id employeeId
  ) {
    PWChrono_Expense_Claim__c claim = requireClaim(claimId);

    if (claim.Employees__c != employeeId &&
        !PWChrono_RequestValidator.isCurrentUserAdmin(employeeId)) {
      throw new AuraHandledException('Unauthorized: You can only cancel your own claims.');
    }

    String transitionError =
      PWChrono_RequestValidator.validateStatusTransition(claim.Status__c, 'Cancelled');
    if (transitionError != null) { throw new AuraHandledException(transitionError); }

    claim.Status__c         = 'Cancelled';
    claim.Cancelled_Date__c = Date.today();
    claim.Cancelled_Reason__c = reason;
    update claim;

    if (claim.Approvers__c != null) {
      String empName = PWChrono_RequestService.getEmployeeName(employeeId);
      PWChrono_RequestService.sendNotification(
        claim.Approvers__c, MODULE_LABEL, claim.Name, 'Cancelled', empName, claim.Id
      );
    }

    PWChrono_RequestCommentService.addSystemComment(
      claim.Id, OBJECT_API_NAME,
      String.isNotBlank(reason)
        ? 'Expense claim cancelled. ' + reason.trim()
        : 'Expense claim cancelled.',
      employeeId
    );

    return PWChrono_ExpenseSelector.getClaimById(claim.Id);
  }

  // ─────────────────────── Dashboard summary ───────────────────────────────

  /**
   * @description Builds the expense dashboard summary for an employee.
   *              Returns request counts by status for the given date range
   *              plus the 5 most recent claims.
   * @param employeeId Portal_Users__c Id.
   * @param startDate  First day of the target month.
   * @param endDate    Last day of the target month.
   * @return ExpenseDashboardDTO.
   */
  public static ExpenseDashboardDTO getDashboardSummary(
    Id employeeId, Date startDate, Date endDate
  ) {
    ExpenseDashboardDTO dto = new ExpenseDashboardDTO();
    dto.summaryMonth = startDate;

    Map<String, Integer> counts =
      PWChrono_ExpenseSelector.getMonthlyClaimCounts(employeeId, startDate, endDate);
    dto.draftCount     = counts.containsKey('Draft')     ? counts.get('Draft')     : 0;
    dto.submittedCount = counts.containsKey('Submitted') ? counts.get('Submitted') : 0;
    dto.approvedCount  = counts.containsKey('Approved')  ? counts.get('Approved')  : 0;
    dto.rejectedCount  = counts.containsKey('Rejected')  ? counts.get('Rejected')  : 0;
    dto.cancelledCount = counts.containsKey('Cancelled') ? counts.get('Cancelled') : 0;
    dto.totalClaims    = dto.draftCount + dto.submittedCount + dto.approvedCount +
                         dto.rejectedCount + dto.cancelledCount;

    dto.recentClaims = PWChrono_ExpenseSelector.getRecentClaimsByEmployee(employeeId);
    return dto;
  }

  // ─────────────────────── DTO ─────────────────────────────────────────────

  /** Dashboard summary wrapper returned to the LWC. */
  public class ExpenseDashboardDTO {
    @AuraEnabled public Date    summaryMonth;
    @AuraEnabled public Integer draftCount     = 0;
    @AuraEnabled public Integer submittedCount = 0;
    @AuraEnabled public Integer approvedCount  = 0;
    @AuraEnabled public Integer rejectedCount  = 0;
    @AuraEnabled public Integer cancelledCount = 0;
    @AuraEnabled public Integer totalClaims    = 0;
    @AuraEnabled public List<PWChrono_Expense_Claim__c> recentClaims;
  }

  // ─────────────────────── Legacy bridge methods ───────────────────────────
  // These keep the existing PWChrono_ExpenseController wiring operational
  // while the new DTO-based path is used by all new LWC components.

  /**
   * @description Legacy save: accepts raw SObject + items.
   *              Called by old pwchronoExpenseClaimPortal via controller.
   */
  public static PWChrono_Expense_Claim__c saveClaim(
    PWChrono_Expense_Claim__c claim, List<PWChrono_Expense_Item__c> items
  ) {
    // Enforce Draft status on save
    if (String.isBlank(claim.Status__c)) {
      claim.Status__c = 'Draft';
    }
    upsert claim;

    if (items != null && !items.isEmpty()) {
      // Delete existing items for this claim then re-insert
      List<PWChrono_Expense_Item__c> existing =
        PWChrono_ExpenseSelector.getItemsByClaimId(claim.Id);
      if (!existing.isEmpty()) {
        delete existing;
      }
      for (PWChrono_Expense_Item__c item : items) {
        item.Expense_Claim__c = claim.Id;
        item.Id = null; // ensure insert, not upsert by Id
      }
      insert items;

      // Total_Amount__c is a Roll-Up Summary — auto-computed after items insert.
    }

    return PWChrono_ExpenseSelector.getClaimById(claim.Id);
  }

  /**
   * @description Legacy delete: removes claim + items (cascade via master-detail).
   *              Only the owner or an admin may delete; only Draft/Rejected claims.
   */
  public static void deleteClaim(Id claimId, Id employeeId) {
    PWChrono_Expense_Claim__c claim = requireClaim(claimId);
    requireOwnership(claim, employeeId);

    if (claim.Status__c != PWChrono_Constants.STATUS_DRAFT &&
        claim.Status__c != PWChrono_Constants.STATUS_REJECTED) {
      throw new AuraHandledException(
        'Only Draft or Rejected claims can be deleted. Current status: ' + claim.Status__c
      );
    }
    delete claim;
  }

  // ─────────────────────── Private helpers ─────────────────────────────────

  private static PWChrono_Expense_Claim__c requireClaim(Id claimId) {
    PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(claimId);
    if (claim == null) { throw new AuraHandledException('Expense claim not found.'); }
    return claim;
  }

  private static void requireOwnership(PWChrono_Expense_Claim__c claim, Id employeeId) {
    if (claim.Employees__c != employeeId &&
        !PWChrono_RequestValidator.isCurrentUserAdmin(employeeId)) {
      throw new AuraHandledException('Unauthorized access to this expense claim.');
    }
  }

  /**
   * @description On new: returns a blank record.
   *              On edit: fetches existing, verifies ownership and editability.
   */
  private static PWChrono_Expense_Claim__c resolveClaimForEdit(Id claimId, Id employeeId) {
    if (claimId == null) {
      return new PWChrono_Expense_Claim__c();
    }

    PWChrono_Expense_Claim__c existing = requireClaim(claimId);
    requireOwnership(existing, employeeId);

    if (existing.Status__c != PWChrono_Constants.STATUS_DRAFT &&
        existing.Status__c != PWChrono_Constants.STATUS_REJECTED) {
      throw new AuraHandledException(
        'Only Draft or Rejected claims can be edited. Current status: ' + existing.Status__c
      );
    }
    return existing;
  }

  /**
   * @description Deletes current items for a claim and inserts new ones from the DTO.
   */
  private static void replaceItems(
    Id claimId, List<PWChrono_ExpenseValidator.ExpenseItemDTO> dtoItems
  ) {
    List<PWChrono_Expense_Item__c> existing =
      PWChrono_ExpenseSelector.getItemsByClaimId(claimId);
    if (!existing.isEmpty()) {
      delete existing;
    }

    if (dtoItems == null || dtoItems.isEmpty()) { return; }

    List<PWChrono_Expense_Item__c> toInsert = new List<PWChrono_Expense_Item__c>();
    for (PWChrono_ExpenseValidator.ExpenseItemDTO di : dtoItems) {
      toInsert.add(new PWChrono_Expense_Item__c(
        Expense_Claim__c      = claimId,
        Date__c               = di.expenseDate,
        Type__c               = di.itemType,
        Description__c        = di.description,
        Merchant__c           = di.merchant,
        Amount__c             = di.amount,
        Receipt_Reference__c  = di.receiptReference
      ));
    }
    insert toInsert;
  }

  private static String normalizeAction(String action) {
    if (String.isBlank(action)) { return action; }
    if (action == 'Approved') { return 'Approve'; }
    if (action == 'Rejected') { return 'Reject'; }
    return action;
  }
}