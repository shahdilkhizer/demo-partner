import { LightningElement, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getAttendanceDashboardSummary from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceDashboardSummary";
import getAttendanceTrackerData from "@salesforce/apex/PWChrono_AttendanceController.getAttendanceTrackerData";

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
];

export default class PwchronoAttendanceDashboard extends LightningElement {
  static renderMode = "light";

  @track isLoading = true;
  @track error = null;
  @track recentRequests = [];
  @track stats = { present: 0, absent: 0, late: 0, onLeave: 0 };

  currentDate = new Date();
  currentMonth;
  currentYear;
  placeholderCards = [1, 2, 3, 4];

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  connectedCallback() {
    this.currentMonth = this.currentDate.getMonth();
    this.currentYear = this.currentDate.getFullYear();
    this.loadDashboardData();
  }

  get monthLabel() {
    return `${MONTH_NAMES[this.currentMonth]} ${this.currentYear}`;
  }

  get hasRecentRequests() {
    return this.recentRequests && this.recentRequests.length > 0;
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  loadDashboardData() {
    this.isLoading = true;
    this.error = null;

    const firstDay = new Date(this.currentYear, this.currentMonth, 1);
    const lastDay  = new Date(this.currentYear, this.currentMonth + 1, 0);
    const startDate = this.formatDate(firstDay);
    const endDate   = this.formatDate(lastDay);

    Promise.all([
      getAttendanceDashboardSummary({
        startDate,
        endDate,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      }),
      getAttendanceTrackerData({
        startDate,
        endDate,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      })
    ])
      .then(([summary, trackerDays]) => {
        this.recentRequests = summary?.recentRequests || [];
        this.stats = this.computeStats(trackerDays);
      })
      .catch((err) => {
        this.error = err?.body?.message || err?.message || "Error loading attendance data.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  computeStats(days) {
    const stats = { present: 0, absent: 0, late: 0, onLeave: 0 };
    if (!days) return stats;
    for (const day of days) {
      if (day.status === "Present") stats.present++;
      else if (day.status === "Absent") stats.absent++;
      else if (day.status === "Late")   { stats.present++; stats.late++; }
      else if (day.status === "Leave")  stats.onLeave++;
    }
    return stats;
  }

  // ── Month Navigation ──────────────────────────────────────────────────────

  handlePrevMonth() {
    if (this.currentMonth === 0) {
      this.currentMonth = 11;
      this.currentYear--;
    } else {
      this.currentMonth--;
    }
    this.loadDashboardData();
  }

  handleNextMonth() {
    if (this.currentMonth === 11) {
      this.currentMonth = 0;
      this.currentYear++;
    } else {
      this.currentMonth++;
    }
    this.loadDashboardData();
  }

  // ── User Actions ──────────────────────────────────────────────────────────

  handleNewRequest() {
    this.dispatchEvent(new CustomEvent("newrequest", { bubbles: true, composed: true }));
  }

  handleViewAll() {
    this.dispatchEvent(new CustomEvent("viewall", { bubbles: true, composed: true }));
  }

  handleRowClick(event) {
    const requestId = event.currentTarget.dataset.id;
    this.dispatchEvent(
      new CustomEvent("viewdetail", {
        detail: { requestId },
        bubbles: true,
        composed: true
      })
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  formatDate(d) {
    const yyyy = d.getFullYear();
    const mm   = String(d.getMonth() + 1).padStart(2, "0");
    const dd   = String(d.getDate()).padStart(2, "0");
    return `${yyyy}-${mm}-${dd}`;
  }
}