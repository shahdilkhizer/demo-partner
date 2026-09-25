import { LightningElement, api, track } from "lwc";
import saveAttendanceRequest from "@salesforce/apex/PWChrono_PortalApi.saveAttendanceRequest";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoAttendanceModal extends LightningElement {
  static renderMode = "light";
  @api isOpen = false;
  @api recordId;
  @api employeeOptions = [];

  @track attendanceDate;
  @track fromTime;
  @track toTime;
  @track status = "Approved";
  @track selectedEmployeeId;
  @track correctionType = "Other";
  @track reason = "HR attendance adjustment";
  @track productionHours = "0h";
  @track isSaving = false;

  _record;

  connectedCallback() {
    if (!this.selectedEmployeeId && this.employeeOptions?.length) {
      this.selectedEmployeeId = this.employeeOptions[0].value;
    }
    if (!this.attendanceDate) {
      this.attendanceDate = new Date().toISOString().split("T")[0];
    }
  }

  @api
  get record() {
    return this._record;
  }
  set record(value) {
    this._record = value;
    if (value) {
      this.attendanceDate = value.Attendance_Date__c;
      this.fromTime = this.normalizeTimeForInput(value.From_Time__c);
      this.toTime = this.normalizeTimeForInput(value.To_Time__c);
      this.status = value.Request_Status__c || "Approved";
      this.selectedEmployeeId = value.Employees__c;
      this.correctionType = value.Correction_Type__c || "Other";
      this.reason = value.Reason__c || "HR attendance adjustment";
      this.calculateProduction();
    } else {
      // Reset for new
      this.attendanceDate = new Date().toISOString().split("T")[0];
      this.fromTime = null;
      this.toTime = null;
      this.status = "Approved";
      this.selectedEmployeeId =
        this.employeeOptions?.length === 1
          ? this.employeeOptions[0].value
          : null;
      this.correctionType = "Other";
      this.reason = "HR attendance adjustment";
      this.productionHours = "0h";
    }
  }

  get modalTitle() {
    return this.recordId ? "Edit Attendance" : "Add Attendance";
  }

  get isDraft() {
    return this.status === "Draft";
  }
  get isSubmitted() {
    return this.status === "Submitted";
  }
  get isApproved() {
    return this.status === "Approved";
  }
  get isRejected() {
    return this.status === "Rejected";
  }
  get isCancelled() {
    return this.status === "Cancelled";
  }
  get isEmployeeLocked() {
    return Boolean(this.recordId);
  }
  get saveButtonLabel() {
    return this.isSaving ? "Saving…" : "Save attendance";
  }

  handleDateChange(event) {
    this.attendanceDate = event.target.value;
  }

  handleFromTimeChange(event) {
    this.fromTime = event.target.value;
    this.calculateProduction();
  }

  handleToTimeChange(event) {
    this.toTime = event.target.value;
    this.calculateProduction();
  }

  handleStatusChange(event) {
    this.status = event.target.value;
  }

  handleEmployeeChange(event) {
    this.selectedEmployeeId = event.target.value;
  }

  handleCorrectionTypeChange(event) {
    this.correctionType = event.target.value;
  }

  handleReasonChange(event) {
    this.reason = event.target.value;
  }

  calculateProduction() {
    if (this.fromTime && this.toTime) {
      // Simple diff
      const start = new Date(`1970-01-01T${this.fromTime}`);
      const end = new Date(`1970-01-01T${this.toTime}`);
      let diff = (end - start) / 1000 / 60 / 60; // hours
      if (diff < 0) diff += 24; // Handle overnight?
      this.productionHours = diff.toFixed(2) + "h";
    } else {
      this.productionHours = "0h";
    }
  }

  closeModal() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  async handleSave() {
    const controls = [
      ...this.querySelectorAll("input, select, textarea")
    ];
    const isValid = controls.reduce((valid, control) => {
      control.reportValidity?.();
      return valid && (control.checkValidity?.() ?? true);
    }, true);
    if (!isValid) {
      return;
    }

    const attendanceRecord = {
      sobjectType: "PWChrono_Attendance_Request__c",
      Id: this.recordId,
      Employees__c: this.selectedEmployeeId,
      Attendance_Date__c: this.attendanceDate,
      From_Time__c: this.formatTimeForApex(this.fromTime),
      To_Time__c: this.formatTimeForApex(this.toTime),
      Status__c: this.status,
      Correction_Type__c: this.correctionType,
      Reason__c: this.reason
    };

    this.isSaving = true;
    try {
      await saveAttendanceRequest({
        attendanceRequest: attendanceRecord,
        portalUserId: getEmployeeId(),
        sessionToken: getSessionToken()
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Attendance saved successfully",
          variant: "success"
        })
      );
      this.dispatchEvent(new CustomEvent("save"));
      this.closeModal();
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message:
            "Error saving attendance: " +
            (error.body ? error.body.message : error.message),
          variant: "error"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  formatTimeForApex(timeStr) {
    if (!timeStr) return null;
    // If it's already HH:mm:ss.SSSZ, leave it. If HH:mm, append seconds.
    if (timeStr.length === 5) return timeStr + ":00.000Z";
    return timeStr;
  }

  normalizeTimeForInput(timeValue) {
    if (!timeValue) return null;
    return String(timeValue).slice(0, 5);
  }
}