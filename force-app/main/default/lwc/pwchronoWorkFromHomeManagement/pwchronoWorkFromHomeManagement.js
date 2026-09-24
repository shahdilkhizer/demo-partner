import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import decideWorkLog from "@salesforce/apex/PWChrono_WorkLogController.decideWorkLog";
import getAssignableEmployees from "@salesforce/apex/PWChrono_WorkLogController.getAssignableEmployees";
import getWorkLogs from "@salesforce/apex/PWChrono_WorkLogController.getWorkLogs";
import saveWorkLog from "@salesforce/apex/PWChrono_WorkLogController.saveWorkLog";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

const WORK_TYPE = "Work From Home";

export default class WfhChildManagement extends LightningElement {
  @track allRequests = [];
  @track visibleRequests = [];
  @track employeeOptions = [];
  @track isAddModalOpen = false;
  @track isLoading = true;
  canReview = false;
  selectedStatus = "All";
  searchTerm = "";
  employeeId;
  sessionToken;

  filterConfigs = [
    {
      label: "Status",
      type: "status",
      options: ["All", "Submitted", "Approved", "Rejected", "Cancelled"]
    }
  ];

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.initialize();
  }

  async initialize() {
    this.isLoading = true;
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
      this.notify("Unable to load WFH requests", this.message(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  async loadData() {
    const rows = await getWorkLogs({
      workType: WORK_TYPE,
      statusFilter: this.selectedStatus,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    });
    this.allRequests = (rows || []).map((row) => this.mapRow(row));
    this.applyFilters();
  }

  mapRow(row) {
    return {
      id: row.Id,
      empId: row.Name,
      name: row.Employee__r?.Name || "Employee",
      userImage: row.Employee__r?.Photo_Url__c,
      designation: row.Employee__r?.Designation__c || "—",
      shift: row.End_Date__c ? "Date range" : "Single day",
      reason: row.Description__c,
      date: row.End_Date__c
        ? `${this.formatDate(row.Work_Date__c)} – ${this.formatDate(row.End_Date__c)}`
        : this.formatDate(row.Work_Date__c),
      status: row.Status__c,
      statusClass: this.statusClass(row.Status__c),
      canDecide: this.canReview && row.Status__c === "Submitted"
    };
  }

  get totalRecords() {
    return this.visibleRequests.length;
  }

  get showEmployeeSelect() {
    return this.canReview && this.employeeOptions.length > 0;
  }

  handleSearch(event) {
    this.searchTerm = (event.target.value || "").toLowerCase();
    this.applyFilters();
  }

  handleDropdownFilter(event) {
    this.selectedStatus = event.currentTarget.dataset.value;
    this.loadData();
  }

  applyFilters() {
    this.visibleRequests = this.allRequests.filter((request) =>
      `${request.name} ${request.empId} ${request.designation}`
        .toLowerCase()
        .includes(this.searchTerm)
    );
  }

  handleSelectAll(event) {
    this.visibleRequests = this.visibleRequests.map((request) => ({
      ...request,
      selected: event.target.checked
    }));
  }

  handleOpenAddModal() {
    this.isAddModalOpen = true;
  }

  handleCloseModal() {
    this.isAddModalOpen = false;
  }

  async handleSaveNewRequest(event) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.target));
    try {
      await saveWorkLog({
        workLog: {
          Work_Type__c: WORK_TYPE,
          Employee__c: values.employee || this.employeeId,
          Work_Date__c: values.startDate,
          End_Date__c: values.endDate || values.startDate,
          Description__c: values.description
        },
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.handleCloseModal();
      await this.loadData();
      this.notify(
        "Request submitted",
        "The WFH request is awaiting approval.",
        "success"
      );
    } catch (error) {
      this.notify("Unable to submit request", this.message(error), "error");
    }
  }

  async handleDecision(event) {
    try {
      await decideWorkLog({
        workLogId: event.currentTarget.dataset.id,
        decision: event.currentTarget.dataset.decision,
        comments: "Reviewed from Work From Home Management",
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      await this.loadData();
      this.notify("Request updated", "The decision has been saved.", "success");
    } catch (error) {
      this.notify("Unable to update request", this.message(error), "error");
    }
  }

  handleExportExcel() {
    this.downloadCsv("pwchrono-wfh.csv", [
      ["Request", "Employee", "Designation", "Dates", "Status", "Reason"],
      ...this.visibleRequests.map((row) => [
        row.empId,
        row.name,
        row.designation,
        row.date,
        row.status,
        row.reason
      ])
    ]);
  }

  handleExportPDF() {
    globalThis?.window?.print?.();
  }

  handleFilterChange() {}
  handlePageSizeChange() {}

  downloadCsv(filename, rows) {
    const csv = rows
      .map((row) =>
        row
          .map((value) => `"${String(value ?? "").replaceAll('"', '""')}"`)
          .join(",")
      )
      .join("\n");
    const link = document.createElement("a");
    link.href = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
    link.download = filename;
    link.click();
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