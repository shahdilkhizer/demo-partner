import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import saveExpenseClaim from "@salesforce/apex/PWChrono_ExpenseController.saveExpenseClaim";
import submitExpenseClaim from "@salesforce/apex/PWChrono_ExpenseController.submitExpenseClaim";
import getExpenseClaimDetail from "@salesforce/apex/PWChrono_ExpenseController.getExpenseClaimDetail";

const TODAY = new Date().toISOString().split("T")[0];

export default class PwchronoExpenseClaimForm extends LightningElement {
  static renderMode = "light";

  _claimId = null;
  _internalClaimId = null;

  @api
  get claimId() {
    return this._claimId;
  }

  set claimId(value) {
    this._claimId = value || null;
    this._internalClaimId = null;
  }

  @track isLoading = false;
  @track isSaving = false;
  @track formErrors = [];

  // Header fields
  @track claimDate = TODAY;
  @track description = "";
  @track businessPurpose = "";

  // Line items (managed by child editor)
  @track items = [];

  // Loaded claim data (edit mode)
  @track existingClaim = null;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  connectedCallback() {
    if (this.effectiveClaimId) {
      this.loadExistingClaim();
    } else {
      // New claim: start with one empty item
      this.items = this.createEmptyItems();
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  loadExistingClaim() {
    this.isLoading = true;
    getExpenseClaimDetail({
      claimId: this.effectiveClaimId,
      employeeId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((claim) => {
        this.existingClaim = claim;
        this.claimDate = claim.Claim_Date__c || TODAY;
        this.description = claim.Description__c || "";
        this.businessPurpose = claim.Business_Purpose__c || "";

        // Map sub-queried items to editor DTO format
        const rawItems = claim.Expense_Items__r || [];
        this.items = rawItems.map((item) => ({
          itemId: item.Id,
          expenseDate: item.Date__c,
          itemType: item.Type__c,
          description: item.Description__c || "",
          merchant: item.Merchant__c || "",
          amount: item.Amount__c,
          receiptReference: item.Receipt_Reference__c || ""
        }));

        if (this.items.length === 0) {
          this.items = this.createEmptyItems();
        }
      })
      .catch((err) => {
        this.showToast(
          "Error",
          err?.body?.message || err?.message || "Failed to load claim.",
          "error"
        );
        this.handleCancel();
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.effectiveClaimId ? "Edit Expense Claim" : "New Expense Claim";
  }

  get hasErrors() {
    return this.formErrors && this.formErrors.length > 0;
  }

  get canSubmitDirectly() {
    // Show "Save & Submit" only on new claim or first save hasn't happened
    return true;
  }

  get isSavedClaim() {
    return !!this.effectiveClaimId;
  }

  get effectiveClaimId() {
    return this._internalClaimId || this.claimId;
  }

  // ── Field handlers ────────────────────────────────────────────────────────

  handleClaimDateChange(event) {
    this.claimDate = event.target.value;
  }

  handleDescriptionChange(event) {
    this.description = event.target.value;
  }

  handleBusinessPurposeChange(event) {
    this.businessPurpose = event.target.value;
  }

  handleItemsChange(event) {
    this.items = event.detail.items;
  }

  // ── Save Draft ────────────────────────────────────────────────────────────

  handleSaveDraft() {
    const errors = this.validateForm();
    if (errors.length) {
      this.formErrors = errors;
      return;
    }
    this.formErrors = [];
    this.isSaving = true;

    saveExpenseClaim({
      dto: this.buildDTO(),
      employeeId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((saved) => {
        this._internalClaimId = saved.Id;
        this.showToast("Saved", "Expense claim saved as Draft.", "success");
        this.dispatchEvent(
          new CustomEvent("claimsubmitted", {
            detail: { claimId: saved.Id, action: "saved" },
            bubbles: true,
            composed: true
          })
        );
      })
      .catch((err) => {
        this.showToast(
          "Error",
          err?.body?.message || err?.message || "Failed to save claim.",
          "error"
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  // ── Save & Submit ─────────────────────────────────────────────────────────

  handleSaveAndSubmit() {
    const errors = this.validateForm();
    if (errors.length) {
      this.formErrors = errors;
      return;
    }
    this.formErrors = [];
    this.isSaving = true;

    saveExpenseClaim({
      dto: this.buildDTO(),
      employeeId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((saved) => {
        this._internalClaimId = saved.Id;
        return submitExpenseClaim({
          claimId: saved.Id,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        });
      })
      .then((submitted) => {
        this.showToast(
          "Submitted",
          "Expense claim submitted for approval.",
          "success"
        );
        this.dispatchEvent(
          new CustomEvent("claimsubmitted", {
            detail: { claimId: submitted.Id, action: "submitted" },
            bubbles: true,
            composed: true
          })
        );
      })
      .catch((err) => {
        this.showToast(
          "Error",
          err?.body?.message || err?.message || "Failed to submit claim.",
          "error"
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  handleCancel() {
    this.dispatchEvent(
      new CustomEvent("cancel", { bubbles: true, composed: true })
    );
  }

  // ── Validation ────────────────────────────────────────────────────────────

  validateForm() {
    const errors = [];

    if (!this.claimDate) {
      errors.push("Claim date is required.");
    }
    if (!this.description || this.description.trim().length < 3) {
      errors.push("Description is required (minimum 3 characters).");
    }
    if (!this.items || this.items.length === 0) {
      errors.push("At least one expense item is required.");
    } else {
      this.items.forEach((item, idx) => {
        const line = `Item ${idx + 1}: `;
        if (!item.expenseDate) {
          errors.push(line + "Date is required.");
        }
        if (!item.itemType) {
          errors.push(line + "Type is required.");
        }
        const amt = Number.parseFloat(item.amount);
        if (!item.amount || isNaN(amt) || amt <= 0) {
          errors.push(line + "Amount must be greater than zero.");
        }
      });
    }

    return errors;
  }

  // ── Build DTO ─────────────────────────────────────────────────────────────

  buildDTO() {
    return {
      claimId: this.effectiveClaimId || null,
      claimDate: this.claimDate,
      description: this.description.trim(),
      businessPurpose: this.businessPurpose
        ? this.businessPurpose.trim()
        : null,
      items: (this.items || []).map((item) => ({
        itemId: item.itemId || null,
        expenseDate: item.expenseDate,
        itemType: item.itemType,
        description: item.description || "",
        merchant: item.merchant || "",
        amount: Number.parseFloat(item.amount) || 0,
        receiptReference: item.receiptReference || ""
      }))
    };
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  createEmptyItems() {
    return [
      {
        itemId: null,
        expenseDate: TODAY,
        itemType: "Other",
        description: "",
        merchant: "",
        amount: null,
        receiptReference: ""
      }
    ];
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}