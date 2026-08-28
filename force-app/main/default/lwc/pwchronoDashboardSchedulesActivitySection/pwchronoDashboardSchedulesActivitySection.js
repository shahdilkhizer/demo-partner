import { LightningElement, api } from "lwc";

export default class PwchronoDashboardSchedulesActivitySection extends LightningElement {
  @api schedules;
  @api activities;
  @api isLoadingActivities = false;

  get skeletonItems() {
    return [1, 2, 3, 4];
  }

  get normalizedSchedules() {
    const list = Array.isArray(this.schedules) ? this.schedules : [];
    return list.map((sch, idx) => {
      const isLast = idx === list.length - 1;
      return {
        ...sch,
        itemClass: `schedule-list${isLast ? "" : " mb-4"}`,
        badgeClass:
          idx % 2 === 0
            ? "badge badge-soft-warning badge-xs mb-2"
            : "badge badge-soft-success badge-xs mb-2"
      };
    });
  }

  get normalizedActivities() {
    const list = Array.isArray(this.activities) ? this.activities : [];
    return list.map((a) => {
      const name = a?.name || a?.title || "Activity";
      return {
        ...a,
        name,
        initials: this.getInitials(name)
      };
    });
  }

  getInitials(name) {
    const n = (name || "").toString().trim();
    if (!n) return "";
    const parts = n.split(/\s+/).filter(Boolean);
    const first = parts[0]?.[0] || "";
    const last = parts.length > 1 ? parts[parts.length - 1]?.[0] || "" : "";
    return (first + last).toUpperCase();
  }

  handleViewAllActivities() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "activities" },
        bubbles: true,
        composed: true
      })
    );
  }

  handleViewAllSchedules() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "schedules" },
        bubbles: true,
        composed: true
      })
    );
  }

  handleNoop(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
  }
}