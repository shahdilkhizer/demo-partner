import { LightningElement, api } from "lwc";

export default class PwchronoProfileCard extends LightningElement {
  @api avatarUrl;
  @api name;
  @api role;
  @api performance;
}