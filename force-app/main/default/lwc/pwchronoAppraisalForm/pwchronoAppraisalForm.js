import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getMyAppraisals from "@salesforce/apex/PWChrono_PerformanceController.getMyAppraisals";
import saveAppraisal from "@salesforce/apex/PWChrono_PerformanceController.saveAppraisal";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import { getSession, getEmployeeId, getSessionToken } from "c/pwchronoSession";

const COLUMNS = [
  {
    label: "Period",
    fieldName: "Appraisal_Period__c",
    type: "text",
    sortable: true
  },
  {
    label: "Start Date",
    fieldName: "Start_Date__c",
    type: "date",
    sortable: true
  },
  { label: "End Date", fieldName: "End_Date__c", type: "date", sortable: true },
  { label: "Status", fieldName: "Status__c", type: "text", sortable: true },
  { label: "Self Rating", fieldName: "Self_Rating__c", type: "number" },
  { label: "Manager Rating", fieldName: "Overall_Rating__c", type: "number" },
  {
    type: "button",
    typeAttributes: {
      label: "View/Edit",
      name: "view_edit",
      variant: "base"
    }
  }
];

export default class PwchronoAppraisalForm extends LightningElement {
  @track hasAccess = false;
  @track accessLoaded = false;
  @track allAppraisals = [];
  @track appraisals = [];
  @track error;
  @track isLoading = true;
  @track showModal = false;
  @track currentAppraisal = {};
  @track isReadOnly = false;
  columns = COLUMNS;
  wiredAppraisalsResult;

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  // Filters
  @track statusFilter = "";
  @track searchFilter = "";

  employeeId;
  sessionToken;

  filterStatusOptions = [
    { label: "All Statuses", value: "" },
    { label: "Draft", value: "Draft" },
    { label: "Submitted", value: "Submitted" },
    { label: "In Progress", value: "In Progress" },
    { label: "Completed", value: "Completed" }
  ];

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" }
  ];

  connectedCallback() {
    const session = getSession();
    this.employeeId = session.user ? session.user.Id : null;
    this.sessionToken = getSessionToken();
    this.checkAccess();
  }

  async checkAccess() {
    try {
      const employeeId = getEmployeeId();
      const accessData = await getUserAccessById({
        employeeId: employeeId,
        sessionToken: this.sessionToken
      });
      if (
        accessData &&
        accessData.features &&
        accessData.features.includes("Performance Management")
      ) {
        this.hasAccess = true;
      }
    } catch (error) {
      this.hasAccess = false;
      this.error = error?.body?.message || error?.message;
    }
    this.accessLoaded = true;
  }

  get statusOptions() {
    return [
      { label: "Draft", value: "Draft" },
      { label: "Submitted", value: "Submitted" },
      { label: "In Progress", value: "In Progress" },
      { label: "Completed", value: "Completed" }
    ];
  }

  get modalTitle() {
    return this.currentAppraisal.Id ? "Edit Appraisal" : "New Appraisal";
  }

  @wire(getMyAppraisals, {
    statusFilter: "All",
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredAppraisals(result) {
    this.wiredAppraisalsResult = result;
    this.isLoading = true;
    if (result.data) {
      this.allAppraisals = result.data;
      this.error = undefined;
      this.applyFilters();
    } else if (result.error) {
      this.error = result.error.body?.message || "Failed to load appraisals";
      this.allAppraisals = [];
      this.appraisals = [];
    }
    this.isLoading = false;
  }

  // Filter and Pagination Methods
  applyFilters() {
    let filtered = [...this.allAppraisals];

    if (this.statusFilter) {
      filtered = filtered.filter(
        (item) => item.Status__c === this.statusFilter
      );
    }

    if (this.searchFilter) {
      const search = this.searchFilter.toLowerCase();
      filtered = filtered.filter(
        (item) =>
          item.Appraisal_Period__c &&
          item.Appraisal_Period__c.toLowerCase().includes(search)
      );
    }

    this._filteredAppraisals = filtered;

    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.appraisals = filtered.slice(start, end);
  }

  handleStatusFilterChange(event) {
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
    this.pageSize = parseInt(event.detail.value, 10);
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
    return this._filteredAppraisals ? this._filteredAppraisals.length : 0;
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

  get hasAppraisals() {
    return this.appraisals && this.appraisals.length > 0;
  }

  get hasNoAppraisals() {
    return (
      !this.isLoading && (!this.appraisals || this.appraisals.length === 0)
    );
  }

  handleNewAppraisal() {
    this.currentAppraisal = {
      sobjectType: "PWChrono_Appraisal__c",
      Status__c: "Draft",
      Self_Rating__c: 3,
      Employees__c: this.employeeId
    };
    this.isReadOnly = false;
    this.showModal = true;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    if (actionName === "view_edit") {
      this.currentAppraisal = { ...row };
      // Read only if Submitted or Completed
      this.isReadOnly =
        row.Status__c === "Submitted" || row.Status__c === "Completed";
      this.showModal = true;
    }
  }

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    this.currentAppraisal[field] = event.target.value;
  }

  closeModal() {
    this.showModal = false;
    this.currentAppraisal = {};
  }

  handleSaveDraft() {
    this.saveRecord("Draft");
  }

  handleSubmit() {
    if (!this.validateFields()) {
      return;
    }
    this.saveRecord("Submitted");
  }

  validateFields() {
    if (
      !this.currentAppraisal.Appraisal_Period__c ||
      !this.currentAppraisal.Achievements__c
    ) {
      this.showToast(
        "Error",
        "Please fill in Period and Achievements",
        "error"
      );
      return false;
    }
    return true;
  }

  saveRecord(status) {
    const recordToSave = { ...this.currentAppraisal, Status__c: status };
    if (this.employeeId) {
      recordToSave.Employees__c = this.employeeId;
    }

    saveAppraisal({
      appraisal: recordToSave,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          `Appraisal ${status === "Submitted" ? "submitted" : "saved"} successfully`,
          "success"
        );
        this.closeModal();
        return refreshApex(this.wiredAppraisalsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          error?.body?.message || error?.message || "Failed to save appraisal",
          "error"
        );
      });
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