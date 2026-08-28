import checkRecordAccess from "@salesforce/apex/PWChrono_EmployeeDirectoryController.checkRecordAccess";
import searchEmployees from "@salesforce/apex/PWChrono_EmployeeDirectoryController.searchEmployees";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoEmployeeDirectory extends NavigationMixin(
  LightningElement
) {
  @track searchTerm = "";
  @track allEmployees = [];
  @track employees = [];
  @track isLoading = true;
  @track loadError = null;

  // Pagination
  @track currentPage = 1;
  @track pageSize = 12;

  get pageSizeOptions() {
    return [
      { label: "8 per page", value: "8" },
      { label: "12 per page", value: "12" },
      { label: "24 per page", value: "24" },
      { label: "48 per page", value: "48" }
    ];
  }

  @wire(searchEmployees, { searchTerm: "$searchTerm" })
  wiredEmployees({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.allEmployees = data.map((emp) => ({
        ...emp,
        initials: this.getInitials(emp.Name),
        managerName: emp.Reports_To__r ? emp.Reports_To__r.Name : ""
      }));
      this.currentPage = 1;
      this.applyPagination();
      this.loadError = null;
    } else if (error) {
      this.loadError = error?.body?.message || "Failed to load employees";
      this.showErrorToast("Error loading employees: " + this.loadError);
      this.employees = [];
      this.allEmployees = [];
    }
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.employees = this.allEmployees.slice(start, end);
  }

  get totalPages() {
    return Math.ceil(this.allEmployees.length / this.pageSize) || 1;
  }

  get totalCount() {
    return this.allEmployees.length;
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
      this.allEmployees.length
    );
    return `${start}–${end} of ${this.allEmployees.length}`;
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

  handleSearch(event) {
    this.isLoading = true;
    this.searchTerm = event.target.value;
  }

  async handleNavigate(event) {
    const recordId = event.currentTarget.dataset.id;

    try {
      // Check if user has read access to the Portal_Users record
      const hasAccess = await checkRecordAccess({ recordId: recordId });

      if (hasAccess) {
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: recordId,
            objectApiName: "Portal_Users__c",
            actionName: "view"
          }
        });
      } else {
        this.showErrorToast(
          "You do not have permission to view this employee record"
        );
      }
    } catch (error) {
      this.showErrorToast(
        "Error checking access: " +
          (error?.body?.message || error?.message || "Unknown error")
      );
    }
  }

  getInitials(name) {
    if (!name) return "";
    const parts = name.split(" ");
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
    return (
      parts[0].charAt(0) + parts[parts.length - 1].charAt(0)
    ).toUpperCase();
  }

  showErrorToast(message) {
    const evt = new ShowToastEvent({
      title: "Error",
      message: message,
      variant: "error",
      mode: "dismissable"
    });
    this.dispatchEvent(evt);
  }
}