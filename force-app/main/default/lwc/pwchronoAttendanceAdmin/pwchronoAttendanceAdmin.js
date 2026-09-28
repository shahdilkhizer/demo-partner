import getAttendanceAdminRows from "@salesforce/apex/PWChrono_PortalApi.getAttendanceAdminRows";
import getAttendanceEmployeeOptions from "@salesforce/apex/PWChrono_PortalApi.getAttendanceEmployeeOptions";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import { logError } from "c/pwchronoErrorHandler";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoAttendanceAdmin extends NavigationMixin(
  LightningElement
) {
  @track attendanceData = [];
  @track allAttendanceData = [];
  @track isLoading = false;
  @track reportData = null;
  @track accessLoaded = false;
  @track hasAccess = false;
  @track canManage = false;
  @track accessRole = "";

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
    this.initializeAccess();
  }

  async initializeAccess() {
    try {
      const access = await getUserAccessById({
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      const features = access?.features || [];
      this.hasAccess =
        features.includes("Attendance Team") ||
        features.includes("Attendance Administration");
      this.canManage = features.includes("Attendance Administration");
      this.accessRole = access?.role || "";
      if (this.hasAccess) {
        await Promise.all([this.loadAttendance(), this.loadEmployeeOptions()]);
      }
    } catch (error) {
      logError("pwchronoAttendanceAdmin.initializeAccess", error);
      this.hasAccess = false;
    } finally {
      this.accessLoaded = true;
    }
  }

  async loadEmployeeOptions() {
    try {
      const options = await getAttendanceEmployeeOptions({
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      if (options && options.length > 0) {
        this.allEmployeeOptions = options;
      }
    } catch (error) {
      logError("pwchronoAttendanceAdmin.loadEmployeeOptions", error);
    }
  }

  get isAccessLoading() {
    return !this.accessLoaded;
  }

  get isAccessDenied() {
    return this.accessLoaded && !this.hasAccess;
  }

  get pageTitle() {
    return this.canManage ? "Attendance Administration" : "Team Attendance";
  }

  get pageDescription() {
    return this.canManage
      ? "Review and manage attendance across the organization."
      : "Review attendance for employees within your assigned scope.";
  }

  @track viewMode = "list"; // 'list' or 'grid'

  get isListView() {
    return this.viewMode === "list";
  }

  get isGridView() {
    return this.viewMode === "grid";
  }

  get listViewButtonClass() {
    return `btn btn-icon btn-sm me-1 ${this.isListView ? "active bg-primary text-white" : ""}`;
  }

  get gridViewButtonClass() {
    return `btn btn-icon btn-sm ${this.isGridView ? "active bg-primary text-white" : ""}`;
  }

  handleViewModeChange(event) {
    const view = event.currentTarget.dataset.view;
    if (view) {
      this.viewMode = view;
    }
  }

  get employeeOptions() {
    if (this.allEmployeeOptions && this.allEmployeeOptions.length > 0) {
      return this.allEmployeeOptions;
    }
    const seen = new Set();
    const options = [];
    for (const record of this.allAttendanceData || []) {
      if (record.Employees__c && !seen.has(record.Employees__c)) {
        seen.add(record.Employees__c);
        options.push({
          label: record.employeeName,
          value: record.Employees__c
        });
      }
    }
    return options.sort((a, b) => a.label.localeCompare(b.label));
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

  handleExportCsv() {
    downloadCsv(
      "team-attendance.csv",
      [
        "Employee",
        "Role",
        "Date",
        "Check in",
        "Check out",
        "Working hours",
        "Status"
      ],
      this.attendanceData.map((record) => [
        record.employeeName,
        record.role,
        record.Attendance_Date__c,
        record.From_Time__c,
        record.To_Time__c,
        record.productionHours,
        record.Status__c
      ])
    );
    this.showExportDropdown = false;
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
      const result = await getAttendanceAdminRows({
        dateFilter: this.selectedDate,
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });

      if (result) {
        this.allAttendanceData = result.map((record) => {
          const fromTime = record.checkIn || "—";
          const toTime = record.checkOut || "—";
          const prodHoursStr = this.calculateProductionHours(
            record.checkIn,
            record.checkOut
          );
          const prodNumeric = parseFloat(prodHoursStr) || 0;
          const progressPercent = Math.min(
            Math.round((prodNumeric / 8) * 100),
            100
          );
          let progressBarClass = "progress-bar bg-success";
          if (progressPercent < 50) {
            progressBarClass = "progress-bar bg-danger";
          } else if (progressPercent < 80) {
            progressBarClass = "progress-bar bg-warning";
          }

          const name = record.employeeName || "Unknown";
          const parts = name.trim().split(" ");
          const initials =
            parts.length > 1
              ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
              : name.substring(0, 2).toUpperCase();

          return {
            ...record,
            Id: record.attendanceRecordId || `employee-${record.employeeId}`,
            Employees__c: record.employeeId,
            Attendance_Date__c: record.attendanceDate,
            From_Time__c: fromTime,
            To_Time__c: toTime,
            Status__c: record.status,
            Request_Status__c: record.requestStatus || "Approved",
            Correction_Type__c: record.correctionType || "Other",
            employeeName: name,
            initials,
            role: record.role || "Employee",
            hasAttendanceRecord: Boolean(record.attendanceRecordId),
            statusClass: this.getStatusClass(record.status),
            productionHours: prodHoursStr,
            progressPercent,
            progressBarStyle: `width: ${progressPercent}%;`,
            progressBarClass,
            overtime: "—"
          };
        });
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
    const onLeave = this.attendanceData.filter((r) =>
      ["On Leave", "Leave"].includes(r.Status__c)
    ).length;
    const holiday = this.attendanceData.filter(
      (r) => r.Status__c === "Holiday"
    ).length;

    this.metrics = {
      totalEmployees: total,
      present,
      late,
      absent,
      onLeave,
      holiday
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
      case "Leave":
        return badgeClass + "badge-info-transparent";
      case "Holiday":
      case "Weekend":
      case "Future":
        return badgeClass + "badge-light-transparent";
      default:
        return badgeClass + "badge-light-transparent";
    }
  }

  calculateProductionHours(start, end) {
    if (!start || !end) return "0h";
    const startTime = new Date(`1970-01-01T${String(start).replace("Z", "")}Z`);
    const endTime = new Date(`1970-01-01T${String(end).replace("Z", "")}Z`);
    if (Number.isNaN(startTime.getTime()) || Number.isNaN(endTime.getTime())) {
      return "—";
    }
    let minutes = Math.round((endTime - startTime) / 60000);
    if (minutes < 0) minutes += 24 * 60;
    const hours = Math.floor(minutes / 60);
    const remainder = minutes % 60;
    return `${hours}h ${String(remainder).padStart(2, "0")}m`;
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
      breakHours: "—",
      overtime: record.overtime || "—"
    };
  }

  // Modal State
  @track showModal = false;
  @track selectedRecordId;
  @track selectedRecord;

  handleNewAttendance() {
    if (!this.canManage) {
      return;
    }
    this.selectedRecordId = null;
    this.selectedRecord = null;
    this.showModal = true;
  }

  handleEdit(event) {
    if (!this.canManage) {
      return;
    }
    const id = event.currentTarget.dataset.id;
    this.selectedRecordId = id;
    this.selectedRecord = this.allAttendanceData.find((r) => r.Id === id);
    this.showModal = true;
  }

  handleViewEmployee(event) {
    const employeeId = event.currentTarget.dataset.employeeId;
    if (!employeeId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "Attendance_Employee__c"
      },
      state: {
        c__employeeId: employeeId
      }
    });
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