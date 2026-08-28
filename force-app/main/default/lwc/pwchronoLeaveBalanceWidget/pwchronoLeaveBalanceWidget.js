import { LightningElement, wire, track } from "lwc";
import getMyLeaveBalance from "@salesforce/apex/PWChrono_LeaveController.getMyLeaveBalance";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoLeaveBalanceWidget extends LightningElement {
  @track balances = [];
  @track isLoading = true;
  @track loadError = null;

  @track employeeId;
  @track sessionToken;

  connectedCallback() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getMyLeaveBalance, {
    employeeId: "$employeeId",
    sessionToken: "$sessionToken"
  })
  wiredBalances({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.balances = data;
      this.loadError = null;
    } else if (error) {
      this.loadError =
        error?.body?.message ||
        error?.message ||
        "Failed to load leave balances";
      this.balances = [];
    }
  }

  get hasBalances() {
    return this.balances && this.balances.length > 0;
  }
}