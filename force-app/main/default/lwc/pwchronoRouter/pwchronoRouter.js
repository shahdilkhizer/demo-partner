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
  PROFILE: "profile",
  CONFIGURATION: "configuration",
  CHAT: "chat",
  PAYROLL: "payroll",
  RECRUITMENT: "recruitment",
  PERFORMANCE: "performance",
  TRAINING: "training"
};

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