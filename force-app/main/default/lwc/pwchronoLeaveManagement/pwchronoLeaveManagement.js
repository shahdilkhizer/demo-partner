import { LightningElement, track } from "lwc";

export default class PwchronoLeaveManagement extends LightningElement {
  static renderMode = "light";

  @track selectedLeaveId = null;

  get isDetailView() {
    return !!this.selectedLeaveId;
  }

  handleNewLeave() {
    const appComp = this.template.querySelector("c-pwchrono-leave-application");
    if (appComp && typeof appComp.open === "function") {
      appComp.open();
    }
  }

  handleLeaveApplied() {
    // Refresh child components by forcing re-render
    this.selectedLeaveId = null;
  }

  handleViewDetail(event) {
    this.selectedLeaveId = event.detail.leaveId;
  }

  handleBackToList() {
    this.selectedLeaveId = null;
  }

  handleLeaveActioned() {
    // Go back to list and let children refresh
    this.selectedLeaveId = null;
  }
}