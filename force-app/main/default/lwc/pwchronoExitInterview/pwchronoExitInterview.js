import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { PAGES } from "c/pwchronoRouter";

import getInterviews from "@salesforce/apex/PWChrono_ExitInterviewController.getInterviews";
import saveInterview from "@salesforce/apex/PWChrono_ExitInterviewController.saveInterview";
import deleteInterview from "@salesforce/apex/PWChrono_ExitInterviewController.deleteInterview";
import getActiveDesignations from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveEmployees";
import getActiveSeparations from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveSeparations";

const STATUS_BADGE = {
  Pending: "badge bg-secondary",
  Scheduled: "badge bg-warning text-dark",
  Completed: "badge bg-success",
  Skipped: "badge bg-danger"
};

const EI_STATUSES = ["Pending", "Scheduled", "Completed", "Skipped"];

function emptyRecord() {
  return {
    Id: null,
    Employee__c: "",
    Employee_Name__c: "",
    Department__c: "",
    Designation__c: "",
    Separation__c: "",
    Interviewer__c: "",
    Interview_Date__c: "",
    Exit_Questionnaire__c: "",
    Employee_Feedback__c: "",
    Final_Remarks__c: "",
    Rating__c: "",
    Status__c: "Pending"
  };
}

export default class PwchronoExitInterview extends LightningElement {
  static renderMode = "light";

  @track records = [];
  @track isLoading = false;
  @track isSaving = false;
  @track errorMessage = "";
  @track showModal = false;
  @track editRecord = emptyRecord();
  @track validationError = "";

  _statusFilter = "All";
  _session = null;
  _designations = [];
  _departments = [];
  _employees = [];
  _separations = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  connectedCallback() {
    this._session = getSession();
    this._loadOptions();
    this._loadInterviews();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Session helpers
  // ─────────────────────────────────────────────────────────────────────────

  get _portalUserId() {
    return this._session?.portalUserId ?? "";
  }

  get _sessionToken() {
    return getSessionToken();
  }

  get isHrAdmin() {
    return this._session?.role === "HR Admin";
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  async _loadInterviews() {
    this.isLoading = true;
    this.errorMessage = "";
    try {
      this.records = await getInterviews({
        statusFilter: this._statusFilter,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to load exit interviews.";
    } finally {
      this.isLoading = false;
    }
  }

  async _loadOptions() {
    try {
      const [desigs, depts, emps, seps] = await Promise.all([
        getActiveDesignations(),
        getActiveDepartments(),
        getActiveEmployees(),
        getActiveSeparations()
      ]);
      this._designations = desigs;
      this._departments = depts;
      this._employees = emps;
      this._separations = seps;
    } catch {
      // non-fatal
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Metrics
  // ─────────────────────────────────────────────────────────────────────────

  get totalCount() {
    return this.records.length;
  }
  get pendingCount() {
    return this.records.filter((r) => r.Status__c === "Pending").length;
  }
  get scheduledCount() {
    return this.records.filter((r) => r.Status__c === "Scheduled").length;
  }
  get completedCount() {
    return this.records.filter((r) => r.Status__c === "Completed").length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enriched records
  // ─────────────────────────────────────────────────────────────────────────

  get enrichedRecords() {
    return this.records.map((r) => ({
      ...r,
      statusBadgeClass: STATUS_BADGE[r.Status__c] ?? "badge bg-secondary",
      employeeName: r.Employee__r?.Name ?? r.Employee_Name__c ?? "—",
      deptName: r.Department__r?.Name ?? "—",
      desigName: r.Designation__r?.Name ?? "—",
      interviewerName: r.Interviewer__r?.Name ?? "—"
    }));
  }

  get hasRecords() {
    return this.records.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    return ["All", ...EI_STATUSES].map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadInterviews();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal dropdown options
  // ─────────────────────────────────────────────────────────────────────────

  get employeeOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label: e.Name,
      selected: this.editRecord.Employee__c === e.Id,
      interviewerSelected: this.editRecord.Interviewer__c === e.Id
    }));
  }

  get departmentOptions() {
    return this._departments.map((d) => ({
      value: d.Id,
      label: d.Name,
      selected: this.editRecord.Department__c === d.Id
    }));
  }

  get designationOptions() {
    return this._designations.map((d) => ({
      value: d.Id,
      label: d.Name,
      selected: this.editRecord.Designation__c === d.Id
    }));
  }

  get separationOptions() {
    return this._separations.map((s) => ({
      value: s.Id,
      label: s.Name + (s.Employee__r?.Name ? " — " + s.Employee__r.Name : ""),
      selected: this.editRecord.Separation__c === s.Id
    }));
  }

  get ratingOptions() {
    return [1, 2, 3, 4, 5].map((n) => ({
      value: String(n),
      label: String(n),
      selected: String(this.editRecord.Rating__c) === String(n)
    }));
  }

  get eiStatusOptions() {
    return EI_STATUSES.map((s) => ({
      value: s,
      label: s,
      selected: this.editRecord.Status__c === s
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal helpers
  // ─────────────────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.editRecord.Id ? "Edit Exit Interview" : "New Exit Interview";
  }

  get isEditMode() {
    return !!this.editRecord.Id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD handlers
  // ─────────────────────────────────────────────────────────────────────────

  handleCreate() {
    this.editRecord = emptyRecord();
    this.validationError = "";
    this.showModal = true;
  }

  handleEdit(evt) {
    const id = evt.currentTarget.dataset.id;
    const rec = this.records.find((r) => r.Id === id);
    if (!rec) return;
    this.editRecord = { ...rec };
    this.validationError = "";
    this.showModal = true;
  }

  handleModalClose() {
    this.showModal = false;
    this.editRecord = emptyRecord();
    this.validationError = "";
  }

  handleFieldChange(evt) {
    const field = evt.currentTarget.dataset.field;
    this.editRecord = { ...this.editRecord, [field]: evt.target.value };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    if (!this.editRecord.Employee__c) return "Employee is required.";
    if (!this.editRecord.Interview_Date__c)
      return "Interview Date is required.";
    const rating = Number(this.editRecord.Rating__c);
    if (
      this.editRecord.Rating__c !== "" &&
      (isNaN(rating) || rating < 1 || rating > 5)
    ) {
      return "Rating must be between 1 and 5.";
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  async handleSave() {
    const err = this._validate();
    if (err) {
      this.validationError = err;
      return;
    }
    this.validationError = "";
    this.isSaving = true;
    try {
      await saveInterview({
        interviewJson: JSON.stringify(this.editRecord),
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadInterviews();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to save exit interview.";
    } finally {
      this.isSaving = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  async handleDelete(evt) {
    const id = evt.currentTarget.dataset.id ?? this.editRecord.Id;
    if (!id) return;
    const confirmed = await LightningConfirm.open({
      message: "Delete this exit interview record? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    try {
      await deleteInterview({
        interviewId: id,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadInterviews();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to delete exit interview.";
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Misc
  // ─────────────────────────────────────────────────────────────────────────

  clearError() {
    this.errorMessage = "";
  }

  handleHome() {
    const nav = this.template.closest("[data-navigate]");
    if (nav)
      nav.dispatchEvent(
        new CustomEvent("navigate", { detail: PAGES.HOME, bubbles: true })
      );
  }
}