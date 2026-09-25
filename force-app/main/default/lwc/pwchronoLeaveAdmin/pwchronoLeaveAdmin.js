import { NavigationMixin } from "lightning/navigation";
import { downloadCsv } from "c/pwchronoCsv";
import getTeamLeavesForApproval from "@salesforce/apex/PWChrono_PortalApi.getTeamLeaves";
import processLeaveApproval from "@salesforce/apex/PWChrono_PortalApi.processLeaveApproval";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import saveLeaveApplication from "@salesforce/apex/PWChrono_LeaveController.saveLeaveApplication";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoLeaveAdmin extends NavigationMixin(
  LightningElement
) {
  employeeId = getEmployeeId();
  sessionToken = getSessionToken();
  @track teamLeaves = [];
  @track allTeamLeaves = [];
  @track isLoading = false;

  // Metrics
  @track approvedCount = 0;
  @track pendingCount = 0;
  @track rejectedCount = 0;
  @track totalCount = 0;

  // Modal State
  @track showApprovalModal = false;
  @track modalAction = "";
  @track rejectionReason = "";
  selectedLeaveId = null;

  // Filters
  @track selectedStatus = "All";
  @track selectedLeaveType = "All";
  @track startDate = null;
  @track endDate = null;

  // New Leave Modal State
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

  @wire(getActiveLeaveTypes)
  wiredLeaveTypes({ data }) {
    if (data) {
      this.leaveTypes = data.map((lt) => ({ label: lt.Name, value: lt.Id }));
    }
  }

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.loadTeamLeaves();
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

  handleNewRequest() {
    this.modalError = "";
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
  }

  handleDialogKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      this.handleCloseLeaveModal();
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
      await this.loadTeamLeaves();
    } catch (error) {
      this.modalError = this.extractErrorMessage(error);
    } finally {
      this.isSavingLeave = false;
    }
  }

  handleExportPdf() {
    window.print();
  }

  handleExportCsv() {
    downloadCsv(
      "team-leave.csv",
      ["Employee", "Leave type", "From", "To", "Days", "Status"],
      this.teamLeaves.map((r) => [
        r.employeeName,
        r.leaveTypeName,
        r.From_Date__c,
        r.To_Date__c,
        r.Total_Days__c,
        r.Status__c
      ])
    );
  }

  async loadTeamLeaves() {
    this.isLoading = true;
    try {
      const result = await getTeamLeavesForApproval({
        statusFilter: "All",
        startDate: null,
        endDate: null,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (result) {
        this.allTeamLeaves = result.map((record) => ({
          ...record,
          employeeName: record.Employees__r
            ? record.Employees__r.Name
            : "Unknown",
          leaveTypeName: record.Leave_Type__r
            ? record.Leave_Type__r.Name
            : "Other",
          statusClass: this.getStatusClass(record.Status__c),
          isPending:
            record.Status__c === "Pending" || record.Status__c === "Submitted"
        }));
        this.teamLeaves = [...this.allTeamLeaves];
        this.calculateMetrics();
      }
    } catch (error) {
      this.showToast(
        "Error",
        "Failed to load leave requests: " +
          (error.body ? error.body.message : error.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  calculateMetrics() {
    this.totalCount = this.allTeamLeaves.length;
    this.approvedCount = this.allTeamLeaves.filter(
      (l) => l.Status__c === "Approved"
    ).length;
    this.pendingCount = this.allTeamLeaves.filter(
      (l) => l.Status__c === "Pending" || l.Status__c === "Submitted"
    ).length;
    this.rejectedCount = this.allTeamLeaves.filter(
      (l) => l.Status__c === "Rejected"
    ).length;
  }

  get leaveTypeButtonLabel() {
    return this.selectedLeaveType === "All"
      ? "All Types"
      : this.selectedLeaveType;
  }

  get statusButtonLabel() {
    return this.selectedStatus === "All"
      ? "All Status"
      : this.selectedStatus;
  }

  getStatusClass(status) {
    switch (status) {
      case "Approved":
        return "badge badge-soft-success";
      case "Pending":
      case "Submitted":
        return "badge badge-soft-warning";
      case "Rejected":
        return "badge badge-soft-danger";
      case "Cancelled":
        return "badge badge-soft-secondary";
      default:
        return "badge badge-soft-info";
    }
  }

  handleDropdownToggle(event) {
    if (event.target.open) {
      const dropdowns = this.template.querySelectorAll("details.native-menu");
      dropdowns.forEach((d) => {
        if (d !== event.target) {
          d.open = false;
        }
      });
    }
  }

  handleStatusFilter(event) {
    this.selectedStatus = event.target.dataset.value;
    const parentDetails = event.target.closest("details");
    if (parentDetails) {
      parentDetails.open = false;
    }
    this.applyFilters();
  }

  handleLeaveTypeFilter(event) {
    this.selectedLeaveType = event.target.dataset.value;
    const parentDetails = event.target.closest("details");
    if (parentDetails) {
      parentDetails.open = false;
    }
    this.applyFilters();
  }

  handleDateFilter(event) {
    const val = event.target.value;
    if (val) {
      this.startDate = val;
    } else {
      this.startDate = null;
    }
    this.applyFilters();
  }

  applyFilters() {
    let filtered = [...this.allTeamLeaves];

    if (this.selectedStatus !== "All") {
      if (this.selectedStatus === "Pending") {
        filtered = filtered.filter(
          (l) => l.Status__c === "Pending" || l.Status__c === "Submitted"
        );
      } else {
        filtered = filtered.filter((l) => l.Status__c === this.selectedStatus);
      }
    }

    if (this.selectedLeaveType !== "All") {
      filtered = filtered.filter(
        (l) => l.leaveTypeName === this.selectedLeaveType
      );
    }

    if (this.startDate) {
      filtered = filtered.filter((l) => l.From_Date__c >= this.startDate);
    }

    this.teamLeaves = filtered;
  }

  handleApprove(event) {
    event.preventDefault();
    this.selectedLeaveId = event.currentTarget.dataset.id;
    this.modalAction = "Approve";
    this.processApproval();
  }

  handleReject(event) {
    event.preventDefault();
    this.selectedLeaveId = event.currentTarget.dataset.id;
    this.modalAction = "Reject";
    this.processApproval();
  }

  processApproval() {
    this.isLoading = true;
    processLeaveApproval({
      leaveId: this.selectedLeaveId,
      action: this.modalAction,
      comments: this.rejectionReason || "Processed via Admin Console",
      employeeId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          `Leave request ${this.modalAction}ed successfully`,
          "success"
        );
        return this.loadTeamLeaves();
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  handleNoop(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
  }
}