import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getCurrentUserContext from "@salesforce/apex/PWChrono_AuthController.getCurrentUserContext";
import { navigateTo } from "c/pwchronoRouter";
import {
  clearSession,
  getEmployeeId,
  getSession,
  getSessionToken,
  setSession
} from "c/pwchronoSession";
import { NavigationMixin } from "lightning/navigation";
import { LightningElement, track } from "lwc";

export default class PwchronoMainLayout extends NavigationMixin(
  LightningElement
) {
  uiAssetsLoadedKey = "__pwchronoUiAssetsLoaded";
  @track isUiReady = false;
  @track isAuthChecked = false;
  @track isLoggedIn = false;
  @track isExperienceBuilder = false;
  @track user;
  @track permissions;
  @track features = [];
  @track isSalesforceUser = false;
  @track isLightningExperience = false;

  sessionToken;

  connectedCallback() {
    this.sessionToken = getSessionToken();
    this.isUiReady = Boolean(globalThis[this.uiAssetsLoadedKey]);

    // Safety fallback: if asset loading takes too long (>2.5s), display the page
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this.isUiReady = true;
      this.isAuthChecked = true;
    }, 2500);

    // If we're embedded inside Salesforce Lightning Experience (tabs/app pages),
    // don't render the portal chrome (header/sidebar) because Salesforce already provides navigation.
    const path = globalThis.location?.pathname || "";
    const isLightning =
      path.startsWith("/lightning/") ||
      path === "/one/one.app" ||
      path.startsWith("/apex/");
    const isLightningSetup = path.startsWith("/lightning/setup/");

    // Experience Builder (and its Live Preview) are hosted under /lightning/setup/...
    // We still want to render the portal chrome there for design/preview.
    this.isExperienceBuilder = isLightningSetup;

    // Important: Experience Builder runs under /lightning/setup/... but we still
    // want to render the portal chrome in Builder/Live Preview.
    this.isLightningExperience = isLightning && !isLightningSetup;

    this.checkLoginStatus();
  }

  handleAssetsReady() {
    this.isUiReady = true;
  }

  get isPageReady() {
    if (this.isExperienceBuilder || this.isLightningExperience) {
      return true;
    }
    return this.isUiReady && this.isAuthChecked;
  }

  get globalLoaderStyle() {
    if (this.isPageReady) {
      return "display: none !important;";
    }
    return [
      "position: fixed",
      "inset: 0",
      "z-index: 9999999",
      "display: flex",
      "flex-direction: column",
      "align-items: center",
      "justify-content: center",
      "background-color: #ffffff",
      "transition: opacity 0.3s ease-out"
    ].join("; ");
  }

  get mainWrapperStyle() {
    if (this.isPageReady) {
      return "opacity: 1; transition: opacity 0.25s ease-in-out;";
    }
    return "visibility: hidden; opacity: 0; pointer-events: none;";
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

  redirectToLoginIfNeeded() {
    // With custom OTP auth, we keep Experience routes Public and enforce login client-side.
    // Only redirect when we're in the portal (not Lightning Experience) and NOT already on /login.
    try {
      if (this.isLightningExperience || this.isLoginRoute) return;

      const base = this.getCommunityBasePath();
      const targetPath = base ? `${base}/login` : "/login";

      // Avoid unnecessary navigation loops.
      const current = globalThis.location?.pathname || "";
      if (current.endsWith("/login") || current.includes("/login/")) return;

      globalThis.location?.replace(targetPath);
    } catch {
      // no-op
    }
  }

  navigateToLanding() {
    // Target Experience route apiName.
    const namedPage = "Home";

    try {
      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: { name: namedPage }
      });
    } catch {
      // no-op
    }

    // Fallback: if SPA navigation doesn't update the URL, force a hard redirect
    // to the community home route (/s/).
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      try {
        const p = globalThis.location?.pathname || "";
        if (p.endsWith("/login") || p.includes("/login/")) {
          const base = this.getCommunityBasePath();
          const targetUrl = base ? `${base}/` : "/";
          globalThis.location?.assign(targetUrl);
        }
      } catch {
        // no-op
      }
    }, 700);
  }

  get showPortalChrome() {
    return !this.isLightningExperience && !this.isLoginRoute;
  }

  get shouldRenderPortalChrome() {
    // In the real portal runtime, only show chrome once the custom session is established.
    // In Experience Builder/Live Preview, allow chrome to render so it can be styled/inspected.
    return (
      this.showPortalChrome && (this.isLoggedIn || this.isExperienceBuilder)
    );
  }

  get isLoginRoute() {
    try {
      const path = globalThis.location?.pathname || "";
      // Site uses /PulseWorkChrono/login (no /s). Be tolerant of trailing slash.
      return /\/login\/?$/.test(path);
    } catch {
      return false;
    }
  }

  async checkLoginStatus() {
    try {
      const session = getSession();

      if (session.isLoggedIn) {
        this.setSessionState(session.user, session.permissions);
        await this.loadFeatureAccess(getEmployeeId());
      } else {
        await this.attemptAutoBootstrap();
      }
    } finally {
      this.isAuthChecked = true;
    }
  }

  setSessionState(user, permissions) {
    this.user = user;
    this.permissions = permissions;
    this.isLoggedIn = true;
  }

  async loadFeatureAccess(employeeId) {
    try {
      const accessData = await getUserAccessById({
        employeeId: employeeId || null,
        sessionToken: this.sessionToken
      });
      if (accessData?.hasAccess) {
        this.features = accessData.features || [];
        this.isSalesforceUser = accessData.isSalesforceUser || false;
      } else {
        this.features = [];
        this.isSalesforceUser = false;
      }
    } catch {
      this.features = [];
      this.isSalesforceUser = false;
    }
  }

  async attemptAutoBootstrap() {
    try {
      const ctx = await getCurrentUserContext();
      if (ctx?.user && ctx?.permissions) {
        setSession(ctx.user, ctx.permissions, null);
        this.setSessionState(ctx.user, ctx.permissions);
        await this.loadFeatureAccess(ctx.user?.Id);
        return;
      }

      // Fallback: Check if internal Salesforce user without map
      await this.attemptInternalUserFallback();
    } catch {
      this.handleLoginFailure();
    }
  }

  async attemptInternalUserFallback() {
    try {
      const accessData = await getUserAccessById({ employeeId: null });
      if (accessData?.hasAccess && accessData?.isSalesforceUser) {
        const mockUser = { Id: "sf-user", Name: "Salesforce User" };
        setSession(mockUser, {}, null);
        this.setSessionState(mockUser, {});

        this.features = accessData.features || [];
        this.isSalesforceUser = true;
        return;
      }
    } catch {
      // Fall through to failure
    }
    this.handleLoginFailure();
  }

  handleLoginFailure() {
    this.isLoggedIn = false;
    this.redirectToLoginIfNeeded();
  }
  handleLogout() {
    clearSession();
    this.isLoggedIn = false;
    this.user = null;
    this.permissions = null;
    navigateTo("");

    // For OTP-only portal auth, ensure we actually land on the login route.
    this.redirectToLoginIfNeeded();
  }

  handleSidebarToggle(event) {
    const mode = event?.detail?.mode;

    // Mobile toggle is the slide-in drawer
    if (mode === "mobile") {
      document.body.classList.toggle("slide-nav");
      return;
    }

    // Desktop toggle collapses to "mini-sidebar"
    document.body.classList.toggle("mini-sidebar");
  }

  handleHeaderNavigate(event) {
    const page = event.detail.page;
    const action = event.detail.action;

    if (action === "my_profile" || page === "profile") {
      navigateTo("profile");
      return;
    }

    if (action === "chat") {
      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: {
          name: "Chat__c"
        }
      });
      return;
    }

    let pageName;

    switch (page) {
      case "settings":
        pageName = "Settings__c"; // Assuming a custom page for settings
        break;
      case "inbox":
        pageName = "Inbox__c"; // Assuming a custom page for inbox
        break;
      case "chat":
        pageName = "Chat__c";
        break;
      default:
        return;
    }

    if (pageName) {
      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: {
          name: pageName
        }
      });
    }
  }
}