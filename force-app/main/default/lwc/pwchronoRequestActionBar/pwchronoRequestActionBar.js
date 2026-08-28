import { LightningElement, api } from "lwc";

export default class PwchronoRequestActionBar extends LightningElement {
  static renderMode = "light";

  @api status = "";
  @api isApprover = false;
  @api isOwner = false;

  showReasonModal = false;
  pendingAction = "";
  reasonText = "";

  // ── Visibility Computed ──

  get showActions() {
    return this.canApprove || this.canReject || this.canCancel;
  }

  get canApprove() {
    return (
      this.isApprover &&
      (this.status === "Submitted" || this.status === "Pending")
    );
  }

  get canReject() {
    return this.canApprove;
  }

  get canCancel() {
    return (
      this.isOwner &&
      (this.status === "Submitted" ||
        this.status === "Pending" ||
        this.status === "Approved")
    );
  }

  // ── Modal Computed ──

  get modalTitle() {
    return this.pendingAction === "Reject" ? "Reject Request" : "Cancel Request";
  }

  get reasonLabel() {
    return this.pendingAction === "Reject" ? "Rejection Reason" : "Cancellation Reason";
  }

  get reasonPlaceholder() {
    return this.pendingAction === "Reject"
      ? "Please provide a reason for rejection..."
      : "Please provide a reason for cancellation...";
  }

  get confirmButtonLabel() {
    return this.pendingAction === "Reject" ? "Confirm Rejection" : "Confirm Cancellation";
  }

  get confirmButtonClass() {
    return this.pendingAction === "Reject" ? "btn btn-danger" : "btn btn-warning";
  }

  get isReasonEmpty() {
    return !this.reasonText || this.reasonText.trim().length === 0;
  }

  // ── Handlers ──

  handleApprove() {
    this.dispatchEvent(
      new CustomEvent("requestaction", {
        detail: { action: "Approve", comments: "" }
      })
    );
  }

  handleRejectClick() {
    this.pendingAction = "Reject";
    this.reasonText = "";
    this.showReasonModal = true;
  }

  handleCancelClick() {
    this.pendingAction = "Cancel";
    this.reasonText = "";
    this.showReasonModal = true;
  }

  handleReasonChange(event) {
    this.reasonText = event.target.value;
  }

  handleConfirmAction() {
    this.dispatchEvent(
      new CustomEvent("requestaction", {
        detail: {
          action: this.pendingAction,
          comments: this.reasonText.trim()
        }
      })
    );
    this.handleCloseModal();
  }

  handleCloseModal() {
    this.showReasonModal = false;
    this.pendingAction = "";
    this.reasonText = "";
  }
}