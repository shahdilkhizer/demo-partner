import { NavigationMixin } from "lightning/navigation";
import { downloadCsv } from "c/pwchronoCsv";
import getTeamLeavesForApproval from "@salesforce/apex/PWChrono_PortalApi.getTeamLeaves";
import processLeaveApproval from "@salesforce/apex/PWChrono_PortalApi.processLeaveApproval";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import saveLeaveApplication from "@salesforce/apex/PWChrono_LeaveController.saveLeaveApplication";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
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
  @track approvalModalError = "";
  selectedLeaveId = null;
  boundHandleSessionChange = null;

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
    this.syncSession();
    this.loadTeamLeaves();
    this.boundHandleSessionChange = () => {
      this.syncSession();
      this.loadTeamLeaves();
    };
    window.addEventListener(
      SESSION_CHANGED_EVENT,
      this.boundHandleSessionChange
    );
  }

  disconnectedCallback() {
    if (this.boundHandleSessionChange) {
      window.removeEventListener(
        SESSION_CHANGED_EVENT,
        this.boundHandleSessionChange
      );
    }
  }

  syncSession() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
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
      halfDay: false,
      halfDaySession: "Session 1"
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

  get isHalfDayDisabled() {
    if (!this.newLeaveForm.fromDate || !this.newLeaveForm.toDate) {
      return false;
    }
    return this.newLeaveForm.fromDate !== this.newLeaveForm.toDate;
  }

  handleNewLeaveFormChange(event) {
    this.modalError = "";
    const field = event.target.name;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
    const updatedForm = { ...this.newLeaveForm, [field]: value };
    if (
      updatedForm.fromDate &&
      updatedForm.toDate &&
      updatedForm.fromDate !== updatedForm.toDate
    ) {
      updatedForm.halfDay = false;
    }
    this.newLeaveForm = updatedForm;
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
        Half_Day_Session__c: this.newLeaveForm.halfDay
          ? this.newLeaveForm.halfDaySession || "Session 1"
          : null,
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
        this.allTeamLeaves = result.map((record) => {
          const isSelf = record.Employees__c === this.employeeId;
          return {
            ...record,
            employeeName: record.Employees__r
              ? record.Employees__r.Name
              : "Unknown",
            leaveTypeName: record.Leave_Type__r
              ? record.Leave_Type__r.Name
              : "Other",
            statusClass: this.getStatusClass(record.Status__c),
            isPending:
              record.Status__c === "Pending" || record.Status__c === "Submitted",
            isSelf,
            approveTooltip: isSelf ? "Self-approval is not allowed" : "Approve",
            rejectTooltip: isSelf ? "Self-approval is not allowed" : "Reject"
          };
        });
        this.teamLeaves = [...this.allTeamLeaves];
        this.calculateMetrics();
      }
    } catch (error) {
      this.showToast(
        "Error",
        "Failed to load leave requests: " + this.extractErrorMessage(error),
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

  get modalTitle() {
    return this.modalAction === "Approve"
      ? "Approve Leave Request"
      : "Reject Leave Request";
  }

  get modalPromptMessage() {
    return this.modalAction === "Approve"
      ? "Are you sure you want to approve this leave request?"
      : "Please provide a reason for rejecting this leave request.";
  }

  get isRejectionAction() {
    return this.modalAction === "Reject";
  }

  get modalCommentLabel() {
    return this.modalAction === "Reject" ? "Rejection Reason" : "Comments";
  }

  get modalCommentPlaceholder() {
    return this.modalAction === "Reject"
      ? "Enter reason for rejection..."
      : "Add optional comments...";
  }

  get modalSubmitButtonClass() {
    return this.modalAction === "Reject" ? "btn btn-danger" : "btn btn-success";
  }

  get modalActionLabel() {
    return this.modalAction === "Reject" ? "Reject Request" : "Approve Request";
  }

  handleApprove(event) {
    event.preventDefault();
    this.selectedLeaveId = event.currentTarget.dataset.id;
    this.modalAction = "Approve";
    this.rejectionReason = "";
    this.approvalModalError = "";
    this.showApprovalModal = true;
  }

  handleReject(event) {
    event.preventDefault();
    this.selectedLeaveId = event.currentTarget.dataset.id;
    this.modalAction = "Reject";
    this.rejectionReason = "";
    this.approvalModalError = "";
    this.showApprovalModal = true;
  }

  handleCloseApprovalModal() {
    this.showApprovalModal = false;
    this.selectedLeaveId = null;
    this.modalAction = "";
    this.rejectionReason = "";
    this.approvalModalError = "";
  }

  handleRejectionReasonChange(event) {
    this.rejectionReason = event.target.value;
    if (this.approvalModalError) {
      this.approvalModalError = "";
    }
  }

  handleConfirmApproval() {
    if (this.modalAction === "Reject" && !this.rejectionReason?.trim()) {
      this.approvalModalError = "Rejection reason is required.";
      return;
    }
    this.processApproval();
  }

  processApproval() {
    this.isLoading = true;
    this.approvalModalError = "";
    processLeaveApproval({
      leaveId: this.selectedLeaveId,
      action: this.modalAction,
      comments:
        this.rejectionReason?.trim() ||
        (this.modalAction === "Approve" ? "Approved via Admin Console" : ""),
      employeeId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          `Leave request ${this.modalAction.toLowerCase() === "approve" ? "approved" : "rejected"} successfully`,
          "success"
        );
        this.handleCloseApprovalModal();
        return this.loadTeamLeaves();
      })
      .catch((error) => {
        const errorMsg = this.extractErrorMessage(error);
        this.approvalModalError = errorMsg;
        this.showToast("Error", errorMsg, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleRowClick(event) {
    event.preventDefault();
    const leaveId = event.currentTarget.dataset.id;
    if (leaveId) {
      this.dispatchEvent(
        new CustomEvent("viewdetail", {
          detail: { leaveId },
          bubbles: true,
          composed: true
        })
      );
    }
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