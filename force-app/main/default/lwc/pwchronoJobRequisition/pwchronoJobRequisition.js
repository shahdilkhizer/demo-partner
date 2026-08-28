import getJobRequisitions from "@salesforce/apex/PWChrono_JobRequisitionController.getJobRequisitions";
import getJobRequisitionById from "@salesforce/apex/PWChrono_JobRequisitionController.getJobRequisitionById";
import saveJobRequisition from "@salesforce/apex/PWChrono_JobRequisitionController.saveJobRequisition";
import deleteJobRequisition from "@salesforce/apex/PWChrono_JobRequisitionController.deleteJobRequisition";
import updateJobRequisitionStatus from "@salesforce/apex/PWChrono_JobRequisitionController.updateJobRequisitionStatus";
import getActiveDesignations from "@salesforce/apex/PWChrono_JobRequisitionController.getActiveDesignations";
import getActiveDepartments from "@salesforce/apex/PWChrono_JobRequisitionController.getActiveDepartments";
import getAvailableStaffingPlans from "@salesforce/apex/PWChrono_JobRequisitionController.getAvailableStaffingPlans";
import LightningConfirm from "lightning/confirm";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";
import { getSession, getSessionToken } from "c/pwchronoSession";

const emptyRecord = () => ({
  Id: null,
  Name: "",
  Company__c: "",
  Department__c: "",
  Designation__c: "",
  Requested_By_Department__c: "",
  No_of_Positions__c: 1,
  Expected_Compensation__c: null,
  Status__c: "Pending",
  Expected_By_Date__c: "",
  Posting_Date__c: "",
  Completed_On__c: "",
  Time_to_Fill__c: null,
  Staffing_Plan__c: "",
  Reason_for_Hiring__c: "",
  Job_Description__c: ""
});

const STATUS_BADGE = {
  Pending: "badge bg-warning-subtle text-warning",
  "Open & Approved": "badge bg-success-subtle text-success",
  Filled: "badge bg-primary-subtle text-primary",
  Rejected: "badge bg-danger-subtle text-danger",
  Closed: "badge bg-secondary-subtle text-secondary"
};

export default class PwchronoJobRequisition extends LightningElement {
  static renderMode = "light";

  @track records = [];
  @track isLoading = true;
  @track isModalOpen = false;
  @track isSaving = false;
  @track statusFilter = "All";

  @track editRecord = emptyRecord();
  @track departmentOptions = [];
  @track designationOptions = [];
  @track staffingPlanOptions = [];

  _employeeId;
  _sessionToken;

  connectedCallback() {
    const session = getSession();
    this._employeeId = session?.user?.Id ?? null;
    this._sessionToken = getSessionToken();
    this.loadRecords();
    this.loadLookups();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────────

  async loadRecords() {
    this.isLoading = true;
    try {
      const raw = await getJobRequisitions({
        statusFilter: this.statusFilter === "All" ? null : this.statusFilter,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.records = (raw ?? []).map((r) => this.enrichRecord(r));
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    } finally {
      this.isLoading = false;
    }
  }

  async loadLookups() {
    try {
      const [depts, desigs, plans] = await Promise.all([
        getActiveDepartments(),
        getActiveDesignations(),
        getAvailableStaffingPlans()
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
      this.staffingPlanOptions = (plans ?? []).map((p) => ({
        label: p.Name,
        value: p.Id,
        selected: false
      }));
    } catch {
      this.showToast("Warning", "Could not load lookup data.", "warning");
    }
  }

  enrichRecord(r) {
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
    return {
      ...r,
      designationName: r.Designation__r?.Name ?? "—",
      departmentName: r.Department__r?.Name ?? "—",
      staffingPlanName: r.Staffing_Plan__r?.Name ?? "—",
      formattedExpectedBy: fmt(r.Expected_By_Date__c),
      statusBadgeClass: STATUS_BADGE[r.Status__c] ?? "badge bg-light text-dark",
      cannotApprove: r.Status__c !== "Pending"
    };
  }

  // ─── Metrics ─────────────────────────────────────────────────────────────────

  get totalCount() {
    return this.records.length;
  }
  get pendingCount() {
    return this.records.filter((r) => r.Status__c === "Pending").length;
  }
  get approvedCount() {
    return this.records.filter(
      (r) => r.Status__c === "Open & Approved" || r.Status__c === "Filled"
    ).length;
  }
  get rejectedCount() {
    return this.records.filter(
      (r) => r.Status__c === "Rejected" || r.Status__c === "Closed"
    ).length;
  }
  get hasRecords() {
    return this.records.length > 0;
  }

  // ─── Status booleans for <option selected> ───────────────────────────────────

  get isPending() {
    return this.editRecord.Status__c === "Pending";
  }
  get isApproved() {
    return this.editRecord.Status__c === "Open & Approved";
  }
  get isFilled() {
    return this.editRecord.Status__c === "Filled";
  }
  get isRejected() {
    return this.editRecord.Status__c === "Rejected";
  }
  get isClosed() {
    return this.editRecord.Status__c === "Closed";
  }

  get isNewPosition() {
    return this.editRecord.Reason_for_Hiring__c === "New Position";
  }
  get isReplacement() {
    return this.editRecord.Reason_for_Hiring__c === "Replacement";
  }
  get isExpansion() {
    return this.editRecord.Reason_for_Hiring__c === "Expansion";
  }
  get isTemporary() {
    return this.editRecord.Reason_for_Hiring__c === "Temporary";
  }

  get modalTitle() {
    return this.editRecord.Id ? "Edit Job Requisition" : "New Job Requisition";
  }

  // ─── Filter ───────────────────────────────────────────────────────────────────

  handleStatusFilter(event) {
    this.statusFilter = event.target.value;
    this.loadRecords();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  handleNoop() {}

  handleNew() {
    this.editRecord = emptyRecord();
    this.refreshOptions(null, null, null);
    this.isModalOpen = true;
  }

  async handleEdit(event) {
    const id = event.currentTarget.dataset.id;
    try {
      this.isLoading = true;
      const rec = await getJobRequisitionById({
        requisitionId: id,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.editRecord = {
        Id: rec.Id,
        Name: rec.Name,
        Company__c: rec.Company__c ?? "",
        Department__c: rec.Department__c ?? "",
        Designation__c: rec.Designation__c ?? "",
        Requested_By_Department__c: rec.Requested_By_Department__c ?? "",
        No_of_Positions__c: rec.No_of_Positions__c ?? 1,
        Expected_Compensation__c: rec.Expected_Compensation__c ?? null,
        Status__c: rec.Status__c ?? "Pending",
        Expected_By_Date__c: rec.Expected_By_Date__c ?? "",
        Posting_Date__c: rec.Posting_Date__c ?? "",
        Completed_On__c: rec.Completed_On__c ?? "",
        Time_to_Fill__c: rec.Time_to_Fill__c ?? null,
        Staffing_Plan__c: rec.Staffing_Plan__c ?? "",
        Reason_for_Hiring__c: rec.Reason_for_Hiring__c ?? "",
        Job_Description__c: rec.Job_Description__c ?? ""
      };
      this.refreshOptions(
        rec.Department__c,
        rec.Designation__c,
        rec.Staffing_Plan__c
      );
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
      this.refreshOptions(
        value,
        this.editRecord.Designation__c,
        this.editRecord.Staffing_Plan__c
      );
    } else if (name === "Designation__c") {
      this.refreshOptions(
        this.editRecord.Department__c,
        value,
        this.editRecord.Staffing_Plan__c
      );
    } else if (name === "Staffing_Plan__c") {
      this.refreshOptions(
        this.editRecord.Department__c,
        this.editRecord.Designation__c,
        value
      );
    }
  }

  refreshOptions(deptId, desigId, planId) {
    this.departmentOptions = this.departmentOptions.map((o) => ({
      ...o,
      selected: o.value === deptId
    }));
    this.designationOptions = this.designationOptions.map((o) => ({
      ...o,
      selected: o.value === desigId
    }));
    this.staffingPlanOptions = this.staffingPlanOptions.map((o) => ({
      ...o,
      selected: o.value === planId
    }));
  }

  async handleSave() {
    if (!this.validate()) return;
    this.isSaving = true;
    try {
      const payload = { ...this.editRecord };
      // Strip enriched display fields before serialization
      [
        "designationName",
        "departmentName",
        "staffingPlanName",
        "formattedExpectedBy",
        "statusBadgeClass",
        "cannotApprove"
      ].forEach((k) => delete payload[k]);

      await saveJobRequisition({
        requisitionJson: JSON.stringify(payload),
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });

      this.showToast(
        "Success",
        "Job Requisition saved successfully.",
        "success"
      );
      this.isModalOpen = false;
      await this.loadRecords();
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
      await updateJobRequisitionStatus({
        requisitionId: id,
        newStatus,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.showToast("Success", `Status updated to ${newStatus}.`, "success");
      await this.loadRecords();
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    }
  }

  async handleDelete(event) {
    const id = event.currentTarget.dataset.id;
    const confirmed = await LightningConfirm.open({
      message: "Are you sure you want to delete this Job Requisition?",
      label: "Confirm Delete",
      theme: "warning"
    });
    if (!confirmed) return;
    try {
      await deleteJobRequisition({
        requisitionId: id,
        portalUserId: this._employeeId,
        sessionToken: this._sessionToken
      });
      this.showToast("Success", "Job Requisition deleted.", "success");
      await this.loadRecords();
    } catch (err) {
      this.showToast("Error", this.extractMessage(err), "error");
    }
  }

  // ─── Validation ───────────────────────────────────────────────────────────────

  validate() {
    if (!this.editRecord.Name?.trim()) {
      this.showToast("Validation", "Requisition Title is required.", "warning");
      return false;
    }
    const pos = Number(this.editRecord.No_of_Positions__c);
    if (!pos || pos < 1) {
      this.showToast(
        "Validation",
        "Number of Positions must be at least 1.",
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