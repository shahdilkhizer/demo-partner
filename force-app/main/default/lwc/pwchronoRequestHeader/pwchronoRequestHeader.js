import { LightningElement, api } from "lwc";

export default class PwchronoRequestHeader extends LightningElement {
  static renderMode = "light";

  @api recordName = "";
  @api recordType = "";
  @api status = "";
  @api submittedBy = "";
  @api submittedDate = "";

  get hasMetadata() {
    return this.submittedBy || this.submittedDate;
  }
}