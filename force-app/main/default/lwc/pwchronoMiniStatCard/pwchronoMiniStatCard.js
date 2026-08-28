import { LightningElement, api } from "lwc";

export default class PwchronoMiniStatCard extends LightningElement {
  @api label;
  @api value;
  @api iconName;
  @api alternativeText = "Statistic"; // Accessible text for icon
}