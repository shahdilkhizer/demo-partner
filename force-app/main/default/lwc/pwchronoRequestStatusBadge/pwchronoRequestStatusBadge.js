import { LightningElement, api } from "lwc";

const STATUS_BADGE_MAP = {
  Draft: "badge badge-soft-secondary border border-secondary",
  Submitted: "badge badge-soft-info border border-info",
  Pending: "badge badge-soft-info border border-info",
  Approved: "badge badge-soft-success border border-success",
  Rejected: "badge badge-soft-danger border border-danger",
  Cancelled: "badge badge-soft-warning border border-warning"
};

const DEFAULT_CLASS = "badge badge-soft-secondary border border-secondary";

export default class PwchronoRequestStatusBadge extends LightningElement {
  static renderMode = "light";

  @api status = "";
  @api size = ""; // "sm" for small variant

  get badgeClass() {
    let base = STATUS_BADGE_MAP[this.status] || DEFAULT_CLASS;
    if (this.size === "sm") {
      base += " fs-10";
    }
    return base;
  }
}