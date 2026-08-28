import { LightningElement, api } from "lwc";

export default class PwchronoRequestListRow extends LightningElement {
  static renderMode = "light";

  @api recordId = "";
  @api employeeName = "";
  @api requestType = "";
  @api dateRange = "";
  @api daysLabel = "";
  @api reason = "";
  @api status = "";
  @api appliedDate = "";
  @api showApproveReject = false;

  handleApprove() {
    this.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { recordId: this.recordId, action: "Approve" },
        bubbles: true,
        composed: true
      })
    );
  }

  handleReject() {
    this.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { recordId: this.recordId, action: "Reject" },
        bubbles: true,
        composed: true
      })
    );
  }

  handleView() {
    this.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: { recordId: this.recordId, action: "View" },
        bubbles: true,
        composed: true
      })
    );
  }
}