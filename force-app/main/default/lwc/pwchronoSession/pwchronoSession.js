const USER_KEY = "portalUser";
const PERM_KEY = "portalPermissions";
const TOKEN_KEY = "portalSessionToken";

// Fired whenever setSession/clearSession mutates the current session.
// Used by pre-rendered tab components to refresh wire params after login completes.
export const SESSION_CHANGED_EVENT = "pwchrono-session-changed";

// In Experience Builder / Live Preview, Locker/Proxies and storage restrictions can cause
// sessionStorage access or JSON (de)serialization to throw. Keep an in-memory fallback
// so the app can still run without hard-crashing the router.
let memorySession = {
  user: null,
  permissions: null,
  sessionToken: null
};

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function safeJsonStringify(value) {
  try {
    return JSON.stringify(value);
  } catch {
    return null;
  }
}

function notifySessionChanged() {
  // In Experience runtime / Locker, window access can be restricted.
  // Treat this as a best-effort signal.
  try {
    const w = globalThis?.window ?? globalThis;
    if (w?.dispatchEvent) {
      w.dispatchEvent(new CustomEvent(SESSION_CHANGED_EVENT));
    }
  } catch {
    // no-op
  }
}

// Security Note: Storing sensitive data in sessionStorage is risky.
// Ideally, use HttpOnly cookies or a secure token mechanism.
// For this implementation, we ensure no critical secrets (like passwords) are stored here.
// The 'user' object should only contain non-sensitive profile info.

export function getSession() {
  try {
    const userText = sessionStorage.getItem(USER_KEY);
    const permText = sessionStorage.getItem(PERM_KEY);
    const tokenText = sessionStorage.getItem(TOKEN_KEY);

    const user = userText ? safeJsonParse(userText) : null;
    const permissions = permText ? safeJsonParse(permText) : null;
    const sessionToken = tokenText || null;

    // If parsing fails (null), fall back to memory.
    const finalUser = user ?? memorySession.user;
    const finalPerms = permissions ?? memorySession.permissions;
    const finalToken = sessionToken ?? memorySession.sessionToken;

    return {
      user: finalUser,
      permissions: finalPerms,
      sessionToken: finalToken,
      isLoggedIn: !!(finalUser && finalPerms)
    };
  } catch {
    // sessionStorage not available (or blocked) - use memory fallback.
    return {
      user: memorySession.user,
      permissions: memorySession.permissions,
      sessionToken: memorySession.sessionToken,
      isLoggedIn: !!(memorySession.user && memorySession.permissions)
    };
  }
}

export function getEmployeeId() {
  const { user } = getSession();
  return user?.Id || null;
}

export function getSessionToken() {
  const { sessionToken } = getSession();
  return sessionToken || null;
}

export function setSession(user, permissions, sessionToken) {
  // IMPORTANT:
  // Never keep raw objects in memorySession, because Apex/Locker can return Proxy-wrapped
  // values in Live Preview. If those Proxies leak into reactive state, LWR's mutation logging
  // can recurse (ownKeys/getOwnPropertyNames) and crash the router.
  //
  // So: store ONLY plain JSON-cloned values in memory.
  const userText = safeJsonStringify(user);
  const permText = safeJsonStringify(permissions);
  const tokenValue = sessionToken ? String(sessionToken) : null;

  memorySession = {
    user: userText ? safeJsonParse(userText) : null,
    permissions: permText ? safeJsonParse(permText) : null,
    sessionToken: tokenValue
  };

  try {
    // Only write to storage if serialization succeeded.
    if (userText) sessionStorage.setItem(USER_KEY, userText);
    if (permText) sessionStorage.setItem(PERM_KEY, permText);
    if (tokenValue) sessionStorage.setItem(TOKEN_KEY, tokenValue);
  } catch {
    // sessionStorage not available; memory fallback is already set.
  }

  notifySessionChanged();
}

export function clearSession() {
  memorySession = { user: null, permissions: null, sessionToken: null };
  try {
    sessionStorage.removeItem(USER_KEY);
    sessionStorage.removeItem(PERM_KEY);
    sessionStorage.removeItem(TOKEN_KEY);
  } catch {
    // sessionStorage not available
  }

  notifySessionChanged();
}

export function hasPermission(objectName, accessType) {
  const { permissions } = getSession();
  return !!permissions?.[objectName]?.[accessType];
}

export function hasFieldPermission(objectName, fieldName, accessType) {
  const { permissions } = getSession();
  return !!permissions?.[objectName]?.fields?.[fieldName]?.[accessType];
}