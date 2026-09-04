import { LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { logError } from "c/pwchronoErrorHandler";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import getMyLeaveBalance from "@salesforce/apex/PWChrono_LeaveController.getMyLeaveBalance";
import saveLeaveApplication from "@salesforce/apex/PWChrono_LeaveController.saveLeaveApplication";

export default class PwchronoLeaveApplication extends LightningElement {
  @track leaveRecord = {
    Leave_Type__c: "",
    From_Date__c: null,
    To_Date__c: null,
    Half_Day__c: false,
    Reason__c: "",
    Status__c: "Submitted"
  };

  leaveTypeOptions = [];
  leaveBalances = {};
  isLoading = false;

  employeeId;
  sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  errorCallback(error) {
    logError("PwchronoLeaveApplication", error, true);
  }

  get totalDays() {
    const from = this.leaveRecord.From_Date__c;
    const to = this.leaveRecord.To_Date__c;
    if (!from || !to) return 0;

    if (this.leaveRecord.Half_Day__c) return 0.5;

    const start = new Date(from);
    const end = new Date(to);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;

    const diffMs = end.getTime() - start.getTime();
    const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
    return diffDays + 1;
  }

  @wire(getActiveLeaveTypes)
  wiredLeaveTypes({ error, data }) {
    if (data) {
      this.leaveTypeOptions = data.map((type) => ({
        label: type.Name,
        value: type.Id
      }));
    } else if (error) {
      logError("wiredLeaveTypes", error, true, {
        dispatchEvent: this.dispatchEvent.bind(this)
      });
    }
  }

  @wire(getMyLeaveBalance, {
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredBalances({ error, data }) {
    if (data) {
      // Create a map using Leave Type ID for proper lookup
      this.leaveBalances = {};
      data.forEach((wrapper) => {
        // Store remaining balance keyed by leave type ID
        this.leaveBalances[wrapper.leaveTypeId] = wrapper.remaining;
      });
    } else if (error) {
      logError("wiredBalances", error, true, {
        dispatchEvent: this.dispatchEvent.bind(this)
      });
    }
  }

  get selectedLeaveBalance() {
    if (!this.leaveRecord.Leave_Type__c) return null;
    // Direct lookup by Leave Type ID
    return this.leaveBalances[this.leaveRecord.Leave_Type__c] || 0;
  }

  get isSubmitDisabled() {
    const { Leave_Type__c, From_Date__c, To_Date__c, Reason__c } =
      this.leaveRecord;
    const isValidDateRange =
      From_Date__c &&
      To_Date__c &&
      new Date(From_Date__c) <= new Date(To_Date__c);

    return (
      !Leave_Type__c ||
      !From_Date__c ||
      !To_Date__c ||
      !Reason__c ||
      !isValidDateRange
    );
  }

  handleLeaveTypeChange(event) {
    this.leaveRecord.Leave_Type__c = event.detail.value;
  }

  handleDateChange(event) {
    const field = event.target.name;
    this.leaveRecord[field === "fromDate" ? "From_Date__c" : "To_Date__c"] =
      event.detail.value;
  }

  handleHalfDayChange(event) {
    this.leaveRecord.Half_Day__c = event.target.checked;
  }

  handleReasonChange(event) {
    this.leaveRecord.Reason__c = event.detail.value;
  }

  handleCancel() {
    this.resetForm();
  }

  validateInputs() {
    const allValid = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-combobox, lightning-textarea"
      )
    ].reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);
    return allValid;
  }

  handleSubmit() {
    if (!this.validateInputs()) {
      return;
    }

    this.isLoading = true;
    const leaveToSave = {
      ...this.leaveRecord,
      Total_Days__c: this.totalDays,
      sobjectType: "Leave__c"
    };

    saveLeaveApplication({
      leaveRecord: leaveToSave,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          "Leave application submitted successfully",
          "success"
        );
        this.resetForm();
        // Dispatch event to refresh other components if needed
        this.dispatchEvent(new CustomEvent("leaveapplied"));
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  resetForm() {
    this.leaveRecord = {
      Leave_Type__c: "",
      From_Date__c: null,
      To_Date__c: null,
      Half_Day__c: false,
      Reason__c: "",
      Status__c: "Submitted"
    };
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}