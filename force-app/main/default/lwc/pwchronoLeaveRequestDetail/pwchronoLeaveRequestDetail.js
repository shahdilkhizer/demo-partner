import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getLeaveDetail from "@salesforce/apex/PWChrono_LeaveController.getLeaveDetail";
import processLeaveApproval from "@salesforce/apex/PWChrono_LeaveController.processLeaveApproval";
import cancelLeave from "@salesforce/apex/PWChrono_LeaveController.cancelLeave";
import getLeaveFiles from "@salesforce/apex/PWChrono_LeaveController.getLeaveFiles";
import uploadLeaveFile from "@salesforce/apex/PWChrono_LeaveController.uploadLeaveFile";
import getLeaveComments from "@salesforce/apex/PWChrono_LeaveController.getLeaveComments";
import addLeaveComment from "@salesforce/apex/PWChrono_LeaveController.addLeaveComment";
import getLeaveLedgerHistory from "@salesforce/apex/PWChrono_LeaveController.getLeaveLedgerHistory";

export default class PwchronoLeaveRequestDetail extends LightningElement {
  static renderMode = "light";

  _leaveId;

  @api
  get leaveId() {
    return this._leaveId;
  }

  set leaveId(value) {
    this._leaveId = value;
    if (value && this.employeeId && this.sessionToken) {
      this.loadDetail();
    }
  }

  @track isLoading = true;
  @track loadError = null;
  @track leave = null;
  @track files = [];
  @track comments = [];
  @track ledgerEntries = [];

  employeeId;
  sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    if (this.leaveId) {
      this.loadDetail();
    }
  }

  async loadDetail() {
    this.isLoading = true;
    this.loadError = null;
    try {
      const [leave, files, comments, ledgerEntries] = await Promise.all([
        getLeaveDetail({
          leaveId: this.leaveId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getLeaveFiles({
          leaveId: this.leaveId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getLeaveComments({
          leaveId: this.leaveId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getLeaveLedgerHistory({
          leaveId: this.leaveId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        })
      ]);
      this.leave = leave;
      this.files = files || [];
      this.comments = comments || [];
      this.ledgerEntries = ledgerEntries || [];
    } catch (error) {
      this.loadError =
        error?.body?.message ||
        error?.message ||
        "Failed to load leave details";
    } finally {
      this.isLoading = false;
    }
  }

  get hasData() {
    return !this.isLoading && !this.loadError && this.leave;
  }

  get leaveTitle() {
    return `Leave Request — ${this.leave.From_Date__c} to ${this.leave.To_Date__c}`;
  }

  get leaveTypeName() {
    return this.leave.Leave_Type__r ? this.leave.Leave_Type__r.Name : "Leave";
  }

  get leaveStatus() {
    return this.leave.Status__c;
  }

  get employeeName() {
    return this.leave.Employees__r ? this.leave.Employees__r.Name : "";
  }

  get appliedDate() {
    return this.leave.Applied_Date__c || "";
  }

  get fromDate() {
    return this.leave.From_Date__c;
  }

  get toDate() {
    return this.leave.To_Date__c;
  }

  get totalDays() {
    return this.leave.Total_Days__c || 0;
  }

  get isHalfDay() {
    return this.leave.Half_Day__c;
  }

  get halfDaySession() {
    return this.leave.Half_Day_Session__c || "Session 1";
  }

  get approverName() {
    return this.leave.Approvers__r ? this.leave.Approvers__r.Name : "—";
  }

  get approvalDate() {
    return this.leave.Approval_Date__c || null;
  }

  get reason() {
    return this.leave.Reason__c || "";
  }

  get rejectionReason() {
    return this.leave.Rejection_Reason__c || null;
  }

  get isOwner() {
    return this.leave.Employees__c === this.employeeId;
  }

  get isApprover() {
    return this.leave.Approvers__c === this.employeeId;
  }

  get canComment() {
    return this.isOwner || this.isApprover;
  }

  get canUploadFiles() {
    return this.isOwner;
  }

  get hasFiles() {
    return this.files && this.files.length > 0;
  }

  get hasLedgerEntries() {
    return this.ledgerEntries && this.ledgerEntries.length > 0;
  }

  get timelineEntries() {
    if (this.comments?.length) {
      return this.comments.map((entry) => ({
        key: entry.commentId,
        authorName: entry.authorName,
        text: entry.text,
        displayDate: this.formatDateTime(entry.createdDate),
        type: entry.commentType === "Comment" ? "Comment" : "System"
      }));
    }

    const fallbackEntries = [];
    if (this.leave?.Applied_Date__c) {
      fallbackEntries.push({
        key: "fallback-submit",
        authorName: this.employeeName,
        text: `Submitted leave request for ${this.totalDays} day(s)`,
        displayDate: this.leave.Applied_Date__c,
        type: "Submitted"
      });
    }
    return fallbackEntries;
  }

  get enrichedLedgerEntries() {
    return (this.ledgerEntries || []).map((entry) => ({
      ...entry,
      key: entry.entryId,
      displayDate: entry.transactionDate,
      signedDays: entry.days > 0 ? `+${entry.days}` : `${entry.days}`
    }));
  }

  async handleRequestAction(event) {
    const { action, comments } = event.detail;
    this.isLoading = true;

    try {
      if (action === "Cancel") {
        await cancelLeave({
          leaveId: this.leaveId,
          reason: comments,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        });
        this.showToast("Success", "Leave request cancelled", "success");
      } else {
        await processLeaveApproval({
          leaveId: this.leaveId,
          action,
          comments,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        });
        const successLabel = action === "Approve" ? "approved" : "rejected";
        this.showToast("Success", `Leave request ${successLabel}`, "success");
      }

      await this.loadDetail();
      this.dispatchEvent(
        new CustomEvent("leaveactioned", { bubbles: true, composed: true })
      );
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || error?.message || "Action failed",
        "error"
      );
      this.isLoading = false;
    }
  }

  async handleNewComment(event) {
    try {
      await addLeaveComment({
        leaveId: this.leaveId,
        commentText: event.detail?.text,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      await this.loadDetail();
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || error?.message || "Failed to add comment",
        "error"
      );
    }
  }

  async handleFilesSelected(event) {
    const files = event.detail?.files || [];
    if (!files.length) {
      return;
    }

    this.isLoading = true;
    try {
      await Promise.all(
        Array.from(files).map(async (file) => {
          const base64Data = await this.readFileAsBase64(file);
          return uploadLeaveFile({
            leaveId: this.leaveId,
            fileName: file.name,
            base64Data,
            employeeId: this.employeeId,
            sessionToken: this.sessionToken
          });
        })
      );
      this.showToast("Success", "Attachment uploaded", "success");
      await this.loadDetail();
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || error?.message || "Failed to upload file",
        "error"
      );
      this.isLoading = false;
    }
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const dataUrl = reader.result;
        const parts = typeof dataUrl === "string" ? dataUrl.split(",") : [];
        resolve(parts.length > 1 ? parts[1] : "");
      };
      reader.onerror = () =>
        reject(reader.error || new Error("File read failed"));
      reader.readAsDataURL(file);
    });
  }

  formatDateTime(value) {
    if (!value) {
      return "";
    }

    try {
      return new Intl.DateTimeFormat("en", {
        year: "numeric",
        month: "short",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      }).format(new Date(value));
    } catch {
      return value;
    }
  }

  handleBack() {
    this.dispatchEvent(
      new CustomEvent("back", { bubbles: true, composed: true })
    );
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}