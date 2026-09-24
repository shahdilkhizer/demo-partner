import { LightningElement, track } from "lwc";
import {
  getCurrentPage,
  normalizeApplicationRoute,
  onPageChange
} from "c/pwchronoRouter";

export default class PwchronoLightningApp extends LightningElement {
  @track currentRoute = "dashboard";
  unsubscribePageChange;

  connectedCallback() {
    this.setRoute(getCurrentPage());
    this.unsubscribePageChange = onPageChange((page) => this.setRoute(page));
  }

  disconnectedCallback() {
    this.unsubscribePageChange?.();
    this.unsubscribePageChange = undefined;
  }

  setRoute(page) {
    this.currentRoute = normalizeApplicationRoute(page);
  }

  handleNavigate(event) {
    this.setRoute(event.detail?.page);
  }

  get isDashboard() {
    return this.currentRoute === "dashboard";
  }
  get isAttendance() {
    return this.currentRoute === "attendance";
  }
  get isLeave() {
    return this.currentRoute === "leave";
  }
  get isHolidays() {
    return this.currentRoute === "holidays";
  }
  get isDirectory() {
    return this.currentRoute === "directory";
  }
  get isRecruitment() {
    return this.currentRoute === "recruitment";
  }
  get isOnboarding() {
    return this.currentRoute === "onboarding";
  }
  get isPerformance() {
    return this.currentRoute === "performance";
  }
  get isGoals() {
    return this.currentRoute === "goals";
  }
  get isTraining() {
    return this.currentRoute === "training";
  }
  get isProjects() {
    return this.currentRoute === "projects";
  }
  get isExpenses() {
    return this.currentRoute === "expenses";
  }
  get isPayroll() {
    return this.currentRoute === "payroll";
  }
  get isApprovals() {
    return this.currentRoute === "approvals";
  }
  get isPolicies() {
    return this.currentRoute === "policies";
  }
  get isReports() {
    return this.currentRoute === "reports";
  }
  get isProfile() {
    return this.currentRoute === "profile";
  }
  get isConfiguration() {
    return this.currentRoute === "configuration";
  }
}