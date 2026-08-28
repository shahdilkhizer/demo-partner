import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { PAGES } from "c/pwchronoRouter";

import getPromotions from "@salesforce/apex/PWChrono_EmployeePromotionController.getPromotions";
import getPromotionDetails from "@salesforce/apex/PWChrono_EmployeePromotionController.getPromotionDetails";
import savePromotion from "@salesforce/apex/PWChrono_EmployeePromotionController.savePromotion";
import deletePromotion from "@salesforce/apex/PWChrono_EmployeePromotionController.deletePromotion";
import getActiveDesignations from "@salesforce/apex/PWChrono_EmployeePromotionController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_EmployeePromotionController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_EmployeePromotionController.getActiveEmployees";

const STATUS_BADGE = {
  Draft: "badge bg-secondary",
  Submitted: "badge bg-warning text-dark",
  Approved: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const PROMOTION_STATUSES = ["Draft", "Submitted", "Approved", "Cancelled"];

let _keyCounter = 0;
function nextKey() {
  return `dk_${++_keyCounter}`;
}

function emptyPromotion() {
  return {
    Id: null,
    Employee__c: "",
    Employee_Name__c: "",
    Company__c: "",
    Promotion_Date__c: "",
    Current_Designation__c: "",
    New_Designation__c: "",
    Current_Department__c: "",
    New_Department__c: "",
    Current_Grade__c: "",
    New_Grade__c: "",
    Current_Branch__c: "",
    New_Branch__c: "",
    Current_Reports_To__c: "",
    New_Reports_To__c: "",
    Current_Salary__c: null,
    New_Salary__c: null,
    Promotion_Details__c: "",
    Status__c: "Draft"
  };
}

function emptyDetailLine() {
  return {
    _key: nextKey(),
    Property__c: "",
    Current_Value__c: "",
    New_Value__c: ""
  };
}

export default class PwchronoEmployeePromotion extends LightningElement {
  static renderMode = "light";

  @track records = [];
  @track isLoading = false;
  @track isSaving = false;
  @track errorMessage = "";
  @track showModal = false;
  @track editRecord = emptyPromotion();
  @track detailLines = [];
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
    this._loadPromotions();
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

  async _loadPromotions() {
    this.isLoading = true;
    this.errorMessage = "";
    try {
      this.records = await getPromotions({
        statusFilter: this._statusFilter,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to load promotions.";
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
      // non-fatal — dropdowns will be empty
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
    return this.records.map((r) => {
      const sameDept = r.Current_Department__c === r.New_Department__c;
      return {
        ...r,
        statusBadgeClass: STATUS_BADGE[r.Status__c] ?? "badge bg-secondary",
        employeeName: r.Employee__r?.Name ?? r.Employee_Name__c ?? "—",
        promotionDateFormatted: r.Promotion_Date__c ?? "—",
        currentDesignationName: r.Current_Designation__r?.Name ?? "—",
        newDesignationName: r.New_Designation__r?.Name ?? "—",
        currentDepartmentName: r.Current_Department__r?.Name ?? "—",
        newDepartmentName: r.New_Department__r?.Name ?? "—",
        deptChanged: !sameDept,
        hasSalary: r.Current_Salary__c != null || r.New_Salary__c != null,
        currentSalaryFormatted:
          r.Current_Salary__c != null
            ? `$${Number(r.Current_Salary__c).toLocaleString()}`
            : "—",
        newSalaryFormatted:
          r.New_Salary__c != null
            ? `$${Number(r.New_Salary__c).toLocaleString()}`
            : "—"
      };
    });
  }

  get hasRecords() {
    return this.records.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    const opts = ["All", ...PROMOTION_STATUSES];
    return opts.map((s) => ({
      value: s,
      label: s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(evt) {
    this._statusFilter = evt.target.value;
    this._loadPromotions();
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
      selectedCurrentDept: this.editRecord.Current_Department__c === d.Id,
      selectedNewDept: this.editRecord.New_Department__c === d.Id
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

  get promotionStatusOptions() {
    return PROMOTION_STATUSES.map((s) => ({
      value: s,
      label: s,
      selected: this.editRecord.Status__c === s
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal helpers
  // ─────────────────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.editRecord.Id ? "Edit Promotion" : "New Promotion";
  }

  get isEditMode() {
    return !!this.editRecord.Id;
  }

  get hasDetailLines() {
    return this.detailLines.length > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD handlers
  // ─────────────────────────────────────────────────────────────────────────

  handleCreate() {
    this.editRecord = emptyPromotion();
    this.detailLines = [];
    this.validationError = "";
    this.showModal = true;
  }

  async handleEdit(evt) {
    const id = evt.currentTarget.dataset.id;
    const rec = this.records.find((r) => r.Id === id);
    if (!rec) return;
    this.editRecord = { ...rec };
    this.validationError = "";
    this.showModal = true;
    // load existing detail lines
    try {
      const lines = await getPromotionDetails({
        promotionId: id,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.detailLines = lines.map((l) => ({ ...l, _key: nextKey() }));
    } catch {
      this.detailLines = [];
    }
  }

  handleModalClose() {
    this.showModal = false;
    this.editRecord = emptyPromotion();
    this.detailLines = [];
    this.validationError = "";
  }

  handleFieldChange(evt) {
    const field = evt.currentTarget.dataset.field;
    this.editRecord = { ...this.editRecord, [field]: evt.target.value };
  }

  // Detail line handlers
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
    this.detailLines = this.detailLines.map((l) => {
      if (l._key === key) {
        return { ...l, [col]: evt.target.value };
      }
      return l;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    if (!this.editRecord.Employee__c) {
      return "Employee is required.";
    }
    if (!this.editRecord.Promotion_Date__c) {
      return "Promotion Date is required.";
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
      // strip client-only keys from detail lines before sending
      const cleanDetails = this.detailLines.map((line) => {
        const cleanLine = { ...line };
        delete cleanLine._key;
        return cleanLine;
      });
      await savePromotion({
        promotionJson: JSON.stringify(this.editRecord),
        detailsJson: JSON.stringify(cleanDetails),
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadPromotions();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to save promotion.";
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
      message: "Delete this promotion record? This cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    try {
      await deletePromotion({
        promotionId: id,
        portalUserId: this._portalUserId,
        sessionToken: this._sessionToken
      });
      this.showModal = false;
      this._loadPromotions();
    } catch (e) {
      this.errorMessage =
        e?.body?.message ?? e?.message ?? "Failed to delete promotion.";
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Misc
  // ─────────────────────────────────────────────────────────────────────────

  clearError() {
    this.errorMessage = "";
  }

  handleHome() {
    // navigate to home via router if available
    const nav = this.template.closest("[data-navigate]");
    if (nav)
      nav.dispatchEvent(
        new CustomEvent("navigate", { detail: PAGES.HOME, bubbles: true })
      );
  }
}