import { LightningElement, track, wire } from "lwc";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getAttendanceTrackerDataForEmployee from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceTrackerDataForEmployee";
import { showErrorToast, logError } from "c/pwchronoErrorHandler";
import { getSession, getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";

const MONTH_NAMES = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
];

export default class PwchronoAttendanceTracker extends NavigationMixin(
  LightningElement
) {
  @track currentDate = new Date();
  @track attendanceData = [];
  @track isLoading = false;
  @track error = null;
  @track reportData = null;

  // Modal State
  @track showModal = false;
  @track selectedRecordId;
  @track selectedRecord;

  @track stats = {
    present: 0,
    absent: 0,
    late: 0,
    leaves: 0
  };

  @track hasAccess = false;
  @track accessLoaded = false;
  @track debugInfo = "";

  safeStringify(value) {
    try {
      return JSON.stringify(value, null, 2);
    } catch {
      // If this is a Proxy/circular structure in Live Preview, avoid crashing the page.
      return "[unserializable]";
    }
  }

  // Dropdown State
  @track showExportDropdown = false;
  @track showStatusDropdown = false;
  @track showDateRangeDropdown = false;

  @track viewMode = "list"; // 'list' or 'calendar'
  @track selectedStatus = "All"; // All, Present, Absent, Late, Leave
  @track selectedDateRange = "This Week"; // 'Week', 'Month', 'Custom'

  @track customStartDate;
  @track customEndDate;
  @track isCustomDateMode = false;

  // Raw data from server
  rawAttendanceData = [];

  employeeId;
  targetEmployeeId;
  sessionToken;
  userName = "Employee";
  hasRendered = false;
  _boundWindowClick;

  connectedCallback() {
    const session = getSession();
    this.employeeId =
      getEmployeeId() || (session.user ? session.user.Id : null);
    this.sessionToken = getSessionToken();
    this.userName = session.user ? session.user.Name : "Employee";
    this.checkAccess();
  }

  @wire(CurrentPageReference)
  capturePageReference(pageReference) {
    const nextEmployeeId = pageReference?.state?.c__employeeId || null;
    const employeeChanged = nextEmployeeId !== this.targetEmployeeId;
    this.targetEmployeeId = nextEmployeeId;
    if (employeeChanged && this.hasAccess) {
      this.loadData();
    }
  }

  get isViewingEmployeeAsAdmin() {
    return Boolean(
      this.targetEmployeeId && this.targetEmployeeId !== this.employeeId
    );
  }

  handleBackToAdmin() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "Attendance_Admin__c"
      }
    });
  }

  get isListView() {
    return this.viewMode === "list";
  }

  get isCalendarView() {
    return this.viewMode === "calendar";
  }

  get listViewButtonClass() {
    return `btn btn-icon btn-sm me-1 ${this.viewMode === "list" ? "active bg-primary text-white" : ""}`;
  }

  get calendarViewButtonClass() {
    return `btn btn-icon btn-sm me-1 ${this.viewMode === "calendar" ? "active bg-primary text-white" : ""}`;
  }

  get userInitials() {
    if (!this.userName) return "E";
    const nameParts = this.userName.split(" ");
    if (nameParts.length >= 2) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    }
    return this.userName.substring(0, 2).toUpperCase();
  }

  handleViewChange(event) {
    this.viewMode = event.currentTarget.dataset.view;
  }

  renderedCallback() {
    if (!this.hasRendered) {
      this.hasRendered = true;
      this._boundWindowClick = this.closeDropdowns.bind(this);
      window.addEventListener("click", this._boundWindowClick);
    }
  }

  disconnectedCallback() {
    if (this._boundWindowClick) {
      window.removeEventListener("click", this._boundWindowClick);
      this._boundWindowClick = null;
    }
  }

  closeDropdowns(event) {
    // Don't close if clicking inside a dropdown content (like Custom Date Inputs)
    const target = event?.target;
    if (
      target &&
      target.closest(".dropdown-menu") &&
      target.closest(".keep-open")
    ) {
      return;
    }

    this.showExportDropdown = false;
    this.showStatusDropdown = false;
    this.showDateRangeDropdown = false;
  }

  toggleExportDropdown(event) {
    this.stopPropagation(event);
    this.showExportDropdown = !this.showExportDropdown;
    this.showStatusDropdown = false;
    this.showDateRangeDropdown = false;
  }

  toggleStatusDropdown(event) {
    this.stopPropagation(event);
    this.showStatusDropdown = !this.showStatusDropdown;
    this.showExportDropdown = false;
    this.showDateRangeDropdown = false;
  }

  toggleDateRangeDropdown(event) {
    this.stopPropagation(event);
    this.showDateRangeDropdown = !this.showDateRangeDropdown;
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

  get dateRangeDropdownClass() {
    return this.showDateRangeDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  get dateRangeLabel() {
    if (this.selectedDateRange === "Custom") {
      return `${this.customStartDate || ""} - ${this.customEndDate || ""}`;
    }
    return this.selectedDateRange;
  }

  handleStatusSelect(event) {
    this.stopPropagation(event);
    this.selectedStatus = event.currentTarget.dataset.value;
    this.showStatusDropdown = false;
    this.filterData();
  }

  handleDateRangeSelect(event) {
    this.stopPropagation(event);
    const range = event.currentTarget.dataset.value;
    if (range === "Custom") {
      this.isCustomDateMode = true;
      // Don't close dropdown yet
    } else {
      this.selectedDateRange = range;
      this.isCustomDateMode = false;
      this.showDateRangeDropdown = false;
      this.loadData();
    }
  }

  handleCustomDateApply() {
    if (this.customStartDate && this.customEndDate) {
      this.selectedDateRange = "Custom";
      this.showDateRangeDropdown = false;
      this.loadData();
    }
  }

  handleCustomStartDate(event) {
    this.customStartDate = event.target.value;
  }

  handleCustomEndDate(event) {
    this.customEndDate = event.target.value;
  }

  get currentDateFormatted() {
    const options = {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric"
    };
    return this.currentDate.toLocaleDateString("en-US", options);
  }

  get currentTimeFormatted() {
    return new Date().toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit"
    });
  }

  get greeting() {
    const hour = new Date().getHours();
    if (hour < 12) return "Good Morning";
    if (hour < 18) return "Good Afternoon";
    return "Good Evening";
  }

  get isAccessLoading() {
    return !this.accessLoaded;
  }

  get isAccessDenied() {
    return this.accessLoaded && !this.hasAccess;
  }

  async checkAccess() {
    try {
      const employeeId = getEmployeeId();
      const accessData = await getUserAccessById({
        employeeId: employeeId,
        sessionToken: this.sessionToken
      });
      this.debugInfo = this.safeStringify(accessData);
      if (
        accessData.features &&
        accessData.features.includes("Attendance Management")
      ) {
        this.hasAccess = true;
        this.loadData();
      }
      this.accessLoaded = true;
    } catch (error) {
      const message = error?.body?.message || error?.message || "Unknown error";
      this.debugInfo = "Error: " + message;
      this.hasAccess = false;
      this.accessLoaded = true;
    }
  }

  get currentMonthName() {
    return MONTH_NAMES[this.currentDate.getMonth()];
  }

  get currentYear() {
    return this.currentDate.getFullYear();
  }

  get presentPercentage() {
    const total = this.stats.present + this.stats.absent + this.stats.late;
    if (total === 0) return 0;
    return Math.round((this.stats.present / total) * 100);
  }

  get recordCount() {
    return this.attendanceData ? this.attendanceData.length : 0;
  }

  stopPropagation(event) {
    event.stopPropagation();
  }

  handlePrevMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() - 1);
    this.currentDate = new Date(this.currentDate);
    this.loadData();
  }

  handleNextMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() + 1);
    this.currentDate = new Date(this.currentDate);
    this.loadData();
  }

  handleToday() {
    this.currentDate = new Date();
    this.loadData();
  }

  loadData() {
    this.isLoading = true;
    let startDate, endDate;

    if (this.selectedDateRange === "This Week") {
      const curr = new Date();
      const first = curr.getDate() - curr.getDay(); // First day is the day of the month - the day of the week
      startDate = new Date(curr.setDate(first));
      endDate = new Date(curr.setDate(curr.getDate() + 6));
    } else if (this.selectedDateRange === "Last Month") {
      const now = new Date();
      startDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      endDate = new Date(now.getFullYear(), now.getMonth(), 0);
    } else if (this.selectedDateRange === "Custom") {
      startDate = new Date(this.customStartDate);
      endDate = new Date(this.customEndDate);
    } else {
      // Default: This Month
      const year = this.currentDate.getFullYear();
      const month = this.currentDate.getMonth();
      startDate = new Date(year, month, 1);
      endDate = new Date(year, month + 1, 0);
    }

    // Adjust for timezone offset if needed or use local YYYY-MM-DD
    // Using simple ISO string split might be off by one day depending on timezone
    // Safer to use local pieces
    const startStr = this.formatDateToIso(startDate);
    const endStr = this.formatDateToIso(endDate);

    getAttendanceTrackerDataForEmployee({
      startDate: startStr,
      endDate: endStr,
      targetEmployeeId: this.targetEmployeeId,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        if (result?.[0]?.employeeName) {
          this.userName = result[0].employeeName;
        }
        this.rawAttendanceData = result; // Store for filtering
        this.processData(result);
        this.filterData(); // Apply status filter
        this.error = null;
      })
      .catch((error) => {
        this.error =
          error?.body?.message ||
          error?.message ||
          "Failed to load attendance data";
        logError("AttendanceTracker.loadData", error);
        showErrorToast(
          this.dispatchEvent.bind(this),
          "Error",
          "Failed to load attendance data"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  formatDateToIso(dateObj) {
    if (!dateObj || isNaN(dateObj.getTime())) return null;
    const y = dateObj.getFullYear();
    const m = String(dateObj.getMonth() + 1).padStart(2, "0");
    const d = String(dateObj.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  }

  filterData() {
    // Filter rawAttendanceData based on selectedStatus
    // And update attendanceData (which is mapped)

    // Since processData maps raw data to display format, we should probably:
    // 1. Process Raw Data -> Mapped All Data
    // 2. Filter Mapped Data

    // Let's re-run processData on the raw data, but inside processData we only output matches?
    // Better: Process ALL, then filter.

    this.processData(this.rawAttendanceData); // Re-process all

    if (this.selectedStatus !== "All") {
      this.attendanceData = this.attendanceData.filter((item) => {
        if (this.selectedStatus === "Present") return item.status === "Present";
        if (this.selectedStatus === "Absent") return item.status === "Absent";
        if (this.selectedStatus === "Late") return item.isLate;
        if (this.selectedStatus === "Leave") return item.status === "Leave";
        return true;
      });
    }

    this.setDefaultReportData();
  }

  setDefaultReportData() {
    const day =
      this.attendanceData && this.attendanceData.length
        ? this.attendanceData[0]
        : null;
    this.reportData = day ? this.buildReportData(day) : null;
  }

  buildReportData(day) {
    return {
      dateLabel: day.formattedDate || "--",
      punchIn: day.formattedCheckIn || "--",
      punchOut: day.formattedCheckOut || "--",
      status: day.displayStatus || "--",
      totalWorking: day.productionHours || "--",
      productive: day.productionHours || "--",
      breakHours: day.breakTime || "00 Min",
      overtime: "0h"
    };
  }

  processData(data) {
    if (!data) {
      this.attendanceData = [];
      return;
    }

    let present = 0;
    let absent = 0;
    let late = 0;
    let leaves = 0;

    this.attendanceData = data.map((day) => {
      // Update Stats
      if (day.status === "Present") present++;
      if (
        day.status === "Absent" &&
        day.dayName !== "Saturday" &&
        day.dayName !== "Sunday"
      )
        absent++; // Simple logic
      if (day.isLate) late++;
      if (day.status === "Leave") leaves++;

      // Format Times
      const formattedCheckIn = this.formatTime(day.checkIn) || "--";
      const formattedCheckOut = this.formatTime(day.checkOut) || "--";
      const formattedShiftStart = this.formatTime(day.shiftStart);
      const formattedShiftEnd = this.formatTime(day.shiftEnd);

      // Extract date number for timeline display
      const dateObj = new Date(day.attendanceDate);
      const dateNumber = dateObj.getDate();

      // Production Hours
      let productionHours = "--";
      if (day.checkIn && day.checkOut) {
        const cIn = this.getTimeInMs(day.checkIn);
        const cOut = this.getTimeInMs(day.checkOut);
        if (cIn !== 0 && cOut !== 0) {
          let diffMs = cOut - cIn;
          if (diffMs < 0) diffMs = 0;
          // Decimal hours (e.g. 8.55 Hrs)
          const decHrs = (diffMs / 3600000).toFixed(2);
          productionHours = `${decHrs} Hrs`;
        }
      }

      // Break (Mock or Derived)
      const breakTime = "00 Min"; // Placeholder until data available

      // Late Status & Duration
      let lateDisplay = "-"; // Default
      if (day.isLate) {
        lateDisplay = "Late"; // Fallback
        // Calculate duration if slots available
        if (day.checkIn && day.shiftStart) {
          // Assuming shiftStart is time-of-day ms.
          // Need to align checkIn date with shiftStart (which is just time).
          // Logic: checkIn includes date? No, APEX returns Time field as ms usually?
          // Let's verify formatTime behavior.
          // formatTime handles "string" HH:mm or "number" ms.
          // If both are numbers (ms from midnight), simple subtraction.
          // If one is string, convert.
          const checkInMs = this.getTimeInMs(day.checkIn);
          const shiftStartMs = this.getTimeInMs(day.shiftStart);

          if (checkInMs > shiftStartMs) {
            const diffMin = Math.floor((checkInMs - shiftStartMs) / 60000);
            lateDisplay = `${diffMin} Min`;
          }
        }
      }

      // Determine Status Display & Class
      let displayStatus = day.status;
      let statusClass = "status-badge";
      let attendanceStatus = (day.status || "").toLowerCase();
      let rowClass = "";

      if (day.status === "Present") {
        statusClass += " status-present";
      } else if (day.status === "Absent") {
        statusClass += " status-absent";
        rowClass = "attendance-row-warning";
      } else if (day.status === "Leave") {
        statusClass += " status-leave";
        displayStatus = `Leave (${day.leaveType})`;
        attendanceStatus = "leave";
      } else if (day.status === "Holiday") {
        statusClass += " status-holiday";
        displayStatus = `Holiday: ${day.holidayName}`;
        attendanceStatus = "holiday";
      } else if (day.status === "Weekend") {
        statusClass += " status-weekend";
        attendanceStatus = "weekend";
      }

      // Can Regularize? (Absent or Late/Early in the past)
      const isPast = new Date(day.attendanceDate) <= new Date();
      const canRegularize =
        isPast &&
        (day.status === "Absent" ||
          day.isLate ||
          day.isEarlyLeave ||
          day.status === "Present") &&
        day.status !== "Leave" &&
        day.status !== "Holiday" &&
        day.status !== "Weekend";

      return {
        ...day,
        formattedDate: day.attendanceDate,
        dateNumber,
        formattedCheckIn,
        formattedCheckOut,
        productionHours,
        breakTime,
        lateDisplay,
        formattedShiftStart,
        formattedShiftEnd,
        displayStatus,
        statusClass,
        attendanceStatus,
        rowClass,
        canRegularize
      };
    });

    this.stats = { present, absent, late, leaves };
  }

  getTimeInMs(timeVal) {
    if (typeof timeVal === "number") return timeVal;
    if (typeof timeVal === "string") {
      const parts = timeVal.split(":");
      if (parts.length >= 2) {
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        let s = 0;
        if (parts.length >= 3) {
          s = parseFloat(parts[2]);
        }
        return h * 3600000 + m * 60000 + s * 1000;
      }
    }
    return 0;
  }

  formatTime(timeMs) {
    if (!timeMs && timeMs !== 0) return "";

    try {
      let hours, minutes;

      // Handle string format "HH:mm:ss" or "HH:mm:ss.SSSZ"
      if (typeof timeMs === "string") {
        const timeParts = timeMs.split(":");
        if (timeParts.length >= 2) {
          hours = parseInt(timeParts[0], 10);
          minutes = parseInt(timeParts[1], 10);
        } else {
          return timeMs;
        }
      }
      // Handle milliseconds from midnight
      else if (typeof timeMs === "number") {
        const date = new Date();
        date.setHours(0, 0, 0, 0);
        date.setMilliseconds(timeMs);
        hours = date.getHours();
        minutes = date.getMinutes();
      } else {
        return timeMs;
      }

      // Convert to 12-hour format
      const hour12 = hours % 12 || 12;
      const minutesPadded = String(minutes).padStart(2, "0");
      const ampm = hours >= 12 ? "PM" : "AM";
      return `${hour12}:${minutesPadded} ${ampm}`;
    } catch (error) {
      logError("AttendanceTracker.formatTime", error);
      return timeMs;
    }
  }

  // Modal Handlers
  handleAddAttendance() {
    this.selectedRecordId = null;
    this.selectedRecord = null;
    this.showModal = true;
  }

  handleEdit(event) {
    const recordId = event.currentTarget?.dataset?.id;
    if (recordId) {
      this.selectedRecordId = recordId;
      this.selectedRecord = null; // Let the modal fetch the record details if needed, or pass row data if available
      this.showModal = true;
    }
  }

  handleCloseModal() {
    this.showModal = false;
    this.selectedRecordId = null;
    this.selectedRecord = null;
  }

  handleSaveSuccess() {
    this.showModal = false;
    this.loadData(); // Refresh the list
  }
}