// Lightweight Bootstrap attribute compatibility for LWC.
//
// This repo uses SmartHR/Bootstrap-inspired markup (e.g., data-bs-toggle="dropdown").
// In Salesforce LWC, Bootstrap JS is not loaded/initialized by default and often
// cannot be safely used due to Locker/LWS restrictions.
//
// This module provides minimal, accessible behavior for:
// - dropdown toggles (data-bs-toggle="dropdown")
// - tooltips (data-bs-toggle="tooltip") via native title attribute
//
// Usage:
//   import { initBootstrapCompat, teardownBootstrapCompat } from 'c/pwchronoBootstrapCompat';
//   renderedCallback() { initBootstrapCompat(this); }
//   disconnectedCallback() { teardownBootstrapCompat(this); }

const ROOT_STATE = new WeakMap();

function getRootElement(rootLike) {
  // Prefer the component root element (works for both shadow and light DOM).
  if (rootLike && typeof rootLike.querySelectorAll === "function") {
    return rootLike;
  }

  // Fallback: allow passing template/shadow root.
  if (rootLike && typeof rootLike.querySelectorAll === "function") {
    return rootLike;
  }

  return null;
}

function closeAllDropdowns(root) {
  const toggles = root.querySelectorAll('[data-bs-toggle="dropdown"]');
  toggles.forEach((toggle) => {
    toggle.classList.remove("show");
    toggle.setAttribute("aria-expanded", "false");
  });

  const menus = root.querySelectorAll(".dropdown-menu.show");
  menus.forEach((m) => m.classList.remove("show"));

  const dropdowns = root.querySelectorAll(".dropdown.show");
  dropdowns.forEach((d) => d.classList.remove("show"));
}

function isEventInsideRoot(event, root) {
  try {
    const path =
      typeof event.composedPath === "function" ? event.composedPath() : null;
    if (Array.isArray(path)) {
      return path.includes(root);
    }
  } catch {
    // ignore
  }

  // Fallback check (best-effort)
  const target = event && event.target;
  return !!(
    target &&
    typeof root.contains === "function" &&
    root.contains(target)
  );
}

export function initBootstrapCompat(rootLike) {
  const root = getRootElement(rootLike);
  if (!root) return;

  // Tooltip: map data-bs-original-title -> title (native tooltip).
  root.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => {
    if (el.dataset.pwchronoTooltipInit === "true") return;
    el.dataset.pwchronoTooltipInit = "true";

    const existingTitle = el.getAttribute("title");
    if (existingTitle) return;

    const original = el.getAttribute("data-bs-original-title");
    if (original) {
      el.setAttribute("title", original);
    }
  });

  // Dropdown toggles.
  root.querySelectorAll('[data-bs-toggle="dropdown"]').forEach((toggle) => {
    if (toggle.dataset.pwchronoDropdownInit === "true") return;
    toggle.dataset.pwchronoDropdownInit = "true";

    // Ensure a11y defaults.
    if (!toggle.hasAttribute("aria-expanded")) {
      toggle.setAttribute("aria-expanded", "false");
    }
    if (!toggle.hasAttribute("aria-haspopup")) {
      toggle.setAttribute("aria-haspopup", "true");
    }

    const onToggleClick = (event) => {
      // Stop click-outside handler from immediately closing.
      event?.stopPropagation?.();

      // For <a href="#"> etc.
      if (toggle.tagName === "A") {
        event?.preventDefault?.();
      }

      const dropdown = toggle.closest(".dropdown");
      const menu = dropdown ? dropdown.querySelector(".dropdown-menu") : null;
      if (!menu) return;

      const isOpen = menu.classList.contains("show");
      closeAllDropdowns(root);

      if (!isOpen) {
        dropdown?.classList?.add("show");
        toggle.classList.add("show");
        menu.classList.add("show");
        toggle.setAttribute("aria-expanded", "true");
      }
    };

    toggle.addEventListener("click", onToggleClick);

    const state = ROOT_STATE.get(root) || {
      elementListeners: [],
      documentListeners: null
    };
    state.elementListeners.push({
      el: toggle,
      type: "click",
      fn: onToggleClick
    });
    ROOT_STATE.set(root, state);
  });

  // One document-level click/keydown handler per root.
  const existing = ROOT_STATE.get(root);
  if (existing && existing.documentListeners) {
    return;
  }

  const onDocClick = (event) => {
    if (isEventInsideRoot(event, root)) return;
    closeAllDropdowns(root);
  };

  const onDocKeydown = (event) => {
    if (event && event.key === "Escape") {
      closeAllDropdowns(root);
    }
  };

  document.addEventListener("click", onDocClick);
  document.addEventListener("keydown", onDocKeydown);

  const state = existing || { elementListeners: [], documentListeners: null };
  state.documentListeners = [
    { type: "click", fn: onDocClick },
    { type: "keydown", fn: onDocKeydown }
  ];
  ROOT_STATE.set(root, state);
}

export function teardownBootstrapCompat(rootLike) {
  const root = getRootElement(rootLike);
  if (!root) return;

  const state = ROOT_STATE.get(root);
  if (!state) return;

  // Remove element listeners
  (state.elementListeners || []).forEach(({ el, type, fn }) => {
    try {
      el?.removeEventListener?.(type, fn);
    } catch {
      // ignore
    }
  });

  // Remove document listeners
  (state.documentListeners || []).forEach(({ type, fn }) => {
    try {
      document.removeEventListener(type, fn);
    } catch {
      // ignore
    }
  });

  ROOT_STATE.delete(root);
}