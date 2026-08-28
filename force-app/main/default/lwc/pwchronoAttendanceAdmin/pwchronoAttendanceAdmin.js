import getAllAttendance from "@salesforce/apex/PWChrono_AttendanceController.getAllAttendance";
import { logError } from "c/pwchronoErrorHandler";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoAttendanceAdmin extends LightningElement {
  @track attendanceData = [];
  @track allAttendanceData = [];
  @track isLoading = false;
  @track reportData = null;

  // Metrics
  @track metrics = {
    totalEmployees: 0,
    present: 0,
    late: 0,
    absent: 0,
    onLeave: 0,
    holiday: 0
  };

  // Filters
  @track selectedStatus = "All";
  @track selectedDate = null;

  // Dropdown State
  @track showExportDropdown = false;
  @track showStatusDropdown = false;
  @track showDeptDropdown = false;
  hasRendered = false;
  _boundCloseDropdowns;

  employeeId;
  sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.loadAttendance();
  }

  renderedCallback() {
    if (!this.hasRendered) {
      this.hasRendered = true;
      this._boundCloseDropdowns = this.closeDropdowns.bind(this);
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.("click", this._boundCloseDropdowns);
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      if (this._boundCloseDropdowns) {
        w?.removeEventListener?.("click", this._boundCloseDropdowns);
      }
    } catch {
      // no-op
    }
    this._boundCloseDropdowns = null;
  }

  closeDropdowns() {
    this.showExportDropdown = false;
    this.showStatusDropdown = false;
    this.showDeptDropdown = false;
  }

  toggleExportDropdown(event) {
    event.stopPropagation();
    this.showExportDropdown = !this.showExportDropdown;
    this.showStatusDropdown = false;
    this.showDeptDropdown = false;
  }

  toggleStatusDropdown(event) {
    event.stopPropagation();
    this.showStatusDropdown = !this.showStatusDropdown;
    this.showExportDropdown = false;
    this.showDeptDropdown = false;
  }

  toggleDeptDropdown(event) {
    event.stopPropagation();
    this.showDeptDropdown = !this.showDeptDropdown;
    this.showExportDropdown = false;
    this.showStatusDropdown = false;
  }

  get exportDropdownClass() {
    return this.showExportDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  get statusDropdownClass() {
    return this.showStatusDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  get deptDropdownClass() {
    return this.showDeptDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  async loadAttendance() {
    this.isLoading = true;
    try {
      const result = await getAllAttendance({
        dateFilter: this.selectedDate,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });

      if (result) {
        this.allAttendanceData = result.map((record) => ({
          ...record,
          employeeName: record.Employees__r
            ? record.Employees__r.Name
            : "Unknown",
          role: record.Employees__r ? record.Employees__r.Role__c : "Employee",
          statusClass: this.getStatusClass(record.Status__c),
          productionHours: this.calculateProductionHours(
            record.From_Time__c,
            record.To_Time__c
          ),
          overtime: "0h" // Placeholder logic
        }));
        this.attendanceData = [...this.allAttendanceData];
        this.calculateMetrics();
        this.setDefaultReportData();
      }
    } catch (error) {
      logError("pwchronoAttendanceAdmin.loadAttendance", error);
      this.showToast("Error", "Failed to load attendance data", "error");
    } finally {
      this.isLoading = false;
    }
  }

  calculateMetrics() {
    const total = this.attendanceData.length;
    const present = this.attendanceData.filter(
      (r) => r.Status__c === "Present"
    ).length;
    const late = this.attendanceData.filter(
      (r) => r.Status__c === "Late"
    ).length;
    const absent = this.attendanceData.filter(
      (r) => r.Status__c === "Absent"
    ).length;
    const onLeave = this.attendanceData.filter(
      (r) => r.Status__c === "On Leave"
    ).length;

    this.metrics = {
      totalEmployees: total, // This should ideally be total active employees, but using record count for now
      present,
      late,
      absent,
      onLeave,
      holiday: 0 // Placeholder
    };
  }

  getStatusClass(status) {
    let badgeClass = "badge d-inline-flex align-items-center ";
    switch (status) {
      case "Present":
        return badgeClass + "badge-success-transparent";
      case "Absent":
        return badgeClass + "badge-danger-transparent";
      case "Late":
        return badgeClass + "badge-warning-transparent";
      case "On Leave":
        return badgeClass + "badge-info-transparent";
      default:
        return badgeClass + "badge-light-transparent";
    }
  }

  calculateProductionHours(start, end) {
    if (!start || !end) return "0h";
    // Simple calculation placeholder. Real logic needs Time parsing.
    return "8h";
  }

  handleDateFilter(event) {
    this.selectedDate = event.target.value;
    this.loadAttendance(); // Reload from server for date
  }

  handleStatusFilter(event) {
    this.selectedStatus = event.target.dataset.value;
    this.applyClientFilters();
  }

  applyClientFilters() {
    if (this.selectedStatus === "All") {
      this.attendanceData = [...this.allAttendanceData];
    } else {
      this.attendanceData = this.allAttendanceData.filter(
        (r) => r.Status__c === this.selectedStatus
      );
    }
    this.calculateMetrics();
    this.setDefaultReportData();
  }

  setDefaultReportData() {
    const record =
      this.attendanceData && this.attendanceData.length
        ? this.attendanceData[0]
        : null;
    this.reportData = record ? this.buildReportData(record) : null;
  }

  buildReportData(record) {
    const dateLabel = record.Attendance_Date__c || "--";
    const punchIn = record.From_Time__c || "--";
    const punchOut = record.To_Time__c || "--";
    const status = record.Status__c || "--";
    const productive = this.calculateProductionHours(
      record.From_Time__c,
      record.To_Time__c
    );
    return {
      dateLabel,
      punchIn,
      punchOut,
      status,
      totalWorking: productive,
      productive,
      breakHours: "00m",
      overtime: record.overtime || "0h"
    };
  }

  // Modal State
  @track showModal = false;
  @track selectedRecordId;
  @track selectedRecord;

  handleNewAttendance() {
    this.selectedRecordId = null;
    this.selectedRecord = null;
    this.showModal = true;
  }

  handleEdit(event) {
    const id = event.currentTarget.dataset.id;
    this.selectedRecordId = id;
    this.selectedRecord = this.allAttendanceData.find((r) => r.Id === id);
    this.showModal = true;
  }

  handleCloseModal() {
    this.showModal = false;
    this.selectedRecordId = null;
    this.selectedRecord = null;
  }

  handleSaveSuccess() {
    this.loadAttendance(); // Reload data
  }

  handleReportModal() {
    this.setDefaultReportData();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}