import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import decideWorkLog from "@salesforce/apex/PWChrono_WorkLogController.decideWorkLog";
import getAssignableEmployees from "@salesforce/apex/PWChrono_WorkLogController.getAssignableEmployees";
import getWorkLogs from "@salesforce/apex/PWChrono_WorkLogController.getWorkLogs";
import saveWorkLog from "@salesforce/apex/PWChrono_WorkLogController.saveWorkLog";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

const WORK_TYPE = "Overtime";

export default class OvertimeManagement extends LightningElement {
  @track allData = [];
  @track filteredData = [];
  @track employeeOptions = [];
  @track isModalOpen = false;
  canReview = false;
  searchTerm = "";
  statusFilter = "All";
  employeeId;
  sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.initialize();
  }

  async initialize() {
    try {
      const access = await getUserAccessById({
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      const features = access?.features || [];
      this.canReview =
        features.includes("Attendance Team") ||
        features.includes("Attendance Administration");
      if (this.canReview) {
        const employees = await getAssignableEmployees({
          portalUserId: this.employeeId,
          sessionToken: this.sessionToken
        });
        this.employeeOptions = (employees || []).map((employee) => ({
          label: employee.Name,
          value: employee.Id
        }));
      }
      await this.loadData();
    } catch (error) {
      this.notify("Unable to load overtime", this.message(error), "error");
    }
  }

  async loadData() {
    const rows = await getWorkLogs({
      workType: WORK_TYPE,
      statusFilter: this.statusFilter,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    });
    this.allData = (rows || []).map((row) => ({
      id: row.Id,
      name: row.Employee__r?.Name || "Employee",
      team: row.Employee__r?.Department__c || "—",
      date: this.formatDate(row.Work_Date__c),
      hours: row.Hours__c,
      project: row.Project__r?.Name || "—",
      approvedBy: row.Approver__r?.Name || "Awaiting assignment",
      status: row.Status__c,
      statusBadgeClass: this.statusClass(row.Status__c),
      userImg: row.Employee__r?.Photo_Url__c,
      canDecide: this.canReview && row.Status__c === "Submitted"
    }));
    this.applyFilters();
  }

  get stats() {
    const uniqueEmployees = new Set(this.allData.map((row) => row.name)).size;
    const hours = this.allData.reduce(
      (sum, row) => sum + Number(row.hours || 0),
      0
    );
    return [
      this.stat(
        "Overtime Employees",
        uniqueEmployees,
        "ti ti-user-check text-primary fs-18",
        "primary"
      ),
      this.stat(
        "Overtime Hours",
        hours.toFixed(2),
        "ti ti-clock text-pink fs-18",
        "pink"
      ),
      this.stat(
        "Pending Requests",
        this.allData.filter((row) => row.status === "Submitted").length,
        "ti ti-user-exclamation text-purple fs-18",
        "purple"
      ),
      this.stat(
        "Rejected",
        this.allData.filter((row) => row.status === "Rejected").length,
        "ti ti-circle-x text-skyblue fs-18",
        "skyblue"
      )
    ];
  }

  get showEmployeeSelect() {
    return this.canReview && this.employeeOptions.length > 0;
  }

  stat(label, value, iconClass, tone) {
    return {
      label,
      value,
      iconClass,
      iconBgClass: `p-2 br-10 bg-transparent-${tone} border border-${tone} d-flex align-items-center justify-content-center`
    };
  }

  openAddModal() {
    this.isModalOpen = true;
  }
  closeModal() {
    this.isModalOpen = false;
  }

  handleSearch(event) {
    this.searchTerm = (event.target.value || "").toLowerCase();
    this.applyFilters();
  }

  handleFilter(event) {
    this.statusFilter = event.currentTarget.dataset.status || "All";
    this.loadData();
  }

  applyFilters() {
    this.filteredData = this.allData.filter((row) =>
      `${row.name} ${row.project}`.toLowerCase().includes(this.searchTerm)
    );
  }

  async handleSave(event) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.target));
    try {
      await saveWorkLog({
        workLog: {
          Work_Type__c: WORK_TYPE,
          Employee__c: values.employee || this.employeeId,
          Work_Date__c: values.date,
          Hours__c: Number(values.hours),
          Description__c: values.description
        },
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.closeModal();
      await this.loadData();
      this.notify(
        "Overtime submitted",
        "The request is awaiting approval.",
        "success"
      );
    } catch (error) {
      this.notify("Unable to submit overtime", this.message(error), "error");
    }
  }

  async handleDecision(event) {
    try {
      await decideWorkLog({
        workLogId: event.currentTarget.dataset.id,
        decision: event.currentTarget.dataset.decision,
        comments: "Reviewed from Overtime",
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      await this.loadData();
      this.notify(
        "Overtime updated",
        "The decision has been saved.",
        "success"
      );
    } catch (error) {
      this.notify("Unable to update overtime", this.message(error), "error");
    }
  }

  handleSort() {
    this.filteredData = [...this.filteredData].reverse();
  }

  exportExcel() {
    const rows = [
      ["Employee", "Date", "Hours", "Project", "Approver", "Status"],
      ...this.filteredData.map((row) => [
        row.name,
        row.date,
        row.hours,
        row.project,
        row.approvedBy,
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
    link.download = "pwchrono-overtime.csv";
    link.click();
  }

  exportPDF() {
    globalThis?.window?.print?.();
  }

  statusClass(status) {
    const tone =
      status === "Approved"
        ? "success"
        : status === "Rejected" || status === "Cancelled"
          ? "danger"
          : "info";
    return `badge badge-soft-${tone} d-inline-flex align-items-center badge-xs`;
  }

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