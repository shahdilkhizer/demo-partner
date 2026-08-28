import { LightningElement, api } from "lwc";

/**
 * A reusable card for displaying key statistics with a title, value, icon, and trend.
 * The visual appearance is controlled by the 'variant' property.
 */
export default class PwchronoStatCard extends LightningElement {
  @api title;
  @api value;
  @api trend; // e.g., 5.4 or -2.1
  // Backward-compatibility: this property is declared in the component's
  // js-meta.xml for Builder configuration.
  //
  // We do NOT rely on SLDS icons here; if provided, this can be a global icon
  // font class list (e.g., "ti ti-users fs-16" or "fa-solid fa-user").
  @api iconName;
  @api variant = "info"; // 'success', 'warning', 'danger', 'info'
  @api linkText = "View Details"; // Link text at bottom

  get avatarClass() {
    const bg = this.variantBackgroundClass;
    return `avatar rounded-circle ${bg} mb-2`;
  }

  get variantBackgroundClass() {
    switch ((this.variant || "").toLowerCase()) {
      case "success":
        return "bg-success";
      case "warning":
        return "bg-warning";
      case "danger":
        return "bg-danger";
      case "secondary":
        return "bg-secondary";
      case "pink":
        return "bg-pink";
      case "purple":
        return "bg-purple";
      case "dark":
        return "bg-dark";
      case "info":
      default:
        return "bg-primary";
    }
  }

  get iconClass() {
    const configured = (this.iconName || "").trim();
    // Allow passing global icon classes via the existing "iconName" input.
    // If it's an SLDS-style icon name like "utility:up", we intentionally
    // ignore it (head CSS + icon fonts are the styling source for this project).
    if (configured && !configured.includes(":")) {
      return configured;
    }

    // Prefer stable, global icon font classes (as used in Temp.html).
    // Map by title when possible; fall back by variant.
    const t = (this.title || "").toLowerCase();
    if (t.includes("attendance")) return "fa-solid fa-calendar-check fs-16";
    if (t.includes("project")) return "fa-solid fa-diagram-project fs-16";
    if (t.includes("client")) return "fa-solid fa-users fs-16";
    if (t.includes("task")) return "fa-solid fa-list-check fs-16";
    if (t.includes("earning") || t.includes("invoice"))
      return "fa-solid fa-money-bill-wave fs-16";
    if (t.includes("job")) return "fa-solid fa-users fs-16";
    if (t.includes("hire")) return "fa-solid fa-user-plus fs-16";
    return "fa-solid fa-chart-line fs-16";
  }

  get hasTrend() {
    return this.trend !== null && this.trend !== undefined;
  }

  get isTrendPositive() {
    return this.hasTrend && Number.parseFloat(this.trend) >= 0;
  }

  get trendLabel() {
    return `${Math.abs(this.trend)}%`;
  }

  get trendTextClass() {
    return this.isTrendPositive
      ? "fs-12 fw-medium text-success"
      : "fs-12 fw-medium text-danger";
  }

  get trendIconClass() {
    // Using Font Awesome caret icons per Temp.html.
    return this.isTrendPositive
      ? "fa-solid fa-caret-up me-1"
      : "fa-solid fa-caret-down me-1";
  }

  // --- Event Handlers ---

  handleViewClick(event) {
    event.preventDefault();
    this.dispatchEvent(
      new CustomEvent("viewdetails", {
        detail: { title: this.title }
      })
    );
  }
}