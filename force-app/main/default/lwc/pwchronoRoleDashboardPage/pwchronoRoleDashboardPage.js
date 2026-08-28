import { getSession, SESSION_CHANGED_EVENT } from "c/pwchronoSession";
import { LightningElement } from "lwc";

export default class PwchronoRoleDashboardPage extends LightningElement {
  static renderMode = "light";

  role;
  isLoggedIn = false;

  sessionChangedHandler;

  refreshFromSession() {
    const { user, isLoggedIn } = getSession();
    this.isLoggedIn = !!isLoggedIn;
    this.role = user?.Role__c || null;
  }

  connectedCallback() {
    this.refreshFromSession();

    this.sessionChangedHandler = () => {
      this.refreshFromSession();
    };

    try {
      const w = globalThis?.window ?? globalThis;
      if (w?.addEventListener) {
        w.addEventListener(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
      }
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      if (w?.removeEventListener && this.sessionChangedHandler) {
        w.removeEventListener(
          SESSION_CHANGED_EVENT,
          this.sessionChangedHandler
        );
      }
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  get isAdmin() {
    return this.isLoggedIn && this.role === "HR Admin";
  }

  get isManager() {
    return this.isLoggedIn && this.role === "Manager";
  }

  get isProjectManager() {
    return this.isLoggedIn && this.role === "Project Manager";
  }

  get isEmployee() {
    // Default to Employee dashboard if role is missing/unrecognized.
    return (
      this.isLoggedIn &&
      !this.isAdmin &&
      !this.isManager &&
      !this.isProjectManager
    );
  }
}