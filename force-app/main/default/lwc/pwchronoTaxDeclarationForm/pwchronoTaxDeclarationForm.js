import { refreshApex } from "@salesforce/apex";
import getMyTaxDeclarations from "@salesforce/apex/PWChrono_TaxController.getMyTaxDeclarations";
import saveTaxDeclaration from "@salesforce/apex/PWChrono_TaxController.saveTaxDeclaration";
import submitTaxDeclaration from "@salesforce/apex/PWChrono_TaxController.submitTaxDeclaration";
import { CONSTANTS } from "c/pwchronoConstants";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

const COLUMNS = [
  { label: "Fiscal Year", fieldName: "Fiscal_Year__c", sortable: true },
  { label: "Status", fieldName: "Status__c", sortable: true },
  {
    label: "Total Declared",
    fieldName: "Total_Declared_Amount__c",
    type: "currency",
    sortable: true,
    typeAttributes: { currencyCode: CONSTANTS.CURRENCY_CODE }
  },
  {
    label: "Created Date",
    fieldName: "CreatedDate",
    type: "date",
    sortable: true
  },
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
      label: "View",
      name: "view",
      title: "View",
      variant: "base"
    }
  }
];

export default class PwchronoTaxDeclarationForm extends LightningElement {
  static renderMode = "light";
  currencyCode = CONSTANTS.CURRENCY_CODE;
  @track allDeclarations = [];
  @track declarations = [];
  // Store only a plain string here (not a wire error object / Proxy)
  // to avoid recursion issues in Experience Live Preview.
  @track error = "";
  @track isLoading = true;
  columns = COLUMNS;
  wiredDeclarationsResult;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  normalizeWireError(err) {
    try {
      if (!err) return "Unknown error";
      // LDS/Apex wire errors frequently have shape: { body: { message } } or { body: [{ message }, ...] }
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
  @track currentRecord = {};
  @track isReadOnly = false;

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  // Filters
  @track yearFilter = "";
  @track statusFilter = "";

  statusOptions = [
    { label: "All Statuses", value: "" },
    { label: "Draft", value: "Draft" },
    { label: "Submitted", value: "Submitted" },
    { label: "Approved", value: "Approved" },
    { label: "Rejected", value: "Rejected" }
  ];

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" }
  ];

  get fiscalYearOptions() {
    const currentYear = new Date().getFullYear();
    return [
      {
        label: `${currentYear}-${currentYear + 1}`,
        value: `${currentYear}-${currentYear + 1}`
      },
      {
        label: `${currentYear - 1}-${currentYear}`,
        value: `${currentYear - 1}-${currentYear}`
      }
    ];
  }

  get modalTitle() {
    if (this.currentRecord.Id) {
      return this.isReadOnly ? "View Declaration" : "Edit Declaration";
    }
    return "New Declaration";
  }

  get totalDeclared() {
    const c = this.currentRecord;
    return (
      (Number.parseFloat(c.Section_80C__c) || 0) +
      (Number.parseFloat(c.HRA__c) || 0) +
      (Number.parseFloat(c.Medical_Insurance__c) || 0) +
      (Number.parseFloat(c.NPS__c) || 0)
    );
  }

  @wire(getMyTaxDeclarations, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredDeclarations(result) {
    this.wiredDeclarationsResult = result;
    this.isLoading = true;
    if (result.data) {
      this.allDeclarations = result.data.map((row) => ({
        ...row,
        isLocked: row.Status__c !== "Draft" && row.Status__c !== "Rejected"
      }));
      this.error = "";
      this.applyFilters();
    } else if (result.error) {
      this.error = this.normalizeWireError(result.error);
      this.allDeclarations = [];
      this.declarations = [];
    }
    this.isLoading = false;
  }

  // Filter and Pagination Methods
  applyFilters() {
    let filtered = [...this.allDeclarations];

    if (this.yearFilter) {
      filtered = filtered.filter((item) =>
        item.Fiscal_Year__c?.includes(this.yearFilter)
      );
    }

    if (this.statusFilter) {
      filtered = filtered.filter(
        (item) => item.Status__c === this.statusFilter
      );
    }

    this._filteredDeclarations = filtered;

    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.declarations = filtered.slice(start, end);
  }

  handleYearFilter(event) {
    this.yearFilter = event.target.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handleStatusFilter(event) {
    this.statusFilter = event.detail.value;
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

  get totalRecords() {
    return this._filteredDeclarations ? this._filteredDeclarations.length : 0;
  }

  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize) || 1;
  }

  get paginationInfo() {
    if (this.totalRecords === 0) return "0 records";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
    return `${start}-${end} of ${this.totalRecords}`;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get hasDeclarations() {
    return this.declarations && this.declarations.length > 0;
  }

  get hasNoDeclarations() {
    return (
      !this.isLoading && (!this.declarations || this.declarations.length === 0)
    );
  }

  handleNew() {
    this.currentRecord = {
      Fiscal_Year__c: this.fiscalYearOptions[0].value,
      Status__c: "Draft",
      Section_80C__c: 0,
      HRA__c: 0,
      Medical_Insurance__c: 0,
      NPS__c: 0
    };
    this.isReadOnly = false;
    this.isModalOpen = true;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === "edit") {
      this.currentRecord = { ...row };
      this.isReadOnly = false;
      this.isModalOpen = true;
    } else if (actionName === "view") {
      this.currentRecord = { ...row };
      this.isReadOnly = true;
      this.isModalOpen = true;
    }
  }

  handleFieldChange(event) {
    const field = event.target.name;
    this.currentRecord[field] = event.target.value;
  }

  handleSave() {
    saveTaxDeclaration({
      declaration: this.currentRecord,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Declaration saved successfully",
            variant: "success"
          })
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredDeclarationsResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error saving declaration",
            message: error.body.message,
            variant: "error"
          })
        );
      });
  }

  handleSubmit() {
    submitTaxDeclaration({
      declarationId: this.currentRecord.Id,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Declaration submitted successfully",
            variant: "success"
          })
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredDeclarationsResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error submitting declaration",
            message: error.body.message,
            variant: "error"
          })
        );
      });
  }

  closeModal() {
    this.isModalOpen = false;
  }
}