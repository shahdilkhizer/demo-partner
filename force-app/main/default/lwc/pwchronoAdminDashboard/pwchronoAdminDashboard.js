import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getStats from "@salesforce/apex/PWChrono_PortalApi.getAdminDashboardStats";
import getDepartments from "@salesforce/apex/PWChrono_PortalApi.getEmployeesByDepartment";
import getAttendance from "@salesforce/apex/PWChrono_PortalApi.getAttendanceOverview";
import getProjects from "@salesforce/apex/PWChrono_PortalApi.getProjects";
import getApplicants from "@salesforce/apex/PWChrono_PortalApi.getJobApplicants";
import {
  getEmployeeId,
  getSessionToken,
  getSession,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { getErrorMessage } from "c/pwchronoErrorHandler";

export default class PwchronoAdminDashboard extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";
  isLoading = true;
  errors = [];
  stats;
  departments = [];
  attendance;
  projects = [];
  applicants = [];
  requestVersion = 0;
  updatedAt;
  sessionHandler;
  connectedCallback() {
    this.sessionHandler = () => this.loadDashboard();
    window.addEventListener(SESSION_CHANGED_EVENT, this.sessionHandler);
    this.loadDashboard();
  }
  disconnectedCallback() {
    ++this.requestVersion;
    window.removeEventListener(SESSION_CHANGED_EVENT, this.sessionHandler);
  }
  async loadDashboard() {
    const version = ++this.requestVersion;
    this.isLoading = true;
    this.errors = [];
    this.stats = null;
    this.attendance = null;
    this.departments = [];
    this.projects = [];
    this.applicants = [];
    const params = {
      portalUserId: getEmployeeId(),
      sessionToken: getSessionToken()
    };
    const results = await Promise.allSettled([
      getStats(params),
      getDepartments(params),
      getAttendance({ ...params, forDate: null }),
      getProjects(params),
      getApplicants(params)
    ]);
    if (version !== this.requestVersion) return;
    const sections = [
      "stats",
      "departments",
      "attendance",
      "projects",
      "applicants"
    ];
    const labels = [
      "Summary",
      "Departments",
      "Attendance requests",
      "Projects",
      "Applicants"
    ];
    results.forEach((result, i) => {
      if (result.status === "fulfilled") this[sections[i]] = result.value;
      else
        this.errors = [
          ...this.errors,
          {
            id: sections[i],
            message: `${labels[i]}: ${getErrorMessage(result.reason)}`
          }
        ];
    });
    this.updatedAt = new Date().toLocaleString();
    this.isLoading = false;
  }
  get userName() {
    return getSession()?.user?.Name || "Administrator";
  }
  get avatarUrl() {
    return getSession()?.user?.Photo_Url__c || null;
  }
  get hasErrors() {
    return this.errors.length > 0;
  }
  get cards() {
    if (!this.stats) return [];
    return [
      [
        "Active employees",
        this.stats.totalEmployees,
        "EmployeeDirectory__c",
        "fa-users",
        "orange"
      ],
      [
        "On leave today",
        this.stats.onLeaveToday,
        "Leaves_Admin__c",
        "fa-calendar-days",
        "green"
      ],
      [
        "Pending leave & attendance",
        this.stats.pendingApprovals,
        "Approvals__c",
        "fa-list-check",
        "blue"
      ],
      [
        "Projects",
        this.stats.totalProjects,
        "project_list__c",
        "fa-diagram-project",
        "pink"
      ],
      [
        "Overdue leave approvals",
        this.stats.overdueApprovals,
        "Leaves_Admin__c",
        "fa-hourglass-half",
        "purple"
      ],
      [
        "Leave approved this week",
        this.stats.approvedThisWeek,
        "Leaves_Admin__c",
        "fa-circle-check",
        "green"
      ],
      [
        "Completed onboarding tasks",
        this.stats.completedTasks,
        "Onboarding__c",
        "fa-user-check",
        "orange"
      ],
      [
        "Pending requests",
        this.stats.pendingRequests,
        "Approvals__c",
        "fa-inbox",
        "blue"
      ]
    ].map(([label, value, route, icon, color]) => ({
      label,
      value: value ?? 0,
      route,
      icon: `fa-solid ${icon}`,
      iconClass: `metric-icon ${color}`
    }));
  }
  get departmentRows() {
    const max = Math.max(1, ...(this.departments || []).map((d) => d.value));
    return (this.departments || []).map((d) => ({
      ...d,
      barStyle: `width:${(100 * d.value) / max}%`
    }));
  }
  get hasDepartments() {
    return this.departmentRows.length > 0;
  }
  get attendanceRows() {
    if (!this.attendance) return [];
    return [
      ["Approved", this.attendance.present],
      ["Submitted", this.attendance.late],
      ["Draft", this.attendance.permission],
      ["Rejected", this.attendance.absent]
    ].map(([label, value]) => ({ label, value }));
  }
  get projectRows() {
    return (this.projects || []).slice(0, 6);
  }
  get hasProjects() {
    return this.projectRows.length > 0;
  }
  get applicantRows() {
    return (this.applicants || []).slice(0, 5);
  }
  get hasApplicants() {
    return this.applicantRows.length > 0;
  }
  navigate(event) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: event.currentTarget.dataset.route }
    });
  }
  handlePrint() {
    window.print();
  }
}