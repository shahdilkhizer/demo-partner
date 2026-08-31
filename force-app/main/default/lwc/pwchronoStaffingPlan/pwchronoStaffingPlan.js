import getStaffingPlans from "@salesforce/apex/PWChrono_StaffingPlanController.getStaffingPlans";
import saveStaffingPlan from "@salesforce/apex/PWChrono_StaffingPlanController.saveStaffingPlan";
import saveStaffingPlanDetails from "@salesforce/apex/PWChrono_StaffingPlanController.saveStaffingPlanDetails";
import deleteStaffingPlan from "@salesforce/apex/PWChrono_StaffingPlanController.deleteStaffingPlan";
import updateStaffingPlanStatus from "@salesforce/apex/PWChrono_StaffingPlanController.updateStaffingPlanStatus";
import getActiveDesignations from "@salesforce/apex/PWChrono_StaffingPlanController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_StaffingPlanController.getActiveDepartments";
import getStaffingPlanById from "@salesforce/apex/PWChrono_StaffingPlanController.getStaffingPlanById";
import LightningConfirm from "lightning/confirm";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { CONSTANTS } from "c/pwchronoConstants";

const CURRENCY_CODE = CONSTANTS?.CURRENCY_CODE ?? "USD";

const emptyPlan = () => ({
  Id: null,
  Name: "",
  Company__c: "",
  Department__c: "",
  From_Date__c: "",
  To_Date__c: "",
  Status__c: "Draft",
  Notes__c: ""
});

const emptyDetailRow = () => ({
  _key: Date.now() + Math.random(),
  Designation__c: "",
  Vacancies__c: 0,
  Estimated_Cost_Per_Position__c: 0,
  Number_of_Positions__c: 0
});

export default class PwchronoStaffingPlan extends LightningElement {
  static renderMode = "light";

  @track allPlans = [];
  @track filteredPlans = [];
  @track isLoading = true;
  @track isModalOpen = false;
  @track isSaving = false;
  @track statusFilter = "All";

  @track editRecord = emptyPlan();
  @track editDetails = [];

  @track departmentOptions = [];
  @track designationOptions = [];

  _employeeId;
  _sessionToken;

  connectedCallback() {
    const session = getSession();
    this._employeeId = session?.user?.Id ?? null;
    this._sessionToken = getSessionToken();
    this.loadPlans();
    this.loadLookups();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────────

  async loadPlans() {
    this.isLoading = true;
    try {
      const raw = await getStaffingPlans({
        statusFilter: this.statusFilter === "All" ? null : this.statusFilter,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.allPlans = (raw ?? []).map((p) => this.enrichPlan(p));
      this.applyFilter();
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    } finally {
      this.isLoading = false;
    }
  }

  async loadLookups() {
    try {
      const [depts, desigs] = await Promise.all([
        getActiveDepartments(),
        getActiveDesignations()
      ]);
      this.departmentOptions = (depts ?? []).map((d) => ({
        label: d.Name,
        value: d.Id,
        selected: false
      }));
      this.designationOptions = (desigs ?? []).map((d) => ({
        label: d.Name,
        value: d.Id,
        selected: false
      }));
    } catch {
      this.showToast("Warning", "Could not load lookup data.", "warning");
    }
  }

  enrichPlan(p) {
    const fmt = (d) => {
      if (d) {
        return new Date(d).toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric"
        });
      }
      return "—";
    };
    const fmtCurrency = (v) => {
      if (v != null) {
        return new Intl.NumberFormat("en-US", {
          style: "currency",
          currency: CURRENCY_CODE,
          maximumFractionDigits: 0
        }).format(v);
      }
      return "—";
    };
    const badgeMap = {
      Draft: "badge bg-warning-subtle text-warning",
      Submitted: "badge bg-success-subtle text-success",
      Closed: "badge bg-secondary-subtle text-secondary"
    };
    return {
      ...p,
      departmentName: p.Department__r?.Name ?? "—",
      requestedByName: p.Requested_By__r?.Name ?? "—",
      formattedFromDate: fmt(p.From_Date__c),
      formattedToDate: fmt(p.To_Date__c),
      formattedCost: fmtCurrency(p.Total_Estimated_Cost__c),
      statusBadgeClass: badgeMap[p.Status__c] ?? "badge bg-light text-dark",
      isSubmitted: p.Status__c === "Submitted" || p.Status__c === "Closed"
    };
  }

  applyFilter() {
    this.filteredPlans = [...this.allPlans];
  }

  // ─── Metrics ─────────────────────────────────────────────────────────────────

  get totalCount() {
    return this.allPlans.length;
  }
  get draftCount() {
    return this.allPlans.filter((p) => p.Status__c === "Draft").length;
  }
  get submittedCount() {
    return this.allPlans.filter((p) => p.Status__c === "Submitted").length;
  }
  get closedCount() {
    return this.allPlans.filter((p) => p.Status__c === "Closed").length;
  }
  get hasPlans() {
    return this.filteredPlans.length > 0;
  }

  // ─── Filter ───────────────────────────────────────────────────────────────────

  handleStatusFilter(event) {
    this.statusFilter = event.target.value;
    this.loadPlans();
  }

  // ─── Modal helpers ────────────────────────────────────────────────────────────

  get modalTitle() {
    return this.editRecord.Id ? "Edit Staffing Plan" : "New Staffing Plan";
  }

  get isDraft() {
    return this.editRecord.Status__c === "Draft";
  }
  get isSubmitted() {
    return this.editRecord.Status__c === "Submitted";
  }
  get isClosed() {
    return this.editRecord.Status__c === "Closed";
  }

  get hasDetailRows() {
    return this.editDetails.length > 0;
  }

  get grandTotalFormatted() {
    const total = this.editDetails.reduce((acc, r) => {
      const cost = Number(r.Estimated_Cost_Per_Position__c) || 0;
      const vac = Number(r.Vacancies__c) || 0;
      return acc + cost * vac;
    }, 0);
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: CURRENCY_CODE,
      maximumFractionDigits: 0
    }).format(total);
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  handleNoop() {}

  handleNewPlan() {
    this.editRecord = emptyPlan();
    this.editDetails = [];
    this.refreshDesigOptions(null);
    this.refreshDeptOptions(null);
    this.isModalOpen = true;
  }

  async handleEdit(event) {
    const id = event.currentTarget.dataset.id;
    try {
      this.isLoading = true;
      const plan = await getStaffingPlanById({
        planId: id,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.editRecord = {
        Id: plan.Id,
        Name: plan.Name,
        Company__c: plan.Company__c ?? "",
        Department__c: plan.Department__c ?? "",
        From_Date__c: plan.From_Date__c ?? "",
        To_Date__c: plan.To_Date__c ?? "",
        Status__c: plan.Status__c ?? "Draft",
        Notes__c: plan.Notes__c ?? ""
      };
      this.editDetails = (plan.Staffing_Plan_Details__r ?? []).map((d) => ({
        ...d,
        _key: d.Id
      }));
      this.refreshDeptOptions(plan.Department__c);
      this.editDetails = this.editDetails.map((row) => this.recalcRow(row));
      this.isModalOpen = true;
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    } finally {
      this.isLoading = false;
    }
  }

  handleCloseModal() {
    this.isModalOpen = false;
  }

  handleFieldChange(event) {
    const { name, value } = event.target;
    this.editRecord = { ...this.editRecord, [name]: value };
    if (name === "Department__c") {
      this.refreshDeptOptions(value);
    }
  }

  handleAddDetailRow() {
    const newRow = recalcRowStatic(emptyDetailRow(), this.designationOptions);
    this.editDetails = [...this.editDetails, newRow];
  }

  handleRemoveDetailRow(event) {
    const idx = Number(event.currentTarget.dataset.idx);
    this.editDetails = this.editDetails.filter((_, i) => i !== idx);
  }

  handleDetailChange(event) {
    const idx = Number(event.currentTarget.dataset.idx);
    const { name, value } = event.currentTarget;
    this.editDetails = this.editDetails.map((row, i) => {
      if (i !== idx) return row;
      const updated = { ...row, [name]: value };
      return this.recalcRow(updated);
    });
  }

  recalcRow(row) {
    const cost = Number(row.Estimated_Cost_Per_Position__c) || 0;
    const vac = Number(row.Vacancies__c) || 0;
    const total = cost * vac;
    const fmtCurrency = (v) =>
      new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: CURRENCY_CODE,
        maximumFractionDigits: 0
      }).format(v);
    return {
      ...row,
      rowTotalFormatted: fmtCurrency(total)
    };
  }

  refreshDeptOptions(selectedId) {
    this.departmentOptions = this.departmentOptions.map((opt) => ({
      ...opt,
      selected: opt.value === selectedId
    }));
  }

  refreshDesigOptions(selectedId) {
    this.designationOptions = this.designationOptions.map((opt) => ({
      ...opt,
      selected: opt.value === selectedId
    }));
  }

  async handleSave() {
    if (!this.validate()) return;
    this.isSaving = true;
    try {
      const planPayload = { ...this.editRecord };
      delete planPayload.departmentName;
      delete planPayload.requestedByName;
      delete planPayload.formattedFromDate;
      delete planPayload.formattedToDate;
      delete planPayload.formattedCost;
      delete planPayload.statusBadgeClass;
      delete planPayload.isSubmitted;
      if (!planPayload.Id) delete planPayload.Id;
      if (!planPayload.From_Date__c) planPayload.From_Date__c = null;
      if (!planPayload.To_Date__c) planPayload.To_Date__c = null;
      if (!planPayload.Department__c) planPayload.Department__c = null;

      const planId = await saveStaffingPlan({
        planJson: JSON.stringify(planPayload),
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });

      const detailPayload = this.editDetails.map((row) => {
        const d = {
          Designation__c: row.Designation__c || null,
          Vacancies__c: Number(row.Vacancies__c) || 0,
          Estimated_Cost_Per_Position__c:
            Number(row.Estimated_Cost_Per_Position__c) || 0,
          Number_of_Positions__c: Number(row.Number_of_Positions__c) || 0
        };
        return d;
      });

      await saveStaffingPlanDetails({
        planId,
        detailsJson: JSON.stringify(detailPayload),
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });

      this.showToast("Success", "Staffing Plan saved successfully.", "success");
      this.isModalOpen = false;
      await this.loadPlans();
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    } finally {
      this.isSaving = false;
    }
  }

  async handleStatusChange(event) {
    const id = event.currentTarget.dataset.id;
    const newStatus = event.currentTarget.dataset.status;
    try {
      await updateStaffingPlanStatus({
        planId: id,
        newStatus,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.showToast("Success", `Status updated to ${newStatus}.`, "success");
      await this.loadPlans();
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    }
  }

  async handleDelete(event) {
    const id = event.currentTarget.dataset.id;
    const confirmed = await LightningConfirm.open({
      message: "Are you sure you want to delete this Staffing Plan?",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    try {
      await deleteStaffingPlan({
        planId: id,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.showToast("Success", "Staffing Plan deleted.", "success");
      await this.loadPlans();
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    }
  }

  handleViewDetail(event) {
    // Placeholder: future drill-down view
    const id = event.currentTarget.dataset.id;
    this.handleEdit({ currentTarget: { dataset: { id } } });
  }

  // ─── Validation ───────────────────────────────────────────────────────────────

  validate() {
    const r = this.editRecord;
    if (!r.Name?.trim()) {
      this.showToast("Validation", "Plan Name is required.", "warning");
      return false;
    }
    if (!r.From_Date__c) {
      this.showToast("Validation", "From Date is required.", "warning");
      return false;
    }
    if (!r.To_Date__c) {
      this.showToast("Validation", "To Date is required.", "warning");
      return false;
    }
    if (r.From_Date__c > r.To_Date__c) {
      this.showToast(
        "Validation",
        "From Date must be before To Date.",
        "warning"
      );
      return false;
    }
    return true;
  }

  // ─── Utilities ────────────────────────────────────────────────────────────────

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  extractMessage(err) {
    return (
      err?.body?.message ?? err?.message ?? "An unexpected error occurred."
    );
  }
}

function recalcRowStatic(row) {
  const cost = Number(row.Estimated_Cost_Per_Position__c) || 0;
  const vac = Number(row.Vacancies__c) || 0;
  const total = cost * vac;
  return {
    ...row,
    rowTotalFormatted: new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: CURRENCY_CODE,
      maximumFractionDigits: 0
    }).format(total)
  };
}