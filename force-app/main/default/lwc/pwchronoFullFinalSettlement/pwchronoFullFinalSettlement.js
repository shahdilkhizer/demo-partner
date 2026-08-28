import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { PAGES } from "c/pwchronoRouter";
import getSettlements from "@salesforce/apex/PWChrono_FullFinalSettlementController.getSettlements";
import getSettlementById from "@salesforce/apex/PWChrono_FullFinalSettlementController.getSettlementById";
import getPayables from "@salesforce/apex/PWChrono_FullFinalSettlementController.getPayables";
import getReceivables from "@salesforce/apex/PWChrono_FullFinalSettlementController.getReceivables";
import saveSettlement from "@salesforce/apex/PWChrono_FullFinalSettlementController.saveSettlement";
import deleteSettlement from "@salesforce/apex/PWChrono_FullFinalSettlementController.deleteSettlement";
import getActiveDesignations from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveDepartments";
import getActiveEmployees from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveEmployees";
import getActiveSeparations from "@salesforce/apex/PWChrono_FullFinalSettlementController.getActiveSeparations";

const STATUS_BADGE = {
  Draft: "badge bg-secondary",
  Submitted: "badge bg-warning text-dark",
  Paid: "badge bg-success",
  Cancelled: "badge bg-danger"
};

const FFS_STATUSES = ["Draft", "Submitted", "Paid", "Cancelled"];

let _keyCounter = 0;

const emptyPayableLine = () => ({
  _key: ++_keyCounter,
  Component__c: "",
  Reference_Document__c: "",
  Account__c: "",
  Amount__c: 0,
  Status__c: "Pending",
  _statusPending: true,
  _statusPaid: false,
  _statusWaived: false
});

const emptyReceivableLine = () => ({
  _key: ++_keyCounter,
  Component__c: "",
  Reference_Document__c: "",
  Account__c: "",
  Amount__c: 0,
  Status__c: "Pending",
  _statusPending: true,
  _statusRecovered: false,
  _statusWaived: false
});

const emptyRecord = () => ({
  Employee__c: "",
  Employee_Name__c: "",
  Company__c: "",
  Department__c: "",
  Designation__c: "",
  Separation__c: "",
  Date_of_Joining__c: "",
  Relieving_Date__c: "",
  Status__c: "Draft"
});

export default class PwchronoFullFinalSettlement extends LightningElement {
  static renderMode = "light";

  @track settlements = [];
  @track currentRecord = emptyRecord();
  @track payableLines = [];
  @track receivableLines = [];
  @track viewRecord = {};

  @track isLoading = false;
  @track errorMessage = "";
  @track showModal = false;
  @track showViewModal = false;
  @track modalError = "";
  @track isSaving = false;
  @track isEditMode = false;

  _statusFilter = "All";
  _employees = [];
  _departments = [];
  _designations = [];
  _separations = [];
  _session = null;
  _pages = PAGES;

  connectedCallback() {
    this._session = getSession();
    this._loadLookups();
    this._loadSettlements();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  get isHR() {
    return this._session && this._session.role === "HR Admin";
  }

  get isEmployee() {
    return !this.isHR;
  }

  get hasRecords() {
    return this.settlements && this.settlements.length > 0;
  }

  get totalCount() {
    return this.settlements.length;
  }

  get draftCount() {
    return this.settlements.filter((s) => s.Status__c === "Draft").length;
  }

  get submittedCount() {
    return this.settlements.filter((s) => s.Status__c === "Submitted").length;
  }

  get paidCount() {
    return this.settlements.filter((s) => s.Status__c === "Paid").length;
  }

  get modalTitle() {
    return this.isEditMode ? "Edit Settlement" : "New Settlement";
  }

  get computedTotalPayable() {
    const total = this.payableLines.reduce(
      (sum, l) => sum + (parseFloat(l.Amount__c) || 0),
      0
    );
    return total.toFixed(2);
  }

  get computedTotalReceivable() {
    const total = this.receivableLines.reduce(
      (sum, l) => sum + (parseFloat(l.Amount__c) || 0),
      0
    );
    return total.toFixed(2);
  }

  get computedNetPayable() {
    const net =
      parseFloat(this.computedTotalPayable) -
      parseFloat(this.computedTotalReceivable);
    return net.toFixed(2);
  }

  get employeeOptions() {
    return this._employees.map((e) => ({
      value: e.Id,
      label:
        e.Full_Name__c +
        (e.Employee_ID__c ? " (" + e.Employee_ID__c + ")" : ""),
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
      label: s.Name + (s.Employee__r ? " — " + s.Employee__r.Full_Name__c : ""),
      selected: s.Id === this.currentRecord.Separation__c
    }));
  }

  get statusOptions() {
    return FFS_STATUSES.map((s) => ({
      value: s,
      label: s,
      selected: s === this.currentRecord.Status__c
    }));
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  _loadLookups() {
    Promise.all([
      getActiveEmployees(),
      getActiveDepartments(),
      getActiveDesignations(),
      getActiveSeparations()
    ])
      .then(([emps, depts, desigs, seps]) => {
        this._employees = emps;
        this._departments = depts;
        this._designations = desigs;
        this._separations = seps;
      })
      .catch(() => {});
  }

  _loadSettlements() {
    this.isLoading = true;
    this.errorMessage = "";
    const puid = this._session ? this._session.portalUserId : "";
    const tok = getSessionToken();
    getSettlements({
      statusFilter: this._statusFilter,
      portalUserId: puid,
      sessionToken: tok
    })
      .then((data) => {
        this.settlements = data.map((s) => ({
          ...s,
          _badgeClass: STATUS_BADGE[s.Status__c] || "badge bg-secondary"
        }));
        this.isLoading = false;
      })
      .catch((err) => {
        this.errorMessage = err.body ? err.body.message : err.message;
        this.isLoading = false;
      });
  }

  // ─── Filter ───────────────────────────────────────────────────────────────

  handleFilterChange(event) {
    this._statusFilter = event.target.value;
    this._loadSettlements();
  }

  // ─── New / Edit ───────────────────────────────────────────────────────────

  handleNew() {
    this.isEditMode = false;
    this.currentRecord = emptyRecord();
    this.payableLines = [];
    this.receivableLines = [];
    this.modalError = "";
    this.showModal = true;
  }

  handleEdit(event) {
    const id = event.currentTarget.dataset.id;
    const puid = this._session ? this._session.portalUserId : "";
    const tok = getSessionToken();
    this.isEditMode = true;
    this.modalError = "";
    Promise.all([
      getSettlementById({
        settlementId: id,
        portalUserId: puid,
        sessionToken: tok
      }),
      getPayables({ settlementId: id, portalUserId: puid, sessionToken: tok }),
      getReceivables({
        settlementId: id,
        portalUserId: puid,
        sessionToken: tok
      })
    ])
      .then(([rec, pays, recs]) => {
        this.currentRecord = { ...rec };
        this.payableLines = pays.map((p) => this._decoratePayable(p));
        this.receivableLines = recs.map((r) => this._decorateReceivable(r));
        this.showModal = true;
      })
      .catch((err) => {
        this.errorMessage = err.body ? err.body.message : err.message;
      });
  }

  _decoratePayable(p) {
    return {
      ...p,
      _key: ++_keyCounter,
      _statusPending: p.Status__c === "Pending",
      _statusPaid: p.Status__c === "Paid",
      _statusWaived: p.Status__c === "Waived"
    };
  }

  _decorateReceivable(r) {
    return {
      ...r,
      _key: ++_keyCounter,
      _statusPending: r.Status__c === "Pending",
      _statusRecovered: r.Status__c === "Recovered",
      _statusWaived: r.Status__c === "Waived"
    };
  }

  // ─── View ─────────────────────────────────────────────────────────────────

  handleView(event) {
    const id = event.currentTarget.dataset.id;
    const found = this.settlements.find((s) => s.Id === id);
    if (found) {
      this.viewRecord = { ...found };
      this.showViewModal = true;
    }
  }

  handleViewClose() {
    this.showViewModal = false;
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  async handleDelete(event) {
    const id = event.currentTarget.dataset.id;
    const confirmed = await LightningConfirm.open({
      message: "Delete this settlement? This action cannot be undone.",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    const puid = this._session ? this._session.portalUserId : "";
    const tok = getSessionToken();
    deleteSettlement({
      settlementId: id,
      portalUserId: puid,
      sessionToken: tok
    })
      .then(() => {
        this._loadSettlements();
      })
      .catch((err) => {
        this.errorMessage = err.body ? err.body.message : err.message;
      });
  }

  // ─── Modal Field Changes ──────────────────────────────────────────────────

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    this.currentRecord = { ...this.currentRecord, [field]: event.target.value };
  }

  // ─── Line Item Changes ────────────────────────────────────────────────────

  handleAddPayable() {
    this.payableLines = [...this.payableLines, emptyPayableLine()];
  }

  handleAddReceivable() {
    this.receivableLines = [...this.receivableLines, emptyReceivableLine()];
  }

  handleLineChange(event) {
    const key = parseInt(event.target.dataset.key, 10);
    const field = event.target.dataset.field;
    const table = event.target.dataset.table;
    const val =
      field === "Amount__c"
        ? parseFloat(event.target.value) || 0
        : event.target.value;

    if (table === "payable") {
      this.payableLines = this.payableLines.map((p) => {
        if (p._key !== key) return p;
        const updated = { ...p, [field]: val };
        if (field === "Status__c") {
          updated._statusPending = val === "Pending";
          updated._statusPaid = val === "Paid";
          updated._statusWaived = val === "Waived";
        }
        return updated;
      });
    } else {
      this.receivableLines = this.receivableLines.map((r) => {
        if (r._key !== key) return r;
        const updated = { ...r, [field]: val };
        if (field === "Status__c") {
          updated._statusPending = val === "Pending";
          updated._statusRecovered = val === "Recovered";
          updated._statusWaived = val === "Waived";
        }
        return updated;
      });
    }
  }

  handleRemoveLine(event) {
    const key = parseInt(event.currentTarget.dataset.key, 10);
    const table = event.currentTarget.dataset.table;
    if (table === "payable") {
      this.payableLines = this.payableLines.filter((p) => p._key !== key);
    } else {
      this.receivableLines = this.receivableLines.filter((r) => r._key !== key);
    }
  }

  // ─── Validate ─────────────────────────────────────────────────────────────

  _validate() {
    if (!this.currentRecord.Employee__c) {
      this.modalError = "Employee is required.";
      return false;
    }
    if (!this.currentRecord.Relieving_Date__c) {
      this.modalError = "Relieving Date is required.";
      return false;
    }
    return true;
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  handleSave() {
    this.modalError = "";
    if (!this._validate()) return;

    this.isSaving = true;
    const puid = this._session ? this._session.portalUserId : "";
    const tok = getSessionToken();

    const cleanPayables = this.payableLines.map((line) =>
      stripClientFields(line, [
        "_key",
        "_statusPending",
        "_statusPaid",
        "_statusWaived"
      ])
    );
    const cleanReceivables = this.receivableLines.map((line) =>
      stripClientFields(line, [
        "_key",
        "_statusPending",
        "_statusRecovered",
        "_statusWaived"
      ])
    );

    saveSettlement({
      settlementJson: JSON.stringify(this.currentRecord),
      payablesJson: JSON.stringify(cleanPayables),
      receivablesJson: JSON.stringify(cleanReceivables),
      portalUserId: puid,
      sessionToken: tok
    })
      .then(() => {
        this.isSaving = false;
        this.showModal = false;
        this._loadSettlements();
      })
      .catch((err) => {
        this.isSaving = false;
        this.modalError = err.body ? err.body.message : err.message;
      });
  }

  // ─── Modal Close ──────────────────────────────────────────────────────────

  handleModalClose() {
    this.showModal = false;
  }
}

function stripClientFields(record, fields) {
  const cleanRecord = { ...record };
  fields.forEach((field) => {
    delete cleanRecord[field];
  });
  return cleanRecord;
}