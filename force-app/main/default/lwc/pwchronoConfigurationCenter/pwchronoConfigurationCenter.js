import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import getAllUsersWithAccess from "@salesforce/apex/PWChrono_ConfigurationController.getAllUsersWithAccess";
import getAvailableFeatures from "@salesforce/apex/PWChrono_ConfigurationController.getAvailableFeatures";
import saveUserFeatureAccess from "@salesforce/apex/PWChrono_ConfigurationController.saveUserFeatureAccess";
import getGlobalFeatureSettings from "@salesforce/apex/PWChrono_ConfigurationController.getGlobalFeatureSettings";
import saveGlobalFeatureSettings from "@salesforce/apex/PWChrono_ConfigurationController.saveGlobalFeatureSettings";

export default class PwchronoConfigurationCenter extends NavigationMixin(
  LightningElement
) {
  @track users = [];
  @track filteredUsers = [];
  @track paginatedUsers = [];
  @track searchTerm = "";
  @track showUserFeatureModal = false;
  @track showNewUserModal = false;
  @track selectedUser = null;
  @track features = [];
  @track globalSettings = {};
  @track isSaving = false;
  @track isLoading = true;
  @track activeTab = "users";
  wiredUsersResult;
  baseFeatures = [];

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" },
    { label: "50", value: "50" }
  ];

  // Feature icon mapping
  featureIcons = {
    Dashboard: "standard:dashboard",
    "Leave Management": "standard:event",
    "Attendance Management": "standard:timesheet",
    "Employee Directory": "standard:people",
    "Expense Management": "standard:service_contract",
    Payroll: "standard:currency",
    "Performance Management": "standard:goals",
    "Training Management": "standard:education",
    Recruitment: "standard:lead",
    Onboarding: "standard:task",
    "Manager Dashboard": "standard:employee",
    "Admin Settings": "standard:settings",
    Appraisal: "standard:performance",
    Approvals: "standard:approval",
    "Company Policies": "standard:article",
    Goals: "standard:metrics",
    Holidays: "standard:date_input",
    "My Profile": "standard:user",
    "Tax Declaration": "standard:investment_account"
  };

  userColumns = [
    { label: "Name", fieldName: "userName", type: "text", sortable: true },
    { label: "Email", fieldName: "userEmail", type: "email", sortable: true },
    { label: "Role", fieldName: "profileName", type: "text", sortable: true },
    {
      label: "Active Features",
      fieldName: "activeFeatureCount",
      type: "number",
      cellAttributes: { alignment: "center" }
    },
    {
      type: "action",
      typeAttributes: {
        rowActions: [
          { label: "Manage Access", name: "manage_access" },
          { label: "View Record", name: "view_record" }
        ]
      }
    }
  ];

  @wire(getAllUsersWithAccess)
  wiredUsers(result) {
    this.wiredUsersResult = result;
    this.isLoading = true;
    const { error, data } = result;
    if (data) {
      this.users = data.map((user) => ({
        ...user,
        activeFeatureCount: user.featureAccess
          ? user.featureAccess.filter((f) => f.isActive).length
          : 0,
        profileName: user.profileName || "N/A"
      }));
      this.filterUsers();
    } else if (error) {
      this.showToast(
        "Error",
        error.body?.message || "Failed to load users",
        "error"
      );
    }
    this.isLoading = false;
  }

  @wire(getAvailableFeatures)
  wiredFeatures({ error, data }) {
    if (data) {
      // Store base feature list and check for empty
      this.baseFeatures = data;
      if (!data || data.length === 0) {
        this.showToast(
          "Warning",
          "No features are available. Please contact your administrator.",
          "warning"
        );
      }
    } else if (error) {
      const errorMsg =
        error?.body?.message || error?.message || "Failed to load features";
      this.showToast("Error", "Failed to load features: " + errorMsg, "error");
    }
  }

  @wire(getGlobalFeatureSettings)
  wiredGlobalSettings({ error, data }) {
    if (data) {
      this.globalSettings = { ...data };
    } else if (error) {
      this.showToast("Error", error.body.message, "error");
    }
  }

  handleUserSearch(event) {
    this.searchTerm = event.target.value.toLowerCase();
    this.currentPage = 1;
    this.filterUsers();
  }

  filterUsers() {
    if (this.searchTerm) {
      this.filteredUsers = this.users.filter(
        (user) =>
          (user.userName &&
            user.userName.toLowerCase().includes(this.searchTerm)) ||
          (user.userEmail &&
            user.userEmail.toLowerCase().includes(this.searchTerm))
      );
    } else {
      this.filteredUsers = [...this.users];
    }
    this.applyPagination();
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.paginatedUsers = this.filteredUsers.slice(start, end);
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

  get totalRecords() {
    return this.filteredUsers ? this.filteredUsers.length : 0;
  }

  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize) || 1;
  }

  get paginationInfo() {
    if (this.totalRecords === 0) return "0 users";
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

  get hasUsers() {
    return this.paginatedUsers && this.paginatedUsers.length > 0;
  }

  handleNewUser() {
    this.showNewUserModal = true;
  }

  handleCloseNewUserModal() {
    this.showNewUserModal = false;
  }

  handleUserSaved() {
    this.showNewUserModal = false;
    return refreshApex(this.wiredUsersResult);
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === "manage_access") {
      this.openManageAccessModal(row);
    } else if (actionName === "view_record") {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: row.userId,
          objectApiName: "Portal_Users__c",
          actionName: "view"
        }
      });
    }
  }

  openManageAccessModal(user) {
    this.selectedUser = { ...user };

    // Map existing user access
    const userAccessMap = new Map();
    if (user.featureAccess) {
      user.featureAccess.forEach((f) => {
        userAccessMap.set(f.featureName, f);
      });
    }

    // Build features list for the modal
    this.features = this.baseFeatures.map((featureName) => {
      const existing = userAccessMap.get(featureName);
      return {
        name: featureName,
        description: this.getFeatureDescription(featureName),
        iconName: this.featureIcons[featureName] || "standard:default",
        iconVariant: existing && existing.isActive ? "success" : "warning",
        hasAccess: existing ? existing.isActive : false,
        accessLevel: existing ? existing.accessLevel : "No Access",
        featureAccessId: existing ? existing.featureAccessId : null
      };
    });

    this.showUserFeatureModal = true;
  }

  closeModal() {
    this.showUserFeatureModal = false;
    this.selectedUser = null;
  }

  handleFeatureToggle(event) {
    const featureName = event.target.dataset.name;
    const isChecked = event.target.checked;

    this.features = this.features.map((f) => {
      if (f.name === featureName) {
        return {
          ...f,
          hasAccess: isChecked,
          iconVariant: isChecked ? "success" : "warning",
          accessLevel: isChecked ? "Full Access" : "No Access" // Default to Full Access when toggled on
        };
      }
      return f;
    });
  }

  handleSelectAllFeatures() {
    this.features = this.features.map((f) => ({
      ...f,
      hasAccess: true,
      iconVariant: "success",
      accessLevel: "Full Access"
    }));
  }

  handleDeselectAllFeatures() {
    this.features = this.features.map((f) => ({
      ...f,
      hasAccess: false,
      iconVariant: "warning",
      accessLevel: "No Access"
    }));
  }

  handleSaveUserFeatures() {
    this.isSaving = true;

    const featuresToSave = this.features.map((f) => ({
      featureAccessId: f.featureAccessId,
      featureName: f.name,
      accessLevel: f.hasAccess ? "Full Access" : "No Access",
      isActive: f.hasAccess
    }));

    saveUserFeatureAccess({
      portalUserId: this.selectedUser.userId,
      features: featuresToSave
    })
      .then(() => {
        this.showToast(
          "Success",
          "User permissions updated successfully",
          "success"
        );
        this.closeModal();
        return refreshApex(this.wiredUsersResult);
      })
      .catch((error) => {
        const errorMsg =
          error.body?.message || error.message || "Unknown error";
        this.showToast("Error", errorMsg, "error");
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  handleGlobalSettingChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.checked;
    this.globalSettings = { ...this.globalSettings, [field]: value };
  }

  handleSaveGlobalSettings() {
    this.isSaving = true;
    saveGlobalFeatureSettings({ settings: this.globalSettings })
      .then(() => {
        this.showToast("Success", "Global settings saved", "success");
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  getFeatureDescription(featureName) {
    const descriptions = {
      Dashboard: "Personalized dashboard with quick stats",
      "Leave Management": "Apply and track leave requests",
      "Attendance Management": "Mark attendance and view history",
      "Employee Directory": "Browse employee directory",
      "Expense Management": "Submit and track expenses",
      Payroll: "View salary slips and tax info",
      "Performance Management": "Goals and appraisals",
      "Training Management": "Training programs and tracking",
      Recruitment: "Job openings and applicants",
      Onboarding: "New hire onboarding tasks",
      "Manager Dashboard": "Team management and approvals",
      "Admin Settings": "System configuration"
    };
    return descriptions[featureName] || "Feature access control";
  }

  // Tab visibility getters
  get isUserManagementTab() {
    return this.activeTab === "users";
  }

  get isGlobalSettingsTab() {
    return this.activeTab === "settings";
  }

  get isLeaveTab() {
    return this.activeTab === "leave";
  }

  get isAttendanceTab() {
    return this.activeTab === "attendance";
  }

  get usersTabClass() {
    return this.getNavTabClass("users");
  }

  get settingsTabClass() {
    return this.getNavTabClass("settings");
  }

  get leaveTabClass() {
    return this.getNavTabClass("leave");
  }

  get attendanceTabClass() {
    return this.getNavTabClass("attendance");
  }

  // Tab navigation handler
  handleTabChange(event) {
    const tab = event.currentTarget.getAttribute("data-tab");
    this.activeTab = tab;
  }

  // Get CSS class for nav tab button
  getNavTabClass(tab) {
    return tab === this.activeTab ? "nav-link active" : "nav-link";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}