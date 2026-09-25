import getMyLeaves from "@salesforce/apex/PWChrono_LeaveController.getMyLeaves";
import getMyLeaveBalance from "@salesforce/apex/PWChrono_LeaveController.getMyLeaveBalance";
import saveLeaveApplication from "@salesforce/apex/PWChrono_LeaveController.saveLeaveApplication";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { downloadCsv } from "c/pwchronoCsv";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoLeaveEmployee extends LightningElement {
  @track myLeaves = [];
  @track allMyLeaves = [];
  @track isLoading = false;
  searchTerm = "";
  loadError = "";
  balanceError = "";
  _leaveRequest = 0;

  get showLeaveTable() {
    return !this.isLoading && !this.loadError;
  }

  get visibleLeaves() {
    const query = this.searchTerm.trim().toLowerCase();
    return this.myLeaves.filter(
      (leave) =>
        !query ||
        `${leave.leaveTypeName} ${leave.Reason__c || ""} ${leave.Status__c}`
          .toLowerCase()
          .includes(query)
    );
  }
  get hasVisibleLeaves() {
    return this.visibleLeaves.length > 0;
  }
  handleSearch(event) {
    this.searchTerm = event.target.value;
  }
  handleStatusSelect(event) {
    this.statusFilter = event.target.value;
    this.loadLeaveRequests();
  }
  handleResetFilters() {
    this.searchTerm = "";
    this.statusFilter = "All";
    this.startDate = null;
    this.endDate = null;
    this.loadLeaveRequests();
  }
  handleExport() {
    downloadCsv(
      "my-leaves.csv",
      ["Leave Type", "From", "To", "Days", "Reason", "Status"],
      this.visibleLeaves.map((l) => [
        l.leaveTypeName,
        l.formattedStartDate,
        l.formattedEndDate,
        l.totalDays,
        l.Reason__c,
        l.Status__c
      ])
    );
  }

  // Metrics
  @track annualLeaveCount = 0;
  @track medicalLeaveCount = 0;
  @track otherLeaveCount = 0;
  @track remainingLeaveCount = 0;

  @track statusFilter = "All";
  @track startDate = null;
  @track endDate = null;

  employeeId;
  sessionToken;

  // Dropdown State
  @track showExportDropdown = false;
  @track showFilterDropdown = false;

  // New Leave Modal
  @track isNewLeaveModalOpen = false;
  @track isSavingLeave = false;
  @track leaveTypes = [];
  @track newLeaveForm = {
    leaveTypeId: "",
    fromDate: "",
    toDate: "",
    reason: "",
    halfDay: false
  };
  hasRendered = false;
  _boundCloseDropdowns;

  @wire(getActiveLeaveTypes)
  wiredLeaveTypes({ data }) {
    if (data) {
      this.leaveTypes = data.map((lt) => ({ label: lt.Name, value: lt.Id }));
    }
  }

  connectedCallback() {
    const session = getSession();
    this.employeeId = session.user ? session.user.Id : null;
    this.sessionToken = getSessionToken();
    Promise.all([this.loadLeaveBalance(), this.loadLeaveRequests()]);
  }

  renderedCallback() {
    if (this._focusLeaveForm) {
      const firstField = this.template.querySelector(
        'select[name="leaveTypeId"]'
      );
      if (firstField) {
        firstField.focus();
        this._focusLeaveForm = false;
      }
    }
    const status = this.template.querySelector('[name="statusFilter"]');
    if (status && status.value !== this.statusFilter)
      status.value = this.statusFilter;
    if (!this.hasRendered) {
      this.hasRendered = true;
      this._boundCloseDropdowns = this.closeDropdowns.bind(this);
      globalThis.addEventListener("click", this._boundCloseDropdowns);
    }
  }

  disconnectedCallback() {
    if (this._boundCloseDropdowns) {
      globalThis.removeEventListener("click", this._boundCloseDropdowns);
    }
  }

  closeDropdowns() {
    this.showExportDropdown = false;
    this.showFilterDropdown = false;
  }

  toggleExportDropdown(event) {
    event.preventDefault();
    event.stopPropagation();
    this.showExportDropdown = !this.showExportDropdown;
    this.showFilterDropdown = false;
  }

  toggleFilterDropdown(event) {
    event.preventDefault();
    event.stopPropagation();
    this.showFilterDropdown = !this.showFilterDropdown;
    this.showExportDropdown = false;
  }

  get exportDropdownClass() {
    return this.showExportDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  get filterDropdownClass() {
    return this.showFilterDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  async loadLeaveBalance() {
    this.balanceError = "";
    try {
      const balances = await getMyLeaveBalance({
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (balances) {
        this.annualLeaveCount = 0;
        this.medicalLeaveCount = 0;
        this.otherLeaveCount = 0;
        let totalRemaining = 0;
        balances.forEach((b) => {
          const type = (b.leaveType || "").toLowerCase();
          if (type.includes("annual")) {
            this.annualLeaveCount = b.allocated || 0;
          } else if (type.includes("medical") || type.includes("sick")) {
            this.medicalLeaveCount = b.allocated || 0;
          } else {
            this.otherLeaveCount += b.allocated || 0;
          }
          totalRemaining += b.remaining || 0;
        });
        this.remainingLeaveCount = totalRemaining;
      }
    } catch {
      this.balanceError = "Leave balances are unavailable. Please try again.";
      this.annualLeaveCount = "—";
      this.medicalLeaveCount = "—";
      this.otherLeaveCount = "—";
      this.remainingLeaveCount = "—";
    }
  }

  async loadLeaveRequests() {
    const request = ++this._leaveRequest;
    this.isLoading = true;
    this.loadError = "";
    try {
      const result = await getMyLeaves({
        statusFilter: this.statusFilter,
        startDate: this.startDate,
        endDate: this.endDate,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (request !== this._leaveRequest) return;
      {
        this.allMyLeaves = (result || []).map((record) => ({
          ...record,
          leaveTypeName: record.Leave_Type__r
            ? record.Leave_Type__r.Name
            : "Other",
          statusClass: this.getStatusClass(record.Status__c),
          formattedStartDate: record.From_Date__c,
          formattedEndDate: record.To_Date__c,
          totalDays: record.Total_Days__c ?? 0
        }));
        this.myLeaves = [...this.allMyLeaves];
        // Calculate metrics if needed based on data
      }
    } catch (error) {
      if (request !== this._leaveRequest) return;
      this.allMyLeaves = [];
      this.myLeaves = [];
      this.loadError = "Unable to load leave requests. Please try again.";
      this.showToast(
        "Error",
        "Failed to load leaves: " +
          (error.body ? error.body.message : error.message),
        "error"
      );
    } finally {
      if (request === this._leaveRequest) this.isLoading = false;
    }
  }

  getStatusClass(status) {
    const color =
      {
        Approved: "success",
        Rejected: "danger",
        Submitted: "warning",
        Pending: "warning",
        Cancelled: "secondary"
      }[status] || "secondary";
    return `badge bg-${color}-transparent`;
  }

  handleStatusFilter(event) {
    event.preventDefault();
    event.stopPropagation();
    this.statusFilter = event.target.dataset.value;
    this.loadLeaveRequests();
  }

  handleDateFilter(event) {
    this[event.target.name] = event.target.value || null;
    this.loadLeaveRequests();
  }

  @track modalError = "";

  extractErrorMessage(error) {
    if (!error) return "An unexpected error occurred.";
    if (typeof error === "string") return error;
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e?.message || JSON.stringify(e)).join("\n");
    }
    if (error.body?.message) return error.body.message;
    if (error.body?.output?.errors?.length) {
      return error.body.output.errors.map((e) => e?.message).join("\n");
    }
    if (error.message) return error.message;
    return "An unexpected error occurred.";
  }

  handleNewLeaveRequest(event) {
    event?.preventDefault();
    this.modalError = "";
    this._leaveOpener = event?.currentTarget;
    this._focusLeaveForm = true;
    this.newLeaveForm = {
      leaveTypeId: "",
      fromDate: "",
      toDate: "",
      reason: "",
      halfDay: false
    };
    this.isNewLeaveModalOpen = true;
  }

  handleCloseLeaveModal() {
    if (this.isSavingLeave) return;
    this.modalError = "";
    this.isNewLeaveModalOpen = false;
    this._leaveOpener?.focus();
  }

  handleDialogKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      this.handleCloseLeaveModal();
    }
    if (event.key !== "Tab") return;
    const controls = [
      ...event.currentTarget.querySelectorAll(
        "button:not([disabled]), input, select, textarea"
      )
    ];
    const first = controls[0],
      last = controls[controls.length - 1];
    if (event.shiftKey && event.target === first) {
      event.preventDefault();
      last?.focus();
    } else if (!event.shiftKey && event.target === last) {
      event.preventDefault();
      first?.focus();
    }
  }

  handleNewLeaveFormChange(event) {
    this.modalError = "";
    const field = event.target.name;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
    this.newLeaveForm = { ...this.newLeaveForm, [field]: value };
  }

  async handleSubmitLeave(event) {
    event?.preventDefault();
    if (this.isSavingLeave) return;
    this.modalError = "";
    const form = this.template.querySelector("form");
    if (form && !form.reportValidity()) return;
    if (this.newLeaveForm.toDate < this.newLeaveForm.fromDate) {
      this.modalError = "To Date must be on or after From Date.";
      return;
    }
    if (
      !this.newLeaveForm.leaveTypeId ||
      !this.newLeaveForm.fromDate ||
      !this.newLeaveForm.toDate
    ) {
      this.modalError = "Please fill in Leave Type, From Date and To Date.";
      return;
    }
    this.isSavingLeave = true;
    try {
      const leaveRecord = {
        Leave_Type__c: this.newLeaveForm.leaveTypeId,
        From_Date__c: this.newLeaveForm.fromDate,
        To_Date__c: this.newLeaveForm.toDate,
        Reason__c: this.newLeaveForm.reason,
        Half_Day__c: this.newLeaveForm.halfDay,
        Status__c: "Submitted"
      };
      await saveLeaveApplication({
        leaveRecord,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.isNewLeaveModalOpen = false;
      this.showToast(
        "Success",
        "Leave request submitted successfully",
        "success"
      );
      await Promise.all([this.loadLeaveRequests(), this.loadLeaveBalance()]);
    } catch (error) {
      this.modalError = this.extractErrorMessage(error);
    } finally {
      this.isSavingLeave = false;
    }
  }

  handleNoop(event) {
    event?.preventDefault();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}