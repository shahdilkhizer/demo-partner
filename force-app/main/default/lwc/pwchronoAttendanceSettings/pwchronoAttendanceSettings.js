import createShiftType from "@salesforce/apex/PWChrono_AttendanceController.createShiftType";
import getActiveShiftTypes from "@salesforce/apex/PWChrono_AttendanceController.getActiveShiftTypes";
import updateShiftType from "@salesforce/apex/PWChrono_AttendanceController.updateShiftType";
import { logError } from "c/pwchronoErrorHandler";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoAttendanceSettings extends LightningElement {
  @track shiftTypes = [];
  @track isLoading = true;
  @track settings = {
    geoTracking: false,
    remoteCheckin: true,
    autoCheckout: true,
    ipRestriction: false
  };

  // Modal State
  @track showModal = false;
  @track isEditMode = false;
  @track currentShift = {
    Name: "",
    Start_Time__c: null,
    End_Time__c: null,
    Grace_Period_Minutes__c: 0,
    Is_Active__c: true
  };

  get modalTitle() {
    return this.isEditMode ? "Edit Shift Type" : "Create Shift Type";
  }

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.loadShiftTypes();
  }

  async loadShiftTypes() {
    this.isLoading = true;
    try {
      const result = await getActiveShiftTypes();
      // Sanitize time fields (Apex Time sometimes returns as number of ms)
      this.shiftTypes = result.map((shift) => ({
        ...shift,
        Start_Time__c: this.convertTimeToString(shift.Start_Time__c),
        End_Time__c: this.convertTimeToString(shift.End_Time__c)
      }));
    } catch (error) {
      logError("pwchronoAttendanceSettings.loadShiftTypes", error);
      this.showToast("Error", "Failed to load shift types", "error");
    } finally {
      this.isLoading = false;
    }
  }

  convertTimeToString(value) {
    if (value === null || value === undefined) return null;
    if (typeof value === "string") return value;
    // Handle milliseconds from midnight
    if (typeof value === "number") {
      // If it's a valid timestamp, extracting time might work, but safer to assume ms from midnight
      const hours = Math.floor(value / 3600000);
      const minutes = Math.floor((value % 3600000) / 60000);
      const seconds = Math.floor(((value % 3600000) % 60000) / 1000);
      const pad = (n) => n.toString().padStart(2, "0");
      return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}.000`;
    }
    return String(value);
  }

  handleAddShiftType() {
    this.currentShift = {
      Name: "",
      Start_Time__c: null,
      End_Time__c: null,
      Grace_Period_Minutes__c: 0,
      Is_Active__c: true
    };
    this.isEditMode = false;
    this.showModal = true;
  }

  handleEdit(event) {
    const id = event.target.dataset.id;
    const shift = this.shiftTypes.find((s) => s.Id === id);
    if (shift) {
      this.currentShift = { ...shift };
      this.isEditMode = true;
      this.showModal = true;
    }
  }

  closeModal() {
    this.showModal = false;
    this.currentShift = {};
  }

  handleShiftChange(event) {
    const field = event.target.dataset.field;
    this.currentShift = {
      ...this.currentShift,
      [field]: event.target.value
    };
  }

  async handleSaveShift() {
    if (
      !this.currentShift.Name ||
      !this.currentShift.Start_Time__c ||
      !this.currentShift.End_Time__c
    ) {
      this.showToast("Error", "Please fill in all required fields", "error");
      return;
    }

    // Format times for Apex
    const shiftToSave = {
      ...this.currentShift,
      Start_Time__c: this.formatTimeForApex(this.currentShift.Start_Time__c),
      End_Time__c: this.formatTimeForApex(this.currentShift.End_Time__c)
    };

    this.isLoading = true;
    try {
      if (this.isEditMode) {
        await updateShiftType({
          shiftType: shiftToSave,
          portalUserId: this.employeeId,
          sessionToken: this.sessionToken
        });
        this.showToast("Success", "Shift Type updated successfully", "success");
      } else {
        await createShiftType({
          shiftType: shiftToSave,
          portalUserId: this.employeeId,
          sessionToken: this.sessionToken
        });
        this.showToast("Success", "Shift Type created successfully", "success");
      }
      this.closeModal();
      await this.loadShiftTypes();
    } catch (error) {
      this.showToast(
        "Error",
        "Failed to save shift type: " +
          (error.body ? error.body.message : error.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  formatTimeForApex(timeStr) {
    if (!timeStr) return null;
    // If it's HH:mm, append seconds and milliseconds
    if (timeStr.length === 5) return timeStr + ":00.000Z";
    return timeStr;
  }

  handleSettingChange(event) {
    const setting = event.target.dataset.setting;
    this.settings[setting] = event.target.checked;
    // In a real app, we would save this to the server here
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}