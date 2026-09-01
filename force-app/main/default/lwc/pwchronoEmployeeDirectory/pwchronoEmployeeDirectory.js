import deleteEmployee from "@salesforce/apex/PWChrono_EmployeeDirectoryController.deleteEmployee";
import getEmployeeDesignations from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployeeDesignations";
import getEmployeeDetail from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployeeDetail";
import getEmployeeDirectoryMetrics from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployeeDirectoryMetrics";
import getEmployees from "@salesforce/apex/PWChrono_EmployeeDirectoryController.getEmployees";
import saveEmployee from "@salesforce/apex/PWChrono_EmployeeDirectoryController.saveEmployee";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";
import {
  CARD_BG_BANNER,
  DEFAULT_USER_AVATAR,
  MANAGER_AVATAR
} from "./pwchronoEmployeeConstants";

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

  // Detail View: Accordion Collapsible Sections (Default collapsed as in Image 1)
  @track isAboutOpen = false;
  @track isBankOpen = false;
  @track isFamilyOpen = false;
  @track isEducationOpen = false;
  @track isExperienceOpen = false;

  // Modals Visibility
  @track isAddEditModalOpen = false;
  @track isDeleteModalOpen = false;
  @track isEmergencyModalOpen = false;
  @track isBasicInfoModalOpen = false;
  @track isPersonalModalOpen = false;
  @track isBankModalOpen = false;
  @track isFamilyModalOpen = false;
  @track isAboutModalOpen = false;
  @track isEducationModalOpen = false;
  @track isExperienceModalOpen = false;

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

  // Forms for Detail Page Modals
  @track emergencyForm = {
    primaryName: "",
    primaryRelationship: "",
    primaryPhone1: "",
    primaryPhone2: "",
    secondaryName: "",
    secondaryRelationship: "",
    secondaryPhone1: "",
    secondaryPhone2: ""
  };

  @track basicInfoForm = {
    Phone: "",
    Email: "",
    Gender: "Male",
    Birthdate: "",
    MailingStreet: ""
  };

  @track personalForm = {
    passportNo: "",
    passportExpDate: "",
    nationality: "",
    religion: "",
    maritalStatus: "",
    spouseEmployment: "",
    noOfChildren: ""
  };

  @track bankForm = {
    bankName: "",
    accountNo: "",
    ifscCode: "",
    branch: ""
  };

  @track familyForm = {
    name: "",
    relationship: "",
    phone: "",
    dateOfBirth: ""
  };

  @track aboutForm = {
    about: ""
  };

  // Tabs on Detail View
  @track activeDetailTab = "projects";

  connectedCallback() {
    this.loadDesignations();
    this.loadMetrics();
    this.loadEmployees();
  }

  // Getters for Assets & Styles
  get bannerBackgroundStyle() {
    return `background-image: url('${CARD_BG_BANNER}'); background-size: cover; background-position: top center;`;
  }

  get displayAvatarUrl() {
    return this.selectedEmployee?.avatarUrl || DEFAULT_USER_AVATAR;
  }

  get defaultAvatar() {
    return DEFAULT_USER_AVATAR;
  }

  get managerAvatarUrl() {
    return MANAGER_AVATAR;
  }

  // Chevron Classes
  get aboutChevronClass() {
    return this.isAboutOpen
      ? "ti ti-chevron-up fs-18 collapse-arrow"
      : "ti ti-chevron-down fs-18 collapse-arrow";
  }

  get bankChevronClass() {
    return this.isBankOpen
      ? "ti ti-chevron-up fs-18 collapse-arrow"
      : "ti ti-chevron-down fs-18 collapse-arrow";
  }

  get familyChevronClass() {
    return this.isFamilyOpen
      ? "ti ti-chevron-up fs-18 collapse-arrow"
      : "ti ti-chevron-down fs-18 collapse-arrow";
  }

  get educationChevronClass() {
    return this.isEducationOpen
      ? "ti ti-chevron-up fs-18 collapse-arrow"
      : "ti ti-chevron-down fs-18 collapse-arrow";
  }

  get experienceChevronClass() {
    return this.isExperienceOpen
      ? "ti ti-chevron-up fs-18 collapse-arrow"
      : "ti ti-chevron-down fs-18 collapse-arrow";
  }

  // View state getters
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
    if (!this.totalCount) return "0 - 0";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(this.currentPage * this.pageSize, this.totalCount);
    return `${start} - ${end}`;
  }

  get paginationPages() {
    const pages = [];
    for (let i = 1; i <= this.totalPages; i++) {
      pages.push({
        number: i,
        className:
          i === this.currentPage ? "page-item active" : "page-item"
      });
    }
    return pages;
  }

  // Toggle methods for Accordion Collapsible Sections
  toggleAbout(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    this.isAboutOpen = !this.isAboutOpen;
  }

  toggleBank(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    this.isBankOpen = !this.isBankOpen;
  }

  toggleFamily(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    this.isFamilyOpen = !this.isFamilyOpen;
  }

  toggleEducation(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    this.isEducationOpen = !this.isEducationOpen;
  }

  toggleExperience(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    this.isExperienceOpen = !this.isExperienceOpen;
  }

  // Helper to initialize structured mock fields
  initEmployeeExtraDetails(emp) {
    if (!emp) return emp;
    const lastName = emp.lastName || "Peralt";
    return {
      ...emp,
      emergencyContact: emp.emergencyContact || {
        primaryName: `Adrian ${lastName}`,
        primaryRelationship: "Father",
        primaryPhone1: "+1 127 2685 598",
        primaryPhone2: "",
        secondaryName: "Karen Wills",
        secondaryRelationship: "Mother",
        secondaryPhone1: "+1 989 7774 787",
        secondaryPhone2: ""
      },
      personalInfo: emp.personalInfo || {
        passportNo: "QRET4566FGRT",
        passportExpDate: "15 May 2029",
        nationality: "Indian",
        religion: "Christianity",
        maritalStatus: "Yes",
        spouseEmployment: "No",
        noOfChildren: "2"
      },
      bankInfo: emp.bankInfo || {
        bankName: "Swiz International Bank",
        accountNo: "159843014641",
        ifscCode: "ICI24504",
        branch: "New York, USA"
      },
      familyInfo: emp.familyInfo || {
        name: `Hendry ${lastName}`,
        relationship: "Brother",
        dateOfBirth: "25 May 2014",
        phone: "+1 265 6956 961"
      }
    };
  }

  // View Navigation
  switchToList() {
    this.currentView = "list";
  }

  switchToGrid() {
    this.currentView = "grid";
  }

  handleBackToList() {
    this.currentView = this.previousView || "list";
  }

  selectProjectsTab() {
    this.activeDetailTab = "projects";
  }

  selectAssetsTab() {
    this.activeDetailTab = "assets";
  }

  // Detail Navigation
  handleSelectEmployee(event) {
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

    this.previousView = this.currentView;
    const found = this.allEmployees.find((e) => e.id === empId);
    if (found) {
      this.selectedEmployee = this.initEmployeeExtraDetails(found);
      this.currentView = "detail";
      this.isAboutOpen = false;
      this.isBankOpen = false;
      this.isFamilyOpen = false;
      this.isEducationOpen = false;
      this.isExperienceOpen = false;
      window.scrollTo({ top: 0, behavior: "smooth" });
    } else {
      this.fetchEmployeeDetail(empId);
    }
  }

  async fetchEmployeeDetail(id) {
    this.isLoading = true;
    try {
      const detail = await getEmployeeDetail({ contactId: id });
      this.selectedEmployee = this.initEmployeeExtraDetails(detail);
      this.currentView = "detail";
      this.isAboutOpen = false;
      this.isBankOpen = false;
      this.isFamilyOpen = false;
      this.isEducationOpen = false;
      this.isExperienceOpen = false;
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      this.showToast("Error", "Could not load employee details", "error");
    } finally {
      this.isLoading = false;
    }
  }

  handleStopPropagation(event) {
    if (event && event.stopPropagation) {
      event.stopPropagation();
    }
  }

  handleImageError(event) {
    if (event && event.target) {
      event.target.src = DEFAULT_USER_AVATAR;
    }
  }

  // Data Loading
  async loadEmployees() {
    this.isLoading = true;
    try {
      const data = await getEmployees({
        searchTerm: this.searchTerm,
        designationFilter: this.selectedDesignation,
        statusFilter: this.selectedStatus,
        sortBy: this.sortBy
      });
      this.allEmployees = (data || []).map((emp) =>
        this.initEmployeeExtraDetails(emp)
      );
      this.currentPage = 1;
      this.applyPagination();
    } catch (err) {
      this.showToast(
        "Error",
        "Failed to load employees: " + (err?.body?.message || err.message),
        "error"
      );
      this.allEmployees = [];
      this.displayedEmployees = [];
    } finally {
      this.isLoading = false;
    }
  }

  async loadMetrics() {
    this.isMetricsLoading = true;
    try {
      const data = await getEmployeeDirectoryMetrics();
      if (data) {
        this.metrics = {
          total: data.total || 0,
          active: data.active || 0,
          inactive: data.inactive || 0,
          newJoiners: data.newJoiners || 0
        };
      }
    } catch (err) {
      console.error("Error loading metrics", err);
    } finally {
      this.isMetricsLoading = false;
    }
  }

  async loadDesignations() {
    try {
      const desigs = await getEmployeeDesignations();
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
    const page = parseInt(event.target.dataset.page, 10);
    if (page && page !== this.currentPage) {
      this.currentPage = page;
      this.applyPagination();
    }
  }

  handleSelectAll(event) {
    const isChecked = event.target.checked;
    this.selectAllChecked = isChecked;
    if (isChecked) {
      this.selectedEmployeeIds = new Set(
        this.displayedEmployees.map((e) => e.id)
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
      this.selectAllChecked = false;
    }
  }

  // -------------------------------------------------------------
  // Modals & Action Handlers
  // -------------------------------------------------------------

  // 1. Add / Edit Full Employee Modal
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

  handleOpenEditEmployeeModal(event) {
    const empId = event.target.closest("[data-id]")?.dataset?.id || this.selectedEmployee?.id;
    const emp = this.allEmployees.find((e) => e.id === empId) || this.selectedEmployee;
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
      const record = {
        FirstName: this.employeeForm.FirstName,
        LastName: this.employeeForm.LastName,
        Email: this.employeeForm.Email,
        Phone: this.employeeForm.Phone,
        Title: this.employeeForm.Title,
        Department: this.employeeForm.Department
      };
      if (this.employeeForm.Id) {
        record.Id = this.employeeForm.Id;
      }

      const saved = await saveEmployee({ contactRecord: record });
      this.showToast(
        "Success",
        `Employee ${this.employeeForm.Id ? "updated" : "created"} successfully`,
        "success"
      );
      this.isAddEditModalOpen = false;

      if (this.selectedEmployee && this.selectedEmployee.id === saved.Id) {
        this.selectedEmployee = {
          ...this.selectedEmployee,
          firstName: saved.FirstName,
          lastName: saved.LastName,
          name: `${saved.FirstName || ""} ${saved.LastName || ""}`.trim(),
          email: saved.Email,
          phone: saved.Phone,
          title: saved.Title,
          department: saved.Department
        };
      }

      await this.loadEmployees();
      await this.loadMetrics();
    } catch (err) {
      this.showToast(
        "Error",
        "Failed to save: " + (err?.body?.message || err.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  // 2. Emergency Contact Modal (Image 3)
  handleOpenEmergencyModal() {
    if (this.selectedEmployee && this.selectedEmployee.emergencyContact) {
      this.emergencyForm = { ...this.selectedEmployee.emergencyContact };
    } else {
      this.emergencyForm = {
        primaryName: `Adrian ${this.selectedEmployee?.lastName || "Peralt"}`,
        primaryRelationship: "Father",
        primaryPhone1: "+1 127 2685 598",
        primaryPhone2: "",
        secondaryName: "Karen Wills",
        secondaryRelationship: "Mother",
        secondaryPhone1: "+1 989 7774 787",
        secondaryPhone2: ""
      };
    }
    this.isEmergencyModalOpen = true;
  }

  handleCloseEmergencyModal() {
    this.isEmergencyModalOpen = false;
  }

  handleEmergencyFieldChange(event) {
    const field = event.target.name;
    this.emergencyForm[field] = event.target.value;
  }

  handleSaveEmergency(event) {
    event.preventDefault();
    if (this.selectedEmployee) {
      this.selectedEmployee = {
        ...this.selectedEmployee,
        emergencyContact: { ...this.emergencyForm }
      };
    }
    this.isEmergencyModalOpen = false;
    this.showToast(
      "Success",
      "Emergency contact details updated successfully",
      "success"
    );
  }

  // 3. Basic Information Modal
  handleOpenBasicInfoModal() {
    if (this.selectedEmployee) {
      this.basicInfoForm = {
        Phone: this.selectedEmployee.phone || "",
        Email: this.selectedEmployee.email || "",
        Gender: this.selectedEmployee.gender || "Male",
        Birthdate: this.selectedEmployee.birthDateFormatted || "24th July 2000",
        MailingStreet: this.selectedEmployee.address || "1861 Bayonne Ave, Manchester, NJ"
      };
    }
    this.isBasicInfoModalOpen = true;
  }

  handleCloseBasicInfoModal() {
    this.isBasicInfoModalOpen = false;
  }

  handleBasicInfoFieldChange(event) {
    const field = event.target.name;
    this.basicInfoForm[field] = event.target.value;
  }

  async handleSaveBasicInfo(event) {
    event.preventDefault();
    this.isLoading = true;
    try {
      const contactRecord = {
        Id: this.selectedEmployee.id,
        Phone: this.basicInfoForm.Phone,
        Email: this.basicInfoForm.Email,
        MailingStreet: this.basicInfoForm.MailingStreet
      };
      await saveEmployee({ contactRecord });

      this.selectedEmployee = {
        ...this.selectedEmployee,
        phone: this.basicInfoForm.Phone,
        email: this.basicInfoForm.Email,
        gender: this.basicInfoForm.Gender,
        birthDateFormatted: this.basicInfoForm.Birthdate,
        address: this.basicInfoForm.MailingStreet
      };
      this.isBasicInfoModalOpen = false;
      this.showToast(
        "Success",
        "Basic information updated successfully",
        "success"
      );
    } catch (err) {
      this.showToast("Error", err?.body?.message || err.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  // 4. Personal Information Modal
  handleOpenPersonalModal() {
    if (this.selectedEmployee && this.selectedEmployee.personalInfo) {
      this.personalForm = { ...this.selectedEmployee.personalInfo };
    }
    this.isPersonalModalOpen = true;
  }

  handleClosePersonalModal() {
    this.isPersonalModalOpen = false;
  }

  handlePersonalFieldChange(event) {
    const field = event.target.name;
    this.personalForm[field] = event.target.value;
  }

  handleSavePersonal(event) {
    event.preventDefault();
    if (this.selectedEmployee) {
      this.selectedEmployee = {
        ...this.selectedEmployee,
        personalInfo: { ...this.personalForm }
      };
    }
    this.isPersonalModalOpen = false;
    this.showToast(
      "Success",
      "Personal information updated successfully",
      "success"
    );
  }

  // 5. Bank Information Modal
  handleOpenBankModal() {
    if (this.selectedEmployee && this.selectedEmployee.bankInfo) {
      this.bankForm = { ...this.selectedEmployee.bankInfo };
    }
    this.isBankModalOpen = true;
  }

  handleCloseBankModal() {
    this.isBankModalOpen = false;
  }

  handleBankFieldChange(event) {
    const field = event.target.name;
    this.bankForm[field] = event.target.value;
  }

  handleSaveBank(event) {
    event.preventDefault();
    if (this.selectedEmployee) {
      this.selectedEmployee = {
        ...this.selectedEmployee,
        bankInfo: { ...this.bankForm }
      };
    }
    this.isBankModalOpen = false;
    this.showToast(
      "Success",
      "Bank details updated successfully",
      "success"
    );
  }

  // 6. Family Information Modal
  handleOpenFamilyModal() {
    if (this.selectedEmployee && this.selectedEmployee.familyInfo) {
      this.familyForm = { ...this.selectedEmployee.familyInfo };
    }
    this.isFamilyModalOpen = true;
  }

  handleCloseFamilyModal() {
    this.isFamilyModalOpen = false;
  }

  handleFamilyFieldChange(event) {
    const field = event.target.name;
    this.familyForm[field] = event.target.value;
  }

  handleSaveFamily(event) {
    event.preventDefault();
    if (this.selectedEmployee) {
      this.selectedEmployee = {
        ...this.selectedEmployee,
        familyInfo: { ...this.familyForm }
      };
    }
    this.isFamilyModalOpen = false;
    this.showToast(
      "Success",
      "Family information updated successfully",
      "success"
    );
  }

  // 7. About Modal
  handleOpenAboutModal() {
    if (this.selectedEmployee) {
      this.aboutForm = {
        about: this.selectedEmployee.about || ""
      };
    }
    this.isAboutModalOpen = true;
  }

  handleCloseAboutModal() {
    this.isAboutModalOpen = false;
  }

  handleAboutFieldChange(event) {
    this.aboutForm.about = event.target.value;
  }

  async handleSaveAbout(event) {
    event.preventDefault();
    this.isLoading = true;
    try {
      const contactRecord = {
        Id: this.selectedEmployee.id,
        Description: this.aboutForm.about
      };
      await saveEmployee({ contactRecord });

      this.selectedEmployee = {
        ...this.selectedEmployee,
        about: this.aboutForm.about
      };
      this.isAboutModalOpen = false;
      this.showToast(
        "Success",
        "About employee updated successfully",
        "success"
      );
    } catch (err) {
      this.showToast("Error", err?.body?.message || err.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  // 8. Delete Employee Modal
  handleOpenDeleteModal(event) {
    const empId = event.target.closest("[data-id]")?.dataset?.id;
    const emp = this.allEmployees.find((e) => e.id === empId);
    if (emp) {
      this.employeeToDelete = emp;
      this.isDeleteModalOpen = true;
    }
  }

  handleCloseDeleteModal() {
    this.isDeleteModalOpen = false;
    this.employeeToDelete = null;
  }

  async handleConfirmDelete() {
    if (!this.employeeToDelete) return;
    this.isLoading = true;
    try {
      await deleteEmployee({ contactId: this.employeeToDelete.id });
      this.showToast("Success", "Employee deleted successfully", "success");
      this.isDeleteModalOpen = false;
      this.employeeToDelete = null;

      if (
        this.selectedEmployee &&
        this.selectedEmployee.id === this.employeeToDelete?.id
      ) {
        this.selectedEmployee = null;
        this.currentView = "list";
      }

      await this.loadEmployees();
      await this.loadMetrics();
    } catch (err) {
      this.showToast(
        "Error",
        "Failed to delete: " + (err?.body?.message || err.message),
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  // Utility toast
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  handleCopyEmail() {
    if (this.selectedEmployee && this.selectedEmployee.email) {
      navigator.clipboard.writeText(this.selectedEmployee.email);
      this.showToast("Copied", "Email copied to clipboard", "success");
    }
  }
}