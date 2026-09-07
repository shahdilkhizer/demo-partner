import deleteEmployee from "@salesforce/apex/PWChrono_EmployeeDirectoryController.deleteEmployee";
import getEmployeeDesignations from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployeeDesignations";
import getEmployeeDetail from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployeeDetail";
import getEmployeeDirectoryMetrics from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployeeDirectoryMetrics";
import getEmployees from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployees";
import saveEmployee from "@salesforce/apex/PWChrono_EmployeeDirectoryController.saveEmployee";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { downloadCsv } from "c/pwchronoCsv";
import { LightningElement, track } from "lwc";

export default class PwchronoEmployeeDirectory extends LightningElement {
  static renderMode = "light";

  // View state: 'list', 'grid', 'detail'
  @track currentView = "list";
  @track previousView = "list";

  @track allEmployees = [];
  @track displayedEmployees = [];
  @track selectedEmployee = null;

  @track isLoading = true;
  @track isMetricsLoading = true;
  loadError = "";
  metricsError = "";
  _employeeRequest = 0;

  get showEmptyEmployees() {
    return (
      !this.isLoading && !this.loadError && !this.displayedEmployees.length
    );
  }

  handleRetryDirectory() {
    this.loadEmployees();
    this.loadMetrics();
    this.loadDesignations();
  }

  // Filter & Search states
  @track searchTerm = "";
  @track selectedDesignation = "All";
  @track selectedStatus = "All";
  @track sortBy = "Last 7 Days";

  // Options
  @track designationOptions = [{ label: "All Designations", value: "All" }];
  statusOptions = [
    { label: "All Status", value: "All" },
    { label: "Active", value: "Active" },
    { label: "Inactive", value: "Inactive" }
  ];
  sortOptions = [
    { label: "Last 7 Days", value: "Last 7 Days" },
    { label: "Recently Added", value: "Recently Added" },
    { label: "Ascending", value: "Ascending" },
    { label: "Descending", value: "Descending" }
  ];

  // Metrics
  @track metrics = {
    total: 0,
    active: 0,
    inactive: 0,
    newJoiners: 0
  };

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;
  pageSizeOptions = [
    { label: "10", value: 10 },
    { label: "25", value: 25 },
    { label: "50", value: 50 },
    { label: "100", value: 100 }
  ];

  // Selection
  @track selectAllChecked = false;
  @track selectedEmployeeIds = new Set();

  // Modals
  @track isAddEditModalOpen = false;
  @track isDeleteModalOpen = false;
  @track modalTitle = "Add Employee";
  @track employeeForm = {
    Id: null,
    FirstName: "",
    LastName: "",
    Email: "",
    Phone: "",
    Title: "",
    Department: ""
  };
  @track employeeToDelete = null;
  callerPortalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  // Tabs on Detail View
  @track activeDetailTab = "projects";

  connectedCallback() {
    this.callerPortalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.loadDesignations();
    this.loadMetrics();
    this.loadEmployees();
  }

  // Getters for view state
  get headerTitle() {
    return this.isGridView ? "Employees Grid" : "Employees List";
  }

  get isListView() {
    return this.currentView === "list";
  }

  get isGridView() {
    return this.currentView === "grid";
  }

  get isDetailView() {
    return this.currentView === "detail";
  }

  get listBtnClass() {
    return this.isListView
      ? "btn btn-icon btn-sm active bg-primary text-white me-1"
      : "btn btn-icon btn-sm me-1";
  }

  get gridBtnClass() {
    return this.isGridView
      ? "btn btn-icon btn-sm active bg-primary text-white"
      : "btn btn-icon btn-sm";
  }

  get isProjectsTabActive() {
    return this.activeDetailTab === "projects";
  }

  get isAssetsTabActive() {
    return this.activeDetailTab === "assets";
  }

  get totalCount() {
    return this.allEmployees.length;
  }

  get totalPages() {
    return Math.ceil(this.allEmployees.length / this.pageSize) || 1;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get pageInfo() {
    if (this.allEmployees.length === 0) return "0";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(
      this.currentPage * this.pageSize,
      this.allEmployees.length
    );
    return `${start} - ${end}`;
  }

  get paginationPages() {
    const pages = [];
    const max = Math.min(this.totalPages, 5);
    for (let i = 1; i <= max; i++) {
      pages.push({
        number: i,
        className: i === this.currentPage ? "page-item active" : "page-item"
      });
    }
    return pages;
  }

  // View Switching
  handleExport() {
    downloadCsv(
      "employees.csv",
      ["Employee ID", "Name", "Email", "Phone", "Designation", "Department"],
      this.allEmployees.map((e) => [
        e.empId,
        e.name,
        e.email,
        e.phone,
        e.title,
        e.department
      ])
    );
  }

  renderedCallback() {
    this.querySelectorAll("select[data-filter]").forEach((select) => {
      const value = String(this[select.dataset.filter]);
      if (select.value !== value) select.value = value;
    });
  }

  disconnectedCallback() {
    clearTimeout(this.searchTimeout);
  }

  switchToList() {
    this.previousView = "list";
    this.currentView = "list";
  }

  switchToGrid() {
    this.previousView = "grid";
    this.currentView = "grid";
  }

  handleBackToList() {
    this.currentView = this.previousView || "list";
  }

  // Detail Navigation
  handleSelectEmployee(event) {
    // If clicked on action elements (dropdown, modal trigger, checkbox), don't navigate
    if (
      event.target.closest(".dropdown") ||
      event.target.closest(".form-check") ||
      event.target.closest(".action-icon") ||
      event.target.tagName === "INPUT"
    ) {
      return;
    }

    const targetWithId =
      event.target.closest("[data-id]") || event.currentTarget;
    const empId = targetWithId?.dataset?.id;
    if (!empId) return;

    this.fetchEmployeeDetail(empId);
  }

  async fetchEmployeeDetail(id) {
    this.isLoading = true;
    try {
      const detail = await getEmployeeDetail({
        contactId: id,
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      this.selectedEmployee = {
        ...detail,
        avatarUrl: detail?.avatarUrl || this.DEFAULT_AVATAR
      };
      this.currentView = "detail";
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch {
      this.showToast("Error", "Could not load employee details", "error");
    } finally {
      this.isLoading = false;
    }
  }

  DEFAULT_AVATAR = `${smarthrAssets}/assets/img/users/user-32.jpg`;

  handleStopPropagation(event) {
    if (event && event.stopPropagation) {
      event.stopPropagation();
    }
  }

  handleImageError(event) {
    if (event && event.target) {
      event.target.src = this.DEFAULT_AVATAR;
    }
  }

  // Data Loading
  async loadEmployees() {
    const request = ++this._employeeRequest;
    this.isLoading = true;
    this.loadError = "";
    try {
      const data = await getEmployees({
        searchTerm: this.searchTerm,
        designationFilter: this.selectedDesignation,
        statusFilter: this.selectedStatus,
        sortBy: this.sortBy,
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      if (request !== this._employeeRequest) return;
      this.allEmployees = (data || []).map((employee) => ({
        ...employee,
        avatarUrl: employee.avatarUrl || this.DEFAULT_AVATAR
      }));
      this.currentPage = 1;
      this.applyPagination();
    } catch (err) {
      if (request !== this._employeeRequest) return;
      this.loadError =
        "Unable to load employees. Retry, or sign in again if your session has expired.";
      this.showToast(
        "Error",
        "Failed to load employees: " + (err?.body?.message || err.message),
        "error"
      );
      this.allEmployees = [];
      this.displayedEmployees = [];
    } finally {
      if (request === this._employeeRequest) this.isLoading = false;
    }
  }

  async loadMetrics() {
    this.isMetricsLoading = true;
    this.metricsError = "";
    try {
      const data = await getEmployeeDirectoryMetrics({
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      if (data) {
        this.metrics = {
          total: data.total || 0,
          active: data.active || 0,
          inactive: data.inactive || 0,
          newJoiners: data.newJoiners || 0
        };
      }
    } catch (err) {
      this.metricsError = "Employee summary is unavailable.";
      this.metrics = {
        total: "—",
        active: "—",
        inactive: "—",
        newJoiners: "—"
      };
      console.error("Error loading metrics", err);
    } finally {
      this.isMetricsLoading = false;
    }
  }

  async loadDesignations() {
    try {
      const desigs = await getEmployeeDesignations({
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      if (desigs) {
        this.designationOptions = [
          { label: "All Designations", value: "All" },
          ...desigs.map((d) => ({ label: d, value: d }))
        ];
      }
    } catch (err) {
      console.error("Error loading designations", err);
    }
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.displayedEmployees = this.allEmployees.slice(start, end);
  }

  // Filter Handlers
  handleSearch(event) {
    this.searchTerm = event.target.value;
    this.debounceSearch();
  }

  searchTimeout;
  debounceSearch() {
    clearTimeout(this.searchTimeout);
    // Deliberately debounce server-backed directory searches.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.searchTimeout = setTimeout(() => {
      this.loadEmployees();
    }, 300);
  }

  handleDesignationChange(event) {
    this.selectedDesignation = event.target.value;
    this.loadEmployees();
  }

  handleStatusChange(event) {
    this.selectedStatus = event.target.value;
    this.loadEmployees();
  }

  handleSortChange(event) {
    this.sortBy = event.target.value;
    this.loadEmployees();
  }

  handlePageSizeChange(event) {
    this.pageSize = parseInt(event.target.value, 10);
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

  handleGoToPage(event) {
    const page = parseInt(event.currentTarget.dataset.page, 10);
    if (page && page !== this.currentPage) {
      this.currentPage = page;
      this.applyPagination();
    }
  }

  // Select all checkboxes
  handleSelectAll(event) {
    this.selectAllChecked = event.target.checked;
    if (this.selectAllChecked) {
      this.displayedEmployees.forEach((e) =>
        this.selectedEmployeeIds.add(e.id)
      );
    } else {
      this.selectedEmployeeIds.clear();
    }
  }

  handleSelectRow(event) {
    const id = event.target.dataset.id;
    if (event.target.checked) {
      this.selectedEmployeeIds.add(id);
    } else {
      this.selectedEmployeeIds.delete(id);
    }
    this.selectAllChecked =
      this.displayedEmployees.length > 0 &&
      this.displayedEmployees.every((e) => this.selectedEmployeeIds.has(e.id));
  }

  // Detail tab switching
  selectProjectsTab() {
    this.activeDetailTab = "projects";
  }

  selectAssetsTab() {
    this.activeDetailTab = "assets";
  }

  // Add / Edit Employee
  handleOpenAddModal() {
    this.modalTitle = "Add Employee";
    this.employeeForm = {
      Id: null,
      FirstName: "",
      LastName: "",
      Email: "",
      Phone: "",
      Title: "",
      Department: ""
    };
    this.isAddEditModalOpen = true;
  }

  handleOpenEditModal(event) {
    event.stopPropagation();
    const empId = event.currentTarget.dataset.id;
    const emp = this.allEmployees.find((e) => e.id === empId);
    if (emp) {
      this.modalTitle = "Edit Employee";
      this.employeeForm = {
        Id: emp.id,
        FirstName: emp.firstName,
        LastName: emp.lastName,
        Email: emp.email,
        Phone: emp.phone,
        Title: emp.title,
        Department: emp.department
      };
      this.isAddEditModalOpen = true;
    }
  }

  handleCloseAddEditModal() {
    this.isAddEditModalOpen = false;
  }

  handleFormFieldChange(event) {
    const field = event.target.name;
    this.employeeForm[field] = event.target.value;
  }

  async handleSaveEmployee() {
    if (!this.employeeForm.LastName) {
      this.showToast("Validation Error", "Last Name is required", "error");
      return;
    }

    this.isLoading = true;
    try {
      const contactObj = {
        sobjectType: "Contact",
        Id: this.employeeForm.Id || undefined,
        FirstName: this.employeeForm.FirstName,
        LastName: this.employeeForm.LastName,
        Email: this.employeeForm.Email,
        Phone: this.employeeForm.Phone,
        Title: this.employeeForm.Title,
        Department: this.employeeForm.Department
      };

      await saveEmployee({
        contactRecord: contactObj,
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      this.showToast(
        "Success",
        this.employeeForm.Id
          ? "Employee updated successfully!"
          : "Employee added successfully!",
        "success"
      );
      this.isAddEditModalOpen = false;
      await this.loadEmployees();
      await this.loadMetrics();
    } catch (err) {
      this.showToast(
        "Error",
        "Error saving employee: " + (err?.body?.message || err.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  // Delete Modal
  handleOpenDeleteModal(event) {
    event.stopPropagation();
    const empId = event.currentTarget.dataset.id;
    this.employeeToDelete = this.allEmployees.find((e) => e.id === empId);
    this.isDeleteModalOpen = true;
  }

  handleCloseDeleteModal() {
    this.isDeleteModalOpen = false;
    this.employeeToDelete = null;
  }

  async handleConfirmDelete() {
    if (!this.employeeToDelete) return;
    this.isLoading = true;
    try {
      await deleteEmployee({
        contactId: this.employeeToDelete.id,
        callerPortalUserId: this.callerPortalUserId,
        sessionToken: this.sessionToken
      });
      this.showToast("Success", "Employee deleted successfully.", "success");
      this.isDeleteModalOpen = false;
      this.employeeToDelete = null;
      if (this.currentView === "detail") {
        this.currentView = "list";
      }
      await this.loadEmployees();
      await this.loadMetrics();
    } catch (err) {
      this.showToast(
        "Error",
        "Error deleting employee: " + (err?.body?.message || err.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  // Copy email helper
  handleCopyEmail(event) {
    event.preventDefault();
    if (this.selectedEmployee?.email) {
      navigator.clipboard.writeText(this.selectedEmployee.email);
      this.showToast("Copied", "Email copied to clipboard", "success");
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
}