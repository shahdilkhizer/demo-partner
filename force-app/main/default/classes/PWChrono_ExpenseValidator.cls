/**
 * @description DTO and validation layer for the Expense Claims module.
 *              Contains the ExpenseClaimDTO / ExpenseItemDTO inner classes and
 *              all business validation rules for expense claims.
 *              Called by PWChrono_ExpenseService; reuses
 *              PWChrono_RequestValidator for shared rules.
 *              No DML in this class.
 */
public inherited sharing class PWChrono_ExpenseValidator {
  /** Maximum days in the past an employee may claim expenses for. */
  @TestVisible
  private static final Integer BACKDATED_LIMIT_DAYS = 90;

  private static final Set<String> VALID_ITEM_TYPES = new Set<String>{
    'Travel',
    'Food',
    'Lodging',
    'Communication',
    'Training',
    'Entertainment',
    'Other'
  };

  // ─────────────────────────── DTOs ─────────────────────────────────────────

  /**
   * @description Claim header data transferred from LWC → Controller → Service → Validator.
   */
  public class ExpenseClaimDTO {
    @AuraEnabled
    public Id claimId; // null on new, populated on edit
    @AuraEnabled
    public Date claimDate;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String businessPurpose;
    @AuraEnabled
    public List<ExpenseItemDTO> items;
  }

  /**
   * @description Single expense line item within an ExpenseClaimDTO.
   */
  public class ExpenseItemDTO {
    @AuraEnabled
    public Id itemId; // null on new, populated on edit (re-save)
    @AuraEnabled
    public Date expenseDate;
    @AuraEnabled
    public String itemType; // Travel|Food|Lodging|Communication|Training|Entertainment|Other
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String merchant;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String receiptReference;
  }

  // ─────────────────────── Aggregate validate() ────────────────────────────

  /**
   * @description Runs all validation rules for an expense claim submission.
   *              Returns a non-empty list of errors if invalid; empty list = valid.
   * @param dto        Claim data transfer object.
   * @param employeeId Submitting employee's Portal_Users__c Id.
   * @return List<String> of error messages.
   */
  @SuppressWarnings('PMD.CognitiveComplexity')
  public static List<String> validate(ExpenseClaimDTO dto, Id employeeId) {
    List<String> errors = new List<String>();

    // ── Fatal: active employee ──────────────────────────────────────────────
    String activeError = PWChrono_RequestValidator.validateActiveEmployee(
      employeeId
    );
    if (activeError != null) {
      errors.add(activeError);
      return errors;
    }

    if (dto == null) {
      errors.add('Expense claim data is required.');
      return errors;
    }

    // ── Rule 1: claim date required ──────────────────────────────────────────
    if (dto.claimDate == null) {
      errors.add('Claim date is required.');
      return errors;
    }

    // ── Rule 2: not future ───────────────────────────────────────────────────
    String futureError = validateNotFuture(dto.claimDate);
    if (futureError != null) {
      errors.add(futureError);
      return errors;
    }

    // ── Rule 3: backdated limit ──────────────────────────────────────────────
    String backError = PWChrono_RequestValidator.validateBackdatedLimit(
      dto.claimDate,
      BACKDATED_LIMIT_DAYS
    );
    if (backError != null) {
      errors.add(backError);
      return errors;
    }

    // ── Rule 4: description required ────────────────────────────────────────
    if (String.isBlank(dto.description)) {
      errors.add('Claim description is required.');
    }

    // ── Rule 5: at least one line item ───────────────────────────────────────
    if (dto.items == null || dto.items.isEmpty()) {
      errors.add('At least one expense line item is required.');
      return errors;
    }

    // ── Rule 6: validate each item ───────────────────────────────────────────
    Integer idx = 1;
    for (ExpenseItemDTO item : dto.items) {
      String itemPrefix = 'Line ' + idx + ': ';

      if (item.expenseDate == null) {
        errors.add(itemPrefix + 'Date is required.');
      } else {
        // Item date cannot be future
        if (item.expenseDate > Date.today()) {
          errors.add(itemPrefix + 'Expense date cannot be in the future.');
        }
        // Item date cannot be more than 90 days older than claim date
        if (item.expenseDate < dto.claimDate.addDays(-BACKDATED_LIMIT_DAYS)) {
          errors.add(itemPrefix + 'Expense date is too far in the past.');
        }
      }

      if (String.isBlank(item.itemType)) {
        errors.add(itemPrefix + 'Type is required.');
      } else if (!VALID_ITEM_TYPES.contains(item.itemType)) {
        errors.add(itemPrefix + 'Invalid expense type: ' + item.itemType + '.');
      }

      if (item.amount == null || item.amount <= 0) {
        errors.add(itemPrefix + 'Amount must be greater than zero.');
      }

      idx++;
    }

    return errors;
  }

  // ─────────────────────── Individual rules ────────────────────────────────

  /**
   * @description Validates that the claim date is not in the future.
   */
  public static String validateNotFuture(Date claimDate) {
    if (claimDate > Date.today()) {
      return 'Claim date cannot be in the future.';
    }
    return null;
  }

  /**
   * @description Validates that the item type is a recognised value.
   */
  public static String validateItemType(String itemType) {
    if (String.isBlank(itemType)) {
      return 'Expense type is required.';
    }
    if (!VALID_ITEM_TYPES.contains(itemType)) {
      return 'Invalid expense type: ' + itemType + '.';
    }
    return null;
  }

  /**
   * @description Computes the total of all item amounts in a DTO.
   *              Returns 0 if items list is null or empty.
   */
  public static Decimal computeTotal(List<ExpenseItemDTO> items) {
    Decimal total = 0;
    if (items == null) {
      return total;
    }
    for (ExpenseItemDTO item : items) {
      if (item.amount != null && item.amount > 0) {
        total += item.amount;
      }
    }
    return total;
  }
}