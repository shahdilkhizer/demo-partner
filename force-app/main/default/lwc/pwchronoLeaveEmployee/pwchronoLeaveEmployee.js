import getMyLeaves from "@salesforce/apex/PWChrono_LeaveController.getMyLeaves";
import getMyLeaveBalance from "@salesforce/apex/PWChrono_LeaveController.getMyLeaveBalance";
import saveLeaveApplication from "@salesforce/apex/PWChrono_LeaveController.saveLeaveApplication";
import getActiveLeaveTypes from "@salesforce/apex/PWChrono_LeaveController.getActiveLeaveTypes";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoLeaveEmployee extends LightningElement {
  @track myLeaves = [];
  @track allMyLeaves = [];
  @track isLoading = false;

  // Metrics
  @track annualLeaveCount = 0;
  @track medicalLeaveCount = 0;
  @track otherLeaveCount = 0;
  @track remainingLeaveCount = 0;

  @track statusFilter = "All";
  @track startDate = null;
  @track endDate = null;

  employeeId;
  sessionToken;

  // Dropdown State
  @track showExportDropdown = false;
  @track showFilterDropdown = false;

  // New Leave Modal
  @track isNewLeaveModalOpen = false;
  @track isSavingLeave = false;
  @track leaveTypes = [];
  @track newLeaveForm = {
    leaveTypeId: "",
    fromDate: "",
    toDate: "",
    reason: "",
    halfDay: false
  };
  hasRendered = false;
  _boundCloseDropdowns;

  @wire(getActiveLeaveTypes)
  wiredLeaveTypes({ data }) {
    if (data) {
      this.leaveTypes = data.map((lt) => ({ label: lt.Name, value: lt.Id }));
    }
  }

  connectedCallback() {
    const session = getSession();
    this.employeeId = session.user ? session.user.Id : null;
    this.sessionToken = getSessionToken();
    Promise.all([this.loadLeaveBalance(), this.loadLeaveRequests()]);
  }

  renderedCallback() {
    if (!this.hasRendered) {
      this.hasRendered = true;
      this._boundCloseDropdowns = this.closeDropdowns.bind(this);
      globalThis.addEventListener("click", this._boundCloseDropdowns);
    }
  }

  disconnectedCallback() {
    if (this._boundCloseDropdowns) {
      globalThis.removeEventListener("click", this._boundCloseDropdowns);
    }
  }

  closeDropdowns() {
    this.showExportDropdown = false;
    this.showFilterDropdown = false;
  }

  toggleExportDropdown(event) {
    event.preventDefault();
    event.stopPropagation();
    this.showExportDropdown = !this.showExportDropdown;
    this.showFilterDropdown = false;
  }

  toggleFilterDropdown(event) {
    event.preventDefault();
    event.stopPropagation();
    this.showFilterDropdown = !this.showFilterDropdown;
    this.showExportDropdown = false;
  }

  get exportDropdownClass() {
    return this.showExportDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  get filterDropdownClass() {
    return this.showFilterDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  async loadLeaveBalance() {
    try {
      const balances = await getMyLeaveBalance({
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (balances) {
        let totalRemaining = 0;
        balances.forEach((b) => {
          const type = (b.leaveType || "").toLowerCase();
          if (type.includes("annual")) {
            this.annualLeaveCount = b.allocated || 0;
          } else if (type.includes("medical") || type.includes("sick")) {
            this.medicalLeaveCount = b.allocated || 0;
          } else {
            this.otherLeaveCount += b.allocated || 0;
          }
          totalRemaining += b.remaining || 0;
        });
        this.remainingLeaveCount = totalRemaining;
      }
    } catch {
      // Balance load failure is non-critical; leave counts at 0
    }
  }

  async loadLeaveRequests() {
    this.isLoading = true;
    try {
      const result = await getMyLeaves({
        statusFilter: this.statusFilter,
        startDate: this.startDate,
        endDate: this.endDate,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (result) {
        this.allMyLeaves = result.map((record) => ({
          ...record,
          leaveTypeName: record.Leave_Type__r
            ? record.Leave_Type__r.Name
            : "Other",
          statusClass: this.getStatusClass(record.Status__c),
          formattedStartDate: record.From_Date__c,
          formattedEndDate: record.To_Date__c,
          totalDays: record.Total_Days__c || 1
        }));
        this.myLeaves = [...this.allMyLeaves];
        // Calculate metrics if needed based on data
      }
    } catch (error) {
      this.showToast(
        "Error",
        "Failed to load leaves: " +
          (error.body ? error.body.message : error.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  getStatusClass(status) {
    // Map status to badge classes if needed
    return status;
  }

  handleStatusFilter(event) {
    event.preventDefault();
    event.stopPropagation();
    this.statusFilter = event.target.dataset.value;
    this.loadLeaveRequests();
  }

  handleDateFilter(event) {
    const val = event.target.value;
    if (val) {
      this.startDate = val;
    } else {
      this.startDate = null;
    }
    this.loadLeaveRequests();
  }

  handleNewLeaveRequest(event) {
    event?.preventDefault();
    this.newLeaveForm = {
      leaveTypeId: "",
      fromDate: "",
      toDate: "",
      reason: "",
      halfDay: false
    };
    this.isNewLeaveModalOpen = true;
  }

  handleCloseLeaveModal() {
    this.isNewLeaveModalOpen = false;
  }

  handleNewLeaveFormChange(event) {
    const field = event.target.name;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : event.target.value;
    this.newLeaveForm = { ...this.newLeaveForm, [field]: value };
  }

  async handleSubmitLeave() {
    if (
      !this.newLeaveForm.leaveTypeId ||
      !this.newLeaveForm.fromDate ||
      !this.newLeaveForm.toDate
    ) {
      this.showToast(
        "Validation",
        "Please fill in Leave Type, From Date and To Date.",
        "warning"
      );
      return;
    }
    this.isSavingLeave = true;
    try {
      const leaveRecord = {
        Leave_Type__c: this.newLeaveForm.leaveTypeId,
        From_Date__c: this.newLeaveForm.fromDate,
        To_Date__c: this.newLeaveForm.toDate,
        Reason__c: this.newLeaveForm.reason,
        Half_Day__c: this.newLeaveForm.halfDay,
        Status__c: "Submitted"
      };
      await saveLeaveApplication({
        leaveRecord,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.isNewLeaveModalOpen = false;
      this.showToast(
        "Success",
        "Leave request submitted successfully",
        "success"
      );
      await Promise.all([this.loadLeaveRequests(), this.loadLeaveBalance()]);
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSavingLeave = false;
    }
  }

  handleNoop(event) {
    event?.preventDefault();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}