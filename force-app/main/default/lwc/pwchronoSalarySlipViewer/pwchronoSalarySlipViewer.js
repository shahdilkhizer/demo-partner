import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getEmployeesForDropdown from "@salesforce/apex/PWChrono_PayrollController.getEmployeesForDropdown";
import getMySalarySlips from "@salesforce/apex/PWChrono_PayrollController.getMySalarySlips";
import getPayrollConfiguration from "@salesforce/apex/PWChrono_PayrollController.getPayrollConfiguration";
import getSalarySlipDetails from "@salesforce/apex/PWChrono_PayrollController.getSalarySlipDetails";
import sendSalarySlipEmail from "@salesforce/apex/PWChrono_PayrollController.sendSalarySlipEmail";
import { CONSTANTS } from "c/pwchronoConstants";
import {
  logError,
  showErrorToast,
  showSuccessToast
} from "c/pwchronoErrorHandler";
import { getEmployeeId, getSession, getSessionToken } from "c/pwchronoSession";
import { LightningElement, track, wire } from "lwc";

const COLUMNS = [
  { label: "Period", fieldName: "Payroll_Period__c", type: "date" },
  { label: "Gross Pay", fieldName: "Gross_Pay__c", type: "currency" },
  { label: "Deductions", fieldName: "Total_Deductions__c", type: "currency" },
  { label: "Net Pay", fieldName: "Net_Pay__c", type: "currency" },
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

export default class PwchronoSalarySlipViewer extends LightningElement {
  static renderMode = "light";
  currencyCode = CONSTANTS.CURRENCY_CODE;

  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  @track hasAccess = false;
  @track accessLoaded = false;
  @track selectedYear;
  @track selectedMonth;
  @track salarySlips;
  @track error;

  @track showDetailModal = false;
  @track selectedSlipId;
  @track selectedSlipName;
  @track slipDetails;
  @track isLoadingDetails = false;

  @track isLoading = true;

  // Employee Dropdown
  @track employeeId = getEmployeeId(); // The ID used for querying slips
  @track selectedEmployeeId = getEmployeeId(); // The value in the dropdown
  @track employeeOptions = [];
  @track isSalesforceUser = false;
  @track isEmployeeDropdownReadOnly = true;

  // Email Feature
  @track showEmailModal = false;
  @track emailTo;
  @track emailCc;
  @track emailSubject;
  @track emailBody;
  @track isSendingEmail = false;

  // Pagination
  @track allSlips = [];
  @track currentPage = 1;
  @track pageSize = 10;

  get pageSizeOptions() {
    return [
      { label: "5 per page", value: "5" },
      { label: "10 per page", value: "10" },
      { label: "25 per page", value: "25" },
      { label: "50 per page", value: "50" }
    ];
  }

  columns = COLUMNS;

  connectedCallback() {
    const session = getSession();
    // Initial employee ID from session
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.employeeId = session.user ? session.user.Id : this.portalUserId;
    this.selectedEmployeeId = this.employeeId;
    // Check access imperatively
    this.checkAccess();
  }

  async checkAccess() {
    try {
      const employeeId = getEmployeeId();
      const data = await getUserAccessById({
        employeeId: employeeId,
        sessionToken: this.sessionToken
      });
      if (data) {
        this.hasAccess = data.features?.includes("Payroll") || false;
        this.isSalesforceUser = data.isSalesforceUser;
        this.accessLoaded = true;
      }
    } catch (error) {
      logError("pwchronoSalarySlipViewer.checkAccess", error);
      showErrorToast(
        this.dispatchEvent.bind(this),
        "Error",
        error?.body?.message ||
          error?.message ||
          "Failed to verify access permissions"
      );
      this.hasAccess = false;
      this.accessLoaded = true;
    }
  }

  @wire(getEmployeesForDropdown, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredEmployees({ error: wireError, data }) {
    if (data) {
      this.employeeOptions = data.map((emp) => ({
        label: emp.Name,
        value: emp.Id
      }));

      // If Salesforce user, dropdown is editable. If not, read-only (unless we add more logic later)
      // The requirement says: "if user is not Salesforce User... check rights... if not then read only"
      // For now, we'll assume non-Salesforce users are read-only on their own record
      this.isEmployeeDropdownReadOnly = !this.isSalesforceUser;

      // If Salesforce user and no employee selected yet, maybe select the first one or keep blank?
      // Keeping current session user if available in list, else first one?
      // For now, we keep what was set in connectedCallback (session user)
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

  get yearOptions() {
    const currentYear = new Date().getFullYear();
    return [
      { label: "All", value: "" },
      { label: String(currentYear), value: String(currentYear) },
      { label: String(currentYear - 1), value: String(currentYear - 1) }
    ];
  }

  get slipCount() {
    return this.allSlips ? this.allSlips.length : 0;
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

  @wire(getMySalarySlips, {
    year: "$selectedYearInt",
    month: "$selectedMonthInt",
    employeeId: "$employeeId",
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredSlips({ error, data }) {
    if (data) {
      this.allSlips = data;
      this.currentPage = 1;
      this.applyPagination();
      this.error = undefined;
    } else if (error) {
      this.error = error.body.message;
      this.salarySlips = undefined;
      this.allSlips = [];
    }
    this.isLoading = false;
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.salarySlips = this.allSlips.slice(start, end);
  }

  // Pagination getters
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
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(
      this.currentPage * this.pageSize,
      this.allSlips.length
    );
    return `${start}–${end} of ${this.allSlips.length}`;
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.applyPagination();
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.applyPagination();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.applyPagination();
    }
  }

  get selectedYearInt() {
    return this.selectedYear ? Number.parseInt(this.selectedYear, 10) : null;
  }

  get selectedMonthInt() {
    return this.selectedMonth ? Number.parseInt(this.selectedMonth, 10) : null;
  }

  handleEmployeeChange(event) {
    this.selectedEmployeeId = event.detail.value;
    this.employeeId = event.detail.value; // Triggers wire
  }

  handleYearChange(event) {
    this.selectedYear = event.detail.value;
  }

  handleMonthChange(event) {
    this.selectedMonth = event.detail.value;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    if (actionName === "view_details") {
      this.selectedSlipId = row.Id;
      this.selectedSlipName = row.Name;
      this.openModal();
    }
  }

  openModal() {
    this.showDetailModal = true;
    this.loadSlipDetails();
  }

  closeModal() {
    this.showDetailModal = false;
    this.slipDetails = null;
  }

  loadSlipDetails() {
    this.isLoadingDetails = true;
    getSalarySlipDetails({
      salarySlipId: this.selectedSlipId,
      employeeId: this.employeeId,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then((result) => {
        this.slipDetails = result;
        // Pre-fill email details
        if (this.slipDetails?.salarySlip) {
          // Try to get email from Employee record, fallback to session user email if it matches
          const empEmail = this.slipDetails.salarySlip.Employees__r
            ? this.slipDetails.salarySlip.Employees__r.Email__c
            : "";
          this.emailTo = empEmail;
          this.emailSubject = `Salary Slip - ${this.slipDetails.salarySlip.Name} - ${this.formattedPeriod}`;
          this.emailBody = `Dear ${this.slipDetails.salarySlip.Employees__r ? this.slipDetails.salarySlip.Employees__r.Name : "Employee"},<br/><br/>Please find attached your salary slip for ${this.formattedPeriod}.<br/><br/>Regards,<br/>HR Team`;
        }
      })
      .catch((error) => {
        logError("pwchronoSalarySlipViewer.loadSlipDetails", error);
        showErrorToast(
          this.dispatchEvent.bind(this),
          "Error",
          "Failed to load salary slip details"
        );
      })
      .finally(() => {
        this.isLoadingDetails = false;
      });
  }

  get formattedPeriod() {
    if (this.slipDetails?.salarySlip?.Payroll_Period__c) {
      return new Date(
        this.slipDetails.salarySlip.Payroll_Period__c
      ).toLocaleDateString(undefined, { year: "numeric", month: "long" });
    }
    return "";
  }

  get employeeName() {
    return this.slipDetails?.salarySlip?.Employees__r?.Name || "N/A";
  }

  handlePrint() {
    globalThis.print();
  }

  // Email Handlers
  handleOpenEmailModal() {
    this.showEmailModal = true;
  }

  handleCloseEmailModal() {
    this.showEmailModal = false;
  }

  handleEmailFieldChange(event) {
    const field = event.target.name;
    if (field === "emailSubject") this.emailSubject = event.detail.value;
    if (field === "emailBody") this.emailBody = event.detail.value;
  }

  get isSendDisabled() {
    return !this.emailTo || this.isSendingEmail;
  }

  get sendButtonLabel() {
    return this.isSendingEmail ? "Sending..." : "Send";
  }

  handleSendEmail() {
    this.isSendingEmail = true;
    sendSalarySlipEmail({
      salarySlipId: this.selectedSlipId,
      toEmail: this.emailTo,
      ccEmail: this.emailCc,
      subject: this.emailSubject,
      body: this.emailBody,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        showSuccessToast(
          this.dispatchEvent.bind(this),
          "Success",
          "Email sent successfully"
        );
        this.handleCloseEmailModal();
      })
      .catch((error) => {
        logError("pwchronoSalarySlipViewer.handleSendEmail", error);
        showErrorToast(
          this.dispatchEvent.bind(this),
          "Error",
          "Failed to send email: " +
            (error?.body?.message || error?.message || "Unknown error")
        );
      })
      .finally(() => {
        this.isSendingEmail = false;
      });
  }
}