import getSalesforceChatterUrl from "@salesforce/apex/PWChrono_AuthController.getSalesforceChatterUrl";
import isGuest from "@salesforce/user/isGuest";
import { LightningElement } from "lwc";

export default class PwchronoChat extends LightningElement {
  chatterLoginUrl;
  errorMessage;
  connectedCallback() {
    this.loadChatterUrl();
  }
  async loadChatterUrl() {
    this.errorMessage = "";
    try {
      this.chatterLoginUrl = await getSalesforceChatterUrl();
    } catch {
      this.errorMessage = "Unable to open Chatter. Please try again.";
    }
  }
  get actionLabel() {
    return isGuest ? "Sign in with Salesforce" : "Open Chatter";
  }
}