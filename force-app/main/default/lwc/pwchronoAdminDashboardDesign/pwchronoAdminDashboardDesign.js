import CHART_JS from "@salesforce/resourceUrl/chartjs";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import { loadScript } from "lightning/platformResourceLoader";
import { NavigationMixin } from "lightning/navigation";
import { LightningElement, track, wire } from "lwc";

import getAttendanceOverview from "@salesforce/apex/PWChrono_AdminController.getAttendanceOverview";
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

export default class PwchronoAdminDashboardDesign extends NavigationMixin(
  LightningElement
) {
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

    if (changed) {
      this.employeeStatusLoaded = false;
      this.attendanceLoaded = false;
      this.isLoading = true;

      try {
        this.empChart?.destroy?.();
      } catch {
        /* no-op */
      }
      try {
        this.attendanceChart?.destroy?.();
      } catch {
        /* no-op */
      }
      this.empChart = null;
      this.attendanceChart = null;
    }
  }

  connectedCallback() {
    this.refreshSessionFromStore();

    this.sessionChangedHandler = () => {
      this.refreshSessionFromStore();
    };
    try {
      if (typeof globalThis.addEventListener === "function") {
        globalThis.addEventListener(
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
        typeof globalThis.removeEventListener === "function" &&
        this.sessionChangedHandler
      ) {
        globalThis.removeEventListener(
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
    if (this.chartjsInitialized) {
      return;
    }
    this.chartjsInitialized = true;

    loadScript(this, CHART_JS)
      .then(() => {
        this.initCharts();
      })
      .catch((error) => {
        logError("pwchronoAdminDashboardDesign: Error loading Chart.js", error);
      });
  }

  initCharts() {
    if (!this.employeesByDepartment || !this.attendanceOverview) {
      // Data might not be ready yet, retry or wait for data wire to trigger rendering.
      // For now, we rely on the fact that if data comes later, we might need a separate method to refresh charts.
      // But usually this component loads data fast enough.
      // Let's implement a safe check inside creating method.
    }
    this.createEmployeeDepartmentChart();
    this.createAttendanceChart();
  }

  createEmployeeDepartmentChart() {
    const canvas = this.template.querySelector("div#emp-department canvas");
    if (canvas) {
      if (!globalThis.Chart) {
        return;
      }

      const labels = (this.employeesByDepartment || []).map((d) => d.label);
      const data = (this.employeesByDepartment || []).map((d) => d.value);

      if (this.empChart) {
        this.empChart.data.labels = labels;
        this.empChart.data.datasets[0].data = data;
        this.empChart.update();
        return;
      }

      const ctx = canvas.getContext("2d");

      this.empChart = new globalThis.Chart(ctx, {
        type: "bar",
        data: {
          labels,
          datasets: [
            {
              label: "Employees",
              data,
              backgroundColor: "rgba(255, 111, 40, 0.85)",
              borderWidth: 0
            }
          ]
        },
        options: {
          indexAxis: "y", // Horizontal bar chart
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false }
          },
          scales: {
            x: {
              grid: { display: false }
            },
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
    }
  }

  createAttendanceChart() {
    const container = this.template.querySelector("div#attendance canvas");
    if (container) {
      if (!globalThis.Chart) {
        return;
      }

      const present = this.attendanceOverview?.present ?? 0;
      const late = this.attendanceOverview?.late ?? 0;
      const permission = this.attendanceOverview?.permission ?? 0;
      const absent = this.attendanceOverview?.absent ?? 0;
      const series = [present, late, permission, absent];

      if (this.attendanceChart) {
        this.attendanceChart.data.datasets[0].data = series;
        this.attendanceChart.update();
        return;
      }

      const ctx = container.getContext("2d");
      this.attendanceChart = new globalThis.Chart(ctx, {
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
          plugins: {
            legend: { display: false }
          }
        }
      });
    }
  }

  // -----------------------------
  // Primary summary payloads
  // -----------------------------
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
      if (this.chartjsInitialized) {
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
      if (this.chartjsInitialized) {
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

  navigateToAttendance() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/attendance-admin") }
    });
  }

  navigateToProjects() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/project-list") }
    });
  }

  navigateToPayroll() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/payroll") }
    });
  }

  navigateToRecruitment() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/recruitment") }
    });
  }

  navigateToEmployees() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url: this._communityUrl("/directory") }
    });
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