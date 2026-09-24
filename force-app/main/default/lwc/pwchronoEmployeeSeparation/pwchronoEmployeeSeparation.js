import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";

import getSeparations from "@salesforce/apex/PWChrono_EmployeeSeparationController.getSeparations";
import saveSeparation from "@salesforce/apex/PWChrono_EmployeeSeparationController.saveSeparation";
import updateSeparationStatus from "@salesforce/apex/PWChrono_EmployeeSeparationController.updateSeparationStatus";
import updateChecklistItemStatus from "@salesforce/apex/PWChrono_EmployeeSeparationController.updateChecklistItemStatus";
import deleteSeparation from "@salesforce/apex/PWChrono_EmployeeSeparationController.deleteSeparation";
import getChecklistItems from "@salesforce/apex/PWChrono_EmployeeSeparationController.getChecklistItems";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveEmployees";
import getActiveSeparationTemplates from "@salesforce/apex/PWChrono_EmployeeSeparationController.getActiveSeparationTemplates";

const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

const STATUS = {
  PENDING: "Pending",
  IN_PROCESS: "In Process",
  COMPLETED: "Completed",
  CANCELLED: "Cancelled"
};
const SEPARATION_STATUSES = Object.values(STATUS);
const OPEN_STATUSES = [STATUS.PENDING, STATUS.IN_PROCESS];
const DELETABLE_STATUSES = [STATUS.PENDING, STATUS.CANCELLED];

const CHECKLIST_STATUSES = ["Pending", "In Progress", "Completed"];

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

const STATUS_SUCCESS = {
  "In Process": "Separation moved to In Process.",
  Completed:
    "Separation completed. The employee has been deactivated and signed out of the portal.",
  Cancelled: "Separation cancelled."
};

/** Fields the server accepts from the form. Status is never sent. */
const EDITABLE_FIELDS = [
  "Employee__c",
  "Employee_Name__c",
  "Company__c",
  "Department__c",
  "Designation__c",
  "Separation_Template__c",
  "Resignation_Letter_Date__c",
  "Relieving_Date__c",
  "Reason_for_Leaving__c"
];

let keyCounter = 0;
function nextKey() {
  keyCounter += 1;
  return `cl_${keyCounter}`;
}

function emptySeparation() {
  const record = { Id: null, Status__c: STATUS.PENDING };
  EDITABLE_FIELDS.forEach((field) => {
    record[field] = "";
  });
  return record;
}

function emptyChecklistRow() {
  return {
    _key: nextKey(),
    Id: null,
    Name: "",
    Assigned_To__c: "",
    Status__c: "Pending",
    Is_Required__c: false,
    Notes__c: ""
  };
}

function toChecklistRow(item) {
  return {
    _key: nextKey(),
    Id: item.Id,
    Name: item.Name ?? "",
    Assigned_To__c: item.Assigned_To__c ?? "",
    Status__c: item.Status__c || "Pending",
    Is_Required__c: item.Is_Required__c === true,
    Notes__c: item.Notes__c ?? ""
  };
}

function childRecords(relationship) {
  if (Array.isArray(relationship)) return relationship;
  return Array.isArray(relationship?.records) ? relationship.records : [];
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

export default class PwchronoEmployeeSeparation extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";

  @track records = [];
  @track editRecord = emptySeparation();
  @track checklistRows = [];
  @track viewChecklistItems = [];
  isLoading = false;
  isSaving = false;
  hasLoaded = false;
  loadError = "";
  validationError = "";
  showModal = false;
  isReadOnly = false;
  checklistLoading = false;
  checklistEditable = true;
  checklistLoadError = "";
  showChecklistModal = false;
  isChecklistLoading = false;
  checklistSeparation = null;
  actionPendingId = null;

  _statusFilter = "All";
  _portalUserId = "";
  _role = "";
  _sessionToken = null;
  _designations = [];
  _departments = [];
  _employees = [];
  _templates = [];

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
    this._loadSeparations();
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

  async _loadSeparations() {
    this.isLoading = true;
    this.loadError = "";
    try {
      const rows = await getSeparations({
        statusFilter: this._statusFilter,
        ...this._authParams
      });
      this.records = Array.isArray(rows) ? rows : [];
      this.hasLoaded = true;
    } catch (error) {
      this.records = [];
      this.loadError = reduceError(error, "Failed to load separations.");
    } finally {
      this.isLoading = false;
    }
  }

  async _loadOptions() {
    try {
      const [designations, departments, employees, templates] =
        await Promise.all([
          getActiveDesignations(this._authParams),
          getActiveDepartments(this._authParams),
          getActiveEmployees(this._authParams),
          getActiveSeparationTemplates(this._authParams)
        ]);
      this._designations = designations || [];
      this._departments = departments || [];
      this._employees = employees || [];
      this._templates = templates || [];
    } catch (error) {
      this._designations = [];
      this._departments = [];
      this._employees = [];
      this._templates = [];
      this._toast(
        "Warning",
        reduceError(error, "Could not load the form options."),
        "warning"
      );
    }
  }

  handleRetry() {
    this._loadOptions();
    this._loadSeparations();
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
  get inProcessCount() {
    return this._countByStatus(STATUS.IN_PROCESS);
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
      const open = OPEN_STATUSES.includes(status);
      const items = childRecords(r.Checklist_Items__r);
      const required = items.filter((i) => i.Is_Required__c);
      const requiredDone = required.filter(
        (i) => i.Status__c === "Completed"
      ).length;
      const busy = this.actionPendingId === r.Id;
      return {
        ...r,
        statusBadgeClass: STATUS_BADGE[status] ?? "badge bg-secondary",
        employeeName: r.Employee__r?.Name ?? r.Employee_Name__c ?? "—",
        deptName: r.Department__r?.Name ?? "—",
        desigName: r.Designation__r?.Name ?? "—",
        resignationDateFormatted: formatDate(r.Resignation_Letter_Date__c),
        relievingDateFormatted: formatDate(r.Relieving_Date__c),
        checklistSummary: items.length
          ? `${requiredDone}/${required.length} required`
          : "No items",
        checklistReady: required.length === requiredDone,
        canEdit: open,
        canView: !open,
        canStart: isAdmin && status === STATUS.PENDING,
        canComplete: isAdmin && open,
        canCancel: isAdmin && open,
        canDelete: isAdmin && DELETABLE_STATUSES.includes(status),
        isBusy: busy
      };
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter and export
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    return ["All", ...SEPARATION_STATUSES].map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadSeparations();
  }

  handleExport() {
    const rows = this.enrichedRecords.map((r) => [
      r.Name,
      r.employeeName,
      r.Resignation_Letter_Date__c ?? "",
      r.Relieving_Date__c ?? "",
      r.deptName,
      r.desigName,
      r.Separation_Template__r?.Name ?? "",
      r.checklistSummary,
      r.Status__c
    ]);
    downloadCsv(
      "employee-separations.csv",
      [
        "Separation #",
        "Employee",
        "Resignation Date",
        "Relieving Date",
        "Department",
        "Designation",
        "Template",
        "Checklist",
        "Status"
      ],
      rows
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal options
  // ─────────────────────────────────────────────────────────────────────────

  get employeeOptions() {
    const selectedId = this.editRecord.Employee__c;
    const options = this._employees.map((e) => ({
      value: e.Id,
      label: e.Name,
      selected: selectedId === e.Id
    }));
    // A completed separation's employee is inactive and no longer in the
    // active list; keep them visible so the record still reads correctly.
    if (selectedId && !options.some((o) => o.value === selectedId)) {
      options.unshift({
        value: selectedId,
        label: `${this.editRecord._employeeLabel || "Selected employee"} (inactive)`,
        selected: true
      });
    }
    return options;
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

  /**
   * Checklist rows for the edit form. Item status is shown read-only: progress
   * is recorded from the checklist view. Only administrators may remove an
   * existing item or change whether it is required (the server enforces
   * this too); anyone may add, rename, assign or annotate items.
   */
  get checklistRowsView() {
    const isAdmin = this.isAdmin;
    const locked = this.checklistLocked;
    return this.checklistRows.map((row) => {
      const isExisting = !!row.Id;
      return {
        ...row,
        statusBadge: CHECKLIST_BADGE[row.Status__c] ?? "badge bg-secondary",
        requiredLocked: locked || (isExisting && !isAdmin),
        canRemove: !isExisting || isAdmin,
        assigneeOptions: this._employees.map((e) => ({
          value: e.Id,
          label: e.Name,
          selected: row.Assigned_To__c === e.Id
        }))
      };
    });
  }

  get showChecklistStatusHint() {
    return this.isEditMode && !this.isReadOnly;
  }

  get showChecklistPermissionHint() {
    return this.showChecklistStatusHint && !this.isAdmin;
  }

  get hasChecklistRows() {
    return this.checklistRows.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal state
  // ─────────────────────────────────────────────────────────────────────────

  get isEditMode() {
    return !!this.editRecord.Id;
  }

  get modalTitle() {
    if (this.isReadOnly) return "Separation Details";
    return this.isEditMode ? "Edit Separation" : "New Separation";
  }

  get modalStatusBadgeClass() {
    return `${STATUS_BADGE[this.editRecord.Status__c] ?? "badge bg-secondary"} ms-2`;
  }

  get isEditable() {
    return !this.isReadOnly;
  }

  get closeLabel() {
    return this.isReadOnly ? "Close" : "Cancel";
  }

  get employeeLocked() {
    return this.isReadOnly || this.isEditMode;
  }

  get checklistLocked() {
    return this.isReadOnly || !this.checklistEditable || this.checklistLoading;
  }

  get showTemplateNotice() {
    return (
      !this.isEditMode &&
      !!this.editRecord.Separation_Template__c &&
      this.checklistRows.length === 0
    );
  }

  get selectedTemplateName() {
    return (
      this._templates.find(
        (t) => t.Id === this.editRecord.Separation_Template__c
      )?.Name ?? "selected"
    );
  }

  get saveDisabled() {
    return this.isSaving || this.checklistLoading;
  }

  handleCreate() {
    this.editRecord = emptySeparation();
    this.checklistRows = [];
    this.checklistEditable = true;
    this.checklistLoadError = "";
    this.validationError = "";
    this.isReadOnly = false;
    this.showModal = true;
  }

  handleEdit(evt) {
    this._openExisting(evt.currentTarget.dataset.id, false);
  }

  handleView(evt) {
    this._openExisting(evt.currentTarget.dataset.id, true);
  }

  async _openExisting(id, readOnly) {
    const rec = this.records.find((r) => r.Id === id);
    if (!rec) return;
    // A blank (legacy) status is treated as Pending, as the server does.
    const status = rec.Status__c || STATUS.PENDING;
    const record = {
      Id: rec.Id,
      Status__c: status,
      _employeeLabel: rec.Employee__r?.Name ?? rec.Employee_Name__c ?? ""
    };
    EDITABLE_FIELDS.forEach((field) => {
      record[field] = rec[field] ?? "";
    });
    this.editRecord = record;
    this.isReadOnly = readOnly || !OPEN_STATUSES.includes(status);
    this.validationError = "";
    this.checklistRows = [];
    this.checklistEditable = false;
    this.checklistLoadError = "";
    this.showModal = true;
    this.checklistLoading = true;
    try {
      const items = await getChecklistItems({
        separationId: id,
        ...this._authParams
      });
      this.checklistRows = (items || []).map(toChecklistRow);
      this.checklistEditable = true;
    } catch (error) {
      this.checklistLoadError = reduceError(
        error,
        "The exit checklist could not be loaded."
      );
    } finally {
      this.checklistLoading = false;
    }
  }

  handleModalClose() {
    this.showModal = false;
    this.isReadOnly = false;
    this.editRecord = emptySeparation();
    this.checklistRows = [];
    this.validationError = "";
    this.checklistLoadError = "";
  }

  handleFieldChange(evt) {
    const field = evt.currentTarget.dataset.field;
    const value = evt.target.value;
    const next = { ...this.editRecord, [field]: value };
    if (field === "Employee__c") {
      const employee = this._employees.find((e) => e.Id === value);
      next.Employee_Name__c = employee?.Name ?? "";
    }
    this.editRecord = next;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist rows in the form
  // ─────────────────────────────────────────────────────────────────────────

  handleAddChecklistRow() {
    this.checklistRows = [...this.checklistRows, emptyChecklistRow()];
  }

  handleRemoveChecklistRow(evt) {
    const key = evt.currentTarget.dataset.key;
    this.checklistRows = this.checklistRows.filter(
      (r) => r._key !== key || (!!r.Id && !this.isAdmin)
    );
  }

  handleChecklistChange(evt) {
    const key = evt.currentTarget.dataset.key;
    const field = evt.currentTarget.dataset.field;
    const value =
      field === "Is_Required__c" ? evt.target.checked : evt.target.value;
    this.checklistRows = this.checklistRows.map((r) => {
      return r._key === key ? { ...r, [field]: value } : r;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    const rec = this.editRecord;
    if (!rec.Employee__c) return "Select the employee who is leaving.";
    if (!rec.Resignation_Letter_Date__c)
      return "Resignation letter date is required.";
    if (
      rec.Relieving_Date__c &&
      rec.Relieving_Date__c < rec.Resignation_Letter_Date__c
    ) {
      return "The relieving date cannot be before the resignation letter date.";
    }
    if (this.checklistRows.some((row) => !String(row.Name || "").trim())) {
      return "Each checklist item needs an activity name.";
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
    const usesTemplate = this.showTemplateNotice;
    const payload = { Id: this.editRecord.Id };
    EDITABLE_FIELDS.forEach((field) => {
      payload[field] = this.editRecord[field] || null;
    });
    // Item status is server-owned and never sent; progress is recorded from
    // the checklist view so a stale form cannot overwrite it.
    const checklist = this.checklistEditable
      ? this.checklistRows.map((row) => ({
          Id: row.Id || null,
          Name: String(row.Name || "").trim(),
          Assigned_To__c: row.Assigned_To__c || null,
          Is_Required__c: row.Is_Required__c === true,
          Notes__c: row.Notes__c || null
        }))
      : null;
    try {
      await saveSeparation({
        separationJson: JSON.stringify(payload),
        checklistJson: checklist ? JSON.stringify(checklist) : null,
        ...this._authParams
      });
      this.handleModalClose();
      let message = isNew ? "Separation created." : "Separation updated.";
      if (isNew && usesTemplate) {
        message += " The exit checklist was generated from the template.";
      }
      this._toast("Success", message, "success");
      await this._loadSeparations();
    } catch (error) {
      const message = reduceError(error, "Failed to save the separation.");
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

    if (status === STATUS.COMPLETED || status === STATUS.CANCELLED) {
      const confirmed = await LightningConfirm.open(
        status === STATUS.COMPLETED
          ? {
              label: "Complete separation?",
              theme: "warning",
              message:
                `Completing this separation deactivates ${rec.employeeName} ` +
                "and ends their portal access immediately; they will no " +
                "longer be able to sign in. All required checklist items must " +
                "be completed and the relieving date must have been reached. " +
                "This cannot be undone."
            }
          : {
              label: "Cancel separation?",
              theme: "warning",
              message: `Cancel the separation for ${rec.employeeName}? A cancelled separation cannot be reopened.`
            }
      );
      if (!confirmed) return;
    }

    this.actionPendingId = id;
    try {
      await updateSeparationStatus({
        separationId: id,
        newStatus: status,
        ...this._authParams
      });
      this._toast("Success", STATUS_SUCCESS[status], "success");
      await this._loadSeparations();
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to update the separation status."),
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
      message:
        "Delete this separation and its exit checklist? This cannot be undone.",
      label: "Delete separation?",
      theme: "warning"
    });
    if (!confirmed) return;
    this.actionPendingId = id;
    try {
      await deleteSeparation({ separationId: id, ...this._authParams });
      this._toast("Success", "Separation deleted.", "success");
      await this._loadSeparations();
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to delete the separation."),
        "error"
      );
    } finally {
      this.actionPendingId = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist progress modal
  // ─────────────────────────────────────────────────────────────────────────

  get hasViewChecklistItems() {
    return this.viewChecklistItems.length > 0;
  }

  get checklistModalTitle() {
    return this.checklistSeparation
      ? `Exit Checklist — ${this.checklistSeparation.employeeName}`
      : "Exit Checklist";
  }

  get checklistCanUpdate() {
    return !!this.checklistSeparation?.canEdit;
  }

  get checklistProgress() {
    const required = this.viewChecklistItems.filter((i) => i.Is_Required__c);
    const done = required.filter((i) => i.Status__c === "Completed").length;
    return `${done} of ${required.length} required items completed`;
  }

  async handleViewChecklist(evt) {
    const id = evt.currentTarget.dataset.id;
    this.checklistSeparation = this.enrichedRecords.find((r) => r.Id === id);
    this.showChecklistModal = true;
    await this._loadChecklistView(id);
  }

  async _loadChecklistView(id) {
    this.isChecklistLoading = true;
    try {
      const items = await getChecklistItems({
        separationId: id,
        ...this._authParams
      });
      this.viewChecklistItems = (items || []).map((item) =>
        this._decorateChecklistItem(item)
      );
    } catch (error) {
      this.viewChecklistItems = [];
      this.showChecklistModal = false;
      this._toast(
        "Error",
        reduceError(error, "Failed to load the exit checklist."),
        "error"
      );
    } finally {
      this.isChecklistLoading = false;
    }
  }

  _decorateChecklistItem(item) {
    return {
      ...item,
      assignedToName: item.Assigned_To__r?.Name ?? "Unassigned",
      checklistBadge: CHECKLIST_BADGE[item.Status__c] ?? "badge bg-secondary",
      statusOptions: CHECKLIST_STATUSES.map((s) => ({
        value: s,
        label: s,
        selected: item.Status__c === s
      }))
    };
  }

  async handleChecklistItemStatus(evt) {
    const itemId = evt.currentTarget.dataset.id;
    const newStatus = evt.target.value;
    const previous = this.viewChecklistItems;
    this.viewChecklistItems = previous.map((item) => {
      if (item.Id !== itemId) return item;
      return this._decorateChecklistItem({ ...item, Status__c: newStatus });
    });
    try {
      await updateChecklistItemStatus({
        checklistItemId: itemId,
        newStatus,
        ...this._authParams
      });
      this._toast("Success", "Checklist item updated.", "success");
      this._loadSeparations();
    } catch (error) {
      this.viewChecklistItems = previous;
      this._toast(
        "Error",
        reduceError(error, "Failed to update the checklist item."),
        "error"
      );
    }
  }

  handleChecklistModalClose() {
    this.showChecklistModal = false;
    this.viewChecklistItems = [];
    this.checklistSeparation = null;
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