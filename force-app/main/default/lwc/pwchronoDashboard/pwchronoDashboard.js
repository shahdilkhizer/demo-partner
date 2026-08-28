import { LightningElement, track } from "lwc";
import getDashboardSummary from "@salesforce/apex/PWChrono_DashboardController.getDashboardSummary";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import { showErrorToast, logError } from "c/pwchronoErrorHandler";
import { NavigationMixin } from "lightning/navigation";
import { getEmployeeId } from "c/pwchronoSession";

const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export default class PwchronoDashboard extends NavigationMixin(
  LightningElement
) {
  @track dashboardData = {
    leaveBalance: [],
    pendingApprovals: { total: 0 },
    upcomingShifts: [],
    recentSalarySlips: [],
    activeGoalsCount: 0,
    pendingAppraisalsCount: 0
  };

  @track hasAccess = false;
  @track accessLoaded = false;
  @track isLoading = true;
  @track skeletonCards = [1, 2, 3, 4];

  connectedCallback() {
    this.loadData();
  }

  async loadData() {
    try {
      // Get employee ID from session for portal users
      const employeeId = getEmployeeId();

      // Load access first - pass employeeId for portal users
      const accessData = await getUserAccessById({ employeeId: employeeId });
      this.hasAccess =
        accessData?.hasAccess && accessData?.features?.includes("Dashboard")
          ? true
          : false;
      this.accessLoaded = true;

      if (!this.hasAccess) {
        this.isLoading = false;
        return;
      }

      // Load dashboard summary
      const data = await getDashboardSummary();
      if (data) {
        this.dashboardData = {
          leaveBalance: data.leaveBalance || [],
          pendingApprovals: data.pendingApprovals || { total: 0 },
          upcomingShifts: (data.upcomingShifts || []).map((shift) => {
            const shiftDate = shift.From_Date__c ? new Date(shift.From_Date__c) : null;
            return {
              ...shift,
              shiftName: shift.Shift_Type__r?.Name || "Unnamed",
              timeRange: shift.Shift_Type__r
                ? `${this.formatTime(shift.Shift_Type__r.Start_Time__c)} - ${this.formatTime(shift.Shift_Type__r.End_Time__c)}`
                : "N/A",
              dateFormatted: shiftDate ? String(shiftDate.getUTCDate()) : "--",
              dayOfWeek: shiftDate ? DAY_NAMES[shiftDate.getUTCDay()] : "--"
            };
          }),
          recentSalarySlips: (data.recentSalarySlips || []).map((slip) => ({
            ...slip,
            payPeriodLabel: this.formatPayPeriod(slip.Payroll_Period__c)
          })),
          activeGoalsCount: data.activeGoalsCount || 0,
          pendingAppraisalsCount: data.pendingAppraisalsCount || 0
        };
      }
    } catch (error) {
      logError("Dashboard.loadData", error);
      showErrorToast(
        this.dispatchEvent.bind(this),
        "Error",
        "Failed to load dashboard data"
      );
    } finally {
      this.isLoading = false;
    }
  }

  get hasShifts() {
    return this.dashboardData.upcomingShifts?.length > 0;
  }

  get hasPayslips() {
    return this.dashboardData.recentSalarySlips?.length > 0;
  }

  // Computed property for today's date
  get todayDate() {
    const options = {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric"
    };
    return new Date().toLocaleDateString("en-US", options);
  }

  formatTime(timeValue) {
    if (!timeValue && timeValue !== 0) return "--:--";

    try {
      let hours, minutes;

      // Handle string format "HH:mm:ss" or "HH:mm:ss.SSSZ" from Salesforce Time field
      if (typeof timeValue === "string") {
        const timeParts = timeValue.split(":");
        if (timeParts.length >= 2) {
          hours = parseInt(timeParts[0], 10);
          minutes = parseInt(timeParts[1], 10);
        } else {
          return timeValue;
        }
      }
      // Handle milliseconds from midnight
      else if (typeof timeValue === "number") {
        const date = new Date();
        date.setHours(0, 0, 0, 0);
        date.setMilliseconds(timeValue);
        hours = date.getHours();
        minutes = date.getMinutes();
      } else {
        return timeValue;
      }

      // Convert to 12-hour format with AM/PM
      const hour12 = hours % 12 || 12;
      const minutesPadded = String(minutes).padStart(2, "0");
      const ampm = hours >= 12 ? "PM" : "AM";
      return `${hour12}:${minutesPadded} ${ampm}`;
    } catch (error) {
      logError("Dashboard.formatTime", error);
      return timeValue;
    }
  }

  formatPayPeriod(periodDate) {
    if (!periodDate) return "N/A";

    try {
      const date = new Date(periodDate);
      const monthNames = [
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
      return `${monthNames[date.getMonth()]} ${date.getFullYear()}`;
    } catch (error) {
      logError("Dashboard.formatPayPeriod", error);
      return periodDate;
    }
  }

  // Navigation handlers
  handleGoBack() {
    window.history.back();
  }

  navigateToPendingApprovals() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-approval-center"
      }
    });
  }

  navigateToGoals() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-performance-management"
      }
    });
  }

  navigateToAppraisals() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-performance-management"
      }
    });
  }

  navigateToLeave() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-leave-management"
      }
    });
  }

  navigateToAttendance() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-attendance"
      }
    });
  }

  navigateToShifts() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-shift-roster"
      }
    });
  }

  navigateToPayroll() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "pwchrono-payroll"
      }
    });
  }
}