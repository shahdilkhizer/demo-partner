import CHART_JS from "@salesforce/resourceUrl/chartjs";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import { loadScript } from "lightning/platformResourceLoader";
import { LightningElement, track, wire } from "lwc";

import getAttendanceOverview from "@salesforce/apex/PWChrono_AdminController.getAttendanceOverview";
import getAdminDashboardStats from "@salesforce/apex/PWChrono_AdminController.getAdminDashboardStats";
import getEmployeesByDepartment from "@salesforce/apex/PWChrono_AdminController.getEmployeesByDepartment";
import getEmployeeStatusOverview from "@salesforce/apex/PWChrono_AdminController.getEmployeeStatusOverview";
import getJobApplicants from "@salesforce/apex/PWChrono_AdminController.getJobApplicants";
import getProjects from "@salesforce/apex/PWChrono_AdminController.getProjects";
import getRecentActivities from "@salesforce/apex/PWChrono_AdminController.getRecentActivities";
import getSalesOverview from "@salesforce/apex/PWChrono_AdminController.getSalesOverview";
import getSchedules from "@salesforce/apex/PWChrono_AdminController.getSchedules";
import getTodoTasks from "@salesforce/apex/PWChrono_AdminController.getTodoTasks";
import { logError } from "c/pwchronoErrorHandler";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";

export default class PwchronoAdminDashboard extends LightningElement {
  static renderMode = "light";

  // Template avatar images (served from static resource; no /assets paths in Salesforce)
  avatar31Url = `${smarthrAssets}/assets/img/profiles/avatar-31.jpg`;
  avatar24Url = `${smarthrAssets}/assets/img/profiles/avatar-24.jpg`;
  avatar23Url = `${smarthrAssets}/assets/img/profiles/avatar-23.jpg`;
  avatar25Url = `${smarthrAssets}/assets/img/profiles/avatar-25.jpg`;
  avatar26Url = `${smarthrAssets}/assets/img/profiles/avatar-26.jpg`;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();
  // Right column
  @track employeeStatus;
  @track attendanceOverview;
  @track employeesByDepartment = [];

  @track dashboardStats;

  // Left column datasets consumed by child components via @api
  @track jobApplicants = [];
  @track todoTasks = [];
  @track salesOverview = [];
  @track projects = [];
  @track schedules = [];
  @track recentActivities = [];

  // Loading flags
  @track isLoading = true;
  @track isLoadingActivities = true;

  chartjsInitialized = false;
  isChartJsLoaded = false;
  chartCtor;
  chartsDisabled = false;
  employeeStatusLoaded = false;
  attendanceLoaded = false;

  sessionChangedHandler;

  refreshSessionFromStore() {
    const nextEmployeeId = getEmployeeId();
    const nextSessionToken = getSessionToken();

    const changed =
      nextEmployeeId !== this.employeeId ||
      nextSessionToken !== this.sessionToken;
    this.employeeId = nextEmployeeId;
    this.sessionToken = nextSessionToken;

    // If the component was pre-rendered before login, the initial wire calls never ran
    // because reactive params were null/undefined. When session becomes available,
    // reset core loading flags so the spinner isn't stuck forever.
    if (changed) {
      this.employeeStatusLoaded = false;
      this.attendanceLoaded = false;
      this.isLoading = true;

      // Reset charts so they can re-init once DOM/data is ready.
      try {
        this.chartDepartments?.destroy?.();
      } catch {
        /* no-op */
      }
      try {
        this.chartAttendance?.destroy?.();
      } catch {
        /* no-op */
      }
      this.chartDepartments = null;
      this.chartAttendance = null;
    }
  }

  connectedCallback() {
    this.refreshSessionFromStore();

    // Listen for session establishment (login) or clearing (logout)
    // so tab-preloaded components can refresh.
    this.sessionChangedHandler = () => {
      this.refreshSessionFromStore();
    };
    try {
      if (globalThis?.window?.addEventListener) {
        globalThis.window.addEventListener(
          SESSION_CHANGED_EVENT,
          this.sessionChangedHandler
        );
      }
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      if (
        globalThis?.window?.removeEventListener &&
        this.sessionChangedHandler
      ) {
        globalThis.window.removeEventListener(
          SESSION_CHANGED_EVENT,
          this.sessionChangedHandler
        );
      }
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  renderedCallback() {
    if (this.isChartJsLoaded) {
      this.initCharts();
      return;
    }

    if (this.chartjsInitialized) {
      return;
    }
    this.chartjsInitialized = true;

    loadScript(this, CHART_JS)
      .then(() => {
        // Chart.js may expose itself differently depending on build/Locker.
        this.chartCtor = this.resolveChartCtor();
        this.isChartJsLoaded = true;
        this.initCharts();
      })
      .catch((error) => {
        logError("pwchronoAdminDashboard: Error loading Chart.js", error);
      });
  }

  resolveChartCtor() {
    // In many environments Chart.js UMD attaches to window.Chart.
    // In others (or when bundled differently) it may attach under Chart.Chart or Chart.default.
    // We also need to handle the case where a global named `Chart` exists but isn't constructable.

    const g = globalThis;
    const w = g?.window ?? g;

    const candidates = [
      g?.Chart,
      w?.Chart,
      g?.Chart?.Chart,
      g?.Chart?.default,
      w?.Chart?.Chart,
      w?.Chart?.default
    ];

    const isProbablyConstructable = (fn) =>
      typeof fn === "function" && !!fn.prototype;

    return candidates.find((c) => isProbablyConstructable(c));
  }

  initCharts() {
    if (this.chartsDisabled) {
      return;
    }

    if (!this.isChartJsLoaded) {
      return;
    }

    // Resolve chart constructor lazily in case another script/component loaded Chart.js first.
    this.chartCtor = this.chartCtor || this.resolveChartCtor();
    if (!this.chartCtor) {
      return;
    }

    // Wait for data and DOM
    // Note: Our DOM might be hidden behind if:false={isLoading}
    // So we only try to create charts if canvases are found.

    this.createEmployeeDepartmentChart();
    this.createAttendanceChart();
  }

  createEmployeeDepartmentChart() {
    if (this.chartsDisabled) return;
    const ChartCtor = this.chartCtor || this.resolveChartCtor();
    if (!ChartCtor) return;

    const canvas = this.querySelector("canvas.emp-department-chart");

    if (!canvas) return;

    const labels = (this.employeesByDepartment || []).map((d) => d.label);
    const values = (this.employeesByDepartment || []).map((d) => d.value);

    // Update existing chart if present
    if (this.chartDepartments) {
      this.chartDepartments.data.labels = labels;
      this.chartDepartments.data.datasets[0].data = values;
      this.chartDepartments.update();
      return;
    }

    const ctx = canvas.getContext("2d");
    try {
      this.chartDepartments = new ChartCtor(ctx, {
        type: "bar",
        data: {
          labels,
          datasets: [
            {
              label: "Employees",
              data: values,
              backgroundColor: "rgba(255, 111, 40, 0.85)",
              borderWidth: 0
            }
          ]
        },
        options: {
          indexAxis: "y",
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { display: false } },
            y: {
              grid: { display: false },
              ticks: {
                font: {
                  size: 13,
                  family: "'Helvetica Neue', 'Helvetica', 'Arial', sans-serif"
                }
              }
            }
          }
        }
      });
    } catch {
      // Experience Builder / LWR Locker can expose a non-constructable global.
      // Disable charts to avoid breaking the whole page.
      this.chartsDisabled = true;
    }
  }

  createAttendanceChart() {
    if (this.chartsDisabled) return;
    const ChartCtor = this.chartCtor || this.resolveChartCtor();
    if (!ChartCtor) return;

    const canvas = this.querySelector("canvas.attendance-chart");

    if (!canvas) return;

    const present = this.attendanceOverview?.present ?? 0;
    const late = this.attendanceOverview?.late ?? 0;
    const permission = this.attendanceOverview?.permission ?? 0;
    const absent = this.attendanceOverview?.absent ?? 0;
    const series = [present, late, permission, absent];

    if (this.chartAttendance) {
      this.chartAttendance.data.datasets[0].data = series;
      this.chartAttendance.update();
      return;
    }

    const ctx = canvas.getContext("2d");
    try {
      this.chartAttendance = new ChartCtor(ctx, {
        type: "doughnut",
        data: {
          labels: ["Present", "Late", "Permission", "Absent"],
          datasets: [
            {
              data: series,
              backgroundColor: ["#198754", "#6c757d", "#ffc107", "#dc3545"],
              borderWidth: 0,
              hoverOffset: 4
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: "80%",
          plugins: { legend: { display: false } }
        }
      });
    } catch {
      this.chartsDisabled = true;
    }
  }

  // -----------------------------
  // Primary summary payloads
  // -----------------------------
  @wire(getAdminDashboardStats, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredDashboardStats({ error, data }) {
    if (data) {
      this.dashboardStats = data;
    } else if (error) {
      this.dashboardStats = undefined;
    }
  }

  @wire(getEmployeeStatusOverview, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredEmployeeStatus({ error, data }) {
    this.employeeStatusLoaded = true;
    if (data) {
      this.employeeStatus = data;
    } else if (error) {
      this.employeeStatus = undefined;
      // Keep the dashboard usable; errors can be surfaced via a banner later.
    }
    this.checkLoadingComplete();
  }

  @wire(getAttendanceOverview, {
    forDate: null,
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  }) // null = today
  wiredAttendanceOverview({ error, data }) {
    this.attendanceLoaded = true;
    if (data) {
      this.attendanceOverview = data;
      if (this.chartjsInitialized && !this.chartsDisabled) {
        this.createAttendanceChart();
      }
    } else if (error) {
      this.attendanceOverview = undefined;
    }
    this.checkLoadingComplete();
  }

  checkLoadingComplete() {
    // Only gate the page spinner on the core payloads.
    // Other sections can load independently without blocking the dashboard.
    if (this.employeeStatusLoaded && this.attendanceLoaded) {
      this.isLoading = false;
    }
  }

  // -----------------------------
  // Charts + section datasets
  // -----------------------------
  @wire(getEmployeesByDepartment, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredEmployeesByDepartment({ error, data }) {
    if (Array.isArray(data)) {
      this.employeesByDepartment = data;
      if (this.chartjsInitialized && !this.chartsDisabled) {
        this.createEmployeeDepartmentChart();
      }
    } else if (error) {
      this.employeesByDepartment = [];
    }
  }

  @wire(getSalesOverview, {
    year: "$currentYear",
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredSalesOverview({ error, data }) {
    if (Array.isArray(data)) {
      this.salesOverview = data;
    } else if (error) {
      this.salesOverview = [];
    }
  }

  @wire(getProjects, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredProjects({ error, data }) {
    if (Array.isArray(data)) {
      this.projects = data.map((proj) => this.mapRecordToProjectRow(proj));
    } else if (error) {
      this.projects = [];
    }
  }

  @wire(getJobApplicants, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredJobApplicants({ error, data }) {
    if (Array.isArray(data)) {
      this.jobApplicants = data.map((a) => this.mapApplicant(a));
    } else if (error) {
      this.jobApplicants = [];
    }
  }

  @wire(getTodoTasks, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredTodoTasks({ error, data }) {
    if (Array.isArray(data)) {
      this.todoTasks = data.map((t) => this.mapTodoTask(t));
    } else if (error) {
      this.todoTasks = [];
    }
  }

  @wire(getSchedules, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredSchedules({ error, data }) {
    if (Array.isArray(data)) {
      this.schedules = data.map((e) => this.mapEventToSchedule(e));
    } else if (error) {
      this.schedules = [];
    }
  }

  @wire(getRecentActivities, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredRecentActivities({ error, data }) {
    this.isLoadingActivities = true;
    if (Array.isArray(data)) {
      this.recentActivities = data.map((a) => this.mapTimelineItem(a));
      this.isLoadingActivities = false;
    } else if (error) {
      this.recentActivities = [];
      this.isLoadingActivities = false;
    }
  }

  get currentYear() {
    return new Date().getFullYear();
  }

  // -----------------------------
  // Stats helpers (avoid hardcoded sample strings)
  // -----------------------------
  get userName() {
    return this.dashboardStats?.userName || "";
  }

  get welcomeNameSuffix() {
    return this.userName ? `, ${this.userName}` : "";
  }

  get pendingApprovals() {
    return this.dashboardStats?.pendingApprovals ?? 0;
  }

  get pendingRequests() {
    return this.dashboardStats?.pendingRequests ?? 0;
  }

  get totalProjects() {
    return this.dashboardStats?.totalProjects ?? 0;
  }

  get projectTrend() {
    return this.dashboardStats?.projectTrend || "";
  }

  get totalInvoices() {
    return this.dashboardStats?.totalInvoices ?? 0;
  }

  get invoiceTrend() {
    return this.dashboardStats?.invoiceTrend || "";
  }

  get completedTasks() {
    return this.dashboardStats?.completedTasks ?? 0;
  }

  get taskTrend() {
    return this.dashboardStats?.taskTrend || "";
  }

  get employeeTrend() {
    return this.dashboardStats?.employeeTrend || "";
  }

  // -----------------------------
  // UI helpers for KPI widgets
  // -----------------------------
  get employeeTotal() {
    return this.employeeStatus?.total ?? 0;
  }

  get employeeFulltime() {
    return this.employeeStatus?.fulltime ?? 0;
  }

  get employeeContract() {
    return this.employeeStatus?.contract ?? 0;
  }

  get employeeProbation() {
    return this.employeeStatus?.probation ?? 0;
  }

  get employeeWfh() {
    return this.employeeStatus?.wfh ?? 0;
  }

  pct(part, total) {
    const p = Number(part ?? 0);
    const t = Number(total ?? 0);
    if (!t || Number.isNaN(p) || Number.isNaN(t)) return 0;
    return Math.round((p / t) * 100);
  }

  get employeeFulltimePct() {
    return this.pct(this.employeeFulltime, this.employeeTotal);
  }

  get employeeContractPct() {
    return this.pct(this.employeeContract, this.employeeTotal);
  }

  get employeeProbationPct() {
    return this.pct(this.employeeProbation, this.employeeTotal);
  }

  get employeeWfhPct() {
    return this.pct(this.employeeWfh, this.employeeTotal);
  }

  get employeeFulltimeWidthStyle() {
    return `width: ${this.employeeFulltimePct}%;`;
  }

  get employeeContractWidthStyle() {
    return `width: ${this.employeeContractPct}%;`;
  }

  get employeeProbationWidthStyle() {
    return `width: ${this.employeeProbationPct}%;`;
  }

  get employeeWfhWidthStyle() {
    return `width: ${this.employeeWfhPct}%;`;
  }

  get attendanceTotal() {
    return this.attendanceOverview?.total ?? 0;
  }

  get attendancePresentPct() {
    return this.pct(this.attendanceOverview?.present, this.attendanceTotal);
  }

  get attendanceLatePct() {
    return this.pct(this.attendanceOverview?.late, this.attendanceTotal);
  }

  get attendancePermissionPct() {
    return this.pct(this.attendanceOverview?.permission, this.attendanceTotal);
  }

  get attendanceAbsentPct() {
    return this.pct(this.attendanceOverview?.absent, this.attendanceTotal);
  }

  // -----------------------------
  // Mapping helpers (parent shapes data to match child section templates)
  // -----------------------------
  getInitials(name) {
    const n = (name || "").toString().trim();
    if (!n) return "";
    const parts = n.split(/\s+/).filter(Boolean);
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  formatShortDate(value) {
    if (!value) return "";
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString(undefined, { month: "short", day: "2-digit" });
  }

  formatTime(value) {
    if (!value) return "";
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleTimeString(undefined, {
      hour: "2-digit",
      minute: "2-digit"
    });
  }

  mapEventToSchedule(e) {
    const title = e?.Subject || "Schedule";
    const start = e?.StartDateTime;
    const end = e?.EndDateTime;
    const time = end
      ? `${this.formatTime(start)} - ${this.formatTime(end)}`
      : this.formatTime(start);
    return {
      id: e?.Id,
      initials: this.getInitials(title),
      title,
      department: e?.Location || "—",
      time,
      date: this.formatShortDate(start)
    };
  }

  mapTimelineItem(a) {
    return {
      id: a?.id,
      name: a?.title || a?.category || "Activity",
      action: a?.detail || a?.status || "",
      time: this.formatShortDate(a?.timestamp)
    };
  }

  mapApplicant(a) {
    const designationName = a?.Job_Opening__r?.Designation__r?.Name;
    return {
      ...a,
      initials: this.getInitials(a?.Name),
      // Adapt to what the child template currently expects.
      Job_Opening__r: {
        Position_Title__c: designationName || ""
      }
    };
  }

  mapTodoTask(t) {
    const status = (t?.Status__c || "").toString().toLowerCase();
    const done =
      status === "completed" || status === "complete" || status === "done";
    return {
      id: t?.Id,
      title: t?.Name || "Task",
      done,
      textClass: done
        ? "text-sm text-gray-400 line-through"
        : "text-sm text-gray-900 font-medium"
    };
  }

  mapRecordToProjectRow(proj) {
    const priority = proj?.Priority__c || "Medium";

    // Mapping badge styles to Tailwind classes likely used here or custom classes
    let priorityClass =
      "inline-flex items-center px-2 py-1 rounded-full text-[10px] font-semibold bg-gray-100 text-gray-800 border border-gray-200"; // Default

    if (priority === "High") {
      priorityClass =
        "inline-flex items-center px-2 py-1 rounded-full text-[10px] font-semibold bg-red-100 text-red-800 border border-red-200";
    } else if (priority === "Medium") {
      priorityClass =
        "inline-flex items-center px-2 py-1 rounded-full text-[10px] font-semibold bg-indigo-100 text-indigo-800 border border-indigo-200";
    } else if (priority === "Low") {
      priorityClass =
        "inline-flex items-center px-2 py-1 rounded-full text-[10px] font-semibold bg-green-100 text-green-800 border border-green-200";
    }

    return {
      id: proj?.Id,
      code: (proj?.Id || "").toString().slice(-6) || "—",
      name: proj?.Name || "Project",
      hours: proj?.Total_Hours__c ? `${proj.Total_Hours__c}h` : "—",
      date: this.formatShortDate(proj?.End_Date__c),
      priority,
      priorityClass
    };
  }
}