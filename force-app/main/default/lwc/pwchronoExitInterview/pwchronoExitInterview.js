import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";

import getInterviews from "@salesforce/apex/PWChrono_ExitInterviewController.getInterviews";
import saveInterview from "@salesforce/apex/PWChrono_ExitInterviewController.saveInterview";
import updateInterviewStatus from "@salesforce/apex/PWChrono_ExitInterviewController.updateInterviewStatus";
import deleteInterview from "@salesforce/apex/PWChrono_ExitInterviewController.deleteInterview";
import getActiveDesignations from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveEmployees";
import getActiveSeparations from "@salesforce/apex/PWChrono_ExitInterviewController.getActiveSeparations";

const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

const STATUS = {
  PENDING: "Pending",
  SCHEDULED: "Scheduled",
  COMPLETED: "Completed",
  SKIPPED: "Skipped"
};
const INTERVIEW_STATUSES = Object.values(STATUS);
const EDITABLE_STATUSES = [STATUS.PENDING, STATUS.SCHEDULED];
const DELETABLE_STATUSES = [STATUS.PENDING, STATUS.SKIPPED];

const STATUS_BADGE = {
  Pending: "badge bg-secondary",
  Scheduled: "badge bg-warning text-dark",
  Completed: "badge bg-success",
  Skipped: "badge bg-danger"
};

const STATUS_SUCCESS = {
  Scheduled: "Exit interview scheduled.",
  Completed: "Exit interview marked as completed.",
  Skipped: "Exit interview skipped."
};

/** Fields the server accepts from the form. Status is never sent. */
const EDITABLE_FIELDS = [
  "Employee__c",
  "Employee_Name__c",
  "Department__c",
  "Designation__c",
  "Separation__c",
  "Interviewer__c",
  "Interview_Date__c",
  "Exit_Questionnaire__c",
  "Employee_Feedback__c",
  "Final_Remarks__c",
  "Rating__c"
];

function emptyRecord() {
  const record = { Id: null, Status__c: STATUS.PENDING };
  EDITABLE_FIELDS.forEach((field) => {
    record[field] = "";
  });
  return record;
}

function reduceError(error, fallback) {
  const bodies = Array.isArray(error?.body) ? error.body : [error?.body];
  const messages = bodies.map((body) => body?.message).filter(Boolean);
  if (messages.length) return messages.join(" ");
  return error?.message || fallback;
}

function formatDate(value) {
  if (!value) return "—";
  const [year, month, day] = String(value).split("-").map(Number);
  if (!year || !month || !day) return value;
  return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString(
    undefined,
    { year: "numeric", month: "short", day: "numeric", timeZone: "UTC" }
  );
}

export default class PwchronoExitInterview extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";

  @track records = [];
  @track editRecord = emptyRecord();
  isLoading = false;
  isSaving = false;
  hasLoaded = false;
  loadError = "";
  validationError = "";
  showModal = false;
  isReadOnly = false;
  actionPendingId = null;

  _statusFilter = "All";
  _portalUserId = "";
  _role = "";
  _sessionToken = null;
  _designations = [];
  _departments = [];
  _employees = [];
  _separations = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle and session
  // ─────────────────────────────────────────────────────────────────────────

  connectedCallback() {
    const session = getSession() || {};
    const user = session.user || {};
    this._portalUserId = session.portalUserId || user.Id || "";
    this._role = session.role || user.Role__c || "";
    this._sessionToken = getSessionToken();
    this._loadOptions();
    this._loadInterviews();
  }

  get _authParams() {
    return {
      portalUserId: this._portalUserId,
      sessionToken: this._sessionToken
    };
  }

  /** UI hint only; the server re-checks administrator rights on every call. */
  get isAdmin() {
    return ADMIN_ROLES.includes(this._role);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  async _loadInterviews() {
    this.isLoading = true;
    this.loadError = "";
    try {
      const rows = await getInterviews({
        statusFilter: this._statusFilter,
        ...this._authParams
      });
      this.records = Array.isArray(rows) ? rows : [];
      this.hasLoaded = true;
    } catch (error) {
      this.records = [];
      this.loadError = reduceError(error, "Failed to load exit interviews.");
    } finally {
      this.isLoading = false;
    }
  }

  async _loadOptions() {
    try {
      const [designations, departments, employees, separations] =
        await Promise.all([
          getActiveDesignations(this._authParams),
          getActiveDepartments(this._authParams),
          getActiveEmployees(this._authParams),
          getActiveSeparations(this._authParams)
        ]);
      this._designations = designations || [];
      this._departments = departments || [];
      this._employees = employees || [];
      this._separations = separations || [];
    } catch (error) {
      this._designations = [];
      this._departments = [];
      this._employees = [];
      this._separations = [];
      this._toast(
        "Warning",
        reduceError(error, "Could not load the form options."),
        "warning"
      );
    }
  }

  handleRetry() {
    this._loadOptions();
    this._loadInterviews();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page state and metrics
  // ─────────────────────────────────────────────────────────────────────────

  get canCreate() {
    return this.hasLoaded && !this.loadError;
  }

  get showTable() {
    return !this.isLoading && !this.loadError;
  }

  get hasRecords() {
    return this.records.length > 0;
  }

  get totalCount() {
    return this.records.length;
  }
  get pendingCount() {
    return this._countByStatus(STATUS.PENDING);
  }
  get scheduledCount() {
    return this._countByStatus(STATUS.SCHEDULED);
  }
  get completedCount() {
    return this._countByStatus(STATUS.COMPLETED);
  }

  _countByStatus(status) {
    return this.records.filter((r) => r.Status__c === status).length;
  }

  get enrichedRecords() {
    const isAdmin = this.isAdmin;
    return this.records.map((r) => {
      const status = r.Status__c || STATUS.PENDING;
      const editable = EDITABLE_STATUSES.includes(status);
      return {
        ...r,
        statusBadgeClass: STATUS_BADGE[status] ?? "badge bg-secondary",
        employeeName: r.Employee__r?.Name ?? r.Employee_Name__c ?? "—",
        deptName: r.Department__r?.Name ?? "—",
        desigName: r.Designation__r?.Name ?? "—",
        interviewerName: r.Interviewer__r?.Name ?? "—",
        separationName: r.Separation__r?.Name ?? "—",
        interviewDateFormatted: formatDate(r.Interview_Date__c),
        hasRating: r.Rating__c !== null && r.Rating__c !== undefined,
        canEdit: editable,
        canView: !editable,
        canSchedule: isAdmin && status === STATUS.PENDING,
        canComplete: isAdmin && editable,
        canSkip: isAdmin && editable,
        canDelete: isAdmin && DELETABLE_STATUSES.includes(status),
        isBusy: this.actionPendingId === r.Id
      };
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter and export
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    return ["All", ...INTERVIEW_STATUSES].map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadInterviews();
  }

  handleExport() {
    const rows = this.enrichedRecords.map((r) => [
      r.Name,
      r.employeeName,
      r.separationName,
      r.deptName,
      r.desigName,
      r.Interview_Date__c ?? "",
      r.interviewerName,
      r.hasRating ? r.Rating__c : "",
      r.Status__c
    ]);
    downloadCsv(
      "exit-interviews.csv",
      [
        "Interview #",
        "Employee",
        "Separation",
        "Department",
        "Designation",
        "Interview Date",
        "Interviewer",
        "Rating",
        "Status"
      ],
      rows
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal options
  // ─────────────────────────────────────────────────────────────────────────

  get employeeOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label: e.Is_Active__c === false ? `${e.Name} (inactive)` : e.Name,
      selected: this.editRecord.Employee__c === e.Id
    }));
  }

  get interviewerOptions() {
    return this._employees
      .filter(
        (e) =>
          e.Is_Active__c !== false || e.Id === this.editRecord.Interviewer__c
      )
      .map((e) => ({
        value: e.Id,
        label: e.Name,
        selected: this.editRecord.Interviewer__c === e.Id
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

  // ─────────────────────────────────────────────────────────────────────────
  // Modal state
  // ─────────────────────────────────────────────────────────────────────────

  get isEditMode() {
    return !!this.editRecord.Id;
  }

  get isEditable() {
    return !this.isReadOnly;
  }

  get modalTitle() {
    if (this.isReadOnly) return "Exit Interview Details";
    return this.isEditMode ? "Edit Exit Interview" : "New Exit Interview";
  }

  get modalStatusBadgeClass() {
    return `${STATUS_BADGE[this.editRecord.Status__c] ?? "badge bg-secondary"} ms-2`;
  }

  get closeLabel() {
    return this.isReadOnly ? "Close" : "Cancel";
  }

  handleCreate() {
    this.editRecord = emptyRecord();
    this.validationError = "";
    this.isReadOnly = false;
    this.showModal = true;
  }

  handleEdit(evt) {
    this._openExisting(evt.currentTarget.dataset.id);
  }

  handleView(evt) {
    this._openExisting(evt.currentTarget.dataset.id);
  }

  _openExisting(id) {
    const rec = this.records.find((r) => r.Id === id);
    if (!rec) return;
    // A blank (legacy) status is treated as Pending, as the server does.
    const status = rec.Status__c || STATUS.PENDING;
    const record = { Id: rec.Id, Status__c: status };
    EDITABLE_FIELDS.forEach((field) => {
      const value = rec[field];
      record[field] = value === null || value === undefined ? "" : value;
    });
    this.editRecord = record;
    this.isReadOnly = !EDITABLE_STATUSES.includes(status);
    this.validationError = "";
    this.showModal = true;
  }

  handleModalClose() {
    this.showModal = false;
    this.isReadOnly = false;
    this.editRecord = emptyRecord();
    this.validationError = "";
  }

  handleFieldChange(evt) {
    const field = evt.currentTarget.dataset.field;
    const value = evt.target.value;
    const next = { ...this.editRecord, [field]: value };
    if (field === "Employee__c") {
      next.Employee_Name__c =
        this._employees.find((e) => e.Id === value)?.Name ?? "";
    }
    if (field === "Separation__c" && value) {
      const separation = this._separations.find((s) => s.Id === value);
      if (separation) {
        if (!next.Employee__c && separation.Employee__c) {
          next.Employee__c = separation.Employee__c;
          next.Employee_Name__c =
            separation.Employee__r?.Name ?? separation.Employee_Name__c ?? "";
        }
        if (!next.Department__c) next.Department__c = separation.Department__c;
        if (!next.Designation__c)
          next.Designation__c = separation.Designation__c;
      }
    }
    this.editRecord = next;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    const rec = this.editRecord;
    if (!rec.Employee__c) return "Select the employee for this exit interview.";
    if (!rec.Interview_Date__c) return "Interview date is required.";
    if (rec.Rating__c !== "" && rec.Rating__c !== null) {
      const rating = Number(rec.Rating__c);
      if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
        return "Rating must be a whole number from 1 to 5.";
      }
    }
    return null;
  }

  async handleSave() {
    if (this.isReadOnly) return;
    const err = this._validate();
    if (err) {
      this.validationError = err;
      return;
    }
    this.validationError = "";
    this.isSaving = true;
    const isNew = !this.editRecord.Id;
    const payload = { Id: this.editRecord.Id };
    EDITABLE_FIELDS.forEach((field) => {
      const value = this.editRecord[field];
      payload[field] = value === "" || value === undefined ? null : value;
    });
    try {
      await saveInterview({
        interviewJson: JSON.stringify(payload),
        ...this._authParams
      });
      this.handleModalClose();
      this._toast(
        "Success",
        isNew ? "Exit interview created." : "Exit interview updated.",
        "success"
      );
      await this._loadInterviews();
    } catch (error) {
      const message = reduceError(error, "Failed to save the exit interview.");
      this.validationError = message;
      this._toast("Error", message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow
  // ─────────────────────────────────────────────────────────────────────────

  async handleStatusAction(evt) {
    const { id, status } = evt.currentTarget.dataset;
    const rec = this.enrichedRecords.find((r) => r.Id === id);
    if (!rec || this.actionPendingId) return;

    if (status === STATUS.COMPLETED || status === STATUS.SKIPPED) {
      const confirmed = await LightningConfirm.open({
        label:
          status === STATUS.COMPLETED
            ? "Mark interview as completed?"
            : "Skip exit interview?",
        theme: "warning",
        message:
          status === STATUS.COMPLETED
            ? `Mark the exit interview with ${rec.employeeName} as completed? Completed interviews can no longer be edited.`
            : `Skip the exit interview with ${rec.employeeName}? Skipped interviews can no longer be edited.`
      });
      if (!confirmed) return;
    }

    this.actionPendingId = id;
    try {
      await updateInterviewStatus({
        interviewId: id,
        newStatus: status,
        ...this._authParams
      });
      this._toast("Success", STATUS_SUCCESS[status], "success");
      await this._loadInterviews();
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to update the exit interview status."),
        "error"
      );
    } finally {
      this.actionPendingId = null;
    }
  }

  async handleDelete(evt) {
    const id = evt.currentTarget.dataset.id;
    if (!id || this.actionPendingId) return;
    const confirmed = await LightningConfirm.open({
      message: "Delete this exit interview? This cannot be undone.",
      label: "Delete exit interview?",
      theme: "warning"
    });
    if (!confirmed) return;
    this.actionPendingId = id;
    try {
      await deleteInterview({ interviewId: id, ...this._authParams });
      this._toast("Success", "Exit interview deleted.", "success");
      await this._loadInterviews();
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to delete the exit interview."),
        "error"
      );
    } finally {
      this.actionPendingId = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Misc
  // ─────────────────────────────────────────────────────────────────────────

  _toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  handleHome(evt) {
    evt?.preventDefault();
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "Home" }
    });
  }
}