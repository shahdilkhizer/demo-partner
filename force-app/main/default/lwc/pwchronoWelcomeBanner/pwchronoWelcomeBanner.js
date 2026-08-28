import { LightningElement, api } from "lwc";
import { getSession } from "c/pwchronoSession";

export default class PwchronoWelcomeBanner extends LightningElement {
  @api userName;
  @api pendingApprovals = 0;
  @api leaveRequests = 0;
  @api userPhoto;

  get displayUserName() {
    const provided = (this.userName || "").trim();
    const looksGuest = /\bguest user\b/i.test(provided) || provided === "";

    if (!looksGuest) {
      return provided;
    }

    try {
      const session = getSession();
      const sName = (session?.user?.Name || session?.user?.name || "").trim();
      return sName || provided;
    } catch {
      return provided;
    }
  }

  handleAddProject() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "projects", action: "new" },
        bubbles: true,
        composed: true
      })
    );
  }

  handleAddRequests() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "leave-request", action: "new" },
        bubbles: true,
        composed: true
      })
    );
  }
}