import getRecentNotifications from "@salesforce/apex/PWChrono_NotificationController.getRecentNotifications";
import markAsRead from "@salesforce/apex/PWChrono_NotificationController.markAsRead";
import markAllAsRead from "@salesforce/apex/PWChrono_NotificationController.markAllAsRead";
import { getSession, SESSION_CHANGED_EVENT } from "c/pwchronoSession";
import { api, LightningElement, track } from "lwc";

export default class PwchronoHeader extends LightningElement {
  static renderMode = "light";

  // Branding/logo placeholders (set via parent or Experience Builder)
  @api logoLightUrl;
  @api logoDarkUrl;
  @api logoAltText = "Pulse Work Chrono";

  // Optional brand name for logo fallback initials.
  @api brandName = "Pulse Work Chrono";

  @track logoLightErrored = false;
  @track logoDarkErrored = false;

  get showLightLogo() {
    return Boolean(this.logoLightUrl) && !this.logoLightErrored;
  }

  get showDarkLogo() {
    return Boolean(this.logoDarkUrl) && !this.logoDarkErrored;
  }

  get brandInitials() {
    const name = (this.brandName || this.logoAltText || "").trim();
    if (!name) return "";
    const parts = name.split(/\s+/).filter(Boolean);
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }

  handleLogoError(event) {
    const variant = event?.target?.dataset?.variant;
    if (variant === "dark") {
      this.logoDarkErrored = true;
    } else {
      this.logoLightErrored = true;
    }
  }

  // Label placeholders (no hardcoded copy)
  @api toggleSidebarLabel = "Toggle sidebar";
  @api searchTerm = "";
  @api searchPlaceholder = "Find a page";
  @api searchAriaLabel = "Find a page";
  @api searchShortcutText = "CTRL + /";
  @api exportLabel;
  @api settingsLabel;
  @api quickMenuLabel;
  @api quickMenuTitle;
  @api appsMenuLabel;
  @api appsMenuTitle;
  @api chatLabel = "Chat";
  @api notificationsLabel = "Notifications";
  @api notificationsTitle = "Recent notifications";
  @api markAllReadLabel = "Mark All Read";
  @api notificationFilterLabel;
  @api cancelLabel = "Cancel";
  @api viewAllLabel = "View All";
  @api mobileMenuLabel;
  // Provide a sensible default so the avatar menu always shows a readable action.
  @api logoutLabel = "Log Out";
  @api logoutPending = false;
  get displayedLogoutLabel() {
    return this.logoutPending ? "Signing out…" : this.logoutLabel;
  }
  @api yearPickerAriaLabel;

  // Data-driven dropdown lists
  @api quickMenuColumns = [];
  @api appsMenuItems = [];
  @api notificationFilters = [];
  @api notifications = [];
  @api profileActions = [];
  @api mobileMenuItems = [];

  @track selectedYear = new Date().getFullYear().toString();
  @track showProfileMenu = false;
  @track showNotifications = false;
  @track showQuickMenu = false;
  @track showMobileMenu = false;
  @track showNotificationFilter = false;
  @track userData = null;
  liveNotifications = [];
  notificationError = "";
  notificationsLoading = false;
  notificationsUpdating = false;
  showAllNotifications = false;
  notificationRequestVersion = 0;

  get visibleNotifications() {
    return this.showAllNotifications
      ? this.liveNotifications
      : this.liveNotifications.slice(0, 5);
  }
  get hasMoreNotifications() {
    return !this.showAllNotifications && this.liveNotifications.length > 5;
  }
  get notificationsEmpty() {
    return (
      !this.notificationsLoading &&
      !this.notificationError &&
      !this.liveNotifications.length
    );
  }
  get markAllDisabled() {
    return (
      this.notificationsLoading ||
      this.notificationsUpdating ||
      !this.notificationCount
    );
  }
  async loadNotifications() {
    const requestVersion = ++this.notificationRequestVersion;
    const session = getSession();
    if (!session.isLoggedIn) {
      this.liveNotifications = [];
      this.notificationsLoading = false;
      return;
    }
    this.notificationsLoading = true;
    this.notificationError = "";
    try {
      const rows = await getRecentNotifications({
        portalUserId: session.user?.Id,
        sessionToken: session.sessionToken
      });
      if (
        requestVersion !== this.notificationRequestVersion ||
        !this.isConnected
      )
        return;
      this.liveNotifications = (rows || []).map((row) => ({
        ...row,
        itemClass: row.IsRead
          ? "border-bottom py-2"
          : "border-bottom py-2 fw-semibold",
        readLabel: row.IsRead ? "Read" : "Mark as read"
      }));
    } catch (error) {
      if (
        requestVersion !== this.notificationRequestVersion ||
        !this.isConnected
      )
        return;
      this.notificationError =
        error?.body?.message ||
        error?.message ||
        "Unable to load notifications. Please retry.";
    } finally {
      if (requestVersion === this.notificationRequestVersion)
        this.notificationsLoading = false;
    }
  }
  async updateNotificationReadState(event) {
    if (this.notificationsUpdating) return;
    this.notificationsUpdating = true;
    this.notificationError = "";
    const session = getSession();
    const args = {
      portalUserId: session.user?.Id,
      sessionToken: session.sessionToken
    };
    try {
      const id = event.currentTarget.dataset.id;
      if (id) await markAsRead({ ...args, notificationId: id });
      else await markAllAsRead(args);
      if (
        this.isConnected &&
        getSession().sessionToken === session.sessionToken
      )
        await this.loadNotifications();
    } catch (error) {
      if (
        this.isConnected &&
        getSession().sessionToken === session.sessionToken
      ) {
        this.notificationError =
          error?.body?.message ||
          error?.message ||
          "Unable to update notifications. Please retry.";
      }
    } finally {
      this.notificationsUpdating = false;
    }
  }
  handleShowAllNotifications() {
    this.showAllNotifications = true;
  }

  @track isLightningExperience = false;

  get communityHomeHref() {
    try {
      const path = globalThis.location?.pathname || "";
      const idx = path.indexOf("/s/");
      if (idx >= 0) {
        return path.substring(0, idx) + "/s/";
      }
      if (path.endsWith("/s")) {
        return path + "/";
      }
      const parts = path.split("/").filter(Boolean);
      if (parts.length >= 1) {
        return "/" + parts[0] + "/";
      }
    } catch {
      // no-op
    }
    return "/";
  }

  _handleSearchShortcut = (event) => {
    if ((event.ctrlKey || event.metaKey) && event.key === "/") {
      event.preventDefault();
      this.querySelector('[data-region="search"] input')?.focus();
    }
  };
  _handleDocClick;
  _handleSessionChanged;

  connectedCallback() {
    document.addEventListener("keydown", this._handleSearchShortcut);
    this.isLightningExperience =
      globalThis?.location?.pathname?.startsWith("/lightning") === true;
    this.loadUserData();

    this._handleSessionChanged = () => this.loadUserData();
    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this._handleSessionChanged);
    } catch {
      // no-op
    }

    // Close popovers when clicking outside the header.
    this._handleDocClick = (evt) => {
      try {
        // In Light DOM, this.template is null. Use querySelector to find the root element within the component.
        const root = this.querySelector('[data-region="header"]');
        if (root && evt?.target && !root.contains(evt.target)) {
          this.showProfileMenu = false;
          this.showNotifications = false;
        }
      } catch {
        // no-op
      }
    };
    try {
      document.addEventListener("click", this._handleDocClick);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    this.notificationRequestVersion++;
    document.removeEventListener("keydown", this._handleSearchShortcut);
    try {
      if (this._handleDocClick) {
        document.removeEventListener("click", this._handleDocClick);
      }
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this._handleSessionChanged
      );
    } catch {
      // no-op
    }
  }

  loadUserData() {
    const session = getSession();
    this.userData = session.isLoggedIn && session.user ? session.user : null;
    this.liveNotifications = [];
    this.loadNotifications();
  }

  get userName() {
    return this.currentUser?.name;
  }

  get userSubTitle() {
    return this.currentUser?.role;
  }

  get userAvatarUrl() {
    return this.currentUser?.photoUrl;
  }

  get userInitials() {
    return (this.currentUser?.name || "")
      .split(" ")
      .map((part) => part.slice(0, 1))
      .join("")
      .toUpperCase()
      .slice(0, 2);
  }

  get userAvatarAlt() {
    return this.currentUser?.name;
  }

  get currentUser() {
    if (this.userData) {
      const name = this.userData.Name || this.userData.name || "";
      return {
        name: name,
        role: this.userData.Role__c || this.userData.role || "",
        initials: this.getInitials(name),
        photoUrl: this.userData.Photo_Url__c || null
      };
    }
    return {
      name: "Guest User",
      role: "Guest",
      initials: "GU",
      photoUrl: null
    };
  }

  getInitials(name) {
    if (!name) return "";
    const parts = name.split(" ");
    return parts.length >= 2
      ? (parts[0][0] + parts[1][0]).toUpperCase()
      : name.substring(0, 2).toUpperCase();
  }

  get notificationCount() {
    return this.liveNotifications.filter((item) => !item.IsRead).length;
  }

  get chatCount() {
    // Placeholder until chat is wired.
    return 0;
  }

  get hasNotifications() {
    return Number(this.notificationCount) > 0;
  }

  // Legacy placeholder retained for any consumers still referencing it.
  get notificationsEmptyText() {
    return "";
  }

  closeAllMenus() {
    this.showProfileMenu = false;
    this.showNotifications = false;
    this.showQuickMenu = false;
    this.showMobileMenu = false;
    this.showNotificationFilter = false;
  }

  handleToggleSidebar(mode) {
    // We should optionally listen to this to collapse/expand sidebar.
    this.dispatchEvent(
      new CustomEvent("togglesidebar", {
        detail: { mode },
        bubbles: true,
        composed: true
      })
    );
  }

  handleSearch(event) {
    const searchTerm = event.target.value;
    this.dispatchEvent(
      new CustomEvent("search", {
        detail: { searchTerm }
      })
    );
  }

  handleLogout() {
    if (this.logoutPending) return;
    this.dispatchEvent(
      new CustomEvent("logout", {
        bubbles: true,
        composed: true
      })
    );
  }

  handleActionClick(event) {
    event?.stopPropagation?.();
    // Many header actions are rendered as anchors (to match SmartHR markup).
    // Prevent browser navigation/scroll while we handle actions in JS.
    event?.preventDefault?.();
    const action = event?.currentTarget?.dataset?.action;
    if (!action) {
      return;
    }

    switch (action) {
      case "toggleSidebar":
        this.handleToggleSidebar("toggle");
        return;
      case "toggleSidebarMobile":
        this.handleToggleSidebar("mobile");
        return;
      case "toggleProfileMenu":
        this.showProfileMenu = !this.showProfileMenu;
        if (this.showProfileMenu) {
          this.showNotifications = false;
          this.showQuickMenu = false;
          this.showMobileMenu = false;
        }
        return;
      case "toggleNotifications":
        this.showNotifications = !this.showNotifications;
        if (this.showNotifications) {
          this.showAllNotifications = false;
          this.loadNotifications();
        }
        if (this.showNotifications) {
          this.showProfileMenu = false;
          this.showQuickMenu = false;
          this.showMobileMenu = false;
        }
        return;
      case "closeNotifications":
        this.showNotifications = false;
        this.showNotificationFilter = false;
        return;
      case "toggleNotificationFilter":
        this.showNotificationFilter = !this.showNotificationFilter;
        return;
      case "toggleQuickMenu":
        this.showQuickMenu = !this.showQuickMenu;
        if (this.showQuickMenu) {
          this.showProfileMenu = false;
          this.showNotifications = false;
          this.showMobileMenu = false;
        }
        return;
      case "toggleMobileMenu":
        this.showMobileMenu = !this.showMobileMenu;
        if (this.showMobileMenu) {
          this.showProfileMenu = false;
          this.showNotifications = false;
          this.showQuickMenu = false;
        }
        return;
      case "logout":
        this.handleLogout();
        return;
      case "home":
        this.dispatchEvent(
          new CustomEvent("navigate", {
            detail: { page: "home" },
            bubbles: true,
            composed: true
          })
        );
        return;
      default:
        // Delegate any other action to the shell/router.
        this.dispatchEvent(
          new CustomEvent("navigate", {
            detail: { action },
            bubbles: true,
            composed: true
          })
        );
    }
  }
}