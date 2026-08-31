import getReferrals from "@salesforce/apex/PWChrono_EmployeeReferralController.getReferrals";
import getReferralById from "@salesforce/apex/PWChrono_EmployeeReferralController.getReferralById";
import saveReferral from "@salesforce/apex/PWChrono_EmployeeReferralController.saveReferral";
import deleteReferral from "@salesforce/apex/PWChrono_EmployeeReferralController.deleteReferral";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeeReferralController.getActiveDesignations";
import getJobApplicants from "@salesforce/apex/PWChrono_EmployeeReferralController.getJobApplicants";
import LightningConfirm from "lightning/confirm";
import { LightningElement, track } from "lwc";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { CONSTANTS } from "c/pwchronoConstants";

const STATUS_BADGE = {
  Pending: "badge bg-warning-subtle text-warning",
  "In Process": "badge bg-info-subtle text-info",
  Selected: "badge bg-success-subtle text-success",
  Rejected: "badge bg-danger-subtle text-danger"
};

const emptyRecord = () => ({
  Id: null,
  Name: "",
  Full_Name__c: "",
  Email__c: "",
  Mobile_Number__c: "",
  For_Designation__c: "",
  Status__c: "Pending",
  Job_Applicant__c: "",
  Current_Employee__c: "",
  Referral_Bonus_Amount__c: null,
  Is_Applicable_for_Referral_Bonus__c: false,
  Referral_Bonus_Payment_Status__c: "Not Applicable",
  Additional_Information__c: ""
});

export default class PwchronoEmployeeReferral extends LightningElement {
  static renderMode = "light";

  @track records = [];
  @track isLoading = true;
  @track isModalOpen = false;
  @track isSaving = false;
  @track statusFilter = "All";
  @track modalError = "";

  @track editRecord = emptyRecord();
  @track designationOptions = [];
  @track applicantOptions = [];

  _employeeId;
  _sessionToken;
  _role;

  connectedCallback() {
    const session = getSession();
    this._employeeId = session?.user?.Id ?? null;
    this._sessionToken = getSessionToken();
    this._role = session?.user?.Role__c ?? "";
    this._loadOptions();
    this._loadReferrals();
  }

  renderedCallback() {
    this._syncNativeControlValue("[data-status-filter]", this.statusFilter);

    if (!this.isModalOpen) return;

    this._syncNativeControlValue(
      '[data-field="For_Designation__c"]',
      this.editRecord.For_Designation__c
    );
    this._syncNativeControlValue(
      '[data-field="Status__c"]',
      this.editRecord.Status__c
    );
    this._syncNativeControlValue(
      '[data-field="Job_Applicant__c"]',
      this.editRecord.Job_Applicant__c
    );
    this._syncNativeControlValue(
      '[data-field="Referral_Bonus_Payment_Status__c"]',
      this.editRecord.Referral_Bonus_Payment_Status__c
    );
    this._syncNativeControlValue(
      '[data-field="Additional_Information__c"]',
      this.editRecord.Additional_Information__c
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  get isHrAdmin() {
    return this._role === CONSTANTS.ROLE_HR_ADMIN;
  }

  get modalTitle() {
    return this.editRecord.Id ? "Edit Referral" : "New Referral";
  }

  get totalCount() {
    return this.records.length;
  }

  get pendingCount() {
    return this.records.filter((r) => r.Status__c === "Pending").length;
  }

  get selectedCount() {
    return this.records.filter((r) => r.Status__c === "Selected").length;
  }

  get rejectedCount() {
    return this.records.filter((r) => r.Status__c === "Rejected").length;
  }

  get isEmpty() {
    return !this.isLoading && this.records.length === 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  _loadOptions() {
    getActiveDesignations()
      .then((d) => {
        this.designationOptions = d.map((x) => ({
          label: x.Name,
          value: x.Id
        }));
      })
      .catch(() => {});

    getJobApplicants()
      .then((a) => {
        this.applicantOptions = a.map((x) => ({ label: x.Name, value: x.Id }));
      })
      .catch(() => {});
  }

  _loadReferrals() {
    this.isLoading = true;
    getReferrals({
      statusFilter: this.statusFilter,
      portalUserId: this._employeeId,
      sessionToken: this._sessionToken
    })
      .then((recs) => {
        this.records = recs.map((r) => ({
          ...r,
          designationName: r.For_Designation__r?.Name ?? "—",
          employeeName: r.Current_Employee__r?.Name ?? "—",
          applicantName: r.Job_Applicant__r?.Name ?? "—",
          statusBadgeClass:
            STATUS_BADGE[r.Status__c] ||
            "badge bg-secondary-subtle text-secondary"
        }));
      })
      .catch(() => {
        this.records = [];
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filters
  // ─────────────────────────────────────────────────────────────────────────

  handleStatusFilter(event) {
    this.statusFilter = event.target.value;
    this._loadReferrals();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal
  // ─────────────────────────────────────────────────────────────────────────

  handleNew() {
    this.editRecord = emptyRecord();
    this.modalError = "";
    this.isModalOpen = true;
  }

  handleEdit(event) {
    const id = event.currentTarget.dataset.id;
    getReferralById({
      referralId: id,
      portalUserId: this._employeeId,
      sessionToken: this._sessionToken
    })
      .then((rec) => {
        this.editRecord = {
          ...emptyRecord(),
          ...rec,
          For_Designation__c: rec.For_Designation__c || "",
          Job_Applicant__c: rec.Job_Applicant__c || "",
          Current_Employee__c: rec.Current_Employee__c || ""
        };
        this.modalError = "";
        this.isModalOpen = true;
      })
      .catch(() => {});
  }

  handleCloseModal() {
    this.isModalOpen = false;
    this.modalError = "";
  }

  handleFieldChange(event) {
    const field = event.currentTarget.dataset.field;
    this.editRecord = { ...this.editRecord, [field]: event.target.value };
  }

  handleCheckboxChange(event) {
    const field = event.currentTarget.dataset.field;
    this.editRecord = { ...this.editRecord, [field]: event.target.checked };
  }

  _syncNativeControlValue(selector, value) {
    const element = this.querySelector(selector);
    const nextValue = value ?? "";
    if (element && element.value !== nextValue) {
      element.value = nextValue;
    }
  }

  handleSave() {
    this.modalError = "";
    if (!this._validate()) return;

    const payload = { ...this.editRecord };
    // Strip display-only relationship fields
    delete payload.For_Designation__r;
    delete payload.Current_Employee__r;
    delete payload.Job_Applicant__r;
    if (!payload.Id) delete payload.Id;
    if (!payload.For_Designation__c) payload.For_Designation__c = null;
    if (!payload.Job_Applicant__c) payload.Job_Applicant__c = null;
    if (!payload.Current_Employee__c) payload.Current_Employee__c = null;

    this.isSaving = true;
    saveReferral({
      referralJson: JSON.stringify(payload),
      portalUserId: this._employeeId,
      sessionToken: this._sessionToken
    })
      .then(() => {
        this.isModalOpen = false;
        this._loadReferrals();
      })
      .catch((err) => {
        this.modalError =
          err?.body?.message || "An error occurred while saving.";
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  async handleDelete(event) {
    const id = event.currentTarget.dataset.id;
    const confirmed = await LightningConfirm.open({
      message: "Delete this referral? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    deleteReferral({
      referralId: id,
      portalUserId: this._employeeId,
      sessionToken: this._sessionToken
    })
      .then(() => {
        this._loadReferrals();
      })
      .catch(() => {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    if (!this.editRecord.Name?.trim()) {
      this.modalError = "Referral Name is required.";
      return false;
    }
    if (!this.editRecord.Full_Name__c?.trim()) {
      this.modalError = "Candidate Full Name is required.";
      return false;
    }
    if (!this.editRecord.Email__c?.trim()) {
      this.modalError = "Email is required.";
      return false;
    }
    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRe.test(this.editRecord.Email__c.trim())) {
      this.modalError = "Please enter a valid email address.";
      return false;
    }
    return true;
  }
}