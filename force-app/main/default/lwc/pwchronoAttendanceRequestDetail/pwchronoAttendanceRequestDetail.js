import { LightningElement, api, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getAttendanceRequestDetail from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceRequestDetail";
import processAttendanceCorrectionApproval from "@salesforce/apex/PWChrono_AttendanceController.processAttendanceCorrectionApproval";
import cancelAttendanceRequest from "@salesforce/apex/PWChrono_AttendanceController.cancelAttendanceRequest";
import getAttendanceComments from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceComments";
import addAttendanceComment from "@salesforce/apex/PWChrono_AttendanceController.addAttendanceComment";
import getAttendanceFiles from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceFiles";
import uploadAttendanceFile from "@salesforce/apex/PWChrono_AttendanceController.uploadAttendanceFile";

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB

export default class PwchronoAttendanceRequestDetail extends LightningElement {
  static renderMode = "light";

  // ── Public API ────────────────────────────────────────────────────────────

  _requestId = null;

  @api
  get requestId() {
    return this._requestId;
  }
  set requestId(value) {
    this._requestId = value;
    if (value) this.loadDetail();
  }

  // ── Tracked state ─────────────────────────────────────────────────────────

  @track request       = null;
  @track comments      = [];
  @track uploadedFiles = [];
  @track isLoading     = true;
  @track loadError     = null;
  @track actionError   = null;
  @track isActing      = false;

  maxFileSize = MAX_FILE_SIZE;

  employeeId   = getEmployeeId();
  sessionToken = getSessionToken();

  // ── Computed getters ──────────────────────────────────────────────────────

  get hasData()       { return !!this.request && !this.isLoading; }

  get isOwner() {
    return this.request && this.request.Employees__c === this.employeeId;
  }
  get isApprover() {
    return this.request && this.request.Approvers__c === this.employeeId;
  }
  get canComment() {
    return this.isOwner || this.isApprover;
  }
  get canUploadFiles() {
    return this.isOwner &&
      (this.request.Status__c === "Draft" || this.request.Status__c === "Submitted");
  }

  get correctionTypeLabel() {
    return this.request?.Correction_Type__c || "—";
  }
  get approverName() {
    return this.request?.Approvers__r?.Name || "Not assigned";
  }
  get hasCheckIn()  { return !!this.request?.From_Time__c; }
  get hasCheckOut() { return !!this.request?.To_Time__c; }
  get formattedCheckIn()  { return this.formatTime(this.request?.From_Time__c); }
  get formattedCheckOut() { return this.formatTime(this.request?.To_Time__c); }
  get hasApproverComments() { return !!this.request?.Approver_Comments__c; }
  get hasRejectionReason()  { return !!this.request?.Rejection_Reason__c; }

  get hasShiftContext() {
    return !!this.request?.Shift_Assignment__r?.Shift_Type__r?.Name;
  }
  get shiftName()  { return this.request?.Shift_Assignment__r?.Shift_Type__r?.Name  || "—"; }
  get shiftStart() { return this.formatTime(this.request?.Shift_Assignment__r?.Shift_Type__r?.Start_Time__c); }
  get shiftEnd()   { return this.formatTime(this.request?.Shift_Assignment__r?.Shift_Type__r?.End_Time__c); }

  /** Merge user + system comments into unified timeline entries. */
  get commentEntries() {
    return (this.comments || []).map((c) => ({
      id:        c.id,
      text:      c.text,
      author:    c.authorName,
      timestamp: this.formatDateTime(c.createdDate),
      type:      c.commentType,
      icon:      c.commentType === "System" ? "info" : "comment"
    }));
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  loadDetail() {
    if (!this._requestId) return;
    this.isLoading  = true;
    this.loadError  = null;
    this.actionError = null;

    Promise.all([
      getAttendanceRequestDetail({
        requestId:    this._requestId,
        employeeId:   this.employeeId,
        sessionToken: this.sessionToken
      }),
      getAttendanceComments({
        requestId:    this._requestId,
        employeeId:   this.employeeId,
        sessionToken: this.sessionToken
      }),
      getAttendanceFiles({
        requestId:    this._requestId,
        employeeId:   this.employeeId,
        sessionToken: this.sessionToken
      })
    ])
      .then(([req, commentData, fileData]) => {
        this.request       = req;
        this.comments      = commentData  || [];
        this.uploadedFiles = fileData     || [];
      })
      .catch((err) => {
        this.loadError = err?.body?.message || err?.message || "Error loading request details.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // ── Action Handlers ───────────────────────────────────────────────────────

  handleRequestAction(event) {
    const { action, comments } = event.detail;
    this.actionError = null;

    if (action === "Cancel") {
      this.handleCancel(comments);
    } else {
      this.handleApprovalAction(action, comments);
    }
  }

  handleApprovalAction(action, comments) {
    this.isActing = true;
    processAttendanceCorrectionApproval({
      requestId:    this._requestId,
      action,
      comments:     comments || "",
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((updated) => {
        this.request = updated;
        this.loadDetail(); // Reload to sync comments
        this.showToast("Success", `Request ${action.toLowerCase()}d successfully.`, "success");
        this.dispatchEvent(
          new CustomEvent("requestactioned", {
            detail: { requestId: this._requestId, action },
            bubbles: true,
            composed: true
          })
        );
      })
      .catch((err) => {
        this.actionError = err?.body?.message || err?.message || "Error processing approval.";
      })
      .finally(() => {
        this.isActing = false;
      });
  }

  handleCancel(reason) {
    this.isActing = true;
    cancelAttendanceRequest({
      requestId:    this._requestId,
      cancelReason: reason || "",
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((updated) => {
        this.request = updated;
        this.loadDetail();
        this.showToast("Success", "Request cancelled.", "success");
        this.dispatchEvent(
          new CustomEvent("requestactioned", {
            detail: { requestId: this._requestId, action: "Cancel" },
            bubbles: true,
            composed: true
          })
        );
      })
      .catch((err) => {
        this.actionError = err?.body?.message || err?.message || "Error cancelling request.";
      })
      .finally(() => {
        this.isActing = false;
      });
  }

  handleNewComment(event) {
    const { text } = event.detail;
    if (!text?.trim()) return;

    addAttendanceComment({
      requestId:    this._requestId,
      commentText:  text.trim(),
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        return getAttendanceComments({
          requestId:    this._requestId,
          employeeId:   this.employeeId,
          sessionToken: this.sessionToken
        });
      })
      .then((refreshed) => {
        this.comments = refreshed || [];
      })
      .catch((err) => {
        this.showToast("Error", err?.body?.message || "Error adding comment.", "error");
      });
  }

  handleFilesSelected(event) {
    const { files } = event.detail;
    if (!files || !files.length) return;

    const uploadPromises = files.map((f) =>
      this.readFileAsBase64(f).then((base64) =>
        uploadAttendanceFile({
          requestId:    this._requestId,
          fileName:     f.name,
          base64Data:   base64,
          contentType:  f.type || "application/octet-stream",
          employeeId:   this.employeeId,
          sessionToken: this.sessionToken
        })
      )
    );

    Promise.all(uploadPromises)
      .then((newFiles) => {
        this.uploadedFiles = [...this.uploadedFiles, ...newFiles];
        this.showToast("Success", `${newFiles.length} file(s) uploaded.`, "success");
      })
      .catch((err) => {
        this.showToast("Error", err?.body?.message || "Error uploading file(s).", "error");
      });
  }

  handleFileError(event) {
    this.showToast("Error", event.detail?.message || "File error.", "error");
  }

  handleBack() {
    this.dispatchEvent(new CustomEvent("back", { bubbles: true, composed: true }));
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = reader.result.split(",")[1];
        resolve(base64);
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  formatTime(t) {
    if (!t) return "—";
    // Salesforce Time comes as milliseconds since midnight
    if (typeof t === "number") {
      const totalSec = Math.floor(t / 1000);
      const hh = String(Math.floor(totalSec / 3600)).padStart(2, "0");
      const mm = String(Math.floor((totalSec % 3600) / 60)).padStart(2, "0");
      return `${hh}:${mm}`;
    }
    return String(t);
  }

  formatDateTime(isoString) {
    if (!isoString) return "";
    try {
      const d = new Date(isoString);
      return d.toLocaleString("en-GB", {
        day: "2-digit", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit"
      });
    } catch {
      return isoString;
    }
  }

  showToast(title, message, variant) {
    try {
      this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    } catch {
      // Outside Experience Cloud — silent
    }
  }
}