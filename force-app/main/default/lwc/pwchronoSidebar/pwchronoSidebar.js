import getNavigationMenuItems from "@salesforce/apex/PWChrono_NavigationController.getNavigationMenuItems";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import { filterMenuItemsByFeatures } from "c/pwchronoNavigationAccess";
import { getSession, SESSION_CHANGED_EVENT } from "c/pwchronoSession";
import { navigateTo } from "c/pwchronoRouter";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { api, LightningElement, track, wire } from "lwc";

// Icon class mapping based on label.
// NOTE: Tabler icon CSS in `smarthr_assets` references missing webfonts, so `ti ti-*` icons won't render.
// FontAwesome is present (css + webfonts), so we standardize on it for reliable icons.
const ICON_CLASS_MAP = {
  Dashboard: "fa-solid fa-house fa-fw",
  "Admin Dashboard": "fa-solid fa-house fa-fw",
  "Manager Dashboard": "fa-solid fa-house fa-fw",
  "Leave Management": "fa-solid fa-calendar-minus fa-fw",
  "Attendance Management": "fa-solid fa-user-clock fa-fw",
  "Attendance (Admin)": "fa-solid fa-clipboard-user fa-fw",
  "Attendance Employee": "fa-solid fa-clock fa-fw",
  "Employee Directory": "fa-solid fa-address-book fa-fw",
  "My Profile": "fa-solid fa-address-card fa-fw",
  Approvals: "fa-solid fa-circle-check fa-fw",
  Holidays: "fa-solid fa-plane-departure fa-fw",
  Payroll: "fa-solid fa-file-invoice-dollar fa-fw",
  "Expense Management": "fa-solid fa-wallet fa-fw",
  "Performance Management": "fa-solid fa-chart-simple fa-fw",
  "Reports Dashboard": "fa-solid fa-chart-column fa-fw",
  Configuration: "fa-solid fa-sliders fa-fw",
  Projects: "fa-solid fa-folder-tree fa-fw",
  "Project List": "fa-solid fa-folder-tree fa-fw",
  "Training Management": "fa-solid fa-chalkboard-user fa-fw",
  Recruitment: "fa-solid fa-user-plus fa-fw",
  "Staffing Plan": "fa-solid fa-sitemap fa-fw",
  "Job Requisition": "fa-solid fa-file-signature fa-fw",
  "Career Portal": "fa-solid fa-globe fa-fw",
  "Employee Referral": "fa-solid fa-user-plus fa-fw",
  "Recruitment Dashboard": "fa-solid fa-chart-line fa-fw",
  "Employee Promotion": "fa-solid fa-arrow-trend-up fa-fw",
  "Employee Transfer": "fa-solid fa-right-left fa-fw",
  "Employee Separation": "fa-solid fa-door-open fa-fw",
  "Exit Interview": "fa-solid fa-comments fa-fw",
  "Full & Final Settlement": "fa-solid fa-file-invoice-dollar fa-fw",
  Onboarding: "fa-solid fa-person-circle-check fa-fw",
  "Company Policies": "fa-solid fa-file-shield fa-fw"
};

const APPLICATION_ROUTES = {
  dashboard: "dashboard",
  "attendance management": "attendance",
  "attendance employee": "attendance",
  attendance: "attendance",
  "leave management": "leave",
  leaves: "leave",
  holidays: "holidays",
  "employee directory": "directory",
  recruitment: "recruitment",
  onboarding: "onboarding",
  "performance management": "performance",
  performance: "performance",
  goals: "goals",
  "training management": "training",
  training: "training",
  projects: "projects",
  "project list": "projects",
  "expense management": "expenses",
  expenses: "expenses",
  payroll: "payroll",
  approvals: "approvals",
  "company policies": "policies",
  policies: "policies",
  "reports dashboard": "reports",
  reports: "reports",
  "my profile": "profile",
  profile: "profile",
  configuration: "configuration",
  "admin settings": "configuration"
};

export default class PwchronoSidebar extends NavigationMixin(LightningElement) {
  static renderMode = "light";
  @api features = [];
  @api isSalesforceUser = false;
  @api menuGroupLabel;
  @api applicationMode = false;
  @api navigationContext;

  @track activeSidebarTab = "menu"; // menu | chat | email

  // For lightning-vertical-navigation, selected-item must match an item's `name`.
  // We use menu item ids as names/keys, so default to null until we load menu items.
  @track activeNavKey = null;
  @track rawMenuItems = [];
  @track expandedParentKeys = [];
  @track userData = null;
  _allItemsByKey = {};
  sessionChangedHandler;

  @track logoLightErrored = false;
  @track logoDarkErrored = false;
  @track logoSmallErrored = false;

  get brandName() {
    return "Pulse Work Chrono";
  }

  get brandInitials() {
    const name = (this.brandName || "").trim();
    if (!name) return "";
    const parts = name.split(/\s+/).filter(Boolean);
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }

  handleLogoError(event) {
    const variant = event?.target?.dataset?.variant;
    if (variant === "dark") this.logoDarkErrored = true;
    else if (variant === "small") this.logoSmallErrored = true;
    else this.logoLightErrored = true;
  }

  connectedCallback() {
    this.refreshUserFromSession();
    this.sessionChangedHandler = () => this.refreshUserFromSession();
    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this.sessionChangedHandler
      );
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  refreshUserFromSession() {
    try {
      this.userData = getSession()?.user || null;
    } catch {
      this.userData = null;
    }
  }

  get logoLightUrl() {
    return `${smarthrAssets}/assets/img/logo.svg`;
  }

  get logoDarkUrl() {
    return `${smarthrAssets}/assets/img/logo-white.svg`;
  }

  get logoSmallUrl() {
    return `${smarthrAssets}/assets/img/logo-small.svg`;
  }

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

  get currentUser() {
    if (this.userData) {
      const name = this.userData.Name || this.userData.name || "";
      return {
        name,
        role: this.userData.Role__c || this.userData.role || "",
        photoUrl: this.userData.Photo_Url__c || null
      };
    }
    return {
      name: "Guest User",
      role: "Guest",
      photoUrl: null
    };
  }

  get userName() {
    return this.currentUser?.name;
  }

  get userRole() {
    return this.currentUser?.role;
  }

  get userAvatarUrl() {
    return this.currentUser?.photoUrl;
  }

  get userAvatarAlt() {
    return this.currentUser?.name;
  }

  get userInitials() {
    return (this.currentUser?.name || "")
      .split(" ")
      .map((p) => p.slice(0, 1))
      .join("")
      .toUpperCase()
      .slice(0, 2);
  }

  get menuTabClass() {
    return this.activeSidebarTab === "menu"
      ? "nav-link active border-0"
      : "nav-link border-0";
  }

  get chatTabClass() {
    return this.activeSidebarTab === "chat"
      ? "nav-link active border-0"
      : "nav-link border-0";
  }

  get emailTabClass() {
    return this.activeSidebarTab === "email"
      ? "nav-link active border-0"
      : "nav-link border-0";
  }

  get isMenuTab() {
    return this.activeSidebarTab === "menu";
  }

  get isChatTab() {
    return this.activeSidebarTab === "chat";
  }

  get isEmailTab() {
    return this.activeSidebarTab === "email";
  }

  handleSidebarTabClick(event) {
    // Tabs are rendered as anchors to match SmartHR styling.
    // Prevent navigation and use currentTarget so icon clicks still resolve correctly.
    event?.preventDefault?.();
    event?.stopPropagation?.();

    const tab =
      event?.currentTarget?.dataset?.tab || event?.target?.dataset?.tab;
    if (!tab) return;

    if (tab === "email") {
      this.activeSidebarTab = tab;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Coming soon",
          message: "Coming soon",
          variant: "info"
        })
      );
      return;
    }

    if (tab === "chat") {
      this.activeSidebarTab = tab;
      navigateTo("chat");
      return;
    }

    this.activeSidebarTab = "menu";
  }

  @wire(getNavigationMenuItems, {
    menuName: "Default Navigation",
    publishedState: "Live"
  })
  wiredMenuItems({ error, data }) {
    if (data) {
      const flatMap = {};

      // Recursive helper to map the incoming tree structure (which has subMenu)
      // to our internal node structure.
      const mapItem = (src, index, parentId = null) => {
        // Fallback for ID if missing
        const id = src.id || src.label || `menu-item-${index}`;
        const key = String(id);

        const node = {
          id: id,
          key: key,
          label: src.label,
          // Map actionType (from log) or type (standard)
          type: src.actionType || src.type,
          actionValue: src.actionValue,
          target: src.target,
          parentId: parentId,
          iconClass: ICON_CLASS_MAP[src.label] || "fa-solid fa-circle fa-fw",
          children: []
        };

        // Register in flat map for lookup
        flatMap[key] = node;

        // Recursively process subMenu
        if (src.subMenu?.length > 0) {
          node.children = src.subMenu.map((child, childIdx) =>
            mapItem(child, childIdx, node.id)
          );
        }

        return node;
      };

      // Map the top-level items
      this.rawMenuItems = data.map((item, idx) => mapItem(item, idx));
      this._allItemsByKey = flatMap;

      // Expand the root menu that contains the currently active page (if any).
      this.syncExpandedToActive();

      // Ensure selected item is a valid lightning-vertical-navigation item name.
      // Prefer Dashboard (always present) else first root item.
      if (!this.activeNavKey) {
        const allItems = Object.values(flatMap);
        const dashboardItem = allItems.find((i) => i.label === "Dashboard");
        this.activeNavKey =
          dashboardItem?.key || this.rawMenuItems?.[0]?.key || null;
      }

      this.detectCurrentPage();
    } else if (error) {
      // Avoid logging raw wire error objects (can contain proxies in Live Preview).
      // Keep UI silent; navigation can be retried on refresh.
    }
  }

  get menuItems() {
    if (!this.rawMenuItems || this.rawMenuItems.length === 0) {
      return [];
    }

    // If Salesforce internal user, show everything.
    if (this.isSalesforceUser) {
      return this.rawMenuItems;
    }

    // This is a visibility aid. Apex remains responsible for authorization.
    return filterMenuItemsByFeatures(this.rawMenuItems, this.features);
  }

  get menuGroupLabelValue() {
    return this.menuGroupLabel || "MAIN MENU";
  }

  handleSearch(event) {
    const searchTerm = event?.target?.value || "";
    this.dispatchEvent(
      new CustomEvent("search", {
        detail: { searchTerm },
        bubbles: true,
        composed: true
      })
    );
  }

  getCommunityBasePath() {
    try {
      const path = globalThis.location?.pathname || "";
      // Pattern A: sites that use /s
      const idx = path.indexOf("/s/");
      if (idx >= 0) {
        return path.substring(0, idx) + "/s";
      }
      if (path.endsWith("/s")) {
        return path;
      }

      // Pattern B: sites without /s (e.g. /PulseWorkChrono/login)
      const parts = path.split("/").filter(Boolean);
      if (parts.length >= 1) {
        return "/" + parts[0];
      }
    } catch {
      // no-op
    }
    return "";
  }

  getCommunityRelativePath() {
    try {
      const path = globalThis.location?.pathname || "";
      const base = this.getCommunityBasePath();
      if (base && path.startsWith(base)) {
        let rel = path.substring(base.length);
        if (!rel) {
          rel = "/";
        }
        if (!rel.startsWith("/")) {
          rel = "/" + rel;
        }
        return rel;
      }
      return path || "/";
    } catch {
      return "/";
    }
  }

  normalizeMenuRelativePath(actionValue) {
    if (!actionValue) {
      return null;
    }

    // Ignore absolute URLs here (handled separately).
    if (/^https?:\/\//i.test(actionValue)) {
      return null;
    }

    let p = String(actionValue);
    // Strip query/hash just in case
    p = p.split("?")[0].split("#")[0];
    if (!p.startsWith("/")) {
      p = "/" + p;
    }

    // Strip site base prefix if present (e.g. /PulseWorkChrono/login -> /login)
    const base = this.getCommunityBasePath();
    if (base && p.startsWith(base + "/")) {
      p = p.substring(base.length);
      if (!p.startsWith("/")) {
        p = "/" + p;
      }
    } else if (base && p === base) {
      p = "/";
    }

    // If stored as /s/... in the menu, convert to the relative form /...
    if (p.startsWith("/s/")) {
      p = p.substring(2);
    } else if (p === "/s") {
      p = "/";
    }

    return p;
  }

  toCommunityWebUrl(actionValue) {
    if (!actionValue) {
      return null;
    }

    // External URLs should be used as-is.
    if (/^https?:\/\//i.test(actionValue)) {
      return actionValue;
    }

    const rel = this.normalizeMenuRelativePath(actionValue) || "/";
    const base = this.getCommunityBasePath();
    return base ? `${base}${rel}` : rel;
  }

  detectCurrentPage() {
    try {
      const currentRel = this.getCommunityRelativePath();
      const items = Object.values(this._allItemsByKey || {});
      const found = items.find((item) => {
        if (item.type === "InternalLink" && item.actionValue) {
          const menuRel = this.normalizeMenuRelativePath(item.actionValue);
          if (!menuRel) {
            return false;
          }

          // Special-case home ('/') to avoid matching every route.
          if (menuRel === "/") {
            return currentRel === "/";
          }

          return currentRel === menuRel || currentRel.startsWith(menuRel + "/");
        }
        return false;
      });
      if (found) {
        this.activeNavKey = found.key;
        this.syncExpandedToActive();
      }
    } catch {
      // Fallback to default
    }
  }

  isParentExpanded(parentKey) {
    return (this.expandedParentKeys || []).includes(String(parentKey));
  }

  toggleParentExpanded(parentKey) {
    const key = String(parentKey);
    const current = this.expandedParentKeys || [];
    if (current.includes(key)) {
      this.expandedParentKeys = current.filter((k) => k !== key);
    } else {
      this.expandedParentKeys = [...current, key];
    }
  }

  syncExpandedToActive() {
    try {
      const active = String(this.activeNavKey || "");
      if (!active) {
        return;
      }

      const allItems = Object.values(this._allItemsByKey || {});
      const activeItem = allItems.find((i) => i.key === active);
      if (!activeItem) {
        return;
      }
      const parentId = activeItem.parentId;
      if (!parentId) {
        return;
      }
      const parent = allItems.find((i) => i.id === parentId);
      if (parent) {
        const parentKey = String(parent.key);
        if (!this.isParentExpanded(parentKey)) {
          this.expandedParentKeys = [
            ...(this.expandedParentKeys || []),
            parentKey
          ];
        }
      }
    } catch {
      // no-op
    }
  }

  get menuRenderItems() {
    const items = this.menuItems || [];
    return items.map((item) => {
      const hasChildren =
        Array.isArray(item.children) && item.children.length > 0;

      // Return boolean strictly. false instead of undefined ensures aria-expanded="false" which is valid.
      const isExpanded = hasChildren ? this.isParentExpanded(item.key) : false;

      const isActive = String(this.activeNavKey) === String(item.key);

      const isToggleOnly = hasChildren && (!item.type || !item.actionValue);
      const href = isToggleOnly ? null : this._computeItemHref(item);

      // Template expects 'submenu' on LI if it has children
      let liClass = "";
      if (hasChildren) {
        liClass = "submenu";
      } else if (isActive) {
        liClass = "active";
      }

      // Template expects 'active' and 'subdrop' on A
      const linkClasses = [];
      if (isActive || isExpanded) {
        // expanded usually implies active parent in some templates, or just subdrop
        if (isActive) linkClasses.push("active");
        if (isExpanded) linkClasses.push("subdrop");
      }
      // Add utility class for buttons
      if (isToggleOnly || hasChildren) {
        linkClasses.push("sidebar-toggle-btn");
      }
      const linkClass = linkClasses.join(" ");
      const childId = hasChildren ? `submenu-${item.key}` : null;
      // If it's a toggle-only item, treat as a button. If it's a link, leave role undefined (default to link).
      const itemRole = isToggleOnly ? "button" : undefined;

      return {
        key: String(item.key),
        label: item.label,
        iconClass: item.iconClass || "fa-solid fa-circle fa-fw",
        hasChildren,
        childId,
        itemRole,
        isExpanded,
        isToggleOnly,
        href,
        hrefOrToggle: href || "#",
        liClass,
        linkClass,
        childClass: isExpanded ? "d-block" : "d-none",
        hasBadge: false,
        badgeText: null,
        badgeClass: "",
        children: (item.children || []).map((child) => {
          const childActive = String(this.activeNavKey) === String(child.key);
          const childHref = this._computeItemHref(child);
          return {
            key: String(child.key),
            label: child.label,
            liClass: childActive ? "active" : "",
            linkClass: childActive ? "active" : "",
            href: childHref
          };
        })
      };
    });
  }

  _computeItemHref(item) {
    try {
      const applicationRoute =
        APPLICATION_ROUTES[
          String(item?.label || "")
            .trim()
            .toLowerCase()
        ];
      if (this.isApplicationNavigation && applicationRoute) {
        return `#${applicationRoute}`;
      }

      if (!item?.type || !item?.actionValue) {
        return null;
      }
      if (item.type === "ExternalLink") {
        return item.actionValue;
      }
      if (item.type === "InternalLink") {
        return this.toCommunityWebUrl(item.actionValue);
      }
    } catch {
      // no-op
    }
    return null;
  }

  get sidebarMenuGroups() {
    const items = this.menuRenderItems;
    return [
      {
        key: "main",
        label: this.menuGroupLabelValue,
        items,
        hasItems: Array.isArray(items) && items.length > 0,
        emptyText: "No menu items available",
        emptyKey: "main-empty",
        wrapKey: "main-wrap"
      }
    ];
  }

  handleItemClick(event) {
    const navKey = event?.currentTarget?.dataset?.key;
    const selectedItem = this._allItemsByKey?.[String(navKey)];
    const applicationRoute =
      APPLICATION_ROUTES[
        String(selectedItem?.label || "")
          .trim()
          .toLowerCase()
      ];

    if (this.isApplicationNavigation && applicationRoute) {
      this.activeNavKey = String(navKey);
      this.syncExpandedToActive();
      this._navigateWithinApplication(applicationRoute);
      return;
    }

    try {
      event.preventDefault();
    } catch {
      // no-op
    }

    if (!navKey || !selectedItem) {
      return;
    }

    if (this._shouldToggleParent(selectedItem, event)) {
      this._toggleParent(event, selectedItem.key);
      return;
    }

    this._performNavigation(navKey, selectedItem);
  }

  _shouldToggleParent(item, event) {
    if (!item.children?.length) {
      return false;
    }
    const clickedArrow = event?.target?.closest?.(".menu-arrow");
    return Boolean(clickedArrow || !item.type || !item.actionValue);
  }

  _toggleParent(event, key) {
    try {
      event?.preventDefault();
    } catch {
      // no-op
    }
    this.toggleParentExpanded(key);
  }

  _performNavigation(navKey, item) {
    this.activeNavKey = String(navKey);
    this.syncExpandedToActive();

    const applicationRoute =
      APPLICATION_ROUTES[
        String(item?.label || "")
          .trim()
          .toLowerCase()
      ];
    if (this.applicationMode && applicationRoute) {
      this._navigateWithinApplication(applicationRoute);
      return;
    }

    if (item.type === "InternalLink" || item.type === "ExternalLink") {
      const url =
        item.type === "InternalLink"
          ? this.toCommunityWebUrl(item.actionValue)
          : item.actionValue;

      if (!url) {
        return;
      }

      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: {
          url: url
        }
      });
    } else if (item.type === "SalesforceObject") {
      this[NavigationMixin.Navigate]({
        type: "standard__objectPage",
        attributes: {
          objectApiName: item.actionValue,
          actionName: "home"
        }
      });
    }

    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: navKey },
        bubbles: true,
        composed: true
      })
    );
  }

  _navigateWithinApplication(route) {
    navigateTo(route);
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: route },
        bubbles: true,
        composed: true
      })
    );
  }

  get isApplicationNavigation() {
    return (
      this.applicationMode ||
      String(this.navigationContext || "").toLowerCase() === "application"
    );
  }
}