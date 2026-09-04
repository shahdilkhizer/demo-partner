import getTeamLeavesForApproval from "@salesforce/apex/PWChrono_LeaveController.getTeamLeavesForApproval";
import processLeaveApproval from "@salesforce/apex/PWChrono_LeaveController.processLeaveApproval";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoLeaveAdmin extends LightningElement {
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

  connectedCallback() {
    this.loadTeamLeaves();
  }

  async loadTeamLeaves() {
    this.isLoading = true;
    try {
      const result = await getTeamLeavesForApproval({
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

  getStatusClass(status) {
    // Mapping status to Bootstrap text colors if needed, or just returning status for logic
    return status;
  }

  handleStatusFilter(event) {
    this.selectedStatus = event.target.dataset.value;
    this.applyFilters();
  }

  handleLeaveTypeFilter(event) {
    this.selectedLeaveType = event.target.dataset.value;
    this.applyFilters();
  }

  handleDateFilter(event) {
    // Simple date filter implementation - expects YYYY-MM-DD
    const val = event.target.value;
    if (val) {
      this.startDate = val; // For now just single date or start date
    } else {
      this.startDate = null;
    }
    this.applyFilters();
  }

  applyFilters() {
    let filtered = [...this.allTeamLeaves];

    if (this.selectedStatus !== "All") {
      filtered = filtered.filter((l) => l.Status__c === this.selectedStatus);
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
    // Prevent default anchor behavior
    event.preventDefault();
    this.selectedLeaveId = event.currentTarget.dataset.id;
    this.modalAction = "Approve";
    this.processApproval(); // Direct approve for now, or open modal
  }

  handleReject(event) {
    event.preventDefault();
    this.selectedLeaveId = event.currentTarget.dataset.id;
    this.modalAction = "Reject";
    // For reject, we might want a reason, but for this UI we'll just trigger the action or show a simple prompt
    // Since the UI doesn't have a modal in the HTML provided, we'll use a standard prompt or just process it.
    // For safety, let's just process it as 'Reject' for now.
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