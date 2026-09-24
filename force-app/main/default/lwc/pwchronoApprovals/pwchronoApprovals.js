import { LightningElement } from "lwc";
import getLeaves from "@salesforce/apex/PWChrono_PortalApi.getTeamLeavesForApproval";
import getAttendance from "@salesforce/apex/PWChrono_PortalApi.getTeamAttendanceForApproval";
import processLeave from "@salesforce/apex/PWChrono_PortalApi.processLeaveApproval";
import processAttendance from "@salesforce/apex/PWChrono_PortalApi.processAttendanceApproval";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { getErrorMessage } from "c/pwchronoErrorHandler";
export default class PwchronoApprovals extends LightningElement {
  static renderMode = "light";
  requestType = "leave";
  rows = [];
  isLoading = true;
  isSaving = false;
  errorMessage = "";
  successMessage = "";
  selected;
  action;
  comments = "";
  version = 0;
  sessionHandler;
  connectedCallback() {
    this.sessionHandler = () => {
      this.selected = null;
      this.loadRequests();
    };
    window.addEventListener(SESSION_CHANGED_EVENT, this.sessionHandler);
    this.loadRequests();
  }
  disconnectedCallback() {
    ++this.version;
    window.removeEventListener(SESSION_CHANGED_EVENT, this.sessionHandler);
  }
  get sessionParams() {
    return { employeeId: getEmployeeId(), sessionToken: getSessionToken() };
  }
  get hasRows() {
    return this.rows.length > 0;
  }
  get showEmpty() {
    return !this.isLoading && !this.errorMessage && !this.hasRows;
  }
  get modalTitle() {
    return `${this.action} request`;
  }
  get busy() {
    return this.isLoading || this.isSaving;
  }
  async loadRequests() {
    const version = ++this.version;
    this.rows = [];
    this.errorMessage = "";
    this.isLoading = true;
    try {
      const records = await (
        this.requestType === "leave" ? getLeaves : getAttendance
      )(this.sessionParams);
      if (version !== this.version) return;
      this.rows = (records || [])
        .filter((r) => r.Status__c === "Submitted")
        .map((r) => ({
          id: r.Id,
          name: r.Name,
          employee: r.Employees__r?.Name || "Employee",
          type:
            this.requestType === "leave"
              ? r.Leave_Type__r?.Name || "Leave"
              : "Attendance",
          start: r.From_Date__c || r.Attendance_Date__c,
          end: r.To_Date__c || r.Attendance_Date__c,
          reason: r.Reason__c || "No reason provided",
          status: r.Status__c
        }));
    } catch (error) {
      if (version === this.version) this.errorMessage = getErrorMessage(error);
    } finally {
      if (version === this.version) this.isLoading = false;
    }
  }
  handleTypeChange(event) {
    this.requestType = event.target.value;
    this.successMessage = "";
    this.loadRequests();
  }
  modalTrigger;
  modalFocused = false;
  renderedCallback() {
    if (this.selected && !this.modalFocused) {
      this.querySelector('[role="dialog"] textarea')?.focus();
      this.modalFocused = true;
    }
  }
  handleDialogKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      this.closeModal();
    }
    if (event.key !== "Tab") return;
    const controls = [
      ...event.currentTarget.querySelectorAll(
        "textarea:not([disabled]), button:not([disabled])"
      )
    ];
    const first = controls[0];
    const last = controls[controls.length - 1];
    if (event.shiftKey && event.target === first) {
      event.preventDefault();
      last?.focus();
    } else if (!event.shiftKey && event.target === last) {
      event.preventDefault();
      first?.focus();
    }
  }
  handleAction(event) {
    this.modalTrigger = event.currentTarget;
    this.modalFocused = false;
    this.selected = this.rows.find(
      (r) => r.id === event.currentTarget.dataset.id
    );
    this.action = event.currentTarget.dataset.action;
    this.comments = "";
    this.errorMessage = "";
  }
  closeModal() {
    if (!this.isSaving) {
      this.selected = null;
      this.modalFocused = false;
      this.modalTrigger?.focus();
    }
  }
  handleComments(event) {
    this.comments = event.target.value;
  }
  async confirmAction() {
    if (!this.selected || this.isSaving) return;
    if (this.action === "Reject" && !this.comments.trim()) {
      this.errorMessage = "Enter a reason before rejecting this request.";
      return;
    }
    const params = this.sessionParams;
    const version = this.version;
    this.isSaving = true;
    this.errorMessage = "";
    try {
      const idParams =
        this.requestType === "leave"
          ? { leaveId: this.selected.id }
          : { requestId: this.selected.id };
      await (this.requestType === "leave" ? processLeave : processAttendance)({
        ...params,
        ...idParams,
        action: this.action,
        comments: this.comments.trim()
      });
      if (version !== this.version) return;
      this.successMessage = `Request ${this.action === "Approve" ? "approved" : "rejected"}.`;
      this.selected = null;
      await this.loadRequests();
    } catch (error) {
      if (version === this.version) this.errorMessage = getErrorMessage(error);
    } finally {
      this.isSaving = false;
    }
  }
}