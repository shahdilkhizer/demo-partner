import generatePayrollDrafts from "@salesforce/apex/PWChrono_PortalApi.generatePayrollDrafts";
import getEmployeesForDropdown from "@salesforce/apex/PWChrono_PortalApi.getEmployeesForDropdown";
import getMySalarySlips from "@salesforce/apex/PWChrono_PortalApi.getMySalarySlips";
import getPayrollConfiguration from "@salesforce/apex/PWChrono_PayrollController.getPayrollConfiguration";
import getPayrollWorkspace from "@salesforce/apex/PWChrono_PortalApi.getPayrollWorkspace";
import getSalarySlipDetails from "@salesforce/apex/PWChrono_PortalApi.getSalarySlipDetails";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import markPayrollPaid from "@salesforce/apex/PWChrono_PortalApi.markPayrollPaid";
import saveSalaryAssignment from "@salesforce/apex/PWChrono_PortalApi.saveSalaryAssignment";
import sendSalarySlipEmail from "@salesforce/apex/PWChrono_PayrollController.sendSalarySlipEmail";
import submitPayroll from "@salesforce/apex/PWChrono_PortalApi.submitPayroll";
import hasSendPayslipPermission from "@salesforce/customPermission/PWChrono_Send_Payslips";
import { refreshApex } from "@salesforce/apex";
import { CONSTANTS } from "c/pwchronoConstants";
import {
  logError,
  showErrorToast,
  showSuccessToast
} from "c/pwchronoErrorHandler";
import { getEmployeeId, getSession, getSessionToken } from "c/pwchronoSession";
import { LightningElement, track, wire } from "lwc";

const ADMIN_ROLES = new Set([
  "HR Admin",
  "Payroll Admin",
  "System Administrator",
  "System Admin"
]);

const COLUMNS = [
  { label: "Period", fieldName: "Payroll_Period__c", type: "date" },
  {
    label: "Gross Pay",
    fieldName: "Gross_Pay__c",
    type: "currency",
    typeAttributes: { currencyCode: CONSTANTS.CURRENCY_CODE }
  },
  {
    label: "Deductions",
    fieldName: "Total_Deductions__c",
    type: "currency",
    typeAttributes: { currencyCode: CONSTANTS.CURRENCY_CODE }
  },
  {
    label: "Net Pay",
    fieldName: "Net_Pay__c",
    type: "currency",
    typeAttributes: { currencyCode: CONSTANTS.CURRENCY_CODE }
  },
  { label: "Status", fieldName: "Status__c", type: "text" },
  {
    type: "button",
    typeAttributes: {
      label: "View",
      name: "view_details",
      variant: "base"
    }
  }
];

function currentMonthValue() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function todayValue() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

function readError(error, fallback) {
  const body = error?.body;
  if (Array.isArray(body)) {
    return (
      body
        .map((item) => item?.message)
        .filter(Boolean)
        .join("; ") || fallback
    );
  }
  return (
    body?.message ||
    body?.output?.errors
      ?.map((item) => item?.message)
      .filter(Boolean)
      .join("; ") ||
    error?.message ||
    fallback
  );
}

export default class PwchronoSalarySlipViewer extends LightningElement {
  static renderMode = "light";

  currencyCode = CONSTANTS.CURRENCY_CODE;
  canSendPayslips = hasSendPayslipPermission === true;
  columns = COLUMNS;

  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();
  role;
  activeView = "slips";

  @track hasAccess = false;
  @track accessLoaded = false;
  @track selectedYear;
  @track selectedMonth;
  @track salarySlips = [];
  @track error;
  @track isLoading = true;

  @track showDetailModal = false;
  @track selectedSlipId;
  @track selectedSlipName;
  @track slipDetails;
  @track isLoadingDetails = false;

  @track contactId = null;
  @track selectedContactId;
  @track employeeOptions = [];
  @track isSalesforceUser = false;
  @track isEmployeeDropdownReadOnly = true;

  @track showEmailModal = false;
  @track emailTo;
  @track emailCc;
  @track emailSubject;
  @track emailBody;
  @track isSendingEmail = false;

  @track allSlips = [];
  @track currentPage = 1;
  @track pageSize = 10;
  wiredSlipsResult;

  @track payrollWorkspace;
  @track payrollRows = [];
  @track payrollError;
  @track isPayrollLoading = false;
  @track isPayrollBusy = false;
  payrollBusyLabel = "Updating payroll...";
  payrollMonth = currentMonthValue();
  paymentDate = todayValue();
  paymentMethod = "Bank Transfer";

  @track showConfirmationModal = false;
  confirmationAction;
  confirmationTitle;
  confirmationMessage;
  confirmationButtonLabel;

  connectedCallback() {
    const session = getSession();
    this.portalUserId = session.user?.Id || getEmployeeId();
    this.sessionToken = getSessionToken();
    this.checkAccess();
  }

  async checkAccess() {
    try {
      const data = await getUserAccessById({
        employeeId: this.portalUserId,
        sessionToken: this.sessionToken
      });
      this.hasAccess = data?.features?.includes("Payroll") || false;
      this.isSalesforceUser = data?.isSalesforceUser === true;
      this.role = data?.role;
      this.isEmployeeDropdownReadOnly = !this.isSalesforceUser;
      if (this.hasAdminAccess) {
        this.activeView = "run";
        await this.loadPayrollWorkspace();
      }
    } catch (accessError) {
      logError("pwchronoSalarySlipViewer.checkAccess", accessError);
      this.hasAccess = false;
      this.error = readError(
        accessError,
        "Failed to verify payroll access permissions."
      );
    } finally {
      this.accessLoaded = true;
    }
  }

  @wire(getEmployeesForDropdown, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredEmployees({ error: wireError, data }) {
    if (data) {
      this.employeeOptions = data.map((employee) => ({
        label: employee.Name,
        value: employee.Id
      }));
      const selectedContactExists = this.employeeOptions.some(
        (option) => option.value === this.selectedContactId
      );
      if (!selectedContactExists) {
        this.selectedContactId = this.employeeOptions[0]?.value;
        this.contactId = this.selectedContactId;
      }
    } else if (wireError) {
      logError("pwchronoSalarySlipViewer.wiredEmployees", wireError);
    }
  }

  @wire(getPayrollConfiguration)
  wiredConfig({ data }) {
    if (data) {
      this.emailCc = data.ccEmail;
    }
  }

  @wire(getMySalarySlips, {
    year: "$selectedYearInt",
    month: "$selectedMonthInt",
    contactId: "$contactId",
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredSlips(result) {
    this.wiredSlipsResult = result;
    const { error, data } = result;
    if (data) {
      this.allSlips = data;
      this.currentPage = 1;
      this.applyPagination();
      this.error = undefined;
    } else if (error) {
      this.error = readError(error, "Unable to load salary slips.");
      this.salarySlips = [];
      this.allSlips = [];
    }
    this.isLoading = false;
  }

  get hasAdminAccess() {
    return ADMIN_ROLES.has(this.role);
  }

  get accessDenied() {
    return this.accessLoaded && !this.hasAccess;
  }

  get isRunView() {
    return this.hasAdminAccess && this.activeView === "run";
  }

  get isSlipsView() {
    return !this.hasAdminAccess || this.activeView === "slips";
  }

  get runTabClass() {
    return this.isRunView ? "payroll-tab payroll-tab_active" : "payroll-tab";
  }

  get slipsTabClass() {
    return this.isSlipsView ? "payroll-tab payroll-tab_active" : "payroll-tab";
  }

  get payrollPeriod() {
    return this.payrollMonth ? `${this.payrollMonth}-01` : null;
  }

  get payrollPeriodLabel() {
    return this.payrollWorkspace?.periodLabel || "Selected period";
  }

  get activeEmployeeCount() {
    return this.payrollWorkspace?.activeEmployeeCount || 0;
  }

  get readyEmployeeCount() {
    return this.payrollWorkspace?.readyEmployeeCount || 0;
  }

  get missingAssignmentCount() {
    return this.payrollWorkspace?.missingAssignmentCount || 0;
  }

  get draftCount() {
    return this.payrollWorkspace?.draftCount || 0;
  }

  get submittedCount() {
    return this.payrollWorkspace?.submittedCount || 0;
  }

  get paidCount() {
    return this.payrollWorkspace?.paidCount || 0;
  }

  get totalGross() {
    return this.payrollWorkspace?.totalGross || 0;
  }

  get totalDeductions() {
    return this.payrollWorkspace?.totalDeductions || 0;
  }

  get totalNet() {
    return this.payrollWorkspace?.totalNet || 0;
  }

  get configurationComplete() {
    return this.payrollWorkspace?.configurationComplete === true;
  }

  get hasPayrollRows() {
    return this.payrollRows.length > 0;
  }

  get generateDisabled() {
    return this.isPayrollBusy || this.readyEmployeeCount === 0;
  }

  get submitDisabled() {
    return (
      this.isPayrollBusy || !this.configurationComplete || this.draftCount === 0
    );
  }

  get payDisabled() {
    return (
      this.isPayrollBusy ||
      !this.configurationComplete ||
      this.submittedCount === 0 ||
      this.draftCount > 0
    );
  }

  get setupStepClass() {
    return this.configurationComplete
      ? "process-step process-step_complete"
      : "process-step process-step_current";
  }

  get draftStepClass() {
    if (this.draftCount > 0) return "process-step process-step_current";
    if (this.submittedCount > 0 || this.paidCount > 0) {
      return "process-step process-step_complete";
    }
    return "process-step";
  }

  get submitStepClass() {
    if (this.submittedCount > 0) return "process-step process-step_current";
    if (this.paidCount > 0) return "process-step process-step_complete";
    return "process-step";
  }

  get paidStepClass() {
    return this.paidCount > 0
      ? "process-step process-step_complete"
      : "process-step";
  }

  get pageSizeOptions() {
    return [
      { label: "5 per page", value: "5" },
      { label: "10 per page", value: "10" },
      { label: "25 per page", value: "25" },
      { label: "50 per page", value: "50" }
    ];
  }

  get yearOptions() {
    const currentYear = new Date().getFullYear();
    return [
      { label: "All", value: "" },
      { label: String(currentYear), value: String(currentYear) },
      { label: String(currentYear - 1), value: String(currentYear - 1) }
    ];
  }

  get monthOptions() {
    return [
      { label: "All", value: "" },
      { label: "January", value: "1" },
      { label: "February", value: "2" },
      { label: "March", value: "3" },
      { label: "April", value: "4" },
      { label: "May", value: "5" },
      { label: "June", value: "6" },
      { label: "July", value: "7" },
      { label: "August", value: "8" },
      { label: "September", value: "9" },
      { label: "October", value: "10" },
      { label: "November", value: "11" },
      { label: "December", value: "12" }
    ];
  }

  get paymentMethodOptions() {
    return ["Bank Transfer", "Cash", "Cheque", "Other"];
  }

  get selectedYearInt() {
    return this.selectedYear ? Number.parseInt(this.selectedYear, 10) : null;
  }

  get selectedMonthInt() {
    return this.selectedMonth ? Number.parseInt(this.selectedMonth, 10) : null;
  }

  get hasSalarySlips() {
    return this.salarySlips.length > 0;
  }

  get slipCount() {
    return this.allSlips.length;
  }

  get totalPages() {
    return Math.ceil(this.allSlips.length / this.pageSize) || 1;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get pageInfo() {
    if (!this.allSlips.length) return "0 records";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(
      this.currentPage * this.pageSize,
      this.allSlips.length
    );
    return `${start}–${end} of ${this.allSlips.length}`;
  }

  get formattedPeriod() {
    if (this.slipDetails?.salarySlip?.Payroll_Period__c) {
      return new Date(
        `${this.slipDetails.salarySlip.Payroll_Period__c}T00:00:00`
      ).toLocaleDateString(undefined, { year: "numeric", month: "long" });
    }
    return "";
  }

  get employeeName() {
    return (
      this.slipDetails?.salarySlip?.Employee_Name_Snapshot__c ||
      this.slipDetails?.salarySlip?.Contact__r?.Name ||
      "Not available"
    );
  }

  get employeeCode() {
    return this.slipDetails?.salarySlip?.Employee_Code_Snapshot__c || "Not set";
  }

  get today() {
    return new Date().toISOString();
  }

  get isSendDisabled() {
    return !this.emailTo || this.isSendingEmail;
  }

  get sendButtonLabel() {
    return this.isSendingEmail ? "Sending..." : "Send";
  }

  handleRunTab() {
    this.activeView = "run";
    if (!this.payrollWorkspace) this.loadPayrollWorkspace();
  }

  handleSlipsTab() {
    this.activeView = "slips";
  }

  async loadPayrollWorkspace() {
    if (!this.hasAdminAccess || this.isPayrollLoading) return;
    this.isPayrollLoading = true;
    this.payrollError = undefined;
    try {
      const result = await getPayrollWorkspace({
        payrollPeriod: this.payrollPeriod,
        portalUserId: this.portalUserId,
        sessionToken: this.sessionToken
      });
      this.payrollWorkspace = JSON.parse(JSON.stringify(result));
      this.payrollRows = (this.payrollWorkspace?.employees || []).map(
        (row) => ({
          ...row,
          baseSalaryInput: row.baseSalary ?? "",
          salaryLocked: row.salaryEditable === false,
          statusClass: this.statusClass(row.status),
          initials: this.initials(row.employeeName)
        })
      );
    } catch (workspaceError) {
      logError("pwchronoSalarySlipViewer.loadPayrollWorkspace", workspaceError);
      this.payrollWorkspace = undefined;
      this.payrollRows = [];
      this.payrollError = readError(
        workspaceError,
        "Unable to load the payroll workspace."
      );
    } finally {
      this.isPayrollLoading = false;
    }
  }

  statusClass(status) {
    const normalized = (status || "").toLowerCase().replaceAll(" ", "-");
    return `status-pill status-pill_${normalized || "neutral"}`;
  }

  initials(name) {
    return (name || "Employee")
      .split(" ")
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0])
      .join("")
      .toUpperCase();
  }

  async handlePayrollMonthChange(event) {
    this.payrollMonth = event.target.value;
    await this.loadPayrollWorkspace();
  }

  handlePaymentDateChange(event) {
    this.paymentDate = event.target.value;
  }

  handlePaymentMethodChange(event) {
    this.paymentMethod = event.target.value;
  }

  handleBaseSalaryChange(event) {
    const contactId = event.target.dataset.contactId;
    const value = event.target.value;
    this.payrollRows = this.payrollRows.map((row) => {
      return row.contactId === contactId
        ? { ...row, baseSalaryInput: value }
        : row;
    });
  }

  async handleSaveSalary(event) {
    const contactId = event.currentTarget.dataset.contactId;
    const row = this.payrollRows.find((item) => item.contactId === contactId);
    const baseSalary = Number(row?.baseSalaryInput);
    if (!Number.isFinite(baseSalary) || baseSalary <= 0) {
      showErrorToast(
        this.dispatchEvent.bind(this),
        "Salary setup",
        "Enter a base salary greater than zero."
      );
      return;
    }

    await this.runPayrollMutation(
      "Saving salary setup...",
      () =>
        saveSalaryAssignment({
          contactId,
          baseSalary,
          effectiveDate: this.payrollPeriod,
          portalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        }),
      "Salary setup saved"
    );
  }

  async handleGenerateDrafts() {
    await this.runPayrollMutation(
      "Calculating payroll drafts...",
      () =>
        generatePayrollDrafts({
          payrollPeriod: this.payrollPeriod,
          portalUserId: this.portalUserId,
          sessionToken: this.sessionToken
        }),
      "Payroll drafts prepared"
    );
  }

  handleSubmitPayroll() {
    this.openConfirmation(
      "submit",
      "Finalize payroll?",
      `This locks ${this.draftCount} draft payslip(s) for ${this.payrollPeriodLabel} and makes them visible to employees.`,
      "Finalize payroll"
    );
  }

  handleMarkPaid() {
    this.openConfirmation(
      "paid",
      "Mark payroll paid?",
      `This records ${this.submittedCount} payslip(s) as paid on ${this.paymentDate}. It records the payment state but does not initiate a bank transfer.`,
      "Mark paid"
    );
  }

  openConfirmation(action, title, message, buttonLabel) {
    this.confirmationAction = action;
    this.confirmationTitle = title;
    this.confirmationMessage = message;
    this.confirmationButtonLabel = buttonLabel;
    this.showConfirmationModal = true;
  }

  closeConfirmation() {
    if (this.isPayrollBusy) return;
    this.showConfirmationModal = false;
  }

  async handleConfirmAction() {
    const action = this.confirmationAction;
    this.showConfirmationModal = false;
    if (action === "submit") {
      await this.runPayrollMutation(
        "Finalizing payroll...",
        () =>
          submitPayroll({
            payrollPeriod: this.payrollPeriod,
            portalUserId: this.portalUserId,
            sessionToken: this.sessionToken
          }),
        "Payroll finalized"
      );
    } else if (action === "paid") {
      await this.runPayrollMutation(
        "Recording payment...",
        () =>
          markPayrollPaid({
            payrollPeriod: this.payrollPeriod,
            paymentDate: this.paymentDate,
            paymentMethod: this.paymentMethod,
            portalUserId: this.portalUserId,
            sessionToken: this.sessionToken
          }),
        "Payroll marked paid"
      );
    }
  }

  async runPayrollMutation(busyLabel, operation, successTitle) {
    if (this.isPayrollBusy) return;
    this.isPayrollBusy = true;
    this.payrollBusyLabel = busyLabel;
    try {
      const result = await operation();
      showSuccessToast(
        this.dispatchEvent.bind(this),
        successTitle,
        result?.message || "Payroll updated successfully."
      );
      await this.loadPayrollWorkspace();
      if (this.wiredSlipsResult) await refreshApex(this.wiredSlipsResult);
    } catch (mutationError) {
      logError("pwchronoSalarySlipViewer.runPayrollMutation", mutationError);
      showErrorToast(
        this.dispatchEvent.bind(this),
        "Payroll update failed",
        readError(mutationError, "Unable to update payroll.")
      );
    } finally {
      this.isPayrollBusy = false;
    }
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    this.salarySlips = this.allSlips.slice(start, start + this.pageSize);
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.applyPagination();
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage -= 1;
      this.applyPagination();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage += 1;
      this.applyPagination();
    }
  }

  handleEmployeeChange(event) {
    this.selectedContactId = event.detail.value;
    this.contactId = event.detail.value;
  }

  handleYearChange(event) {
    this.selectedYear = event.detail.value;
  }

  handleMonthChange(event) {
    this.selectedMonth = event.detail.value;
  }

  handleRowAction(event) {
    if (event.detail.action.name === "view_details") {
      this.selectedSlipId = event.detail.row.Id;
      this.selectedSlipName = event.detail.row.Name;
      this.showDetailModal = true;
      this.loadSlipDetails();
    }
  }

  closeModal() {
    this.showDetailModal = false;
    this.slipDetails = null;
  }

  async loadSlipDetails() {
    this.isLoadingDetails = true;
    try {
      const result = await getSalarySlipDetails({
        salarySlipId: this.selectedSlipId,
        contactId: this.contactId,
        portalUserId: this.portalUserId,
        sessionToken: this.sessionToken
      });
      this.slipDetails = result;
      const salarySlip = result?.salarySlip;
      if (salarySlip) {
        this.emailTo = salarySlip.Contact__r?.Email || "";
        const employeeName =
          salarySlip.Employee_Name_Snapshot__c ||
          salarySlip.Contact__r?.Name ||
          "Employee";
        this.emailSubject = `Salary Slip - ${salarySlip.Name} - ${this.formattedPeriod}`;
        this.emailBody = `Dear ${employeeName},<br/><br/>Your salary slip for ${this.formattedPeriod} is available.<br/><br/>Regards,<br/>HR Team`;
      }
    } catch (detailError) {
      logError("pwchronoSalarySlipViewer.loadSlipDetails", detailError);
      showErrorToast(
        this.dispatchEvent.bind(this),
        "Salary slip",
        readError(detailError, "Failed to load salary slip details.")
      );
    } finally {
      this.isLoadingDetails = false;
    }
  }

  handlePrint() {
    globalThis.print();
  }

  handleOpenEmailModal() {
    if (this.canSendPayslips) this.showEmailModal = true;
  }

  handleCloseEmailModal() {
    this.showEmailModal = false;
  }

  handleEmailFieldChange(event) {
    const field = event.target.name;
    if (field === "emailSubject") this.emailSubject = event.detail.value;
    if (field === "emailBody") this.emailBody = event.detail.value;
  }

  async handleSendEmail() {
    this.isSendingEmail = true;
    try {
      await sendSalarySlipEmail({
        salarySlipId: this.selectedSlipId,
        toEmail: this.emailTo,
        ccEmail: this.emailCc,
        subject: this.emailSubject,
        body: this.emailBody,
        portalUserId: this.portalUserId,
        sessionToken: this.sessionToken
      });
      showSuccessToast(
        this.dispatchEvent.bind(this),
        "Payslip sent",
        "The salary slip email was sent successfully."
      );
      this.handleCloseEmailModal();
    } catch (emailError) {
      logError("pwchronoSalarySlipViewer.handleSendEmail", emailError);
      showErrorToast(
        this.dispatchEvent.bind(this),
        "Email failed",
        readError(emailError, "Failed to send the salary slip email.")
      );
    } finally {
      this.isSendingEmail = false;
    }
  }
}