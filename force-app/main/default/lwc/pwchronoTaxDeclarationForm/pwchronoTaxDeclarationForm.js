import { refreshApex } from "@salesforce/apex";
import getMyTaxDeclarations from "@salesforce/apex/PWChrono_TaxController.getMyTaxDeclarations";
import saveTaxDeclaration from "@salesforce/apex/PWChrono_TaxController.saveTaxDeclaration";
import submitTaxDeclaration from "@salesforce/apex/PWChrono_TaxController.submitTaxDeclaration";
import { CONSTANTS } from "c/pwchronoConstants";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoTaxDeclarationForm extends LightningElement {
  static renderMode = "light";
  currencyCode = CONSTANTS.CURRENCY_CODE || "USD";

  @track allDeclarations = [];
  @track declarations = [];
  @track error = "";
  @track isLoading = true;
  wiredDeclarationsResult;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  // Sorting
  @track sortField = "CreatedDate";
  @track sortOrder = "desc";

  // Modal State
  @track isModalOpen = false;
  @track currentRecord = {};
  @track isReadOnly = false;
  @track feedback = null;

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
    { label: "5", value: 5 },
    { label: "10", value: 10 },
    { label: "25", value: 25 },
    { label: "50", value: 50 }
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
    if (this.currentRecord?.Id) {
      return this.isReadOnly ? "View Tax Declaration" : "Edit Tax Declaration";
    }
    return "New Tax Declaration";
  }

  get isEditable() {
    return !this.isReadOnly;
  }

  get totalDeclared() {
    const c = this.currentRecord || {};
    return (
      (Number.parseFloat(c.Section_80C__c) || 0) +
      (Number.parseFloat(c.HRA__c) || 0) +
      (Number.parseFloat(c.Medical_Insurance__c) || 0) +
      (Number.parseFloat(c.NPS__c) || 0)
    );
  }

  get formattedTotalDeclared() {
    return this.formatCurrency(this.totalDeclared);
  }

  get feedbackClass() {
    return this.feedback?.type === "error"
      ? "alert alert-danger d-flex align-items-center justify-content-between mb-3"
      : "alert alert-success d-flex align-items-center justify-content-between mb-3";
  }

  clearFeedback() {
    this.feedback = null;
  }

  handleModalCardClick(event) {
    if (event && event.stopPropagation) {
      event.stopPropagation();
    }
  }

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

  formatCurrency(value) {
    const num = Number.parseFloat(value) || 0;
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: this.currencyCode || "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(num);
  }

  formatDate(dateVal) {
    if (!dateVal) return "-";
    try {
      const d = new Date(dateVal);
      if (isNaN(d.getTime())) return dateVal;
      return d.toLocaleDateString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric"
      });
    } catch {
      return dateVal;
    }
  }

  getStatusBadgeClass(status) {
    switch (status) {
      case "Approved":
        return "badge badge-soft-success";
      case "Submitted":
        return "badge badge-soft-info";
      case "Rejected":
        return "badge badge-soft-danger";
      case "Draft":
      default:
        return "badge badge-soft-warning";
    }
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
        isLocked: row.Status__c !== "Draft" && row.Status__c !== "Rejected",
        formattedTotal: this.formatCurrency(row.Total_Declared_Amount__c),
        formattedDate: this.formatDate(row.CreatedDate),
        statusBadgeClass: this.getStatusBadgeClass(row.Status__c)
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

  // Filtering, Sorting & Pagination
  applyFilters() {
    let filtered = [...this.allDeclarations];

    if (this.yearFilter && this.yearFilter.trim() !== "") {
      const q = this.yearFilter.trim().toLowerCase();
      filtered = filtered.filter((item) =>
        (item.Fiscal_Year__c || "").toLowerCase().includes(q)
      );
    }

    if (this.statusFilter && this.statusFilter !== "") {
      filtered = filtered.filter(
        (item) => item.Status__c === this.statusFilter
      );
    }

    // Sort
    filtered.sort((a, b) => {
      let valA = a[this.sortField] || "";
      let valB = b[this.sortField] || "";

      if (this.sortField === "Total_Declared_Amount__c") {
        valA = Number(valA) || 0;
        valB = Number(valB) || 0;
      }

      if (valA < valB) return this.sortOrder === "asc" ? -1 : 1;
      if (valA > valB) return this.sortOrder === "asc" ? 1 : -1;
      return 0;
    });

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
    this.statusFilter = event.target.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.target.value, 10) || 10;
    this.currentPage = 1;
    this.applyFilters();
  }

  handleSort(event) {
    const field = event.currentTarget.dataset.field;
    if (this.sortField === field) {
      this.sortOrder = this.sortOrder === "asc" ? "desc" : "asc";
    } else {
      this.sortField = field;
      this.sortOrder = "asc";
    }
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
    if (this.totalRecords === 0) return "Showing 0 to 0 of 0 entries";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
    return `Showing ${start} to ${end} of ${this.totalRecords} entries`;
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

  // Row Actions & Modals
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
    this.feedback = null;
  }

  handleEditRow(event) {
    const recordId = event.currentTarget.dataset.id;
    const rec = this.allDeclarations.find((item) => item.Id === recordId);
    if (rec) {
      this.currentRecord = { ...rec };
      this.isReadOnly = false;
      this.isModalOpen = true;
      this.feedback = null;
    }
  }

  handleViewRow(event) {
    const recordId = event.currentTarget.dataset.id;
    const rec = this.allDeclarations.find((item) => item.Id === recordId);
    if (rec) {
      this.currentRecord = { ...rec };
      this.isReadOnly = true;
      this.isModalOpen = true;
      this.feedback = null;
    }
  }

  handleFieldChange(event) {
    const field = event.target.name;
    const val = event.target.value;
    this.currentRecord = {
      ...this.currentRecord,
      [field]: val
    };
  }

  handleSave() {
    saveTaxDeclaration({
      declaration: this.currentRecord,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.feedback = {
          type: "success",
          title: "Success",
          message: "Tax declaration saved as draft."
        };
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Tax declaration saved as draft",
            variant: "success"
          })
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredDeclarationsResult);
      })
      .catch((error) => {
        const errMsg = this.normalizeWireError(error);
        this.feedback = {
          type: "error",
          title: "Error saving declaration",
          message: errMsg
        };
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error saving declaration",
            message: errMsg,
            variant: "error"
          })
        );
      });
  }

  handleSubmit() {
    if (!this.currentRecord.Id) {
      // If saving and submitting at the same time
      saveTaxDeclaration({
        declaration: this.currentRecord,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      })
        .then((savedRec) => {
          const recId = savedRec?.Id || this.currentRecord.Id;
          return submitTaxDeclaration({
            declarationId: recId,
            portalUserId: this.employeeId,
            sessionToken: this.sessionToken
          });
        })
        .then(() => {
          this.feedback = {
            type: "success",
            title: "Success",
            message: "Tax declaration submitted successfully."
          };
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Success",
              message: "Tax declaration submitted successfully",
              variant: "success"
            })
          );
          this.isModalOpen = false;
          return refreshApex(this.wiredDeclarationsResult);
        })
        .catch((error) => {
          const errMsg = this.normalizeWireError(error);
          this.feedback = {
            type: "error",
            title: "Error submitting declaration",
            message: errMsg
          };
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Error submitting declaration",
              message: errMsg,
              variant: "error"
            })
          );
        });
    } else {
      submitTaxDeclaration({
        declarationId: this.currentRecord.Id,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      })
        .then(() => {
          this.feedback = {
            type: "success",
            title: "Success",
            message: "Tax declaration submitted successfully."
          };
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Success",
              message: "Tax declaration submitted successfully",
              variant: "success"
            })
          );
          this.isModalOpen = false;
          return refreshApex(this.wiredDeclarationsResult);
        })
        .catch((error) => {
          const errMsg = this.normalizeWireError(error);
          this.feedback = {
            type: "error",
            title: "Error submitting declaration",
            message: errMsg
          };
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Error submitting declaration",
              message: errMsg,
              variant: "error"
            })
          );
        });
    }
  }

  closeModal() {
    this.isModalOpen = false;
    this.feedback = null;
  }
}