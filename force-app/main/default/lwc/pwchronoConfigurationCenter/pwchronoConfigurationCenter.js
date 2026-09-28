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
  @track showViewRecordModal = false;
  @track viewingUser = null;
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
  wiredManagersResult;
  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  // Sorting
  @track sortBy = "userName";
  @track sortDirection = "asc";

  // Pagination
  @track currentPage = 1;
  @track pageSize = 10;

  pageSizeOptions = [
    { label: "5", value: "5" },
    { label: "10", value: "10" },
    { label: "25", value: "25" },
    { label: "50", value: "50" }
  ];

  get roleOptionsMap() {
    return {
      "HR Admin": "badge badge-soft-purple",
      "Employee": "badge badge-soft-info",
      "Manager": "badge badge-soft-warning",
      "HR Manager": "badge badge-soft-warning",
      "Project Manager": "badge badge-soft-warning",
      "Payroll Admin": "badge badge-soft-success"
    };
  }

  getRoleBadge(role) {
    return this.roleOptionsMap[role] || "badge badge-soft-secondary";
  }

  getUserInitials(name) {
    if (!name) return "U";
    const parts = name.trim().split(" ");
    if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

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
        profileName: user.profileName || "Unassigned",
        managerId:
          user.managerId ||
          this.reportingByUserId.get(user.userId)?.managerId ||
          "",
        managerName:
          user.managerName && user.managerName !== "Unassigned"
            ? user.managerName
            : this.reportingByUserId.get(user.userId)?.managerName ||
              "Unassigned",
        userInitials: this.getUserInitials(user.userName),
        roleBadgeClass: this.getRoleBadge(user.roleName),
        statusBadgeClass: user.isActive
          ? "badge badge-soft-success"
          : "badge badge-soft-danger",
        statusText: user.isActive ? "Active" : "Inactive"
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
  wiredManagers(result) {
    this.wiredManagersResult = result;
    const { error, data } = result;
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
          managerId:
            this.reportingByUserId.get(user.userId)?.managerId ||
            user.managerId ||
            "",
          managerName:
            this.reportingByUserId.get(user.userId)?.managerName ||
            user.managerName ||
            "Unassigned"
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
      this.showToast("Error", error.body?.message || "Error loading settings", "error");
    }
  }

  handleUserSearch(event) {
    this.searchTerm = event.target.value.toLowerCase();
    this.currentPage = 1;
    this.filterUsers();
  }

  get pageSizeValue() {
    return String(this.pageSize);
  }

  handleSort(event) {
    const field = event.currentTarget.dataset.field;
    if (this.sortBy === field) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
    } else {
      this.sortBy = field;
      this.sortDirection = "asc";
    }
    this.currentPage = 1;
    this.filterUsers();
  }

  filterUsers() {
    if (this.searchTerm && this.searchTerm.trim() !== "") {
      const term = this.searchTerm.trim();
      this.filteredUsers = this.users.filter(
        (user) =>
          (user.userName &&
            user.userName.toLowerCase().includes(term)) ||
          (user.userEmail &&
            user.userEmail.toLowerCase().includes(term)) ||
          (user.roleName &&
            user.roleName.toLowerCase().includes(term)) ||
          (user.profileName &&
            user.profileName.toLowerCase().includes(term)) ||
          (user.department &&
            user.department.toLowerCase().includes(term))
      );
    } else {
      this.filteredUsers = [...this.users];
    }
    const direction = this.sortDirection === "asc" ? 1 : -1;
    this.filteredUsers.sort(
      (a, b) =>
        direction *
        String(a[this.sortBy] || "").localeCompare(
          String(b[this.sortBy] || ""),
          undefined,
          { numeric: true, sensitivity: "base" }
        )
    );
    this.applyPagination();
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.paginatedUsers = this.filteredUsers.slice(start, end);
  }

  handlePageSizeSelect(event) {
    this.pageSize = parseInt(event.target.value, 10) || 10;
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
    if (this.totalRecords === 0) return "Showing 0 to 0 of 0 entries";
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
    return `Showing ${start} to ${end} of ${this.totalRecords} entries`;
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

  handleManageAccessClick(event) {
    const userId = event.currentTarget.dataset.id;
    const user = this.users.find((u) => u.userId === userId);
    if (user) {
      this.openManageAccessModal(user);
    }
  }

  handleViewRecordClick(event) {
    const userId = event.currentTarget.dataset.id;
    const user = this.users.find((u) => u.userId === userId);
    if (user) {
      this.openViewRecordModal(user);
    }
  }

  openViewRecordModal(user) {
    this.viewingUser = {
      ...user,
      statusBadgeClass: user.isActive
        ? "badge badge-soft-success"
        : "badge badge-soft-danger",
      statusText: user.isActive ? "Active" : "Inactive"
    };
    this.showViewRecordModal = true;
  }

  closeViewRecordModal() {
    this.showViewRecordModal = false;
    this.viewingUser = null;
  }

  handleManageAccessFromView() {
    const userToManage = this.viewingUser;
    this.closeViewRecordModal();
    if (userToManage) {
      this.openManageAccessModal(userToManage);
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

  handleModalCardClick(event) {
    if (event && event.stopPropagation) {
      event.stopPropagation();
    }
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

  async handleSaveUserProfile() {
    if (!this.selectedUser || !this.selectedProfileId) {
      this.showToast(
        "Error",
        "Select a Portal User Profile before saving.",
        "error"
      );
      return;
    }
    this.isSaving = true;
    try {
      await saveUserSetup({
        targetPortalUserId: this.selectedUser.userId,
        profileId: this.selectedProfileId,
        managerPortalUserId: this.selectedManagerId || null,
        callerPortalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });

      // Calculate updated manager and profile names immediately for instant UI reflection
      let updatedManagerName = "Unassigned";
      if (this.selectedManagerId) {
        const foundManager = this.managerOptions.find(
          (opt) => opt.value === this.selectedManagerId
        );
        if (foundManager && foundManager.label) {
          updatedManagerName = foundManager.label.split(" — ")[0];
        }
      }

      const foundProfile = this.profileOptions.find(
        (opt) => opt.value === this.selectedProfileId
      );
      const updatedProfileName = foundProfile
        ? foundProfile.label
        : "Unassigned";

      // Update in-memory user list immediately
      this.users = this.users.map((u) => {
        if (u.userId === this.selectedUser.userId) {
          return {
            ...u,
            profileId: this.selectedProfileId,
            profileName: updatedProfileName,
            managerId: this.selectedManagerId || "",
            managerName: updatedManagerName
          };
        }
        return u;
      });
      this.filterUsers();

      // Also update reportingByUserId map
      if (this.selectedUser.userId) {
        this.reportingByUserId.set(this.selectedUser.userId, {
          portalUserId: this.selectedUser.userId,
          portalUserName: this.selectedUser.userName,
          managerId: this.selectedManagerId || "",
          managerName: updatedManagerName
        });
      }

      this.showToast(
        "Success",
        "Portal User Profile and reporting manager saved successfully",
        "success"
      );
      this.closeModal();

      // Refresh wire adapters in background
      if (this.wiredUsersResult) {
        await refreshApex(this.wiredUsersResult);
      }
      if (this.wiredManagersResult) {
        await refreshApex(this.wiredManagersResult);
      }
    } catch (error) {
      const errorMsg =
        error.body?.message || error.message || "Unknown error";
      this.showToast("Error", errorMsg, "error");
    } finally {
      this.isSaving = false;
    }
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
        this.showToast("Error", error.body?.message || "Failed to save settings", "error");
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