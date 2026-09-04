/**
 * Router utility for hash-based URL routing
 * Provides centralized navigation across the portal
 */

// Page constants for consistency
export const PAGES = {
  DASHBOARD: "dashboard",
  ADMIN_DASHBOARD: "admin_dashboard",
  MANAGER_DASHBOARD: "manager_dashboard",
  EMPLOYEE_DASHBOARD: "employee_dashboard",
  LEAVE: "leave",
  ATTENDANCE: "attendance",
  HOLIDAYS: "holidays",
  DIRECTORY: "directory",
  PROFILE: "profile",
  CONFIGURATION: "configuration",
  CHAT: "chat",
  PAYROLL: "payroll",
  RECRUITMENT: "recruitment",
  ONBOARDING: "onboarding",
  PERFORMANCE: "performance",
  GOALS: "goals",
  TRAINING: "training",
  PROJECTS: "projects",
  EXPENSES: "expenses",
  APPROVALS: "approvals",
  POLICIES: "policies",
  REPORTS: "reports"
};

export const APPLICATION_ROUTES = new Set([
  PAGES.DASHBOARD,
  PAGES.ATTENDANCE,
  PAGES.LEAVE,
  PAGES.HOLIDAYS,
  PAGES.DIRECTORY,
  PAGES.RECRUITMENT,
  PAGES.ONBOARDING,
  PAGES.PERFORMANCE,
  PAGES.GOALS,
  PAGES.TRAINING,
  PAGES.PROJECTS,
  PAGES.EXPENSES,
  PAGES.PAYROLL,
  PAGES.APPROVALS,
  PAGES.POLICIES,
  PAGES.REPORTS,
  PAGES.PROFILE,
  PAGES.CONFIGURATION
]);

export const APPLICATION_ROUTE_ALIASES = {
  "attendance management": PAGES.ATTENDANCE,
  "attendance employee": PAGES.ATTENDANCE,
  "leave management": PAGES.LEAVE,
  leaves: PAGES.LEAVE,
  "employee directory": PAGES.DIRECTORY,
  "expense management": PAGES.EXPENSES,
  "my profile": PAGES.PROFILE,
  "performance management": PAGES.PERFORMANCE,
  "training management": PAGES.TRAINING,
  "project list": PAGES.PROJECTS,
  "company policies": PAGES.POLICIES,
  "reports dashboard": PAGES.REPORTS,
  administration: PAGES.CONFIGURATION,
  "admin settings": PAGES.CONFIGURATION
};

export function normalizeApplicationRoute(page, fallback = PAGES.DASHBOARD) {
  const requestedRoute = String(page || "")
    .trim()
    .toLowerCase();
  const normalized =
    APPLICATION_ROUTE_ALIASES[requestedRoute] || requestedRoute;
  return APPLICATION_ROUTES.has(normalized) ? normalized : fallback;
}

export function getCurrentPage() {
  const w = globalThis?.window ?? globalThis;
  return w?.location?.hash?.substring(1) || PAGES.EMPLOYEE_DASHBOARD;
}

export function navigateTo(page) {
  const w = globalThis?.window ?? globalThis;
  if (!w?.location) return;
  if (!page) {
    w.location.hash = "";
    return;
  }
  w.location.hash = `#${page}`;
}

export function isPageActive(page) {
  return getCurrentPage() === page;
}

export function onPageChange(callback) {
  // Call immediately with current page
  callback(getCurrentPage());

  // Listen for future changes
  const handler = () => {
    callback(getCurrentPage());
  };

  const w = globalThis?.window ?? globalThis;
  w?.addEventListener?.("hashchange", handler);

  // Return unsubscribe function
  return () => {
    w?.removeEventListener?.("hashchange", handler);
  };
}