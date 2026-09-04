import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import getAllUsersWithAccess from "@salesforce/apex/PWChrono_ConfigurationController.getAllUsersWithAccess";
import getAvailableProfiles from "@salesforce/apex/PWChrono_ConfigurationController.getAvailableProfiles";
import getReportingOptions from "@salesforce/apex/PWChrono_ReportingManagerController.getReportingOptions";
import saveUserSetup from "@salesforce/apex/PWChrono_ReportingManagerController.saveUserSetup";
import getGlobalFeatureSettings from "@salesforce/apex/PWChrono_ConfigurationController.getGlobalFeatureSettings";
import saveGlobalFeatureSettings from "@salesforce/apex/PWChrono_ConfigurationController.saveGlobalFeatureSettings";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

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
  @track selectedProfileId = "";
  @track selectedManagerId = "";
  @track profileOptions = [];
  @track managerOptions = [];
  reportingByUserId = new Map();
  @track globalSettings = {};
  @track isSaving = false;
  @track isLoading = true;
  @track activeTab = "users";
  wiredUsersResult;
  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" },
    { label: "50", value: "50" }
  ];

  userColumns = [
    { label: "Name", fieldName: "userName", type: "text", sortable: true },
    { label: "Email", fieldName: "userEmail", type: "email", sortable: true },
    {
      label: "Portal User Profile",
      fieldName: "profileName",
      type: "text",
      sortable: true
    },
    { label: "Role", fieldName: "roleName", type: "text", sortable: true },
    {
      label: "Reports To",
      fieldName: "managerName",
      type: "text",
      sortable: true
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

  @wire(getAllUsersWithAccess, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredUsers(result) {
    this.wiredUsersResult = result;
    this.isLoading = true;
    const { error, data } = result;
    if (data) {
      this.users = data.map((user) => ({
        ...user,
        profileName: user.profileName || "N/A",
        managerId: this.reportingByUserId.get(user.userId)?.managerId || "",
        managerName:
          this.reportingByUserId.get(user.userId)?.managerName || "Unassigned"
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

  @wire(getAvailableProfiles, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredProfiles({ error, data }) {
    if (data) {
      this.profileOptions = data.map((profile) => ({
        label: profile.profileName,
        value: profile.profileId
      }));
      if (this.profileOptions.length === 0) {
        this.showToast(
          "Warning",
          "No Portal User Profiles are available for assignment.",
          "warning"
        );
      }
    } else if (error) {
      const errorMsg =
        error?.body?.message || error?.message || "Failed to load profiles";
      this.showToast("Error", "Failed to load profiles: " + errorMsg, "error");
    }
  }

  @wire(getReportingOptions, {
    callerPortalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredManagers({ error, data }) {
    if (data) {
      this.reportingByUserId = new Map(
        data.map((portalUser) => [portalUser.portalUserId, portalUser])
      );
      this.managerOptions = [
        { label: "No manager (top-level)", value: "" },
        ...data
          .filter((manager) => manager.isActive)
          .map((manager) => ({
            label: manager.designation
              ? `${manager.portalUserName} — ${manager.designation}`
              : manager.portalUserName,
            value: manager.portalUserId
          }))
      ];
      if (this.users.length > 0) {
        this.users = this.users.map((user) => ({
          ...user,
          managerId: this.reportingByUserId.get(user.userId)?.managerId || "",
          managerName:
            this.reportingByUserId.get(user.userId)?.managerName || "Unassigned"
        }));
        this.filterUsers();
      }
    } else if (error) {
      const errorMsg =
        error?.body?.message || error?.message || "Failed to load managers";
      this.showToast("Error", `Failed to load managers: ${errorMsg}`, "error");
    }
  }

  @wire(getGlobalFeatureSettings, {
    portalUserId: "$employeeId",
    sessionToken: "$sessionToken"
  })
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
    this.selectedProfileId = user.profileId || "";
    this.selectedManagerId = user.managerId || "";
    this.showUserFeatureModal = true;
  }

  closeModal() {
    this.showUserFeatureModal = false;
    this.selectedUser = null;
    this.selectedProfileId = "";
    this.selectedManagerId = "";
  }

  handleProfileChange(event) {
    this.selectedProfileId = event.detail.value;
  }

  handleManagerChange(event) {
    this.selectedManagerId = event.detail.value;
  }

  get availableManagerOptions() {
    if (!this.selectedUser) {
      return this.managerOptions;
    }
    return this.managerOptions.filter(
      (option) => !option.value || option.value !== this.selectedUser.userId
    );
  }

  handleSaveUserProfile() {
    if (!this.selectedUser || !this.selectedProfileId) {
      this.showToast(
        "Error",
        "Select a Portal User Profile before saving.",
        "error"
      );
      return;
    }
    this.isSaving = true;
    saveUserSetup({
      targetPortalUserId: this.selectedUser.userId,
      profileId: this.selectedProfileId,
      managerPortalUserId: this.selectedManagerId || null,
      callerPortalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          "Portal User Profile and reporting manager saved successfully",
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
    saveGlobalFeatureSettings({
      settings: this.globalSettings,
      portalUserId: this.employeeId,
      sessionToken: this.sessionToken
    })
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