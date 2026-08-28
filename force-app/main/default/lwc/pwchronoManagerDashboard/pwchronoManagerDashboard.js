import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import { logError } from "c/pwchronoErrorHandler";
import { loadStyle } from "lightning/platformResourceLoader";
import { LightningElement } from "lwc";

export default class PwchronoManagerDashboard extends LightningElement {
  static renderMode = "light";

  avatarUrl = `${smarthrAssets}/assets/img/profiles/avatar-31.jpg`;

  stylesInitialized = false;

  renderedCallback() {
    if (this.stylesInitialized) {
      return;
    }
    this.stylesInitialized = true;

    // Defensive: In some Experience Builder pages the global SmartHR CSS stack may not be present.
    // Loading here makes the dashboard resilient and prevents the "unstyled/messy" layout.
    const fontAwesomeCss = `${smarthrAssets}/assets/plugins/fontawesome/css/all.min.css`;
    const bootstrapCss = `${smarthrAssets}/assets/css/bootstrap.min.css`;
    const smarthrCss = `${smarthrAssets}/assets/css/style.css`;

    loadStyle(this, fontAwesomeCss)
      .then(() => loadStyle(this, bootstrapCss))
      .then(() => loadStyle(this, smarthrCss))
      .catch((e) => {
        // Keep the UI functional even if CSS fails to load.

        logError("pwchronoManagerDashboard: Failed to load SmartHR styles", e);
      });
  }
}