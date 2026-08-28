import { LightningElement, api, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import submitAttendanceRequest from "@salesforce/apex/PWChrono_AttendanceController.submitAttendanceRequest";

const CORRECTION_TYPES = [
  { label: "Check-In Missing",  value: "Check-In Missing" },
  { label: "Check-Out Missing", value: "Check-Out Missing" },
  { label: "Both Missing",      value: "Both Missing" },
  { label: "Wrong Time",        value: "Wrong Time" },
  { label: "Other",             value: "Other" }
];

// Types that require check-in / check-out
const NEEDS_CHECKIN  = new Set(["Check-In Missing",  "Both Missing", "Wrong Time"]);
const NEEDS_CHECKOUT = new Set(["Check-Out Missing", "Both Missing", "Wrong Time"]);

export default class PwchronoAttendanceRequestForm extends LightningElement {
  static renderMode = "light";

  /** Pre-fill the date field when opened from calendar day click. */
  @api prefillDate = "";

  @track formData = {
    attendanceDate: "",
    correctionType: "",
    requestedCheckIn: "",
    requestedCheckOut: "",
    reason: ""
  };

  @track isSubmitting = false;
  @track formError = null;

  // Field-level errors
  @track dateError    = null;
  @track typeError    = null;
  @track checkInError  = null;
  @track checkOutError = null;
  @track reasonError  = null;

  correctionTypeOptions = CORRECTION_TYPES;

  employeeId   = getEmployeeId();
  sessionToken = getSessionToken();

  connectedCallback() {
    if (this.prefillDate) {
      this.formData = { ...this.formData, attendanceDate: this.prefillDate };
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get todayIso() {
    return new Date().toISOString().split("T")[0];
  }

  get showCheckIn() {
    return NEEDS_CHECKIN.has(this.formData.correctionType);
  }
  get showCheckOut() {
    return NEEDS_CHECKOUT.has(this.formData.correctionType);
  }
  get checkInRequired() {
    return NEEDS_CHECKIN.has(this.formData.correctionType);
  }
  get checkOutRequired() {
    return NEEDS_CHECKOUT.has(this.formData.correctionType);
  }

  // Input CSS classes — add is-invalid when there's an error
  get dateClass()     { return this.dateError     ? "form-control is-invalid" : "form-control"; }
  get typeClass()     { return this.typeError     ? "form-select is-invalid"  : "form-select"; }
  get checkInClass()  { return this.checkInError  ? "form-control is-invalid" : "form-control"; }
  get checkOutClass() { return this.checkOutError ? "form-control is-invalid" : "form-control"; }
  get reasonClass()   { return this.reasonError   ? "form-control is-invalid" : "form-control"; }

  // ── Handlers ──────────────────────────────────────────────────────────────

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    this.formData = { ...this.formData, [field]: value };
    // Clear field-level error on change
    this[`${field.replace(/([A-Z])/g, (m) => m.toLowerCase())}Error`] = null;
    this.formError = null;
  }

  handleSubmit() {
    if (!this.validateForm()) return;
    this.isSubmitting = true;
    this.formError    = null;

    submitAttendanceRequest({
      dto: {
        attendanceDate:     this.formData.attendanceDate,
        correctionType:     this.formData.correctionType,
        requestedCheckIn:   this.showCheckIn  ? this.formData.requestedCheckIn  : null,
        requestedCheckOut:  this.showCheckOut ? this.formData.requestedCheckOut : null,
        reason:             this.formData.reason
      },
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        this.dispatchEvent(
          new CustomEvent("requestsubmitted", {
            detail: { requestId: result.Id, request: result },
            bubbles: true,
            composed: true
          })
        );
      })
      .catch((err) => {
        this.formError = err?.body?.message || err?.message || "Error submitting request.";
      })
      .finally(() => {
        this.isSubmitting = false;
      });
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel", { bubbles: true, composed: true }));
  }

  // ── Validation ────────────────────────────────────────────────────────────

  validateForm() {
    let valid = true;

    // Date
    if (!this.formData.attendanceDate) {
      this.dateError = "Attendance date is required.";
      valid = false;
    } else if (this.formData.attendanceDate > this.todayIso) {
      this.dateError = "Attendance date cannot be in the future.";
      valid = false;
    } else {
      this.dateError = null;
    }

    // Correction type
    if (!this.formData.correctionType) {
      this.typeError = "Correction type is required.";
      valid = false;
    } else {
      this.typeError = null;
    }

    // Check-in
    if (this.checkInRequired && !this.formData.requestedCheckIn) {
      this.checkInError = "Check-in time is required for this correction type.";
      valid = false;
    } else {
      this.checkInError = null;
    }

    // Check-out
    if (this.checkOutRequired && !this.formData.requestedCheckOut) {
      this.checkOutError = "Check-out time is required for this correction type.";
      valid = false;
    } else {
      this.checkOutError = null;
    }

    // Time order
    if (
      this.formData.requestedCheckIn &&
      this.formData.requestedCheckOut &&
      this.formData.requestedCheckIn >= this.formData.requestedCheckOut
    ) {
      this.checkInError  = "Check-in time must be before check-out time.";
      this.checkOutError = " ";
      valid = false;
    }

    // Reason
    if (!this.formData.reason || !this.formData.reason.trim()) {
      this.reasonError = "Reason is required.";
      valid = false;
    } else {
      this.reasonError = null;
    }

    return valid;
  }
}