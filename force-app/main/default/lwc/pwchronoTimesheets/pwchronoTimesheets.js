import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import decideWorkLog from "@salesforce/apex/PWChrono_WorkLogController.decideWorkLog";
import getActiveProjects from "@salesforce/apex/PWChrono_WorkLogController.getActiveProjects";
import getWorkLogs from "@salesforce/apex/PWChrono_WorkLogController.getWorkLogs";
import saveWorkLog from "@salesforce/apex/PWChrono_WorkLogController.saveWorkLog";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

const WORK_TYPE = "Timesheet";

export default class TimesheetManager extends LightningElement {
  @track allData = [];
  @track filteredData = [];
  @track isModalOpen = false;
  @track projectOptions = [];
  searchTerm = "";
  selectedProject = "";
  sortDirection = "desc";
  canReview = false;
  employeeId;
  sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.initialize();
  }

  async initialize() {
    try {
      const [access, projects] = await Promise.all([
        getUserAccessById({
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getActiveProjects({
          portalUserId: this.employeeId,
          sessionToken: this.sessionToken
        })
      ]);
      const features = access?.features || [];
      this.canReview =
        features.includes("Attendance Team") ||
        features.includes("Attendance Administration");
      this.projectOptions = (projects || []).map((project) => ({
        label: project.Name,
        value: project.Id
      }));
      await this.loadData();
    } catch (error) {
      this.notify("Unable to load timesheets", this.message(error), "error");
    }
  }

  async loadData() {
    const rows = await getWorkLogs({
      workType: WORK_TYPE,
      statusFilter: "All",
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    });
    this.allData = (rows || []).map((row) => ({
      id: row.Id,
      employeeName: row.Employee__r?.Name || "Employee",
      team: row.Employee__r?.Department__c || "—",
      workDate: this.formatDate(row.Work_Date__c),
      workDateValue: row.Work_Date__c,
      projectId: row.Project__c,
      projectName: row.Project__r?.Name || "—",
      assignedHours: row.Planned_Hours__c ?? "—",
      workedHours: row.Hours__c,
      status: row.Status__c,
      imageUrl: row.Employee__r?.Photo_Url__c,
      canDecide: this.canReview && row.Status__c === "Submitted"
    }));
    this.applyFilters();
  }

  handleSearch(event) {
    this.searchTerm = (event.target.value || "").toLowerCase();
    this.applyFilters();
  }

  handleProjectFilter(event) {
    this.selectedProject = event.currentTarget.dataset.name || "";
    this.applyFilters();
  }

  applyFilters() {
    this.filteredData = this.allData.filter((row) => {
      const matchesSearch = `${row.employeeName} ${row.projectName}`
        .toLowerCase()
        .includes(this.searchTerm);
      const matchesProject =
        !this.selectedProject || row.projectName === this.selectedProject;
      return matchesSearch && matchesProject;
    });
  }

  handleSort(event) {
    const field = event.currentTarget.dataset.field || "workDateValue";
    const requested = event.currentTarget.dataset.sort;
    this.sortDirection = requested
      ? requested === "asc"
        ? "asc"
        : "desc"
      : this.sortDirection === "asc"
        ? "desc"
        : "asc";
    const multiplier = this.sortDirection === "asc" ? 1 : -1;
    this.filteredData = [...this.filteredData].sort(
      (a, b) =>
        String(a[field] || "").localeCompare(String(b[field] || "")) *
        multiplier
    );
  }

  openAddModal() {
    this.isModalOpen = true;
  }
  closeAddModal() {
    this.isModalOpen = false;
  }

  async handleFormSubmit(event) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.target));
    try {
      await saveWorkLog({
        workLog: {
          Work_Type__c: WORK_TYPE,
          Work_Date__c: values.workDate,
          Project__c: values.project,
          Hours__c: Number(values.workedHours),
          Planned_Hours__c: values.plannedHours
            ? Number(values.plannedHours)
            : null,
          Description__c: values.description
        },
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.closeAddModal();
      await this.loadData();
      this.notify(
        "Timesheet submitted",
        "The entry is awaiting approval.",
        "success"
      );
    } catch (error) {
      this.notify("Unable to submit timesheet", this.message(error), "error");
    }
  }

  async handleDecision(event) {
    try {
      await decideWorkLog({
        workLogId: event.currentTarget.dataset.id,
        decision: event.currentTarget.dataset.decision,
        comments: "Reviewed from Timesheets",
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      await this.loadData();
      this.notify(
        "Timesheet updated",
        "The decision has been saved.",
        "success"
      );
    } catch (error) {
      this.notify("Unable to update timesheet", this.message(error), "error");
    }
  }

  exportExcel() {
    const rows = [
      [
        "Employee",
        "Date",
        "Project",
        "Planned Hours",
        "Worked Hours",
        "Status"
      ],
      ...this.filteredData.map((row) => [
        row.employeeName,
        row.workDate,
        row.projectName,
        row.assignedHours,
        row.workedHours,
        row.status
      ])
    ];
    const csv = rows
      .map((row) =>
        row
          .map((value) => `"${String(value ?? "").replaceAll('"', '""')}"`)
          .join(",")
      )
      .join("\n");
    const link = document.createElement("a");
    link.href = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
    link.download = "pwchrono-timesheets.csv";
    link.click();
  }

  exportPDF() {
    globalThis?.window?.print?.();
  }
  handleRowChange() {}
  formatDate(value) {
    return value
      ? new Intl.DateTimeFormat("en-GB", { dateStyle: "medium" }).format(
          new Date(`${value}T00:00:00`)
        )
      : "—";
  }
  message(error) {
    return error?.body?.message || error?.message || "Please try again.";
  }
  notify(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}