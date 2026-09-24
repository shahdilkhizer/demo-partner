import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";
import { CONSTANTS } from "c/pwchronoConstants";

import getAccessInfo from "@salesforce/apex/PWChrono_EmployeePromotionController.getAccessInfo";
import getPromotions from "@salesforce/apex/PWChrono_EmployeePromotionController.getPromotions";
import getPromotionById from "@salesforce/apex/PWChrono_EmployeePromotionController.getPromotionById";
import getPromotionDetails from "@salesforce/apex/PWChrono_EmployeePromotionController.getPromotionDetails";
import savePromotion from "@salesforce/apex/PWChrono_EmployeePromotionController.savePromotion";
import updatePromotionStatus from "@salesforce/apex/PWChrono_EmployeePromotionController.updatePromotionStatus";
import deletePromotion from "@salesforce/apex/PWChrono_EmployeePromotionController.deletePromotion";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeePromotionController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_EmployeePromotionController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_EmployeePromotionController.getActiveEmployees";

/** Used only until the server reports whether the caller is an admin. */
const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

const STATUS = {
  DRAFT: "Draft",
  SUBMITTED: "Submitted",
  APPROVED: "Approved",
  CANCELLED: "Cancelled"
};
const PROMOTION_STATUSES = Object.values(STATUS);
const EDITABLE_STATUSES = [STATUS.DRAFT, STATUS.SUBMITTED];
const DELETABLE_STATUSES = [STATUS.DRAFT, STATUS.CANCELLED];

const STATUS_BADGE = {
  Draft: "badge bg-secondary",
  Submitted: "badge bg-warning text-dark",
  Approved: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const STATUS_ACTION_LABELS = {
  Submitted: "Promotion submitted for approval.",
  Draft: "Promotion returned to draft.",
  Approved: "Promotion approved. The employee record has been updated.",
  Cancelled: "Promotion cancelled."
};

const SELF_MESSAGE = "You cannot manage a promotion for yourself.";

/**
 * Fields the server accepts from the form. Status, the employee name and the
 * current department, designation and reporting manager are never sent; the
 * server takes them from the employee record.
 */
const EDITABLE_FIELDS = [
  "Employee__c",
  "Company__c",
  "Promotion_Date__c",
  "New_Designation__c",
  "New_Department__c",
  "Current_Grade__c",
  "New_Grade__c",
  "Current_Branch__c",
  "New_Branch__c",
  "New_Reports_To__c",
  "Current_Salary__c",
  "New_Salary__c",
  "Promotion_Details__c"
];

const CURRENCY_CODE = CONSTANTS?.CURRENCY_CODE ?? "USD";

let keyCounter = 0;
function nextKey() {
  keyCounter += 1;
  return `dk_${keyCounter}`;
}

function emptyPromotion() {
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
    record[field] = field.endsWith("Salary__c") ? null : "";
  });
  return record;
}

function emptyDetailLine() {
  return {
    _key: nextKey(),
    Property__c: "",
    Current_Value__c: "",
    New_Value__c: ""
  };
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

function formatMoney(value) {
  if (value === null || value === undefined || value === "") return "—";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: CURRENCY_CODE,
    maximumFractionDigits: 2
  }).format(Number(value));
}

function isNegative(value) {
  return value !== null && value !== "" && Number(value) < 0;
}

export default class PwchronoEmployeePromotion extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";

  @track records = [];
  @track editRecord = emptyPromotion();
  @track detailLines = [];
  isLoading = false;
  isSaving = false;
  actionPendingId = null;
  hasLoaded = false;
  loadError = "";
  errorMessage = "";
  validationError = "";
  showModal = false;
  detailsLoading = false;

  _statusFilter = "All";
  _portalUserId = "";
  _role = "";
  _sessionToken = null;
  _serverIsAdmin = null;
  _designations = [];
  _departments = [];
  _employees = [];
  _detailsLoaded = true;
  _detailsRequestId = 0;

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
    this._loadPromotions();
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

  async _loadPromotions() {
    this.isLoading = true;
    this.loadError = "";
    try {
      const rows = await getPromotions({
        statusFilter: this._statusFilter,
        ...this._authParams
      });
      this.records = Array.isArray(rows) ? rows : [];
      this.hasLoaded = true;
    } catch (error) {
      this.records = [];
      this.loadError = reduceError(error, "Failed to load promotions.");
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
    this._loadPromotions();
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
   * What the current user may do with a promotion. Mirrors the server rules:
   * admins manage the workflow, others only edit drafts, and nobody manages
   * their own promotion.
   */
  _permissionsFor(record) {
    const status = record.Status__c || STATUS.DRAFT;
    const isAdmin = this.isAdmin;
    const isSelf =
      !!record.Employee__c && record.Employee__c === this._portalUserId;
    const manage = isAdmin && !isSelf;
    let readOnlyReason = "";
    if (!EDITABLE_STATUSES.includes(status)) {
      readOnlyReason = `This promotion is ${status} and can no longer be edited.`;
    } else if (isSelf) {
      readOnlyReason = `${SELF_MESSAGE} Ask another HR user to make changes.`;
    } else if (status === STATUS.SUBMITTED && !isAdmin) {
      readOnlyReason =
        "This promotion has been submitted for approval. Only an HR administrator can change it now.";
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
        promotionDateFormatted: formatDate(r.Promotion_Date__c),
        currentDesignationName: r.Current_Designation__r?.Name ?? "—",
        newDesignationName: r.New_Designation__r?.Name ?? "—",
        currentDepartmentName: r.Current_Department__r?.Name ?? "—",
        newDepartmentName: r.New_Department__r?.Name ?? "—",
        deptChanged:
          !!r.New_Department__c &&
          r.Current_Department__c !== r.New_Department__c,
        hasSalary: r.Current_Salary__c != null || r.New_Salary__c != null,
        currentSalaryFormatted: formatMoney(r.Current_Salary__c),
        newSalaryFormatted: formatMoney(r.New_Salary__c),
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
    return ["All", ...PROMOTION_STATUSES].map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadPromotions();
  }

  handleExport() {
    const rows = this.enrichedRecords.map((r) => [
      r.Name,
      r.employeeName,
      r.Promotion_Date__c ?? "",
      r.currentDesignationName,
      r.newDesignationName,
      r.currentDepartmentName,
      r.newDepartmentName,
      r.Current_Reports_To__r?.Name ?? "",
      r.New_Reports_To__r?.Name ?? "",
      r.Current_Salary__c ?? "",
      r.New_Salary__c ?? "",
      r.Status__c ?? ""
    ]);
    downloadCsv(
      "employee-promotions.csv",
      [
        "Promotion #",
        "Employee",
        "Promotion Date",
        "Current Designation",
        "New Designation",
        "Current Department",
        "New Department",
        "Current Reports To",
        "New Reports To",
        "Current Salary",
        "New Salary",
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
      selectedNewDept: this.editRecord.New_Department__c === d.Id
    }));
  }

  /** Employees who can be promoted: everyone except the current user. */
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
    if (!this.isEditMode) return "New Promotion";
    return this.isReadOnly ? "View Promotion" : "Edit Promotion";
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

  get hasDetailLines() {
    return this.detailLines.length > 0;
  }

  get isSaveDisabled() {
    return this.isSaving || this.detailsLoading;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD handlers
  // ─────────────────────────────────────────────────────────────────────────

  handleCreate() {
    this._detailsRequestId += 1;
    this.editRecord = emptyPromotion();
    this.detailLines = [];
    this._detailsLoaded = true;
    this.detailsLoading = false;
    this.validationError = "";
    this.showModal = true;
  }

  async handleEdit(evt) {
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
      record[field] = rec[field] ?? (field.endsWith("Salary__c") ? null : "");
    });
    this.editRecord = record;
    this.detailLines = [];
    this._detailsLoaded = false;
    this.validationError = "";
    this.showModal = true;
    this.detailsLoading = true;

    // Ignore the answer if the user has since closed or switched records.
    this._detailsRequestId += 1;
    const requestId = this._detailsRequestId;
    try {
      const lines = await getPromotionDetails({
        promotionId: id,
        ...this._authParams
      });
      if (requestId !== this._detailsRequestId) return;
      this.detailLines = (lines || []).map((l) => ({
        _key: nextKey(),
        Property__c: l.Property__c ?? "",
        Current_Value__c: l.Current_Value__c ?? "",
        New_Value__c: l.New_Value__c ?? ""
      }));
      this._detailsLoaded = true;
    } catch (error) {
      if (requestId !== this._detailsRequestId) return;
      this.validationError = reduceError(
        error,
        "Could not load the promotion detail lines."
      );
    } finally {
      if (requestId === this._detailsRequestId) {
        this.detailsLoading = false;
      }
    }
  }

  handleModalClose() {
    this._detailsRequestId += 1;
    this.showModal = false;
    this.editRecord = emptyPromotion();
    this.detailLines = [];
    this.detailsLoading = false;
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
   * same values from the employee record when the promotion is saved.
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

  handleAddDetailRow() {
    this.detailLines = [...this.detailLines, emptyDetailLine()];
  }

  handleRemoveDetailRow(evt) {
    const key = evt.currentTarget.dataset.key;
    this.detailLines = this.detailLines.filter((l) => l._key !== key);
  }

  handleDetailChange(evt) {
    const key = evt.currentTarget.dataset.key;
    const col = evt.currentTarget.dataset.col;
    const value = evt.target.value;
    this.detailLines = this.detailLines.map((l) => {
      if (l._key !== key) return l;
      return { ...l, [col]: value };
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    const rec = this.editRecord;
    if (!rec.Employee__c) return "Employee is required.";
    if (rec.Employee__c === this._portalUserId) return SELF_MESSAGE;
    if (!rec.Promotion_Date__c) return "Promotion Date is required.";
    if (rec.New_Reports_To__c && rec.New_Reports_To__c === rec.Employee__c) {
      return "An employee cannot report to themselves.";
    }
    if (isNegative(rec.Current_Salary__c) || isNegative(rec.New_Salary__c)) {
      return "Salary amounts cannot be negative.";
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
      const details = this._detailsLoaded
        ? JSON.stringify(
            this.detailLines.map((line) => ({
              Property__c: line.Property__c,
              Current_Value__c: line.Current_Value__c,
              New_Value__c: line.New_Value__c
            }))
          )
        : null;
      await savePromotion({
        promotionJson: JSON.stringify(this._buildPayload()),
        detailsJson: details,
        ...this._authParams
      });
      const wasEdit = this.isEditMode;
      this.handleModalClose();
      this._toast(
        "Success",
        wasEdit ? "Promotion updated." : "Promotion created as a draft.",
        "success"
      );
      await this._loadPromotions();
    } catch (error) {
      const message = reduceError(error, "Failed to save promotion.");
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
        target = await getPromotionById({
          promotionId: id,
          ...this._authParams
        });
        const current = target?.Status__c || STATUS.DRAFT;
        if (current !== STATUS.SUBMITTED) {
          this._showActionError(
            `This promotion is now ${current} and cannot be approved. The list has been refreshed.`
          );
          await this._loadPromotions();
          return;
        }
      }

      const confirmed = await this._confirmStatusChange(target, newStatus);
      if (!confirmed) return;

      await updatePromotionStatus({
        promotionId: id,
        newStatus,
        ...this._authParams
      });
      this._toast("Success", STATUS_ACTION_LABELS[newStatus], "success");
      if (newStatus === STATUS.APPROVED) {
        // The employee's assignment changed; refresh the form options too.
        await Promise.all([this._loadPromotions(), this._loadOptions()]);
      } else {
        await this._loadPromotions();
      }
    } catch (error) {
      this._showActionError(
        reduceError(error, "Failed to update the promotion status.")
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
          `Approving this promotion will update ${who} department, ` +
          "designation and reporting manager on their employee record. " +
          `New department: ${department}. New designation: ${designation}. ` +
          `New reporting manager: ${manager}. Salary is not changed ` +
          "automatically; update pay in Payroll salary setup. An approved " +
          "promotion cannot be changed.",
        label: "Approve Promotion",
        theme: "warning"
      });
    }
    if (newStatus === STATUS.CANCELLED) {
      return LightningConfirm.open({
        message:
          "Cancel this promotion? Cancelled promotions cannot be reopened.",
        label: "Cancel Promotion",
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
      message: "Delete this promotion record? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    this.actionPendingId = id;
    try {
      await deletePromotion({ promotionId: id, ...this._authParams });
      if (this.showModal) this.handleModalClose();
      this._toast("Success", "Promotion deleted.", "success");
      await this._loadPromotions();
    } catch (error) {
      const message = reduceError(error, "Failed to delete promotion.");
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