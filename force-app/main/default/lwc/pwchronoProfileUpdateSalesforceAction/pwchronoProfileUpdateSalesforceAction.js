import { LightningElement, api } from "lwc";

export default class PwchronoProfileUpdateSalesforceAction extends LightningElement {
  static renderMode = "light";

  @api recordId;
  @api objectApiName;

  // Per project requirement: do not inject CSS from components.
  stylesLoaded = true;
  styleLoadError;

  get effectiveEmployeeId() {
    // For a Portal_Users__c record action, recordId is the Portal_Users__c Id.
    return this.recordId || null;
  }

  // No renderedCallback style loading.
}