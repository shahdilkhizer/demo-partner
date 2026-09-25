import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getCurrentUserContext from "@salesforce/apex/PWChrono_AuthController.getCurrentUserContext";
import revokePortalSession from "@salesforce/apex/PWChrono_AuthController.revokePortalSession";
import {
  clearSession,
  getEmployeeId,
  getFeatures,
  getSession,
  getSessionToken,
  setFeatures,
  setSession,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { NavigationMixin } from "lightning/navigation";
import { api, LightningElement, track } from "lwc";

export default class PwchronoMainLayout extends NavigationMixin(
  LightningElement
) {
  static renderMode = "light";

  @api forcePortalChrome = false;
  @api applicationMode = false;
  @api navigationContext;
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
  logoutPending = false;
  logoutError = "";
  menuSearchTerm = "";
  sessionTimer;
  assetsTimer;
  sessionCheckPending = false;
  handleSessionChanged = () => {
    if (this.isExperienceBuilder || this.isLightningExperience) return;
    if (!getSession().isLoggedIn) {
      this.handleLoginFailure();
      return;
    }
    this.checkActiveSession();
  };
  handleSessionFocus = () => {
    if (document.visibilityState !== "hidden") this.checkActiveSession();
  };

  disconnectedCallback() {
    clearTimeout(this.sessionTimer);
    clearTimeout(this.assetsTimer);
    window.removeEventListener(
      SESSION_CHANGED_EVENT,
      this.handleSessionChanged
    );
    window.removeEventListener("focus", this.handleSessionFocus);
    document.removeEventListener("visibilitychange", this.handleSessionFocus);
  }

  scheduleSessionCheck() {
    clearTimeout(this.sessionTimer);
    if (
      !this.isConnected ||
      !this.isLoggedIn ||
      this.isExperienceBuilder ||
      this.isLightningExperience ||
      this.isLoginRoute
    )
      return;
    const session = getSession();
    const expiresAt = Date.parse(session.user?.Session_Expires_At__c);
    const delay =
      session.sessionToken && Number.isFinite(expiresAt)
        ? Math.max(0, Math.min(60000, expiresAt - Date.now()))
        : 60000;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.sessionTimer = setTimeout(() => this.checkActiveSession(), delay);
  }

  async checkActiveSession() {
    if (
      !this.isConnected ||
      this.isExperienceBuilder ||
      this.isLightningExperience ||
      this.isLoginRoute
    )
      return;
    const session = getSession();
    const expiresAt = Date.parse(session.user?.Session_Expires_At__c);
    if (
      !session.isLoggedIn ||
      (Number.isFinite(expiresAt) && !session.sessionToken) ||
      (session.sessionToken &&
        Number.isFinite(expiresAt) &&
        expiresAt <= Date.now())
    ) {
      this.handleLoginFailure();
      return;
    }
    // Keep the expiry clock running even if a server request stalls.
    this.scheduleSessionCheck();
    if (this.sessionCheckPending) return;
    this.sessionCheckPending = true;
    this.sessionToken = session.sessionToken;
    try {
      await this.loadFeatureAccess(session.user?.Id);
    } finally {
      this.sessionCheckPending = false;
      this.scheduleSessionCheck();
    }
  }

  connectedCallback() {
    this.sessionToken = getSessionToken();
    this.isUiReady = Boolean(globalThis[this.uiAssetsLoadedKey]);

    // Populate cached session state immediately to prevent layout shifts
    const session = getSession();
    if (session.isLoggedIn) {
      this.setSessionState(session.user, session.permissions);
      if (session.features && session.features.length) {
        this.features = session.features;
      }
    }

    // Safety fallback: if asset loading takes too long (>2.5s), display the page
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.assetsTimer = setTimeout(() => {
      this.isUiReady = true;
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

    window.addEventListener(SESSION_CHANGED_EVENT, this.handleSessionChanged);
    window.addEventListener("focus", this.handleSessionFocus);
    document.addEventListener("visibilitychange", this.handleSessionFocus);
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
      if (
        this.isExperienceBuilder ||
        this.isLightningExperience ||
        this.isLoginRoute
      )
        return;

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
    return (
      this.forcePortalChrome ||
      (!this.isLightningExperience && !this.isLoginRoute)
    );
  }

  get applicationNavigationEnabled() {
    return (
      this.applicationMode ||
      this.navigationContext === "application" ||
      (this.forcePortalChrome && this.isLightningExperience)
    );
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
        if (session.features && session.features.length) {
          this.features = session.features;
        }
        // Optimistic UI rendering: Mark auth checked immediately so page renders without blocking loader
        this.isAuthChecked = true;

        if (this.isExperienceBuilder || this.isLightningExperience) {
          await this.loadFeatureAccess(getEmployeeId());
        } else {
          // Verify session in background asynchronously (Stale-While-Revalidate pattern)
          this.checkActiveSession();
        }
      } else {
        await this.attemptAutoBootstrap();
        this.isAuthChecked = true;
      }
    } finally {
      this.isAuthChecked = true;
      this.scheduleSessionCheck();
    }
  }

  setSessionState(user, permissions) {
    this.user = user;
    this.permissions = permissions;
    this.isLoggedIn = true;
  }

  async loadFeatureAccess(employeeId) {
    const requestToken = this.sessionToken;
    const requestUserId = getEmployeeId();
    const isCurrent = () =>
      this.isConnected &&
      requestToken === getSessionToken() &&
      requestUserId === getEmployeeId();
    try {
      const accessData = await getUserAccessById({
        employeeId: employeeId || null,
        sessionToken: requestToken
      });
      if (!isCurrent()) return;
      if (accessData?.hasAccess) {
        this.features = accessData.features || [];
        this.isSalesforceUser = accessData.isSalesforceUser || false;
        setFeatures(this.features);
      } else {
        this.features = [];
        this.isSalesforceUser = false;
        setFeatures([]);
      }
    } catch (error) {
      if (!isCurrent()) return;
      this.features = [];
      this.isSalesforceUser = false;
      const bodies = Array.isArray(error?.body) ? error.body : [error?.body];
      const messages = [...bodies.map((body) => body?.message), error?.message];
      if (
        messages.some((message) =>
          /session (?:invalid|expired)|invalid session attempts|account is inactive|INVALID_SESSION_ID/i.test(
            message || ""
          )
        )
      ) {
        this.handleLoginFailure();
      }
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
        setFeatures(this.features);
        return;
      }
    } catch {
      // Fall through to failure
    }
    this.handleLoginFailure();
  }

  handleLoginFailure() {
    if (this.isExperienceBuilder || this.isLightningExperience) return;
    clearTimeout(this.sessionTimer);
    this.isLoggedIn = false;
    this.user = null;
    this.permissions = null;
    this.features = [];
    this.sessionToken = null;
    this.isSalesforceUser = false;
    // clearSession emits synchronously; avoid recursively handling our own event.
    window.removeEventListener(
      SESSION_CHANGED_EVENT,
      this.handleSessionChanged
    );
    clearSession();
    window.addEventListener(SESSION_CHANGED_EVENT, this.handleSessionChanged);
    this.redirectToLoginIfNeeded();
  }
  async handleLogout(event) {
    event?.stopPropagation();
    if (this.logoutPending) return;
    this.logoutPending = true;
    this.logoutError = "";
    const session = getSession();
    try {
      if (session.sessionToken) {
        await revokePortalSession({
          portalUserId: session.user?.Id,
          sessionToken: session.sessionToken
        });
      }
      // A delayed logout response must not clear a newly established session.
      if (
        getSessionToken() === session.sessionToken &&
        getEmployeeId() === session.user?.Id
      ) {
        if (this.isLightningExperience || this.isExperienceBuilder) {
          clearSession();
          this.isLoggedIn = false;
          this.user = null;
          this.permissions = null;
        } else this.handleLoginFailure();
      }
    } catch {
      this.logoutError =
        "We couldn't complete sign out. Check your connection and try Log Out again.";
    } finally {
      this.logoutPending = false;
    }
  }

  handleMenuSearch(event) {
    this.menuSearchTerm = event.detail?.searchTerm || "";
  }

  handleSidebarOverlayClick() {
    document.body.classList.remove("slide-nav");
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

  handleChildNavigate(event) {
    const page = event.detail?.page;
    const action = event.detail?.action;

    event.stopPropagation();

    // Use a distinct boundary event. Re-emitting `navigate` while handling
    // `navigate` makes ownership ambiguous for nested/light DOM components.
    this.dispatchEvent(
      new CustomEvent("appnavigate", {
        detail: { page: page, action: action },
        bubbles: true,
        composed: true
      })
    );

    if (this.applicationNavigationEnabled) {
      return;
    }

    if (action === "my_profile" || page === "profile") {
      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: { name: "User_Profile__c" }
      });
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