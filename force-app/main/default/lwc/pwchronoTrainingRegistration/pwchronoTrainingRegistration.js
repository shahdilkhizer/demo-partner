import { refreshApex } from "@salesforce/apex";
import cancelRegistration from "@salesforce/apex/PWChrono_TrainingController.cancelRegistration";
import getMyRegistrations from "@salesforce/apex/PWChrono_TrainingController.getMyRegistrations";
import getUpcomingTrainings from "@salesforce/apex/PWChrono_TrainingController.getUpcomingTrainings";
import registerForTraining from "@salesforce/apex/PWChrono_TrainingController.registerForTraining";
import LightningConfirm from "lightning/confirm";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

const COLUMNS = [
  { label: "Program", fieldName: "ProgramName", sortable: true },
  { label: "Start Date", fieldName: "StartDate", type: "date", sortable: true },
  { label: "Location", fieldName: "Location" },
  { label: "Attended", fieldName: "Attended__c", type: "boolean" },
  {
    type: "button",
    typeAttributes: {
      label: "Cancel",
      name: "cancel",
      title: "Cancel Registration",
      variant: "destructive-text",
      disabled: { fieldName: "isPast" }
    }
  }
];

export default class PwchronoTrainingRegistration extends LightningElement {
  @track upcomingTrainings;
  @track allRegistrations = [];
  @track myRegistrations = [];
  @track isLoading = true;
  @track isRegistrationsLoading = true;
  columns = COLUMNS;

  // Pagination for registrations
  @track currentPage = 1;
  @track pageSize = 10;
  @track searchFilter = "";

  wiredUpcomingResult;
  wiredRegistrationsResult;

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" }
  ];

  @wire(getUpcomingTrainings)
  wiredUpcoming(result) {
    this.wiredUpcomingResult = result;
    if (result.data) {
      this.upcomingTrainings = result.data;
    } else if (result.error) {
      this.showToast(
        "Error",
        result.error.body?.message || "Failed to load trainings",
        "error"
      );
    }
    this.isLoading = false;
  }

  @wire(getMyRegistrations)
  wiredRegistrations(result) {
    this.wiredRegistrationsResult = result;
    if (result.data) {
      this.allRegistrations = result.data.map((row) => ({
        ...row,
        ProgramName:
          row.Training_Event__r?.Training_Program__r?.Name || "Unknown",
        StartDate: row.Training_Event__r?.Start_Date__c,
        Location: row.Training_Event__r?.Location__c || "TBD",
        isPast: new Date(row.Training_Event__r?.Start_Date__c) < new Date()
      }));
      this.applyFilters();
    } else if (result.error) {
      this.showToast(
        "Error",
        result.error.body?.message || "Failed to load registrations",
        "error"
      );
    }
    this.isRegistrationsLoading = false;
  }

  // Filter and Pagination
  applyFilters() {
    let filtered = [...this.allRegistrations];

    if (this.searchFilter) {
      const search = this.searchFilter.toLowerCase();
      filtered = filtered.filter(
        (item) =>
          item.ProgramName.toLowerCase().includes(search) ||
          item.Location?.toLowerCase().includes(search)
      );
    }

    this._filteredRegistrations = filtered;

    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.myRegistrations = filtered.slice(start, end);
  }

  handleSearchFilter(event) {
    this.searchFilter = event.target.value;
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.applyFilters();
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.applyFilters();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.applyFilters();
    }
  }

  get totalRecords() {
    return this._filteredRegistrations ? this._filteredRegistrations.length : 0;
  }

  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize) || 1;
  }

  get paginationInfo() {
    if (this.totalRecords === 0) return "0 records";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
    return `${start}-${end} of ${this.totalRecords}`;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  handleRegister(event) {
    const eventId = event.target.dataset.id;
    registerForTraining({ eventId })
      .then(() => {
        this.showToast("Success", "Registered successfully", "success");
        return Promise.all([
          refreshApex(this.wiredUpcomingResult),
          refreshApex(this.wiredRegistrationsResult)
        ]);
      })
      .catch((error) => {
        this.showToast("Error registering", error.body.message, "error");
      });
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === "cancel") {
      LightningConfirm.open({
        message: "Are you sure you want to cancel this registration?",
        variant: "header",
        label: "Cancel Registration"
      }).then((result) => {
        if (result) {
          cancelRegistration({ attendanceId: row.Id })
            .then(() => {
              this.showToast("Success", "Registration cancelled", "success");
              return Promise.all([
                refreshApex(this.wiredUpcomingResult),
                refreshApex(this.wiredRegistrationsResult)
              ]);
            })
            .catch((error) => {
              this.showToast("Error cancelling", error.body.message, "error");
            });
        }
      });
    }
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

  get hasUpcomingTrainings() {
    return this.upcomingTrainings && this.upcomingTrainings.length > 0;
  }

  get hasMyRegistrations() {
    return this.myRegistrations && this.myRegistrations.length > 0;
  }
}