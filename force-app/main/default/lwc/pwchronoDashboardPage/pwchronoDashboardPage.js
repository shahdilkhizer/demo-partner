import getDashboardSummaryForPortal from "@salesforce/apex/PWChrono_DashboardController.getDashboardSummaryForPortal";
import { logError } from "c/pwchronoErrorHandler";
import {
  getEmployeeId,
  getSession,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { NavigationMixin } from "lightning/navigation";
import { LightningElement, track } from "lwc";

export default class PwchronoDashboardPage extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";
  @track isLoading = true;
  @track dashboardData = {};

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  userData;

  sessionChangedHandler;

  connectedCallback() {
    this.refreshSessionFromStore();
    this.loadDashboard();

    // Refresh if this tab/component was pre-rendered before login completed.
    this.sessionChangedHandler = () => {
      this.refreshSessionFromStore();
      this.loadDashboard();
    };
    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this.sessionChangedHandler
      );
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  refreshSessionFromStore() {
    this.userData = getSession()?.user || null;
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  get currentUserName() {
    return this.userData?.Name || "Employee";
  }

  get currentUserAvatarUrl() {
    return this.userData?.Photo_Url__c || null;
  }

  async loadDashboard() {
    this.isLoading = true;
    try {
      const data = await getDashboardSummaryForPortal({
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.dashboardData = data || {};
    } catch (error) {
      // Keep UI alive (show empty sections) rather than hard-crashing.
      logError("pwchronoDashboardPage.loadDashboard", error);
      this.dashboardData = {};
    } finally {
      this.isLoading = false;
    }
  }

  get leaveBalance() {
    return this.dashboardData.leaveBalance || [];
  }

  get upcomingShifts() {
    return this.dashboardData.upcomingShifts || [];
  }

  get hasUpcomingShifts() {
    return this.upcomingShifts.length > 0;
  }

  get upcomingShiftCount() {
    return this.upcomingShifts.length;
  }

  get recentSalarySlips() {
    return this.dashboardData.recentSalarySlips || [];
  }

  get hasSalarySlips() {
    return this.recentSalarySlips.length > 0;
  }

  get activeGoalsCount() {
    return this.dashboardData.activeGoalsCount || 0;
  }

  get pendingAppraisalsCount() {
    return this.dashboardData.pendingAppraisalsCount || 0;
  }

  get pendingApprovalsCount() {
    return this.dashboardData.pendingApprovals?.total || 0;
  }

  get todayAttendance() {
    return this.dashboardData.todayAttendance || {};
  }

  // -------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------
  _communityUrl(pagePath) {
    try {
      const path = globalThis.location?.pathname || "";
      const idx = path.indexOf("/s/");
      const base =
        idx >= 0
          ? path.substring(0, idx) + "/s"
          : path.endsWith("/s")
            ? path
            : "/" + (path.split("/").filter(Boolean)[0] || "s");
      return `${base}${pagePath}`;
    } catch {
      return pagePath;
    }
  }

  navigateToShifts() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/Empattendance") }
    });
  }

  navigateToGoals() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/performance") }
    });
  }

  navigateToAppraisals() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/performance") }
    });
  }

  navigateToApprovals() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/leaves") }
    });
  }

  navigateToLeave() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/leaves") }
    });
  }

  navigateToPayroll() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/payroll") }
    });
  }
}