import { refreshApex } from "@salesforce/apex";
import getMyAttendanceRequests from "@salesforce/apex/PWChrono_AttendanceController.getMyAttendanceRequests";
import saveAttendanceRequest from "@salesforce/apex/PWChrono_AttendanceController.saveAttendanceRequest";
import {
  getEmployeeId,
  getSessionToken,
  hasFieldPermission,
  hasPermission
} from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, api, track, wire } from "lwc";

const COLUMNS = [
  { label: "Date", fieldName: "Attendance_Date__c", type: "date" },
  { label: "Check-In", fieldName: "From_Time__c", type: "time" },
  { label: "Check-Out", fieldName: "To_Time__c", type: "time" },
  { label: "Reason", fieldName: "Reason__c", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Approver", fieldName: "ApproverName", type: "text" }
];

export default class PwchronoAttendanceRequest extends LightningElement {
  _attendanceDate;

  @api
  get attendanceDate() {
    return this._attendanceDate;
  }
  set attendanceDate(value) {
    this._attendanceDate = value;
  }
  @track checkInTime;
  @track checkOutTime;
  @track reason;
  @track isProcessing = false;

  columns = COLUMNS;
  wiredRequestsResult;
  @track allRequests = [];
  @track requests = [];
  @track error;
  @track isLoading = true;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  // Pagination
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

  get canCreateRequest() {
    return hasPermission("PWChrono_Attendance_Request__c", "create");
  }

  get isDateDisabled() {
    return !hasFieldPermission(
      "PWChrono_Attendance_Request__c",
      "Attendance_Date__c",
      "edit"
    );
  }
  get isCheckInDisabled() {
    return !hasFieldPermission(
      "PWChrono_Attendance_Request__c",
      "From_Time__c",
      "edit"
    );
  }
  get isCheckOutDisabled() {
    return !hasFieldPermission(
      "PWChrono_Attendance_Request__c",
      "To_Time__c",
      "edit"
    );
  }
  get isReasonDisabled() {
    return !hasFieldPermission(
      "PWChrono_Attendance_Request__c",
      "Reason__c",
      "edit"
    );
  }
  get isSubmitDisabled() {
    return !this.canCreateRequest || this.isProcessing;
  }

  @wire(getMyAttendanceRequests, {
    statusFilter: "All",
    startDate: null,
    endDate: null,
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredRequests(result) {
    this.wiredRequestsResult = result;
    this.isLoading = false;
    if (result.data) {
      this.allRequests = result.data.map((record) => ({
        ...record,
        ApproverName: record.Approver__r ? record.Approver__r.Name : ""
      }));
      this.currentPage = 1;
      this.applyPagination();
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error.body.message;
      this.requests = [];
      this.allRequests = [];
    }
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.requests = this.allRequests.slice(start, end);
  }

  get totalPages() {
    return Math.ceil(this.allRequests.length / this.pageSize) || 1;
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
      this.allRequests.length
    );
    return `${start}–${end} of ${this.allRequests.length}`;
  }

  get hasRequests() {
    return this.allRequests && this.allRequests.length > 0;
  }

  handlePageSizeChange(event) {
    this.pageSize = parseInt(event.detail.value, 10);
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

  handleDateChange(event) {
    this._attendanceDate = event.target.value;
  }

  handleCheckInChange(event) {
    this.checkInTime = event.target.value;
  }

  handleCheckOutChange(event) {
    this.checkOutTime = event.target.value;
  }

  handleReasonChange(event) {
    this.reason = event.target.value;
  }

  handleSubmit() {
    if (!this.validateFields()) {
      return;
    }

    this.isProcessing = true;
    const request = {
      sobjectType: "PWChrono_Attendance_Request__c",
      Attendance_Date__c: this._attendanceDate,
      From_Time__c: this.checkInTime,
      To_Time__c: this.checkOutTime,
      Reason__c: this.reason,
      Status__c: "Submitted"
    };

    saveAttendanceRequest({
      attendanceRequest: request,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          "Attendance request submitted successfully",
          "success"
        );
        this.dispatchEvent(new CustomEvent("success"));
        this.clearForm();
        return refreshApex(this.wiredRequestsResult);
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isProcessing = false;
      });
  }

  validateFields() {
    if (!this._attendanceDate || !this.reason) {
      this.showToast("Error", "Please fill in Date and Reason", "error");
      return false;
    }
    return true;
  }

  clearForm() {
    this._attendanceDate = null;
    this.checkInTime = null;
    this.checkOutTime = null;
    this.reason = null;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}