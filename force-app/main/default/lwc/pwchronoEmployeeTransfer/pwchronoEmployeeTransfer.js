import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";

import getAccessInfo from "@salesforce/apex/PWChrono_EmployeeTransferController.getAccessInfo";
import getTransfers from "@salesforce/apex/PWChrono_EmployeeTransferController.getTransfers";
import getTransferById from "@salesforce/apex/PWChrono_EmployeeTransferController.getTransferById";
import saveTransfer from "@salesforce/apex/PWChrono_EmployeeTransferController.saveTransfer";
import updateTransferStatus from "@salesforce/apex/PWChrono_EmployeeTransferController.updateTransferStatus";
import deleteTransfer from "@salesforce/apex/PWChrono_EmployeeTransferController.deleteTransfer";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeeTransferController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_EmployeeTransferController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_EmployeeTransferController.getActiveEmployees";

/** Used only until the server reports whether the caller is an admin. */
const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

const STATUS = {
  DRAFT: "Draft",
  SUBMITTED: "Submitted",
  APPROVED: "Approved",
  CANCELLED: "Cancelled"
};
const TRANSFER_STATUSES = Object.values(STATUS);
const EDITABLE_STATUSES = [STATUS.DRAFT, STATUS.SUBMITTED];
const DELETABLE_STATUSES = [STATUS.DRAFT, STATUS.CANCELLED];

const STATUS_BADGE = {
  Draft: "badge bg-secondary",
  Submitted: "badge bg-warning text-dark",
  Approved: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const STATUS_ACTION_LABELS = {
  Submitted: "Transfer submitted for approval.",
  Draft: "Transfer returned to draft.",
  Approved: "Transfer approved. The employee record has been updated.",
  Cancelled: "Transfer cancelled."
};

const SELF_MESSAGE = "You cannot manage a transfer for yourself.";

/**
 * Fields the server accepts from the form. Status, the employee name and the
 * current department, designation and reporting manager are never sent; the
 * server takes them from the employee record.
 */
const EDITABLE_FIELDS = [
  "Employee__c",
  "Company__c",
  "Transfer_Date__c",
  "Current_Branch__c",
  "New_Branch__c",
  "New_Department__c",
  "New_Designation__c",
  "New_Reports_To__c",
  "Transfer_Details__c"
];

function emptyTransfer() {
  const record = {
    Id: null,
    Status__c: STATUS.DRAFT,
    Employee_Name__c: "",
    currentDepartmentName: "",
    currentDesignationName: "",
    currentReportsToName: "",
    canEdit: true,
    canDelete: false,
    readOnlyReason: ""
  };
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

export default class PwchronoEmployeeTransfer extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";

  @track records = [];
  @track editRecord = emptyTransfer();
  isLoading = false;
  isSaving = false;
  actionPendingId = null;
  hasLoaded = false;
  loadError = "";
  errorMessage = "";
  validationError = "";
  showModal = false;

  _statusFilter = "All";
  _portalUserId = "";
  _role = "";
  _sessionToken = null;
  _serverIsAdmin = null;
  _designations = [];
  _departments = [];
  _employees = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  connectedCallback() {
    const session = getSession() || {};
    const user = session.user || {};
    this._portalUserId = user.Id || session.portalUserId || "";
    this._role = user.Role__c || user.role || session.role || "";
    this._sessionToken = getSessionToken();
    this._loadAccess();
    this._loadOptions();
    this._loadTransfers();
  }

  get _authParams() {
    return {
      portalUserId: this._portalUserId,
      sessionToken: this._sessionToken
    };
  }

  /** The server decides; the session role is only used until it answers. */
  get isAdmin() {
    if (typeof this._serverIsAdmin === "boolean") {
      return this._serverIsAdmin;
    }
    return ADMIN_ROLES.includes(this._role);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  async _loadAccess() {
    // A failure here is reported by the list load; keep the role fallback.
    const info = await getAccessInfo(this._authParams).catch(() => null);
    this._serverIsAdmin =
      typeof info?.isAdmin === "boolean" ? info.isAdmin : null;
  }

  async _loadTransfers() {
    this.isLoading = true;
    this.loadError = "";
    try {
      const rows = await getTransfers({
        statusFilter: this._statusFilter,
        ...this._authParams
      });
      this.records = Array.isArray(rows) ? rows : [];
      this.hasLoaded = true;
    } catch (error) {
      this.records = [];
      this.loadError = reduceError(error, "Failed to load transfers.");
    } finally {
      this.isLoading = false;
    }
  }

  async _loadOptions() {
    try {
      const [designations, departments, employees] = await Promise.all([
        getActiveDesignations(this._authParams),
        getActiveDepartments(this._authParams),
        getActiveEmployees(this._authParams)
      ]);
      this._designations = designations || [];
      this._departments = departments || [];
      this._employees = employees || [];
    } catch (error) {
      this._designations = [];
      this._departments = [];
      this._employees = [];
      this._toast(
        "Warning",
        reduceError(error, "Could not load the form options."),
        "warning"
      );
    }
  }

  handleRetry() {
    this._loadAccess();
    this._loadOptions();
    this._loadTransfers();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page state
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
  get draftCount() {
    return this._countByStatus(STATUS.DRAFT);
  }
  get submittedCount() {
    return this._countByStatus(STATUS.SUBMITTED);
  }
  get approvedCount() {
    return this._countByStatus(STATUS.APPROVED);
  }

  _countByStatus(status) {
    return this.records.filter((r) => r.Status__c === status).length;
  }

  /**
   * What the current user may do with a transfer. Mirrors the server rules:
   * admins manage the workflow, others only edit drafts, and nobody manages
   * their own transfer.
   */
  _permissionsFor(record) {
    const status = record.Status__c || STATUS.DRAFT;
    const isAdmin = this.isAdmin;
    const isSelf =
      !!record.Employee__c && record.Employee__c === this._portalUserId;
    const manage = isAdmin && !isSelf;
    let readOnlyReason = "";
    if (!EDITABLE_STATUSES.includes(status)) {
      readOnlyReason = `This transfer is ${status} and can no longer be edited.`;
    } else if (isSelf) {
      readOnlyReason = `${SELF_MESSAGE} Ask another HR user to make changes.`;
    } else if (status === STATUS.SUBMITTED && !isAdmin) {
      readOnlyReason =
        "This transfer has been submitted for approval. Only an HR administrator can change it now.";
    }
    return {
      status,
      canEdit: !readOnlyReason,
      readOnlyReason,
      canSubmit: manage && status === STATUS.DRAFT,
      canReturnToDraft: manage && status === STATUS.SUBMITTED,
      canApprove: manage && status === STATUS.SUBMITTED,
      canCancel: manage && EDITABLE_STATUSES.includes(status),
      canDelete: manage && DELETABLE_STATUSES.includes(status)
    };
  }

  get enrichedRecords() {
    return this.records.map((r) => {
      const perms = this._permissionsFor(r);
      return {
        ...r,
        statusBadgeClass: STATUS_BADGE[perms.status] ?? "badge bg-secondary",
        employeeName: r.Employee__r?.Name ?? r.Employee_Name__c ?? "—",
        transferDateFormatted: formatDate(r.Transfer_Date__c),
        currentBranch: r.Current_Branch__c || "—",
        newBranch: r.New_Branch__c || "—",
        currentDeptName: r.Current_Department__r?.Name ?? "—",
        newDeptName: r.New_Department__r?.Name ?? "—",
        currentDesigName: r.Current_Designation__r?.Name ?? "—",
        newDesigName: r.New_Designation__r?.Name ?? "—",
        deptChanged:
          !!r.New_Department__c &&
          r.Current_Department__c !== r.New_Department__c,
        desigChanged:
          !!r.New_Designation__c &&
          r.Current_Designation__c !== r.New_Designation__c,
        openTitle: perms.canEdit ? "Edit" : "View",
        openIconClass: perms.canEdit
          ? "fa-solid fa-pen-to-square fa-fw"
          : "fa-solid fa-eye fa-fw",
        busy: this.actionPendingId === r.Id,
        canSubmit: perms.canSubmit,
        canReturnToDraft: perms.canReturnToDraft,
        canApprove: perms.canApprove,
        canCancel: perms.canCancel,
        canDelete: perms.canDelete
      };
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter & export
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    return ["All", ...TRANSFER_STATUSES].map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadTransfers();
  }

  handleExport() {
    const rows = this.enrichedRecords.map((r) => [
      r.Name,
      r.employeeName,
      r.Transfer_Date__c ?? "",
      r.Current_Branch__c ?? "",
      r.New_Branch__c ?? "",
      r.currentDeptName,
      r.newDeptName,
      r.currentDesigName,
      r.newDesigName,
      r.Current_Reports_To__r?.Name ?? "",
      r.New_Reports_To__r?.Name ?? "",
      r.Status__c ?? ""
    ]);
    downloadCsv(
      "employee-transfers.csv",
      [
        "Transfer #",
        "Employee",
        "Transfer Date",
        "Current Branch",
        "New Branch",
        "Current Department",
        "New Department",
        "Current Designation",
        "New Designation",
        "Current Reports To",
        "New Reports To",
        "Status"
      ],
      rows
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dropdown options for modal
  // ─────────────────────────────────────────────────────────────────────────

  get designationOptions() {
    return this._designations.map((d) => ({
      value: d.Id,
      label: d.Name,
      selectedNewDesig: this.editRecord.New_Designation__c === d.Id
    }));
  }

  get departmentOptions() {
    return this._departments.map((d) => ({
      value: d.Id,
      label: d.Name,
      selectedNew: this.editRecord.New_Department__c === d.Id
    }));
  }

  /** Employees who can be transferred: everyone except the current user. */
  get employeeOptions() {
    return this._employees
      .filter(
        (e) =>
          e.Id !== this._portalUserId || e.Id === this.editRecord.Employee__c
      )
      .map((e) => ({
        value: e.Id,
        label: e.Name,
        selected: this.editRecord.Employee__c === e.Id
      }));
  }

  get managerOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label: e.Name,
      selectedNewMgr: this.editRecord.New_Reports_To__c === e.Id
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal helpers
  // ─────────────────────────────────────────────────────────────────────────

  get isEditMode() {
    return !!this.editRecord.Id;
  }

  get isReadOnly() {
    return this.isEditMode && !this.editRecord.canEdit;
  }

  get canSaveRecord() {
    return !this.isReadOnly;
  }

  get modalTitle() {
    if (!this.isEditMode) return "New Transfer";
    return this.isReadOnly ? "View Transfer" : "Edit Transfer";
  }

  get modalStatus() {
    return this.editRecord.Status__c || STATUS.DRAFT;
  }

  get modalStatusBadgeClass() {
    return `${STATUS_BADGE[this.modalStatus] ?? "badge bg-secondary"} ms-2`;
  }

  get readOnlyNotice() {
    return this.editRecord.readOnlyReason;
  }

  get canDeleteInModal() {
    return this.isEditMode && this.editRecord.canDelete;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD handlers
  // ─────────────────────────────────────────────────────────────────────────

  handleCreate() {
    this.editRecord = emptyTransfer();
    this.validationError = "";
    this.showModal = true;
  }

  handleEdit(evt) {
    const id = evt.currentTarget.dataset.id;
    const rec = this.records.find((r) => r.Id === id);
    if (!rec) return;
    const perms = this._permissionsFor(rec);
    const record = {
      Id: rec.Id,
      Status__c: perms.status,
      Employee_Name__c: rec.Employee_Name__c ?? rec.Employee__r?.Name ?? "",
      currentDepartmentName: rec.Current_Department__r?.Name ?? "",
      currentDesignationName: rec.Current_Designation__r?.Name ?? "",
      currentReportsToName: rec.Current_Reports_To__r?.Name ?? "",
      canEdit: perms.canEdit,
      canDelete: perms.canDelete,
      readOnlyReason: perms.readOnlyReason
    };
    EDITABLE_FIELDS.forEach((field) => {
      record[field] = rec[field] ?? "";
    });
    this.editRecord = record;
    this.validationError = "";
    this.showModal = true;
  }

  handleModalClose() {
    this.showModal = false;
    this.editRecord = emptyTransfer();
    this.validationError = "";
  }

  handleFieldChange(evt) {
    const field = evt.currentTarget.dataset.field;
    const value = evt.target.value;
    const next = { ...this.editRecord, [field]: value };
    if (field === "Employee__c") {
      this._applyEmployeeSnapshot(next, value);
    }
    this.editRecord = next;
  }

  /**
   * Shows the employee's name and current assignment. The server records the
   * same values from the employee record when the transfer is saved.
   */
  _applyEmployeeSnapshot(record, employeeId) {
    const employee = this._employees.find((e) => e.Id === employeeId);
    const managerId = employee?.Reports_To__c;
    const manager = this._employees.find((e) => e.Id === managerId);
    record.Employee_Name__c = employee?.Name ?? "";
    record.currentDepartmentName = employee?.Department__c ?? "";
    record.currentDesignationName = employee?.Designation__c ?? "";
    record.currentReportsToName =
      employee?.Reports_To__r?.Name ?? manager?.Name ?? "";
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    const rec = this.editRecord;
    if (!rec.Employee__c) return "Employee is required.";
    if (rec.Employee__c === this._portalUserId) return SELF_MESSAGE;
    if (!rec.Transfer_Date__c) return "Transfer Date is required.";
    if (rec.New_Reports_To__c && rec.New_Reports_To__c === rec.Employee__c) {
      return "An employee cannot report to themselves.";
    }
    return null;
  }

  _buildPayload() {
    const payload = {};
    if (this.editRecord.Id) payload.Id = this.editRecord.Id;
    EDITABLE_FIELDS.forEach((field) => {
      const value = this.editRecord[field];
      payload[field] = value === undefined || value === "" ? null : value;
    });
    return payload;
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
    try {
      await saveTransfer({
        transferJson: JSON.stringify(this._buildPayload()),
        ...this._authParams
      });
      const wasEdit = this.isEditMode;
      this.handleModalClose();
      this._toast(
        "Success",
        wasEdit ? "Transfer updated." : "Transfer created as a draft.",
        "success"
      );
      await this._loadTransfers();
    } catch (error) {
      const message = reduceError(error, "Failed to save transfer.");
      this.validationError = message;
      this._toast("Error", message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status actions (administrators)
  // ─────────────────────────────────────────────────────────────────────────

  async handleStatusAction(evt) {
    const id = evt.currentTarget.dataset.id;
    const newStatus = evt.currentTarget.dataset.status;
    const rec = this.records.find((r) => r.Id === id);
    if (!rec || !newStatus || this.actionPendingId) return;

    this.actionPendingId = id;
    try {
      let target = rec;
      if (newStatus === STATUS.APPROVED) {
        // Confirm against the saved values, not the possibly stale list row.
        target = await getTransferById({
          transferId: id,
          ...this._authParams
        });
        const current = target?.Status__c || STATUS.DRAFT;
        if (current !== STATUS.SUBMITTED) {
          this._showActionError(
            `This transfer is now ${current} and cannot be approved. The list has been refreshed.`
          );
          await this._loadTransfers();
          return;
        }
      }

      const confirmed = await this._confirmStatusChange(target, newStatus);
      if (!confirmed) return;

      await updateTransferStatus({
        transferId: id,
        newStatus,
        ...this._authParams
      });
      this._toast("Success", STATUS_ACTION_LABELS[newStatus], "success");
      if (newStatus === STATUS.APPROVED) {
        // The employee's assignment changed; refresh the form options too.
        await Promise.all([this._loadTransfers(), this._loadOptions()]);
      } else {
        await this._loadTransfers();
      }
    } catch (error) {
      this._showActionError(
        reduceError(error, "Failed to update the transfer status.")
      );
    } finally {
      this.actionPendingId = null;
    }
  }

  _confirmStatusChange(rec, newStatus) {
    const employeeName = rec.Employee__r?.Name ?? rec.Employee_Name__c;
    const who = employeeName ? `${employeeName}'s` : "the employee's";
    if (newStatus === STATUS.APPROVED) {
      const department = rec.New_Department__r?.Name ?? "unchanged";
      const designation = rec.New_Designation__r?.Name ?? "unchanged";
      const manager = rec.New_Reports_To__r?.Name ?? "unchanged";
      return LightningConfirm.open({
        message:
          `Approving this transfer will update ${who} department, ` +
          "designation and reporting manager on their employee record. " +
          `New department: ${department}. New designation: ${designation}. ` +
          `New reporting manager: ${manager}. An approved transfer cannot ` +
          "be changed.",
        label: "Approve Transfer",
        theme: "warning"
      });
    }
    if (newStatus === STATUS.CANCELLED) {
      return LightningConfirm.open({
        message:
          "Cancel this transfer? Cancelled transfers cannot be reopened.",
        label: "Cancel Transfer",
        theme: "warning"
      });
    }
    return Promise.resolve(true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete (administrators)
  // ─────────────────────────────────────────────────────────────────────────

  async handleDelete(evt) {
    const id = evt.currentTarget.dataset.id ?? this.editRecord.Id;
    if (!id) return;
    const confirmed = await LightningConfirm.open({
      message: "Delete this transfer record? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    this.actionPendingId = id;
    try {
      await deleteTransfer({ transferId: id, ...this._authParams });
      if (this.showModal) this.handleModalClose();
      this._toast("Success", "Transfer deleted.", "success");
      await this._loadTransfers();
    } catch (error) {
      const message = reduceError(error, "Failed to delete transfer.");
      if (this.showModal) {
        this.validationError = message;
        this._toast("Error", message, "error");
      } else {
        this._showActionError(message);
      }
    } finally {
      this.actionPendingId = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Misc
  // ─────────────────────────────────────────────────────────────────────────

  _showActionError(message) {
    this.errorMessage = message;
    this._toast("Error", message, "error");
  }

  _toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  clearError() {
    this.errorMessage = "";
  }

  handleHome(evt) {
    evt?.preventDefault();
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "Home" }
    });
  }
}