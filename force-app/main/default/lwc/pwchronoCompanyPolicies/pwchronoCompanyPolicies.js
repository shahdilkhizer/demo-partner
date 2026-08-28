import { LightningElement, wire, track } from "lwc";
import getPolicies from "@salesforce/apex/PWChrono_PolicyController.getPolicies";

export default class PwchronoCompanyPolicies extends LightningElement {
  static renderMode = "light";
  @track policies;
  @track error;
  @track selectedCategory = "All";
  @track isLoading = true;

  get categoryOptions() {
    return [
      { label: "All Categories", value: "All" },
      { label: "HR", value: "HR" },
      { label: "IT", value: "IT" },
      { label: "Finance", value: "Finance" },
      { label: "General", value: "General" }
    ];
  }

  @wire(getPolicies, { category: "$selectedCategory" })
  wiredPolicies({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.policies = data;
      this.error = undefined;
    } else if (error) {
      this.error = error.body.message;
      this.policies = undefined;
    }
  }

  get hasPolicies() {
    return this.policies && this.policies.length > 0;
  }

  handleCategoryChange(event) {
    this.selectedCategory = event.detail.value;
  }
}