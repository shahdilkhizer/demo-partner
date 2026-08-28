import { LightningElement, api, track } from "lwc";
import saveAttendanceRequest from "@salesforce/apex/PWChrono_AttendanceController.saveAttendanceRequest";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoAttendanceModal extends LightningElement {
  @api isOpen = false;
  @api recordId;

  @track attendanceDate;
  @track fromTime;
  @track toTime;
  @track status = "Present";
  @track productionHours = "0h";

  _record;

  @api
  get record() {
    return this._record;
  }
  set record(value) {
    this._record = value;
    if (value) {
      this.attendanceDate = value.Attendance_Date__c;
      this.fromTime = value.From_Time__c; // Expecting HH:mm:ss.SSSZ or similar, might need formatting
      this.toTime = value.To_Time__c;
      this.status = value.Status__c || "Present";
      this.calculateProduction();
    } else {
      // Reset for new
      this.attendanceDate = new Date().toISOString().split("T")[0];
      this.fromTime = null;
      this.toTime = null;
      this.status = "Present";
      this.productionHours = "0h";
    }
  }

  get modalTitle() {
    return this.recordId ? "Edit Attendance" : "Add Attendance";
  }

  get isPresent() {
    return this.status === "Present";
  }
  get isAbsent() {
    return this.status === "Absent";
  }
  get isLate() {
    return this.status === "Late";
  }
  get isOnLeave() {
    return this.status === "On Leave";
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
    const attendanceRecord = {
      sobjectType: "PWChrono_Attendance_Request__c",
      Id: this.recordId,
      Attendance_Date__c: this.attendanceDate,
      From_Time__c: this.formatTimeForApex(this.fromTime),
      To_Time__c: this.formatTimeForApex(this.toTime),
      Status__c: this.status
    };

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
    }
  }

  formatTimeForApex(timeStr) {
    if (!timeStr) return null;
    // If it's already HH:mm:ss.SSSZ, leave it. If HH:mm, append seconds.
    if (timeStr.length === 5) return timeStr + ":00.000Z";
    return timeStr;
  }
}