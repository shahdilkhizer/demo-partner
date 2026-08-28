import getDashboardData from "@salesforce/apex/PWChrono_PMDashboardController.getDashboardData";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { LightningElement, track } from "lwc";

export default class PwchronoProjectManagerDashboard extends LightningElement {
  static renderMode = "light";

  @track isLoading = true;
  @track error;
  @track dashboard;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  sessionChangedHandler;

  connectedCallback() {
    this.refreshSessionFromStore();
    this.loadDashboard();

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
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  async loadDashboard() {
    this.isLoading = true;
    this.error = undefined;

    try {
      this.dashboard = await getDashboardData({
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
    } catch (e) {
      this.dashboard = undefined;
      this.error = e?.body?.message || e?.message;
    } finally {
      this.isLoading = false;
    }
  }

  renderedCallback() {
    // Avoid LWC template style-binding like style={...} because VS Code's CSS validator
    // flags it as invalid CSS. Apply the width imperatively instead.
    try {
      const bar = this.template.querySelector(".pm-hours-progress");
      if (bar) {
        bar.style.width = `${this.hoursProgressPercent}%`;
      }
    } catch {
      // no-op
    }
  }

  get totalProjects() {
    return this.dashboard?.totalProjects ?? 0;
  }

  get activeProjects() {
    return this.dashboard?.activeProjects ?? 0;
  }

  get highPriorityActiveProjects() {
    return this.dashboard?.highPriorityActiveProjects ?? 0;
  }

  get endingSoonProjects() {
    return this.dashboard?.endingSoonProjects ?? 0;
  }

  get recentProjects() {
    return this.dashboard?.recentProjects ?? [];
  }

  get hasRecentProjects() {
    return Array.isArray(this.recentProjects) && this.recentProjects.length > 0;
  }

  // New PM KPIs
  get activeProjectValue() {
    return this.dashboard?.activeProjectValue ?? 0;
  }

  get activeHoursLogged() {
    return this.dashboard?.activeHoursLogged ?? 0;
  }

  get activeHoursPlanned() {
    return this.dashboard?.activeHoursPlanned ?? 0;
  }

  get atRiskProjects() {
    return this.dashboard?.atRiskProjects ?? 0;
  }

  get overrunProjects() {
    return this.dashboard?.overrunProjects ?? 0;
  }

  get atRiskProjectRows() {
    return this.dashboard?.atRiskProjectRows ?? [];
  }

  get hasAtRiskProjects() {
    return (
      Array.isArray(this.atRiskProjectRows) && this.atRiskProjectRows.length > 0
    );
  }

  get overrunProjectRows() {
    return this.dashboard?.overrunProjectRows ?? [];
  }

  get hasOverrunProjects() {
    return (
      Array.isArray(this.overrunProjectRows) &&
      this.overrunProjectRows.length > 0
    );
  }

  get hoursProgressPercent() {
    const planned = Number(this.activeHoursPlanned || 0);
    const logged = Number(this.activeHoursLogged || 0);
    if (!planned || planned <= 0) {
      return 0;
    }
    const pct = Math.round((logged / planned) * 100);
    return Math.max(0, Math.min(100, pct));
  }
}