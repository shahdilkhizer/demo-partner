import { LightningElement, wire, track } from "lwc";
import getMyClaims from "@salesforce/apex/PWChrono_ExpenseController.getMyClaims";
import getClaimItems from "@salesforce/apex/PWChrono_ExpenseController.getClaimItems";
import saveClaim from "@salesforce/apex/PWChrono_ExpenseController.saveClaim";
import submitClaim from "@salesforce/apex/PWChrono_ExpenseController.submitClaim";
import deleteClaim from "@salesforce/apex/PWChrono_ExpenseController.deleteClaim";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import { refreshApex } from "@salesforce/apex";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { CONSTANTS } from "c/pwchronoConstants";

const COLUMNS = [
  {
    label: "Claim Date",
    fieldName: "Claim_Date__c",
    type: "date",
    sortable: true
  },
  { label: "Description", fieldName: "Description__c" },
  {
    label: "Total Amount",
    fieldName: "Total_Amount__c",
    type: "currency",
    sortable: true,
    typeAttributes: { currencyCode: CONSTANTS.CURRENCY_CODE }
  },
  { label: "Status", fieldName: "Status__c", sortable: true },
  {
    type: "button",
    typeAttributes: {
      label: "Edit",
      name: "edit",
      title: "Edit",
      disabled: { fieldName: "isLocked" },
      variant: "brand-outline"
    }
  },
  {
    type: "button",
    typeAttributes: {
      label: "Delete",
      name: "delete",
      title: "Delete",
      disabled: { fieldName: "isLocked" },
      variant: "destructive-text"
    }
  }
];

export default class PwchronoExpenseClaimPortal extends LightningElement {
  currencyCode = CONSTANTS.CURRENCY_CODE;
  @track allClaims = [];
  @track claims = [];
  // Store only a plain string here (not a wire error object / Proxy)
  // to avoid recursion issues in Experience Live Preview.
  @track error = "";
  @track isLoading = true;
  columns = COLUMNS;
  wiredClaimsResult;

  normalizeWireError(err) {
    try {
      if (!err) return "Unknown error";
      const body = err.body;
      if (Array.isArray(body)) {
        return (
          body
            .map((e) => e?.message)
            .filter(Boolean)
            .join("; ") || "Unknown error"
        );
      }
      return body?.message || err.message || err.statusText || "Unknown error";
    } catch {
      return "Unknown error";
    }
  }

  @track isModalOpen = false;
  @track currentClaim = {};
  @track currentItems = [];
  @track isReadOnly = false;

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  // Filters
  @track statusFilter = "";
  @track searchFilter = "";

  employeeId;
  sessionToken;

  statusOptions = [
    { label: "All Statuses", value: "" },
    { label: "Draft", value: "Draft" },
    { label: "Submitted", value: "Submitted" },
    { label: "Approved", value: "Approved" },
    { label: "Rejected", value: "Rejected" },
    { label: "Paid", value: "Paid" }
  ];

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" },
    { label: "50", value: "50" }
  ];

  connectedCallback() {
    const session = getSession();
    this.employeeId = session.user ? session.user.Id : null;
    this.sessionToken = getSessionToken();
  }

  get typeOptions() {
    return [
      { label: "Travel", value: "Travel" },
      { label: "Food", value: "Food" },
      { label: "Lodging", value: "Lodging" },
      { label: "Other", value: "Other" }
    ];
  }

  get modalTitle() {
    if (this.currentClaim?.Id) {
      return this.isReadOnly ? "View Claim" : "Edit Claim";
    }
    return "New Claim";
  }

  get totalAmount() {
    return this.currentItems.reduce(
      (sum, item) => sum + (Number.parseFloat(item.Amount__c) || 0),
      0
    );
  }

  @wire(getMyClaims, {
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredClaims(result) {
    this.wiredClaimsResult = result;
    this.isLoading = true;
    if (result.data) {
      this.allClaims = result.data.map((row) => ({
        ...row,
        isLocked: row.Status__c !== "Draft" && row.Status__c !== "Rejected"
      }));
      this.error = "";
      this.applyFilters();
    } else if (result.error) {
      this.error = this.normalizeWireError(result.error);
      this.allClaims = [];
      this.claims = [];
    }
    this.isLoading = false;
  }

  // Filter and Pagination Methods
  applyFilters() {
    let filtered = [...this.allClaims];

    if (this.statusFilter) {
      filtered = filtered.filter(
        (item) => item.Status__c === this.statusFilter
      );
    }

    if (this.searchFilter) {
      const search = this.searchFilter.toLowerCase();
      filtered = filtered.filter(
        (item) =>
          item.Description__c &&
          item.Description__c?.toLowerCase().includes(search)
      );
    }

    this._filteredClaims = filtered;

    // Apply pagination
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.claims = filtered.slice(start, end);
  }

  handleStatusFilter(event) {
    this.statusFilter = event.detail.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handleSearchFilter(event) {
    this.searchFilter = event.target.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.applyFilters();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.applyFilters();
    }
  }

  // Pagination Getters
  get totalRecords() {
    return this._filteredClaims ? this._filteredClaims.length : 0;
  }

  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize) || 1;
  }

  get startRecord() {
    return this.totalRecords === 0
      ? 0
      : (this.currentPage - 1) * this.pageSize + 1;
  }

  get endRecord() {
    const end = this.currentPage * this.pageSize;
    return Math.min(end, this.totalRecords);
  }

  get paginationInfo() {
    return `${this.startRecord}-${this.endRecord} of ${this.totalRecords}`;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get hasClaims() {
    return this.claims && this.claims.length > 0;
  }

  get hasNoClaims() {
    return !this.isLoading && (!this.claims || this.claims.length === 0);
  }

  handleNew() {
    this.currentClaim = {
      Claim_Date__c: new Date().toISOString().split("T")[0],
      Status__c: "Draft",
      Description__c: "",
      Employees__c: this.employeeId
    };
    this.currentItems = [this.createEmptyItem()];
    this.isReadOnly = false;
    this.isModalOpen = true;
  }

  createEmptyItem() {
    return {
      key: Date.now() + Math.random(),
      Date__c: new Date().toISOString().split("T")[0],
      Type__c: "Other",
      Description__c: "",
      Amount__c: 0
    };
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === "edit") {
      this.openEdit(row);
    } else if (actionName === "delete") {
      this.deleteRow(row);
    }
  }

  openEdit(row) {
    this.currentClaim = { ...row };
    this.isReadOnly = row.Status__c !== "Draft" && row.Status__c !== "Rejected";
    this.isModalOpen = true;

    getClaimItems({
      claimId: row.Id,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((data) => {
        this.currentItems = data.map((item) => ({
          ...item,
          key: item.Id
        }));
        if (this.currentItems.length === 0 && !this.isReadOnly) {
          this.currentItems.push(this.createEmptyItem());
        }
      })
      .catch((error) => {
        this.showToast(
          "Error loading items",
          error?.body?.message || error?.message || "Unknown error",
          "error"
        );
      });
  }

  async deleteRow(row) {
    const result = await LightningConfirm.open({
      message: "Are you sure you want to delete this claim?",
      variant: "headerless",
      label: "Delete Claim"
    });

    if (result) {
      deleteClaim({
        claimId: row.Id,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      })
        .then(() => {
          this.showToast("Success", "Claim deleted", "success");
          return refreshApex(this.wiredClaimsResult);
        })
        .catch((error) => {
          this.showToast(
            "Error deleting claim",
            error?.body?.message || error?.message || "Unknown error",
            "error"
          );
        });
    }
  }

  handleClaimFieldChange(event) {
    this.currentClaim[event.target.name] = event.target.value;
  }

  handleItemChange(event) {
    const index = event.target.dataset.index;
    const field = event.target.name;
    this.currentItems[index][field] = event.target.value;
  }

  handleAddItem() {
    this.currentItems = [...this.currentItems, this.createEmptyItem()];
  }

  handleDeleteItem(event) {
    const index = event.target.dataset.index;
    this.currentItems = this.currentItems.filter(
      (_, i) => i !== Number.parseInt(index, 10)
    );
  }

  handleSave() {
    // Validate
    if (!this.currentClaim.Claim_Date__c || !this.currentClaim.Description__c) {
      this.showToast("Error", "Please fill required fields", "error");
      return;
    }

    const itemsToSave = this.currentItems.map((item) => {
      const rest = { ...item };
      delete rest.key;
      return { sobjectType: "PWChrono_Expense_Item__c", ...rest };
    });

    const claimToSave = { ...this.currentClaim };
    if (this.employeeId) {
      claimToSave.Employees__c = this.employeeId;
    }

    saveClaim({
      claim: claimToSave,
      items: itemsToSave,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Claim saved successfully", "success");
        this.isModalOpen = false;
        return refreshApex(this.wiredClaimsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error saving claim",
          error?.body?.message || error?.message || "Unknown error",
          "error"
        );
      });
  }

  handleSubmit() {
    submitClaim({
      claimId: this.currentClaim.Id,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Claim submitted successfully", "success");
        this.isModalOpen = false;
        return refreshApex(this.wiredClaimsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error submitting claim",
          error?.body?.message || error?.message || "Unknown error",
          "error"
        );
      });
  }

  closeModal() {
    this.isModalOpen = false;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}