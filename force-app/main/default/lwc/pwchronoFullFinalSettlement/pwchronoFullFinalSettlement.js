import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";
import { CONSTANTS } from "c/pwchronoConstants";

import getSettlements from "@salesforce/apex/PWChrono_FullFinalSettlementController.getSettlements";
import getSettlementById from "@salesforce/apex/PWChrono_FullFinalSettlementController.getSettlementById";
import getPayables from "@salesforce/apex/PWChrono_FullFinalSettlementController.getPayables";
import getReceivables from "@salesforce/apex/PWChrono_FullFinalSettlementController.getReceivables";
import saveSettlement from "@salesforce/apex/PWChrono_FullFinalSettlementController.saveSettlement";
import updateSettlementStatus from "@salesforce/apex/PWChrono_FullFinalSettlementController.updateSettlementStatus";
import deleteSettlement from "@salesforce/apex/PWChrono_FullFinalSettlementController.deleteSettlement";
import getActiveDesignations from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveEmployees";
import getActiveSeparations from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveSeparations";

const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

const STATUS = {
  DRAFT: "Draft",
  SUBMITTED: "Submitted",
  PAID: "Paid",
  CANCELLED: "Cancelled"
};
const SETTLEMENT_STATUSES = Object.values(STATUS);
const EDITABLE_STATUSES = [STATUS.DRAFT, STATUS.SUBMITTED];
const DELETABLE_STATUSES = [STATUS.DRAFT, STATUS.CANCELLED];

const STATUS_BADGE = {
  Draft: "badge bg-secondary",
  Submitted: "badge bg-warning text-dark",
  Paid: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const STATUS_SUCCESS = {
  Submitted: "Settlement submitted.",
  Paid: "Settlement marked as paid.",
  Cancelled: "Settlement cancelled."
};

const PAYABLE_STATUSES = ["Pending", "Paid", "Waived"];
const RECEIVABLE_STATUSES = ["Pending", "Recovered", "Waived"];
const WAIVED = "Waived";

/** Fields the server accepts from the form. Status and totals are server-owned. */
const EDITABLE_FIELDS = [
  "Employee__c",
  "Employee_Name__c",
  "Company__c",
  "Department__c",
  "Designation__c",
  "Separation__c",
  "Date_of_Joining__c",
  "Relieving_Date__c"
];

const CURRENCY_CODE = CONSTANTS?.CURRENCY_CODE ?? "USD";

let keyCounter = 0;
function nextKey() {
  keyCounter += 1;
  return `ln_${keyCounter}`;
}

function emptyRecord() {
  const record = { Id: null, Status__c: STATUS.DRAFT };
  EDITABLE_FIELDS.forEach((field) => {
    record[field] = "";
  });
  return record;
}

function toLine(line) {
  return {
    _key: nextKey(),
    Name: line?.Name ?? "",
    Component__c: line?.Component__c ?? "",
    Reference_Document__c: line?.Reference_Document__c ?? "",
    Account__c: line?.Account__c ?? "",
    Amount__c:
      line?.Amount__c === null || line?.Amount__c === undefined
        ? 0
        : line.Amount__c,
    Status__c: line?.Status__c || "Pending"
  };
}

function sumLines(lines) {
  return lines
    .filter((line) => line.Status__c !== WAIVED)
    .reduce((sum, line) => sum + (parseFloat(line.Amount__c) || 0), 0);
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

export default class PwchronoFullFinalSettlement extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";

  @track settlements = [];
  @track currentRecord = emptyRecord();
  @track payableLines = [];
  @track receivableLines = [];
  @track viewRecord = null;
  @track viewPayables = [];
  @track viewReceivables = [];

  isLoading = false;
  hasLoaded = false;
  loadError = "";
  showModal = false;
  showViewModal = false;
  modalError = "";
  isSaving = false;
  isOpening = false;
  viewLinesLoading = false;
  actionPendingId = null;

  _statusFilter = "All";
  _portalUserId = "";
  _role = "";
  _sessionToken = null;
  _employees = [];
  _departments = [];
  _designations = [];
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
    this._loadLookups();
    this._loadSettlements();
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

  async _loadSettlements() {
    this.isLoading = true;
    this.loadError = "";
    try {
      const rows = await getSettlements({
        statusFilter: this._statusFilter,
        ...this._authParams
      });
      this.settlements = Array.isArray(rows) ? rows : [];
      this.hasLoaded = true;
    } catch (error) {
      this.settlements = [];
      this.loadError = reduceError(error, "Failed to load settlements.");
    } finally {
      this.isLoading = false;
    }
  }

  async _loadLookups() {
    try {
      const [employees, departments, designations, separations] =
        await Promise.all([
          getActiveEmployees(this._authParams),
          getActiveDepartments(this._authParams),
          getActiveDesignations(this._authParams),
          getActiveSeparations(this._authParams)
        ]);
      this._employees = employees || [];
      this._departments = departments || [];
      this._designations = designations || [];
      this._separations = separations || [];
    } catch (error) {
      this._employees = [];
      this._departments = [];
      this._designations = [];
      this._separations = [];
      this._toast(
        "Warning",
        reduceError(error, "Could not load the form options."),
        "warning"
      );
    }
  }

  handleRetry() {
    this._loadLookups();
    this._loadSettlements();
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
    return this.settlements.length > 0;
  }

  get totalCount() {
    return this.settlements.length;
  }
  get draftCount() {
    return this._countByStatus(STATUS.DRAFT);
  }
  get submittedCount() {
    return this._countByStatus(STATUS.SUBMITTED);
  }
  get paidCount() {
    return this._countByStatus(STATUS.PAID);
  }

  _countByStatus(status) {
    return this.settlements.filter((s) => s.Status__c === status).length;
  }

  _decorate(s) {
    const isAdmin = this.isAdmin;
    const status = s.Status__c || STATUS.DRAFT;
    const editable = EDITABLE_STATUSES.includes(status);
    return {
      ...s,
      badgeClass: STATUS_BADGE[status] ?? "badge bg-secondary",
      employeeName: s.Employee__r?.Name ?? s.Employee_Name__c ?? "—",
      deptName: s.Department__r?.Name ?? "—",
      desigName: s.Designation__r?.Name ?? "—",
      separationName: s.Separation__r?.Name ?? "—",
      joiningDateFormatted: formatDate(s.Date_of_Joining__c),
      relievingDateFormatted: formatDate(s.Relieving_Date__c),
      totalPayableFormatted: formatMoney(s.Total_Payable__c ?? 0),
      totalReceivableFormatted: formatMoney(s.Total_Receivable__c ?? 0),
      netPayableFormatted: formatMoney(s.Net_Payable__c ?? 0),
      canEdit: editable,
      canSubmit: isAdmin && status === STATUS.DRAFT,
      canPay: isAdmin && status === STATUS.SUBMITTED,
      canCancel: isAdmin && editable,
      canDelete: isAdmin && DELETABLE_STATUSES.includes(status),
      isBusy: this.actionPendingId === s.Id
    };
  }

  get enrichedSettlements() {
    return this.settlements.map((s) => this._decorate(s));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter and export
  // ─────────────────────────────────────────────────────────────────────────

  get statusOptions() {
    return ["All", ...SETTLEMENT_STATUSES].map((s) => ({
      value: s,
      label: s === "All" ? "All Status" : s,
      selected: this._statusFilter === s
    }));
  }

  handleFilterChange(event) {
    this._statusFilter = event.target.value;
    this._loadSettlements();
  }

  handleExport() {
    const rows = this.enrichedSettlements.map((s) => [
      s.Name,
      s.employeeName,
      s.separationName,
      s.Relieving_Date__c ?? "",
      s.deptName,
      s.Total_Payable__c ?? 0,
      s.Total_Receivable__c ?? 0,
      s.Net_Payable__c ?? 0,
      s.Status__c
    ]);
    downloadCsv(
      "full-final-settlements.csv",
      [
        "Settlement #",
        "Employee",
        "Separation",
        "Relieving Date",
        "Department",
        "Total Payable",
        "Total Receivable",
        "Net Payable",
        "Status"
      ],
      rows
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modal options and totals
  // ─────────────────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.currentRecord.Id ? "Edit Settlement" : "New Settlement";
  }

  get isEditMode() {
    return !!this.currentRecord.Id;
  }

  get modalStatusBadgeClass() {
    return `${STATUS_BADGE[this.currentRecord.Status__c] ?? "badge bg-secondary"} ms-2`;
  }

  get employeeOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label: e.Is_Active__c === false ? `${e.Name} (inactive)` : e.Name,
      selected: e.Id === this.currentRecord.Employee__c
    }));
  }

  get departmentOptions() {
    return this._departments.map((d) => ({
      value: d.Id,
      label: d.Name,
      selected: d.Id === this.currentRecord.Department__c
    }));
  }

  get designationOptions() {
    return this._designations.map((d) => ({
      value: d.Id,
      label: d.Name,
      selected: d.Id === this.currentRecord.Designation__c
    }));
  }

  get separationOptions() {
    return this._separations.map((s) => ({
      value: s.Id,
      label:
        s.Name +
        (s.Employee__r?.Name ? " — " + s.Employee__r.Name : "") +
        (s.Status__c ? ` (${s.Status__c})` : ""),
      selected: s.Id === this.currentRecord.Separation__c
    }));
  }

  get payableLinesView() {
    return this.payableLines.map((line) => ({
      ...line,
      statusOptions: PAYABLE_STATUSES.map((s) => ({
        value: s,
        label: s,
        selected: line.Status__c === s
      }))
    }));
  }

  get receivableLinesView() {
    return this.receivableLines.map((line) => ({
      ...line,
      statusOptions: RECEIVABLE_STATUSES.map((s) => ({
        value: s,
        label: s,
        selected: line.Status__c === s
      }))
    }));
  }

  get hasPayableLines() {
    return this.payableLines.length > 0;
  }

  get hasReceivableLines() {
    return this.receivableLines.length > 0;
  }

  get computedTotalPayable() {
    return formatMoney(sumLines(this.payableLines));
  }

  get computedTotalReceivable() {
    return formatMoney(sumLines(this.receivableLines));
  }

  get computedNetPayable() {
    return formatMoney(
      sumLines(this.payableLines) - sumLines(this.receivableLines)
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // New / Edit
  // ─────────────────────────────────────────────────────────────────────────

  handleNew() {
    this.currentRecord = emptyRecord();
    this.payableLines = [];
    this.receivableLines = [];
    this.modalError = "";
    this.showModal = true;
  }

  async handleEdit(event) {
    const id = event.currentTarget.dataset.id;
    if (this.isOpening) return;
    this.isOpening = true;
    this.modalError = "";
    try {
      const [rec, pays, recs] = await Promise.all([
        getSettlementById({ settlementId: id, ...this._authParams }),
        getPayables({ settlementId: id, ...this._authParams }),
        getReceivables({ settlementId: id, ...this._authParams })
      ]);
      // A blank (legacy) status is treated as Draft, as the server does.
      const record = { Id: rec.Id, Status__c: rec.Status__c || STATUS.DRAFT };
      EDITABLE_FIELDS.forEach((field) => {
        record[field] = rec[field] ?? "";
      });
      this.currentRecord = record;
      this.payableLines = (pays || []).map(toLine);
      this.receivableLines = (recs || []).map(toLine);
      this.showModal = true;
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to open the settlement."),
        "error"
      );
    } finally {
      this.isOpening = false;
    }
  }

  handleModalClose() {
    this.showModal = false;
    this.modalError = "";
  }

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    const next = { ...this.currentRecord, [field]: value };
    if (field === "Employee__c") {
      const employee = this._employees.find((e) => e.Id === value);
      next.Employee_Name__c = employee?.Name ?? "";
      if (!next.Date_of_Joining__c && employee?.Date_of_Joining__c) {
        next.Date_of_Joining__c = employee.Date_of_Joining__c;
      }
    }
    if (field === "Separation__c" && value && !this.isEditMode) {
      this._applySeparationDefaults(next, value);
    }
    this.currentRecord = next;
  }

  _applySeparationDefaults(record, separationId) {
    const separation = this._separations.find((s) => s.Id === separationId);
    if (!separation) return;
    if (!record.Employee__c && separation.Employee__c) {
      record.Employee__c = separation.Employee__c;
      const employee = this._employees.find(
        (e) => e.Id === separation.Employee__c
      );
      record.Employee_Name__c =
        separation.Employee_Name__c ||
        separation.Employee__r?.Name ||
        employee?.Name ||
        "";
      if (!record.Date_of_Joining__c && employee?.Date_of_Joining__c) {
        record.Date_of_Joining__c = employee.Date_of_Joining__c;
      }
    }
    if (!record.Relieving_Date__c && separation.Relieving_Date__c) {
      record.Relieving_Date__c = separation.Relieving_Date__c;
    }
    if (!record.Department__c && separation.Department__c) {
      record.Department__c = separation.Department__c;
    }
    if (!record.Designation__c && separation.Designation__c) {
      record.Designation__c = separation.Designation__c;
    }
    if (!record.Company__c && separation.Company__c) {
      record.Company__c = separation.Company__c;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Line items
  // ─────────────────────────────────────────────────────────────────────────

  handleAddPayable() {
    this.payableLines = [...this.payableLines, toLine(null)];
  }

  handleAddReceivable() {
    this.receivableLines = [...this.receivableLines, toLine(null)];
  }

  handleLineChange(event) {
    const key = event.target.dataset.key;
    const field = event.target.dataset.field;
    const table = event.target.dataset.table;
    const value =
      field === "Amount__c"
        ? parseFloat(event.target.value) || 0
        : event.target.value;
    const update = (lines) =>
      lines.map((line) => {
        return line._key === key ? { ...line, [field]: value } : line;
      });
    if (table === "payable") {
      this.payableLines = update(this.payableLines);
    } else {
      this.receivableLines = update(this.receivableLines);
    }
  }

  handleRemoveLine(event) {
    const key = event.currentTarget.dataset.key;
    const table = event.currentTarget.dataset.table;
    if (table === "payable") {
      this.payableLines = this.payableLines.filter((p) => p._key !== key);
    } else {
      this.receivableLines = this.receivableLines.filter((r) => r._key !== key);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  _validate() {
    const rec = this.currentRecord;
    if (!rec.Employee__c) return "Employee is required.";
    if (!rec.Relieving_Date__c) return "Relieving date is required.";
    const lines = [...this.payableLines, ...this.receivableLines];
    if (lines.some((line) => (parseFloat(line.Amount__c) || 0) < 0)) {
      return "Line amounts cannot be negative.";
    }
    return null;
  }

  async handleSave() {
    this.modalError = this._validate() || "";
    if (this.modalError) return;

    this.isSaving = true;
    const isNew = !this.currentRecord.Id;
    const payload = { Id: this.currentRecord.Id };
    EDITABLE_FIELDS.forEach((field) => {
      payload[field] = this.currentRecord[field] || null;
    });
    const serializeLines = (lines) =>
      JSON.stringify(
        lines.map((line) => ({
          Name: line.Name || null,
          Component__c: line.Component__c || null,
          Reference_Document__c: line.Reference_Document__c || null,
          Account__c: line.Account__c || null,
          Amount__c: parseFloat(line.Amount__c) || 0,
          Status__c: line.Status__c || "Pending"
        }))
      );
    try {
      await saveSettlement({
        settlementJson: JSON.stringify(payload),
        payablesJson: serializeLines(this.payableLines),
        receivablesJson: serializeLines(this.receivableLines),
        ...this._authParams
      });
      this.showModal = false;
      this._toast(
        "Success",
        isNew ? "Settlement created." : "Settlement updated.",
        "success"
      );
      await this._loadSettlements();
    } catch (error) {
      const message = reduceError(error, "Failed to save the settlement.");
      this.modalError = message;
      this._toast("Error", message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Status workflow and delete
  // ─────────────────────────────────────────────────────────────────────────

  async handleStatusAction(event) {
    const { id, status } = event.currentTarget.dataset;
    const rec = this.enrichedSettlements.find((s) => s.Id === id);
    if (!rec || this.actionPendingId) return;

    if (status === STATUS.PAID || status === STATUS.CANCELLED) {
      const confirmed = await LightningConfirm.open({
        label:
          status === STATUS.PAID
            ? "Mark settlement as paid?"
            : "Cancel settlement?",
        theme: "warning",
        message:
          status === STATUS.PAID
            ? `Mark ${rec.Name} for ${rec.employeeName} as paid (net ${rec.netPayableFormatted})? Paid settlements can no longer be edited.`
            : `Cancel ${rec.Name} for ${rec.employeeName}? Cancelled settlements can no longer be edited.`
      });
      if (!confirmed) return;
    }

    this.actionPendingId = id;
    try {
      await updateSettlementStatus({
        settlementId: id,
        newStatus: status,
        ...this._authParams
      });
      this._toast("Success", STATUS_SUCCESS[status], "success");
      await this._loadSettlements();
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to update the settlement status."),
        "error"
      );
    } finally {
      this.actionPendingId = null;
    }
  }

  async handleDelete(event) {
    const id = event.currentTarget.dataset.id;
    if (!id || this.actionPendingId) return;
    const confirmed = await LightningConfirm.open({
      message:
        "Delete this settlement and its payable and receivable lines? This cannot be undone.",
      label: "Delete settlement?",
      theme: "warning"
    });
    if (!confirmed) return;
    this.actionPendingId = id;
    try {
      await deleteSettlement({ settlementId: id, ...this._authParams });
      this._toast("Success", "Settlement deleted.", "success");
      await this._loadSettlements();
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to delete the settlement."),
        "error"
      );
    } finally {
      this.actionPendingId = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // View
  // ─────────────────────────────────────────────────────────────────────────

  get hasViewPayables() {
    return this.viewPayables.length > 0;
  }

  get hasViewReceivables() {
    return this.viewReceivables.length > 0;
  }

  async handleView(event) {
    const id = event.currentTarget.dataset.id;
    const found = this.enrichedSettlements.find((s) => s.Id === id);
    if (!found) return;
    this.viewRecord = found;
    this.viewPayables = [];
    this.viewReceivables = [];
    this.showViewModal = true;
    this.viewLinesLoading = true;
    const decorate = (line) => ({
      ...line,
      amountFormatted: formatMoney(line.Amount__c ?? 0),
      label: line.Component__c || line.Name
    });
    try {
      const [pays, recs] = await Promise.all([
        getPayables({ settlementId: id, ...this._authParams }),
        getReceivables({ settlementId: id, ...this._authParams })
      ]);
      this.viewPayables = (pays || []).map(decorate);
      this.viewReceivables = (recs || []).map(decorate);
    } catch (error) {
      this._toast(
        "Error",
        reduceError(error, "Failed to load the settlement lines."),
        "error"
      );
    } finally {
      this.viewLinesLoading = false;
    }
  }

  handleViewClose() {
    this.showViewModal = false;
    this.viewRecord = null;
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