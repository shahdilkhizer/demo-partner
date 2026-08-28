import { LightningElement, api } from "lwc";

export default class PwchronoPlaceholderCard extends LightningElement {
  static renderMode = "light";

  @api title = "";
  @api description = "Coming soon.";
}