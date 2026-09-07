import communityBasePath from "@salesforce/community/basePath";
import isGuest from "@salesforce/user/isGuest";
import { NavigationMixin } from "lightning/navigation";
import { LightningElement } from "lwc";

export default class PwchronoChat extends NavigationMixin(LightningElement) {
  get isAuthenticatedChatterUser() {
    return !isGuest;
  }

  get showSignIn() {
    return isGuest;
  }

  get chatterLoginUrl() {
    const basePath = String(communityBasePath || "").replace(/\/$/, "");
    return `${basePath}/login`;
  }

  openChatter() {
    this[NavigationMixin.Navigate]({
      type: "standard__namedPage",
      attributes: {
        pageName: "chatter"
      }
    });
  }
}