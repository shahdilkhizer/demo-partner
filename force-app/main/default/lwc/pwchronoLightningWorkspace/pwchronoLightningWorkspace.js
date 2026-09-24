import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { LightningElement, track } from "lwc";

const ROUTE_FEATURES = {
  dashboard: "Dashboard",
  profile: "My Profile",
  attendance: "Attendance Management",
  leave: "Leave Management",
  holidays: "Holidays",
  directory: "Employee Directory",
  recruitment: "Recruitment",
  onboarding: "Onboarding",
  performance: "Performance Management",
  goals: "Goals",
  training: "Training Management",
  projects: "Projects",
  expenses: "Expense Management",
  payroll: "Payroll",
  approvals: "Approvals",
  policies: "Company Policies",
  reports: "Reports Dashboard",
  configuration: "Configuration"
};

const ROUTES = new Set([
  "dashboard",
  "profile",
  "attendance",
  "leave",
  "holidays",
  "directory",
  "recruitment",
  "onboarding",
  "performance",
  "goals",
  "training",
  "projects",
  "expenses",
  "payroll",
  "approvals",
  "policies",
  "reports",
  "configuration"
]);

export default class PwchronoLightningWorkspace extends LightningElement {
  static renderMode = "light";

  @track currentRoute = "dashboard";
  @track assetsReady = false;
  @track accessReady = false;
  @track features = [];
  @track accessDenied = false;
  hashChangeHandler;

  connectedCallback() {
    this.hashChangeHandler = () => this.syncRouteFromLocation();
    globalThis.addEventListener?.("hashchange", this.hashChangeHandler);
    this.syncRouteFromLocation();
    this.loadAccess();

    // Keep the workspace usable if a static-resource request is slow.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this.assetsReady = true;
    }, 2500);
  }

  disconnectedCallback() {
    globalThis.removeEventListener?.("hashchange", this.hashChangeHandler);
  }

  handleAssetsReady() {
    this.assetsReady = true;
  }

  handleRouteChange(event) {
    this.setRoute(event.detail?.route);
  }

  handleHeaderNavigate(event) {
    const route = event.detail?.page;
    if (route === "profile") {
      globalThis.location.hash = "profile";
      this.setRoute("profile");
    }
  }

  syncRouteFromLocation() {
    this.setRoute(globalThis.location?.hash?.slice(1));
  }

  setRoute(route) {
    const normalized = String(route || "dashboard").toLowerCase();
    const requestedRoute = ROUTES.has(normalized) ? normalized : "dashboard";
    this.currentRoute = requestedRoute;
    this.enforceRouteAccess();
  }

  async loadAccess() {
    try {
      const access = await getUserAccessById({
        employeeId: getEmployeeId() || null,
        sessionToken: getSessionToken() || null
      });
      this.features = access?.features || [];
    } catch {
      this.features = [];
    } finally {
      this.accessReady = true;
      this.enforceRouteAccess();
    }
  }

  enforceRouteAccess() {
    if (!this.accessReady) {
      return;
    }
    const requiredFeature = ROUTE_FEATURES[this.currentRoute];
    this.accessDenied =
      !requiredFeature || !this.features.includes(requiredFeature);
  }

  get loaderStyle() {
    return this.assetsReady ? "display: none !important;" : "";
  }

  get workspaceStyle() {
    return this.assetsReady ? "opacity: 1;" : "visibility: hidden; opacity: 0;";
  }

  get isDashboard() {
    return this.currentRoute === "dashboard";
  }
  get isProfile() {
    return this.currentRoute === "profile";
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
  get isConfiguration() {
    return this.currentRoute === "configuration";
  }
  get isAccessDenied() {
    return this.accessReady && this.accessDenied;
  }
  get isRouteVisible() {
    return this.accessReady && !this.accessDenied;
  }
}