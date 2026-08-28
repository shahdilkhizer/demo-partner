import { LightningElement, api } from "lwc";

const ACTION_ICONS = {
  Submitted: "fa-solid fa-paper-plane text-info",
  Approved: "fa-solid fa-check text-success",
  Rejected: "fa-solid fa-xmark text-danger",
  Cancelled: "fa-solid fa-ban text-warning",
  Comment: "fa-solid fa-comment text-primary",
  System: "fa-solid fa-clock-rotate-left text-muted",
  Default: "fa-solid fa-clock-rotate-left text-muted"
};

export default class PwchronoRequestComments extends LightningElement {
  static renderMode = "light";

  /** Array of { key, authorName, text, displayDate, type } */
  @api entries = [];

  /** Whether to show the add-comment input */
  @api allowNewComment = false;

  newComment = "";

  get hasEntries() {
    return this.entries && this.entries.length > 0;
  }

  get entryCount() {
    return this.entries ? this.entries.length : 0;
  }

  get enrichedEntries() {
    if (!this.entries) {
      return [];
    }
    return this.entries.map((e) => ({
      ...e,
      iconClass: ACTION_ICONS[e.type] || ACTION_ICONS.Default
    }));
  }

  get isCommentEmpty() {
    return !this.newComment || this.newComment.trim().length === 0;
  }

  handleCommentChange(event) {
    this.newComment = event.target.value;
  }

  handleAddComment() {
    if (this.isCommentEmpty) {
      return;
    }

    this.dispatchEvent(
      new CustomEvent("newcomment", {
        detail: { text: this.newComment.trim() }
      })
    );
    this.newComment = "";
  }
}