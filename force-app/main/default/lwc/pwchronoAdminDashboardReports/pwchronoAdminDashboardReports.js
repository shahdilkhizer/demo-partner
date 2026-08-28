import { LightningElement, track, wire } from "lwc";
import getDashboardSummary from "@salesforce/apex/PWChrono_ReportsDashboardController.getDashboardSummary";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

/**
 * PWChrono Reports Dashboard
 *
 * A comprehensive dashboard displaying HR metrics using real Salesforce data.
 * Works for both internal users and guest portal users.
 */
export default class PwchronoAdminDashboardReports extends LightningElement {
  @track isLoading = true;
  @track error = "";
  @track dashboardData = null;

  // Styling is supplied by global Experience Cloud header CSS.

  employeeId;
  sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getDashboardSummary, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredDashboard({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.dashboardData = data;
      this.error = "";
    } else if (error) {
      this.error = error.body?.message || "Failed to load dashboard data";
      this.dashboardData = null;
    }
  }

  // ==================== LEAVE METRICS ====================
  get hasLeaveData() {
    return this.dashboardData?.leaveMetrics != null;
  }

  get leaveTotal() {
    return this.dashboardData?.leaveMetrics?.totalRequests || 0;
  }

  get leavePending() {
    return this.dashboardData?.leaveMetrics?.pending || 0;
  }

  get leaveApproved() {
    return this.dashboardData?.leaveMetrics?.approved || 0;
  }

  get leaveRejected() {
    return this.dashboardData?.leaveMetrics?.rejected || 0;
  }

  get leaveByType() {
    const types = this.dashboardData?.leaveMetrics?.byType || [];
    const colors = [
      "bg-blue-500",
      "bg-green-500",
      "bg-yellow-500",
      "bg-purple-500",
      "bg-pink-500"
    ];
    return types.map((item, index) => ({
      ...item,
      key: `leave-type-${index}`,
      colorClass: colors[index % colors.length],
      percentage:
        this.leaveTotal > 0
          ? Math.round((item.count / this.leaveTotal) * 100)
          : 0
    }));
  }

  // ==================== ATTENDANCE METRICS ====================
  get hasAttendanceData() {
    return this.dashboardData?.attendanceMetrics != null;
  }

  get attendanceTotal() {
    return this.dashboardData?.attendanceMetrics?.totalRecords || 0;
  }

  get attendanceOnTime() {
    return this.dashboardData?.attendanceMetrics?.onTime || 0;
  }

  get attendanceLate() {
    return this.dashboardData?.attendanceMetrics?.late || 0;
  }

  get attendanceAbsent() {
    return this.dashboardData?.attendanceMetrics?.absent || 0;
  }

  get attendanceRate() {
    return this.dashboardData?.attendanceMetrics?.attendanceRate || 0;
  }

  get attendanceRateFormatted() {
    return `${this.attendanceRate}%`;
  }

  // ==================== EMPLOYEE METRICS ====================
  get hasEmployeeData() {
    return this.dashboardData?.employeeMetrics != null;
  }

  get employeeTotal() {
    return this.dashboardData?.employeeMetrics?.totalEmployees || 0;
  }

  get employeeActive() {
    return this.dashboardData?.employeeMetrics?.activeEmployees || 0;
  }

  get employeeInactive() {
    return this.dashboardData?.employeeMetrics?.inactiveEmployees || 0;
  }

  get employeesByDepartment() {
    const depts = this.dashboardData?.employeeMetrics?.byDepartment || [];
    const colors = [
      "bg-indigo-500",
      "bg-teal-500",
      "bg-orange-500",
      "bg-pink-500",
      "bg-cyan-500",
      "bg-lime-500",
      "bg-amber-500",
      "bg-rose-500"
    ];
    const maxCount = Math.max(...depts.map((d) => d.count), 1);
    return depts.map((item, index) => ({
      ...item,
      key: `dept-${index}`,
      colorClass: colors[index % colors.length],
      widthPercentage: Math.round((item.count / maxCount) * 100)
    }));
  }

  // ==================== PERFORMANCE METRICS ====================
  get hasPerformanceData() {
    return this.dashboardData?.performanceMetrics != null;
  }

  get goalsTotal() {
    return this.dashboardData?.performanceMetrics?.totalGoals || 0;
  }

  get goalsCompleted() {
    return this.dashboardData?.performanceMetrics?.completed || 0;
  }

  get goalsInProgress() {
    return this.dashboardData?.performanceMetrics?.inProgress || 0;
  }

  get goalsNotStarted() {
    return this.dashboardData?.performanceMetrics?.notStarted || 0;
  }

  get avgProgress() {
    return this.dashboardData?.performanceMetrics?.avgProgress || 0;
  }

  get avgProgressFormatted() {
    return `${this.avgProgress}%`;
  }

  // ==================== EXPENSE METRICS ====================
  get hasExpenseData() {
    return this.dashboardData?.expenseMetrics != null;
  }

  get expenseTotal() {
    return this.dashboardData?.expenseMetrics?.totalClaims || 0;
  }

  get expenseTotalAmount() {
    return this.formatCurrency(
      this.dashboardData?.expenseMetrics?.totalAmount || 0
    );
  }

  get expenseApprovedAmount() {
    return this.formatCurrency(
      this.dashboardData?.expenseMetrics?.approvedAmount || 0
    );
  }

  get expensePendingAmount() {
    return this.formatCurrency(
      this.dashboardData?.expenseMetrics?.pendingAmount || 0
    );
  }

  // ==================== TRAINING METRICS ====================
  get hasTrainingData() {
    return this.dashboardData?.trainingMetrics != null;
  }

  get trainingTotal() {
    return this.dashboardData?.trainingMetrics?.totalPrograms || 0;
  }

  get trainingActive() {
    return this.dashboardData?.trainingMetrics?.activePrograms || 0;
  }

  get trainingCompleted() {
    return this.dashboardData?.trainingMetrics?.completedPrograms || 0;
  }

  get trainingUpcoming() {
    return this.dashboardData?.trainingMetrics?.upcomingPrograms || 0;
  }

  // ==================== RECRUITMENT METRICS ====================
  get hasRecruitmentData() {
    return this.dashboardData?.recruitmentMetrics != null;
  }

  get recruitmentTotal() {
    return this.dashboardData?.recruitmentMetrics?.totalOpenings || 0;
  }

  get recruitmentActive() {
    return this.dashboardData?.recruitmentMetrics?.activeOpenings || 0;
  }

  get recruitmentClosed() {
    return this.dashboardData?.recruitmentMetrics?.closedOpenings || 0;
  }

  get recruitmentApplicants() {
    return this.dashboardData?.recruitmentMetrics?.totalApplicants || 0;
  }

  // ==================== UTILITY METHODS ====================
  formatCurrency(amount) {
    if (amount >= 1000000) {
      return `$${(amount / 1000000).toFixed(1)}M`;
    } else if (amount >= 1000) {
      return `$${(amount / 1000).toFixed(1)}K`;
    }
    return `$${amount.toFixed(2)}`;
  }

  handleRefresh() {
    this.isLoading = true;
    getDashboardSummary({
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((data) => {
        this.dashboardData = data;
        this.error = "";
      })
      .catch((err) => {
        this.error = err.body?.message || "Failed to refresh dashboard data";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleClearError() {
    this.error = "";
  }

  renderedCallback() {
    if (this.hasAttendanceData) {
      const attendanceBar = this.template.querySelector(
        '[data-id="attendance-bar"]'
      );
      if (attendanceBar) {
        attendanceBar.style.width = `${this.attendanceRate}%`;
      }
    }
    if (this.hasPerformanceData) {
      const goalsBar = this.template.querySelector('[data-id="goals-bar"]');
      if (goalsBar) {
        goalsBar.style.width = `${this.avgProgress}%`;
      }
    }
  }
}