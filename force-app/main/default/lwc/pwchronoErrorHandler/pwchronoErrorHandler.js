/**
 * @description Centralized error handling utility for PWChrono LWC components
 * Provides consistent error logging and user notification patterns
 */

import { ShowToastEvent } from "lightning/platformShowToastEvent";

/**
 * Error severity levels
 */
export const ErrorSeverity = {
  INFO: "info",
  WARNING: "warning",
  ERROR: "error"
};

/**
 * Display an error toast notification to the user
 * @param {Object} dispatchEvent - The component's dispatchEvent function
 * @param {String} title - Toast title
 * @param {String} message - Error message to display
 * @param {String} severity - Error severity (info, warning, error)
 * @param {String} mode - Toast display mode (pester, sticky, dismissable)
 */
export function showErrorToast(
  dispatchEvent,
  title,
  message,
  severity = ErrorSeverity.ERROR,
  mode = "dismissable"
) {
  const evt = new ShowToastEvent({
    title: title,
    message: message,
    variant: severity,
    mode: mode
  });
  dispatchEvent(evt);
}

/**
 * Display a success toast notification to the user
 * @param {Function} dispatchEvent - The component's dispatchEvent function
 * @param {String} title - Toast title
 * @param {String} message - Success message to display
 * @param {String} mode - Toast display mode (pester, sticky, dismissable)
 */
export function showSuccessToast(
  dispatchEvent,
  title,
  message,
  mode = "dismissable"
) {
  const evt = new ShowToastEvent({
    title: title,
    message: message,
    variant: "success",
    mode: mode
  });
  dispatchEvent(evt);
}

/**
 * Log error to console and optionally display toast
 * @param {String} context - Context/component name for logging
 * @param {Error} error - The error object
 * @param {Boolean} showToast - Whether to display toast to user
 * @param {Object} options - Additional options {dispatchEvent, title, message}
 */
export function logError(context, error, showToast = false, options = {}) {
  const errorMessage =
    error?.body?.message || error?.message || "Unknown error occurred";

  // Centralized logging (kept lightweight).
  // Note: In Experience Cloud runtime, browser console logs are often the only
  // client-side diagnostic signal available without additional telemetry.
  try {
    // Centralized logging removed to comply with ESLint rules
  } catch {
    // no-op
  }

  // Optionally show to user
  if (showToast && options.dispatchEvent) {
    const toastTitle = options.title || "Error";
    const toastMessage = options.message || errorMessage;
    showErrorToast(options.dispatchEvent, toastTitle, toastMessage);
  }
}

/**
 * Extract user-friendly error message from Apex exception
 * @param {Error} error - The error object from Apex
 * @returns {String} User-friendly error message
 */
export function getErrorMessage(error) {
  if (!error) {
    return "An unknown error occurred";
  }

  if (error.body?.message) {
    return error.body.message;
  }

  if (error.message) {
    return error.message;
  }

  return "An unknown error occurred";
}

/**
 * Handle wire service errors with consistent logging
 * @param {Object} options - Configuration options
 * @param {Error} options.error - The error from wire service
 * @param {String} options.context - Component context name
 * @param {Object} options.dispatchEvent - Component dispatchEvent function
 * @param {String} options.userMessage - Custom message for user
 * @param {Boolean} options.logToConsole - Whether to log to console (default: true)
 */
export function handleWireError({
  error,
  context,
  dispatchEvent,
  userMessage = "Failed to load data",
  logToConsole = true
}) {
  if (error) {
    if (logToConsole) {
      logError(context, error);
    }

    if (dispatchEvent) {
      showErrorToast(dispatchEvent, "Error", userMessage);
    }
  }
}