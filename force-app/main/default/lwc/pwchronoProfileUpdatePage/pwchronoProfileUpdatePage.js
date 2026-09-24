import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getPortalUsersForProfile from "@salesforce/apex/PWChrono_PermissionController.getPortalUsersForProfile";
import { logError } from "c/pwchronoErrorHandler";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { api, LightningElement, track, wire } from "lwc";

export default class PwchronoProfileUpdatePage extends LightningElement {
  // Provided automatically when placed on a lightning__RecordPage
  @api recordId;

  // Provided automatically when placed on a lightning__RecordPage
  @api objectApiName;

  // Optional override (set in Lightning App Builder)
  @api employeeId;

  // Optional visibility toggles (Lightning App Builder). Undefined => enabled.
  @api showEmployeesTab;
  @api showDashboardTab;
  @api showAttendanceTab;
  @api showPortalUsersTab;
  @api showSelectedUserTab;
  @api showPermissionsTab;

  // Optional feature requirements (override defaults if needed)
  @api employeesTabFeature;
  @api dashboardTabFeature;
  @api attendanceTabFeature;
  @api portalUsersTabFeature;
  @api selectedUserTabFeature;
  @api permissionsTabFeature;

  // Session info (used only for Guest authorization; internal users can be null)
  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  @track features = [];
  @track isSalesforceUser = false;
  @track accessLoaded = false;

  _boundSessionChanged;

  @track portalUsers = [];
  @track isUsersLoading = false;
  @track selectedPortalUserId;

  // Main tabs
  @track activeMainTab = "employees";
  // Child tabs under Employees
  @track activeEmployeesTab = "portalUsers";

  userColumns = [
    { label: "Name", fieldName: "name", type: "text" },
    { label: "Email", fieldName: "email", type: "email" },
    { label: "Active", fieldName: "isActive", type: "boolean" },
    { label: "Role", fieldName: "role", type: "text" },
    {
      type: "action",
      typeAttributes: {
        rowActions: [{ label: "Edit Profile", name: "edit" }]
      }
    }
  ];

  connectedCallback() {
    // Refresh session values (when this component is used in the portal shell)
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();

    this._boundSessionChanged = this.handleSessionChanged.bind(this);
    try {
      globalThis?.addEventListener?.(
        SESSION_CHANGED_EVENT,
        this._boundSessionChanged
      );
    } catch {
      // no-op
    }

    this.loadFeatureAccess();
  }

  disconnectedCallback() {
    try {
      globalThis?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this._boundSessionChanged
      );
    } catch {
      // no-op
    }
  }

  handleSessionChanged() {
    // Session values can change after OTP login completes.
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
    this.loadFeatureAccess();
  }

  async loadFeatureAccess() {
    try {
      const accessData = await getUserAccessById({
        employeeId: this.portalUserId || null,
        sessionToken: this.sessionToken
      });

      this.features = accessData?.features || [];
      this.isSalesforceUser = !!accessData?.isSalesforceUser;
      this.accessLoaded = true;
    } catch {
      this.features = [];
      this.isSalesforceUser = false;
      this.accessLoaded = true;
    }

    this.ensureActiveTabsValid();
  }

  handleMainTabActive(event) {
    const value = event?.target?.value;
    if (value) {
      this.activeMainTab = value;
    }
  }

  handleEmployeesTabActive(event) {
    const value = event?.target?.value;
    if (value) {
      this.activeEmployeesTab = value;
    }
  }

  hasFeature(featureName) {
    if (!featureName) return true;
    return Array.isArray(this.features) && this.features.includes(featureName);
  }

  get employeesRequiredFeature() {
    // Site-related default: this aligns to the Experience Cloud navigation label.
    return this.employeesTabFeature || "Employee Directory";
  }

  get dashboardRequiredFeature() {
    // Dashboard is always visible in the site navigation (sidebar forces it on),
    // so don't require a feature by default.
    return this.dashboardTabFeature || null;
  }

  get attendanceRequiredFeature() {
    // Site-related default: this aligns to the Experience Cloud navigation label.
    return this.attendanceTabFeature || "Attendance Management";
  }

  get portalUsersRequiredFeature() {
    return this.portalUsersTabFeature || this.employeesRequiredFeature;
  }

  get selectedUserRequiredFeature() {
    return this.selectedUserTabFeature || this.employeesRequiredFeature;
  }

  get permissionsRequiredFeature() {
    return this.permissionsTabFeature || this.employeesRequiredFeature;
  }

  get canShowEmployeesTab() {
    if (this.showEmployeesTab === false) return false;
    return this.hasFeature(this.employeesRequiredFeature);
  }

  get canShowDashboardTab() {
    if (this.showDashboardTab === false) return false;
    return this.hasFeature(this.dashboardRequiredFeature);
  }

  get canShowAttendanceTab() {
    if (this.showAttendanceTab === false) return false;
    return this.hasFeature(this.attendanceRequiredFeature);
  }

  get canShowPortalUsersTab() {
    if (this.showPortalUsersTab === false) return false;
    return this.hasFeature(this.portalUsersRequiredFeature);
  }

  get canShowSelectedUserTab() {
    if (this.showSelectedUserTab === false) return false;
    return this.hasFeature(this.selectedUserRequiredFeature);
  }

  get canShowPermissionsTab() {
    if (this.showPermissionsTab === false) return false;
    return this.hasFeature(this.permissionsRequiredFeature);
  }

  get firstVisibleMainTab() {
    if (this.canShowEmployeesTab) return "employees";
    if (this.canShowDashboardTab) return "dashboard";
    if (this.canShowAttendanceTab) return "attendance";
    return "employees";
  }

  get firstVisibleEmployeesTab() {
    if (this.canShowPortalUsersTab) return "portalUsers";
    if (this.canShowSelectedUserTab) return "selectedUser";
    if (this.canShowPermissionsTab) return "permissions";
    return "portalUsers";
  }

  ensureActiveTabsValid() {
    // If access hasn't loaded yet, keep current tab selection (avoid flicker).
    if (!this.accessLoaded) return;

    // Main tab
    const isCurrentMainVisible =
      (this.activeMainTab === "employees" && this.canShowEmployeesTab) ||
      (this.activeMainTab === "dashboard" && this.canShowDashboardTab) ||
      (this.activeMainTab === "attendance" && this.canShowAttendanceTab);

    if (!isCurrentMainVisible) {
      this.activeMainTab = this.firstVisibleMainTab;
    }

    // Employees child tabs
    const isCurrentEmployeesVisible =
      (this.activeEmployeesTab === "portalUsers" &&
        this.canShowPortalUsersTab) ||
      (this.activeEmployeesTab === "selectedUser" &&
        this.canShowSelectedUserTab) ||
      (this.activeEmployeesTab === "permissions" && this.canShowPermissionsTab);

    if (!isCurrentEmployeesVisible) {
      this.activeEmployeesTab = this.firstVisibleEmployeesTab;
    }
  }

  get isPortalUserProfileRecord() {
    return this.objectApiName === "Portal_User_Profile__c" && !!this.recordId;
  }

  get isEmployeesMainTabActive() {
    return this.activeMainTab === "employees";
  }

  get isDashboardMainTabActive() {
    return this.activeMainTab === "dashboard";
  }

  get isAttendanceMainTabActive() {
    return this.activeMainTab === "attendance";
  }

  get isEmployeesPortalUsersTabActive() {
    return this.activeEmployeesTab === "portalUsers";
  }

  get isEmployeesSelectedUserTabActive() {
    return this.activeEmployeesTab === "selectedUser";
  }

  get isEmployeesPermissionsTabActive() {
    return this.activeEmployeesTab === "permissions";
  }

  get hasPortalUsers() {
    return Array.isArray(this.portalUsers) && this.portalUsers.length > 0;
  }

  get usersProfileId() {
    // Load the Portal Users list whenever we're on the Portal User Profile record page.
    // (UI was simplified to remove Dashboard/Employees/Attendance tabs.)
    if (!this.isPortalUserProfileRecord) return null;
    return this.recordId;
  }

  @wire(getPortalUsersForProfile, {
    profileId: "$usersProfileId",
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredPortalUsers({ data, error }) {
    // Only relevant on the Portal User Profile record page.
    if (!this.isPortalUserProfileRecord) {
      this.isUsersLoading = false;
      return;
    }

    // When profileId is null (e.g. user is on another main tab), keep state as-is.
    if (!this.usersProfileId) {
      this.isUsersLoading = false;
      return;
    }

    this.isUsersLoading = true;
    if (Array.isArray(data)) {
      this.portalUsers = data;
      // Default selection: first user (nice UX for admins)
      if (!this.selectedPortalUserId && data.length) {
        this.selectedPortalUserId = data[0].id;
      }
      this.isUsersLoading = false;
    } else if (error) {
      this.portalUsers = [];
      this.isUsersLoading = false;
      // Keep silent; toast not always available depending on host.
      logError("pwchronoProfileUpdatePage.wiredPortalUsers", error);
    }
  }

  handleUserRowAction(event) {
    const actionName = event?.detail?.action?.name;
    const row = event?.detail?.row;
    if (actionName === "edit" && row?.id) {
      this.selectedPortalUserId = row.id;
    }
  }

  get effectiveEmployeeId() {
    // Highest priority: explicit override.
    if (this.employeeId) return this.employeeId;

    // Only treat recordId as an employeeId when we're actually on a Portal_Users__c record.
    if (this.objectApiName === "Portal_Users__c" && this.recordId) {
      return this.recordId;
    }

    // Otherwise, let the child component fall back to session-based employee id.
    return null;
  }
}