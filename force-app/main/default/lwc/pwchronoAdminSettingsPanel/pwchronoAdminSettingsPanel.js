import getFeatureSettings from "@salesforce/apex/PWChrono_AdminController.getFeatureSettings";
import getGlobalSettings from "@salesforce/apex/PWChrono_AdminController.getGlobalSettings";
import saveFeatureSettings from "@salesforce/apex/PWChrono_AdminController.saveFeatureSettings";
import updateGlobalSettings from "@salesforce/apex/PWChrono_AdminController.updateGlobalSettings";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoAdminSettingsPanel extends LightningElement {
  static renderMode = "light";
  @track activeTab = "features";
  @track isLoading = false;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();
  sessionChangedHandler;

  // Feature Settings
  @track featureSettings = {};

  // Global Settings
  @track globalSettings = {};

  // Options
  weekendOptions = [
    { label: "None", value: "None" },
    { label: "Saturday", value: "Saturday" },
    { label: "Sunday", value: "Sunday" },
    { label: "Friday", value: "Friday" }
  ];

  connectedCallback() {
    this.refreshSessionFromStore();
    this.loadSettings();

    // Refresh for pre-rendered tabs/pages once login completes.
    this.sessionChangedHandler = () => {
      this.refreshSessionFromStore();
      this.loadSettings();
    };

    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this.sessionChangedHandler
      );
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  refreshSessionFromStore() {
    this.employeeId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  get apexSessionParams() {
    return { portalUserId: this.employeeId, sessionToken: this.sessionToken };
  }

  async loadSettings() {
    // Avoid calling guest-protected endpoints until session exists.
    if (!this.employeeId || !this.sessionToken) {
      return;
    }

    this.isLoading = true;
    try {
      const [features, globals] = await Promise.all([
        getFeatureSettings(this.apexSessionParams),
        getGlobalSettings(this.apexSessionParams)
      ]);

      this.featureSettings = features ? { ...features } : {};
      this.globalSettings = globals ? { ...globals } : {};
    } catch (error) {
      this.showToast(
        "Error",
        error?.body?.message || error?.message || "Error loading settings",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  handleTabActive(event) {
    this.activeTab = event.target.value;
  }

  handleFeatureChange(event) {
    const field = event.target.dataset.field;
    const value =
      event.target.type === "checkbox" || event.target.type === "toggle"
        ? event.target.checked
        : event.target.value;

    this.featureSettings = {
      ...this.featureSettings,
      [field]: value
    };
  }

  handleGlobalChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;

    this.globalSettings = {
      ...this.globalSettings,
      [field]: value
    };
  }

  handleSaveFeatures() {
    this.isLoading = true;
    saveFeatureSettings({
      settings: this.featureSettings,
      ...this.apexSessionParams
    })
      .then(() => {
        this.showToast(
          "Success",
          "Feature settings saved successfully",
          "success"
        );
        return this.loadSettings();
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleSaveGlobals() {
    this.isLoading = true;

    // Prepare field map
    const fieldData = {
      Currency_Code__c: this.globalSettings.Currency_Code__c,
      Default_Grace_Period_Minutes__c: Number(
        this.globalSettings.Default_Grace_Period_Minutes__c
      ),
      Leave_Year_Start_Month__c: this.globalSettings.Leave_Year_Start_Month__c,
      Max_Consecutive_Leave_Days__c: Number(
        this.globalSettings.Max_Consecutive_Leave_Days__c
      ),
      Probation_Period_Days__c: Number(
        this.globalSettings.Probation_Period_Days__c
      ),
      Standard_Working_Hours__c: Number(
        this.globalSettings.Standard_Working_Hours__c
      ),
      Time_Zone__c: this.globalSettings.Time_Zone__c,
      Weekend_Day_1__c: this.globalSettings.Weekend_Day_1__c,
      Weekend_Day_2__c: this.globalSettings.Weekend_Day_2__c,
      Working_Days_Per_Week__c: Number(
        this.globalSettings.Working_Days_Per_Week__c
      )
    };

    updateGlobalSettings({
      metadataName: this.globalSettings.DeveloperName,
      label: this.globalSettings.MasterLabel,
      fieldData: fieldData,
      ...this.apexSessionParams
    })
      .then(() => {
        this.showToast(
          "Success",
          "Global settings update queued. Changes may take a few moments to reflect.",
          "success"
        );
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleResetFeatures() {
    this.isLoading = true;
    Promise.resolve()
      .then(() => this.loadSettings())
      .then(() => {
        this.showToast(
          "Info",
          "Feature settings reset to last saved state",
          "info"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleResetGlobals() {
    this.isLoading = true;
    Promise.resolve()
      .then(() => this.loadSettings())
      .then(() => {
        this.showToast(
          "Info",
          "Global settings reset to last saved state",
          "info"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}