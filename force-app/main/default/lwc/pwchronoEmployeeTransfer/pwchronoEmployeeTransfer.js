import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { PAGES } from "c/pwchronoRouter";

import getTransfers from "@salesforce/apex/PWChrono_EmployeeTransferController.getTransfers";
import saveTransfer from "@salesforce/apex/PWChrono_EmployeeTransferController.saveTransfer";
import deleteTransfer from "@salesforce/apex/PWChrono_EmployeeTransferController.deleteTransfer";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeeTransferController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_EmployeeTransferController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_EmployeeTransferController.getActiveEmployees";

const STATUS_BADGE = {
  Draft: "badge bg-secondary",
  Submitted: "badge bg-warning text-dark",
  Approved: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const TRANSFER_STATUSES = ["Draft", "Submitted", "Approved", "Cancelled"];

function emptyTransfer() {
  return {
    Id: null,
    Employee__c: "",
    Employee_Name__c: "",
    Company__c: "",
    Transfer_Date__c: "",
    Current_Branch__c: "",
    New_Branch__c: "",
    Current_Department__c: "",
    New_Department__c: "",
    Current_Designation__c: "",
    New_Designation__c: "",
    Current_Reports_To__c: "",
    New_Reports_To__c: "",
    Transfer_Details__c: "",
    Status__c: "Draft"
  };
}

export default class PwchronoEmployeeTransfer extends LightningElement {
  static renderMode = "light";

  @track records = [];
  @track isLoading = false;
  @track isSaving = false;
  @track errorMessage = "";
  @track showModal = false;
  @track editRecord = emptyTransfer();
  @track validationError = "";

  _statusFilter = "All";
  _session = null;
  _designations = [];
  _departments = [];
  _employees = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  connectedCallback() {
    this._session = getSession();
    this._loadOptions();
    this._loadTransfers();
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

  async _loadTransfers() {
    this.isLoading = true;
    this.errorMessage = "";
    try {
      this.records = await getTransfers({
        statusFilter: this._statusFilter,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to load transfers.";
    } finally {
      this.isLoading = false;
    }
  }

  async _loadOptions() {
    try {
      const [desigs, depts, emps] = await Promise.all([
        getActiveDesignations(),
        getActiveDepartments(),
        getActiveEmployees()
      ]);
      this._designations = desigs;
      this._departments = depts;
      this._employees = emps;
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
  get draftCount() {
    return this.records.filter((r) => r.Status__c === "Draft").length;
  }
  get submittedCount() {
    return this.records.filter((r) => r.Status__c === "Submitted").length;
  }
  get approvedCount() {
    return this.records.filter((r) => r.Status__c === "Approved").length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enriched records
  // ─────────────────────────────────────────────────────────────────────────

  get enrichedRecords() {
    return this.records.map((r) => ({
      ...r,
      statusBadgeClass: STATUS_BADGE[r.Status__c] ?? "badge bg-secondary",
      employeeName: r.Employee__r?.Name ?? r.Employee_Name__c ?? "—",
      currentDeptName: r.Current_Department__r?.Name ?? "—",
      newDeptName: r.New_Department__r?.Name ?? "—",
      currentDesigName: r.Current_Designation__r?.Name ?? "—",
      newDesigName: r.New_Designation__r?.Name ?? "—",
      deptChanged: r.Current_Department__c !== r.New_Department__c,
      desigChanged: r.Current_Designation__c !== r.New_Designation__c
    }));
  }

  get hasRecords() {
    return this.records.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter
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

  // ─────────────────────────────────────────────────────────────────────────
  // Dropdown options for modal
  // ─────────────────────────────────────────────────────────────────────────

  get designationOptions() {
    return this._designations.map((d) => ({
      value: d.Id,
      label: d.Name,
      selectedCurrentDesig: this.editRecord.Current_Designation__c === d.Id,
      selectedNewDesig: this.editRecord.New_Designation__c === d.Id
    }));
  }

  get departmentOptions() {
    return this._departments.map((d) => ({
      value: d.Id,
      label: d.Name,
      selectedCurrent: this.editRecord.Current_Department__c === d.Id,
      selectedNew: this.editRecord.New_Department__c === d.Id
    }));
  }

  get employeeOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label: e.Name,
      selected: this.editRecord.Employee__c === e.Id,
      selectedCurrentMgr: this.editRecord.Current_Reports_To__c === e.Id,
      selectedNewMgr: this.editRecord.New_Reports_To__c === e.Id
    }));
  }

  get transferStatusOptions() {
    return TRANSFER_STATUSES.map((s) => ({
      value: s,
      label: s,
      selected: this.editRecord.Status__c === s
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal helpers
  // ─────────────────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.editRecord.Id ? "Edit Transfer" : "New Transfer";
  }

  get isEditMode() {
    return !!this.editRecord.Id;
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
    this.editRecord = { ...rec };
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
    this.editRecord = { ...this.editRecord, [field]: evt.target.value };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    if (!this.editRecord.Employee__c) return "Employee is required.";
    if (!this.editRecord.Transfer_Date__c) return "Transfer Date is required.";
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
      await saveTransfer({
        transferJson: JSON.stringify(this.editRecord),
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadTransfers();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to save transfer.";
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
      message: "Delete this transfer record? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    try {
      await deleteTransfer({
        transferId: id,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadTransfers();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to delete transfer.";
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