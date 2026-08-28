/**
 * @description Thin controller for Expense Claims LWC components.
 *              All business logic is delegated to PWChrono_ExpenseService,
 *              PWChrono_ExpenseSelector, or the shared request framework.
 *              Every public method follows the pattern:
 *                resolveEmployeeId → Service/Selector → catch/rethrow.
 *
 *              Legacy methods (getMyClaims, getClaimItems, saveClaim, submitClaim,
 *              deleteClaim) are retained for backward compatibility with the
 *              existing pwchronoExpenseClaimPortal component.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_ExpenseController {
  // ═══════════════════════════════════════════════════════════════════════════
  // READ  —  Employee
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Dashboard summary: status counts + 5 recent claims.
   */
  @AuraEnabled(cacheable=false)
  public static PWChrono_ExpenseService.ExpenseDashboardDTO getExpenseDashboardSummary(
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseService.getDashboardSummary(
        empId,
        startDate,
        endDate
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching expense dashboard summary', e);
      throw new AuraHandledException(
        'Error loading expense dashboard. Please try again.'
      );
    }
  }

  /**
   * @description Filtered, paginated expense claim list for the employee.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Expense_Claim__c> getMyExpenseClaimList(
    String statusFilter,
    Date startDate,
    Date endDate,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseSelector.getClaimsByEmployee(
        empId,
        statusFilter,
        startDate,
        endDate
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching expense claim list', e);
      throw new AuraHandledException(
        'Error loading expense claims. Please try again.'
      );
    }
  }

  /**
   * @description Full detail of a single claim including sub-queried line items.
   */
  @AuraEnabled(cacheable=false)
  public static PWChrono_Expense_Claim__c getExpenseClaimDetail(
    Id claimId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(
        claimId
      );
      if (claim == null) {
        throw new AuraHandledException('Expense claim not found.');
      }
      requireAccessibleClaim(claim, empId);
      return claim;
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching expense claim detail', e);
      throw new AuraHandledException(
        'Error loading claim details. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WRITE  —  Employee
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Save a new or edited claim as Draft (with full line items).
   */
  @AuraEnabled
  public static PWChrono_Expense_Claim__c saveExpenseClaim(
    PWChrono_ExpenseValidator.ExpenseClaimDTO dto,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseService.saveClaim(dto, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error saving expense claim', e);
      throw new AuraHandledException(
        'Error saving expense claim. Please try again.'
      );
    }
  }

  /**
   * @description Submit a Draft or Rejected claim for manager approval.
   */
  @AuraEnabled
  public static PWChrono_Expense_Claim__c submitExpenseClaim(
    Id claimId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseService.submitClaim(claimId, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error submitting expense claim', e);
      throw new AuraHandledException(
        'Error submitting claim. Please try again.'
      );
    }
  }

  /**
   * @description Cancel a Draft, Submitted, or Approved claim.
   */
  @AuraEnabled
  public static PWChrono_Expense_Claim__c cancelExpenseClaim(
    Id claimId,
    String cancelReason,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseService.cancelClaim(claimId, cancelReason, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error cancelling expense claim', e);
      throw new AuraHandledException(
        'Error cancelling claim. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // READ / WRITE  —  Manager / Approver
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Submitted claims assigned to the current manager.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Expense_Claim__c> getTeamExpenseClaimsForApproval(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseSelector.getTeamClaimsForApproval(empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'Error fetching team expense claims for approval',
        e
      );
      throw new AuraHandledException(
        'Error loading team claims. Please try again.'
      );
    }
  }

  /**
   * @description All team claims with optional status filter — for history view.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Expense_Claim__c> getTeamExpenseClaims(
    String statusFilter,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseSelector.getTeamClaims(empId, statusFilter);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching team expense claims', e);
      throw new AuraHandledException(
        'Error loading team claims. Please try again.'
      );
    }
  }

  /**
   * @description Approve or reject an expense claim.
   */
  @AuraEnabled
  public static PWChrono_Expense_Claim__c processExpenseClaimApproval(
    Id claimId,
    String action,
    String comments,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseService.processApproval(
        claimId,
        action,
        comments,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error processing expense claim approval', e);
      throw new AuraHandledException(
        'Error processing approval. Please try again.'
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMENTS & FILES  —  Shared framework
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Returns the full comments/history thread for a claim.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_RequestCommentService.RequestCommentDTO> getExpenseComments(
    Id claimId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(
        claimId
      );
      if (claim == null) {
        throw new AuraHandledException('Claim not found.');
      }
      requireAccessibleClaim(claim, empId);
      return PWChrono_RequestCommentService.getComments(
        claimId,
        'PWChrono_Expense_Claim__c'
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching expense comments', e);
      throw new AuraHandledException(
        'Error loading comments. Please try again.'
      );
    }
  }

  /**
   * @description Adds a user comment to the claim's comment thread.
   */
  @AuraEnabled
  public static PWChrono_RequestCommentService.RequestCommentDTO addExpenseComment(
    Id claimId,
    String commentText,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(
        claimId
      );
      if (claim == null) {
        throw new AuraHandledException('Claim not found.');
      }
      requireAccessibleClaim(claim, empId);
      if (String.isBlank(commentText)) {
        throw new AuraHandledException('Comment cannot be empty.');
      }
      return PWChrono_RequestCommentService.addComment(
        claimId,
        'PWChrono_Expense_Claim__c',
        commentText,
        empId
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error adding expense comment', e);
      throw new AuraHandledException('Error adding comment. Please try again.');
    }
  }

  /**
   * @description Returns file descriptors (receipts) attached to the claim.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_RequestAttachmentService.FileDescriptorDTO> getExpenseFiles(
    Id claimId,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(
        claimId
      );
      if (claim == null) {
        throw new AuraHandledException('Claim not found.');
      }
      requireAccessibleClaim(claim, empId);
      return PWChrono_RequestAttachmentService.getFilesForRecord(claimId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching expense files', e);
      throw new AuraHandledException('Error loading files. Please try again.');
    }
  }

  /**
   * @description Uploads a receipt/supporting file for the claim.
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static PWChrono_RequestAttachmentService.FileDescriptorDTO uploadExpenseFile(
    Id claimId,
    String fileName,
    String base64Data,
    String contentType,
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(
        claimId
      );
      if (claim == null) {
        throw new AuraHandledException('Claim not found.');
      }
      requireAccessibleClaim(claim, empId);
      return PWChrono_RequestAttachmentService.uploadFile(
        claimId,
        fileName,
        base64Data,
        contentType
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error uploading expense file', e);
      throw new AuraHandledException('Error uploading file. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY  —  Backward compatibility for pwchronoExpenseClaimPortal
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Legacy list method. New code should use getMyExpenseClaimList.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Expense_Claim__c> getMyClaims(
    String employeeId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        employeeId,
        sessionToken
      );
      return PWChrono_ExpenseSelector.getClaimsByEmployee(
        empId,
        null,
        null,
        null
      );
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching expense claims (legacy)', e);
      throw new AuraHandledException('Error fetching expense claims.');
    }
  }

  /**
   * @description Legacy items method. New code uses getExpenseClaimDetail which
   *              includes items via sub-query.
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Expense_Item__c> getClaimItems(
    Id claimId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );
      PWChrono_Expense_Claim__c claim = PWChrono_ExpenseSelector.getClaimById(
        claimId
      );
      if (claim == null) {
        throw new AuraHandledException('Claim not found.');
      }
      requireAccessibleClaim(claim, empId);
      return PWChrono_ExpenseSelector.getItemsByClaimId(claimId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching claim items (legacy)', e);
      throw new AuraHandledException('Error fetching claim items.');
    }
  }

  /**
   * @description Legacy save: accepts raw SObject claim + items list.
   *              New code should use saveExpenseClaim with DTO.
   */
  @AuraEnabled
  public static PWChrono_Expense_Claim__c saveClaim(
    PWChrono_Expense_Claim__c claim,
    List<PWChrono_Expense_Item__c> items,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );
      claim.Employees__c = empId;
      return PWChrono_ExpenseService.saveClaim(claim, items);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error saving expense claim (legacy)', e);
      throw new AuraHandledException('Error saving expense claim.');
    }
  }

  /**
   * @description Legacy submit. New code should use submitExpenseClaim.
   */
  @AuraEnabled
  public static void submitClaim(
    Id claimId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );
      PWChrono_ExpenseService.submitClaim(claimId, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error submitting expense claim (legacy)', e);
      throw new AuraHandledException('Error submitting expense claim.');
    }
  }

  /**
   * @description Legacy delete. Removes a Draft/Rejected claim.
   */
  @AuraEnabled
  public static void deleteClaim(
    Id claimId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id empId = PWChrono_RequestValidator.resolveEmployeeId(
        portalUserId,
        sessionToken
      );
      PWChrono_ExpenseService.deleteClaim(claimId, empId);
    } catch (AuraHandledException ahe) {
      throw ahe;
    } catch (Exception e) {
      PWChrono_Logger.error('Error deleting expense claim (legacy)', e);
      throw new AuraHandledException('Error deleting expense claim.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /**
   * @description Enforces that the requesting employee may access the record.
   *              Owner, assigned approver, and admins are permitted.
   */
  private static void requireAccessibleClaim(
    PWChrono_Expense_Claim__c claim,
    Id employeeId
  ) {
    Boolean isOwner = claim.Employees__c == employeeId;
    Boolean isApprover = claim.Approvers__c == employeeId;
    Boolean isAdmin = PWChrono_RequestValidator.isCurrentUserAdmin(employeeId);
    if (!isOwner && !isApprover && !isAdmin) {
      throw new AuraHandledException(
        'Access denied: You are not authorized to view this expense claim.'
      );
    }
  }
}