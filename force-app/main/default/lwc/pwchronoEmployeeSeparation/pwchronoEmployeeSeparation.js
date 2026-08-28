import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { PAGES } from "c/pwchronoRouter";

import getSeparations from "@salesforce/apex/PWChrono_EmployeeSeparationController.getSeparations";
import saveSeparation from "@salesforce/apex/PWChrono_EmployeeSeparationController.saveSeparation";
import deleteSeparation from "@salesforce/apex/PWChrono_EmployeeSeparationController.deleteSeparation";
import getChecklistItems from "@salesforce/apex/PWChrono_EmployeeSeparationController.getChecklistItems";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveEmployees";
import getActiveSeparationTemplates from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveSeparationTemplates";

const STATUS_BADGE = {
  Pending: "badge bg-secondary",
  "In Process": "badge bg-warning text-dark",
  Completed: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const CHECKLIST_BADGE = {
  Pending: "badge bg-secondary",
  "In Progress": "badge bg-warning text-dark",
  Completed: "badge bg-success"
};

const SEP_STATUSES = ["Pending", "In Process", "Completed", "Cancelled"];

let _keyCounter = 0;

function emptyChecklist() {
  return {
    _key: ++_keyCounter,
    Name: "",
    Assigned_To__c: "",
    Status__c: "Pending",
    Is_Required__c: false,
    Notes__c: ""
  };
}

function emptySeparation() {
  return {
    Id: null,
    Employee__c: "",
    Employee_Name__c: "",
    Company__c: "",
    Department__c: "",
    Designation__c: "",
    Separation_Template__c: "",
    Resignation_Letter_Date__c: "",
    Relieving_Date__c: "",
    Reason_for_Leaving__c: "",
    Status__c: "Pending"
  };
}

export default class PwchronoEmployeeSeparation extends LightningElement {
  static renderMode = "light";

  @track records = [];
  @track isLoading = false;
  @track isSaving = false;
  @track errorMessage = "";
  @track showModal = false;
  @track editRecord = emptySeparation();
  @track checklistRows = [];
  @track validationError = "";

  @track showChecklistModal = false;
  @track viewChecklistItems = [];
  @track isChecklistLoading = false;

  _statusFilter = "All";
  _session = null;
  _designations = [];
  _departments = [];
  _employees = [];
  _templates = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  connectedCallback() {
    this._session = getSession();
    this._loadOptions();
    this._loadSeparations();
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

  async _loadSeparations() {
    this.isLoading = true;
    this.errorMessage = "";
    try {
      this.records = await getSeparations({
        statusFilter: this._statusFilter,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to load separations.";
    } finally {
      this.isLoading = false;
    }
  }

  async _loadOptions() {
    try {
      const [desigs, depts, emps, tmpls] = await Promise.all([
        getActiveDesignations(),
        getActiveDepartments(),
        getActiveEmployees(),
        getActiveSeparationTemplates()
      ]);
      this._designations = desigs;
      this._departments = depts;
      this._employees = emps;
      this._templates = tmpls;
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
  get inProcessCount() {
    return this.records.filter((r) => r.Status__c === "In Process").length;
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
      desigName: r.Designation__r?.Name ?? "—"
    }));
  }

  get hasRecords() {
    return this.records.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    return ["All", ...SEP_STATUSES].map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadSeparations();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal dropdown options
  // ─────────────────────────────────────────────────────────────────────────

  get employeeOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label: e.Name,
      selected: this.editRecord.Employee__c === e.Id
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

  get templateOptions() {
    return this._templates.map((t) => ({
      value: t.Id,
      label: t.Name,
      selected: this.editRecord.Separation_Template__c === t.Id
    }));
  }

  get sepStatusOptions() {
    return SEP_STATUSES.map((s) => ({
      value: s,
      label: s,
      selected: this.editRecord.Status__c === s
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist rows
  // ─────────────────────────────────────────────────────────────────────────

  get hasChecklistRows() {
    return this.checklistRows.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal helpers
  // ─────────────────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.editRecord.Id ? "Edit Separation" : "New Separation";
  }

  get isEditMode() {
    return !!this.editRecord.Id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD handlers
  // ─────────────────────────────────────────────────────────────────────────

  handleCreate() {
    this.editRecord = emptySeparation();
    this.checklistRows = [];
    this.validationError = "";
    this.showModal = true;
  }

  handleEdit(evt) {
    const id = evt.currentTarget.dataset.id;
    const rec = this.records.find((r) => r.Id === id);
    if (!rec) return;
    this.editRecord = { ...rec };
    this.checklistRows = [];
    this.validationError = "";
    this.showModal = true;
  }

  handleModalClose() {
    this.showModal = false;
    this.editRecord = emptySeparation();
    this.checklistRows = [];
    this.validationError = "";
  }

  handleFieldChange(evt) {
    const field = evt.currentTarget.dataset.field;
    this.editRecord = { ...this.editRecord, [field]: evt.target.value };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist row management
  // ─────────────────────────────────────────────────────────────────────────

  handleAddChecklistRow() {
    this.checklistRows = [...this.checklistRows, emptyChecklist()];
  }

  handleRemoveChecklistRow(evt) {
    const key = Number(evt.currentTarget.dataset.key);
    this.checklistRows = this.checklistRows.filter((r) => r._key !== key);
  }

  handleChecklistChange(evt) {
    const key = Number(evt.currentTarget.dataset.key);
    const field = evt.currentTarget.dataset.field;
    const value =
      field === "Is_Required__c" ? evt.target.checked : evt.target.value;
    this.checklistRows = this.checklistRows.map((r) => {
      if (r._key === key) {
        return { ...r, [field]: value };
      }
      return r;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist view modal
  // ─────────────────────────────────────────────────────────────────────────

  async handleViewChecklist(evt) {
    const id = evt.currentTarget.dataset.id;
    this.showChecklistModal = true;
    this.isChecklistLoading = true;
    this.viewChecklistItems = [];
    try {
      const items = await getChecklistItems({
        separationId: id,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.viewChecklistItems = items.map((item) => ({
        ...item,
        assignedToName: item.Assigned_To__r?.Name ?? "—",
        checklistBadge: CHECKLIST_BADGE[item.Status__c] ?? "badge bg-secondary"
      }));
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to load checklist.";
      this.showChecklistModal = false;
    } finally {
      this.isChecklistLoading = false;
    }
  }

  get hasViewChecklistItems() {
    return this.viewChecklistItems.length > 0;
  }

  handleChecklistModalClose() {
    this.showChecklistModal = false;
    this.viewChecklistItems = [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    if (!this.editRecord.Employee__c) return "Employee is required.";
    if (!this.editRecord.Resignation_Letter_Date__c)
      return "Resignation Letter Date is required.";
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
      const cleanChecklist = this.checklistRows.map((row) => {
        const cleanRow = { ...row };
        ["_key", "isPending", "isInProgress", "isCompleted"].forEach(
          (field) => {
            delete cleanRow[field];
          }
        );
        return cleanRow;
      });
      await saveSeparation({
        separationJson: JSON.stringify(this.editRecord),
        checklistJson: JSON.stringify(cleanChecklist),
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadSeparations();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to save separation.";
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
      message: "Delete this separation record? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    try {
      await deleteSeparation({
        separationId: id,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadSeparations();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to delete separation.";
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