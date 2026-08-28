import { LightningElement, api } from "lwc";

export default class PwchronoProfileUpdateSalesforce extends LightningElement {
  static renderMode = "light";

  @api recordId;
  @api objectApiName;

  // Optional explicit override (Portal_Users__c Id)
  @api employeeId;

  // Per project requirement: do not inject CSS from components.
  // Styling must come from the Experience site theme/header (or SLDS).
  stylesLoaded = true;
  styleLoadError;

  get effectiveEmployeeId() {
    // Highest priority: explicit override
    if (this.employeeId) return this.employeeId;

    // If placed on a Portal_Users__c record page (or record action), use recordId.
    // Some contexts may not provide objectApiName, but recordId is still valid because
    // this component is scoped to Portal_Users__c in its metadata.
    if (
      this.recordId &&
      (this.objectApiName === "Portal_Users__c" || !this.objectApiName)
    ) {
      return this.recordId;
    }

    // Otherwise, let the child component fall back to session-based employee id
    return null;
  }

  // No renderedCallback style loading.
}