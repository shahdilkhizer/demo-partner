import getDebugInfo from "@salesforce/apex/PWChrono_DebugUtil.getDebugInfo";
import getTestUsers from "@salesforce/apex/PWChrono_DebugUtil.getTestUsers";
import testFeatureAssignment from "@salesforce/apex/PWChrono_DebugUtil.testFeatureAssignment";
import testOTPSend from "@salesforce/apex/PWChrono_DebugUtil.testOTPSend";
import { logError } from "c/pwchronoErrorHandler";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track } from "lwc";

export default class PwchronoDebugPanel extends LightningElement {
  @track debugInfo = null;
  @track testUsers = [];
  @track selectedUserId = "";
  @track selectedFeature = "";
  @track testEmail = "";
  @track isLoading = false;
  @track debugLogs = [];
  @track showPanel = false;

  features = [
    "Dashboard",
    "Leave Management",
    "Attendance Management",
    "Employee Directory",
    "Payroll",
    "Performance Management"
  ];

  connectedCallback() {
    // Show debug panel if ?debug=1 in URL
    const w = globalThis?.window ?? globalThis;
    const urlParams = new URLSearchParams(w?.location?.search || "");
    this.showPanel = urlParams.get("debug") === "1";
  }

  handleTogglePanel() {
    this.showPanel = !this.showPanel;
  }

  handleLoadDebugInfo() {
    this.isLoading = true;
    this.addLog("Loading system debug info...");

    getDebugInfo()
      .then((result) => {
        this.debugInfo = result;
        this.addLog("✅ Debug info loaded successfully");
      })
      .catch((error) => {
        this.addLog(
          "❌ Error loading debug info: " +
            (error.body?.message || error.message)
        );
        logError("pwchronoDebugPanel.handleLoadDebugInfo", error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleLoadTestUsers() {
    this.isLoading = true;
    this.addLog("Loading test users...");

    getTestUsers()
      .then((result) => {
        this.testUsers = result;
        this.addLog("✅ Loaded " + result.length + " portal users");
      })
      .catch((error) => {
        this.addLog(
          "❌ Error loading users: " + (error.body?.message || error.message)
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleTestOTP() {
    if (!this.testEmail) {
      this.addLog("❌ Please enter an email address");
      return;
    }

    this.isLoading = true;
    this.addLog("Testing OTP send for: " + this.testEmail);

    testOTPSend({ email: this.testEmail })
      .then((result) => {
        // Log each step
        for (const [key, value] of Object.entries(result)) {
          if (typeof value === "object") {
            this.addLog(key + ": " + JSON.stringify(value));
          } else {
            this.addLog(key + ": " + value);
          }
        }

        if (result.success) {
          this.addLog("✅ OTP sent successfully");
          this.showToast("Success", "OTP sent successfully", "success");
        } else {
          this.addLog("❌ OTP send failed: " + result.error);
          this.showToast("Error", result.error, "error");
        }
      })
      .catch((error) => {
        this.addLog("❌ Exception: " + (error.body?.message || error.message));
        logError("pwchronoDebugPanel.handleTestOTP", error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleTestFeatureAssignment() {
    if (!this.selectedUserId || !this.selectedFeature) {
      this.addLog("❌ Please select both a user and a feature");
      return;
    }

    this.isLoading = true;
    this.addLog(
      "Testing feature assignment for user: " +
        this.selectedUserId +
        ", feature: " +
        this.selectedFeature
    );

    testFeatureAssignment({
      portalUserId: this.selectedUserId,
      featureName: this.selectedFeature
    })
      .then((result) => {
        // Log each step
        for (const [key, value] of Object.entries(result)) {
          if (typeof value === "object") {
            this.addLog(key + ": " + JSON.stringify(value));
          } else {
            this.addLog(key + ": " + value);
          }
        }

        if (result.success) {
          this.addLog("✅ Feature assigned successfully");
          this.showToast("Success", "Feature assigned successfully", "success");
        } else {
          this.addLog("❌ Feature assignment failed: " + result.error);
          this.showToast("Error", result.error, "error");
        }
      })
      .catch((error) => {
        this.addLog("❌ Exception: " + (error.body?.message || error.message));
        logError("pwchronoDebugPanel.handleTestFeatureAssignment", error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleUserChange(event) {
    this.selectedUserId = event.target.value;
  }

  handleFeatureChange(event) {
    this.selectedFeature = event.target.value;
  }

  handleEmailChange(event) {
    this.testEmail = event.target.value;
  }

  handleClearLogs() {
    this.debugLogs = [];
  }

  handleDownloadLogs() {
    const logsText = this.debugLogs.join("\n");
    const element = document.createElement("a");
    element.setAttribute(
      "href",
      "data:text/plain;charset=utf-8," + encodeURIComponent(logsText)
    );
    element.setAttribute(
      "download",
      "debug-logs-" + new Date().toISOString() + ".txt"
    );
    element.style.display = "none";
    document.body.appendChild(element);
    element.click();
    element.remove();
  }

  addLog(message) {
    const timestamp = new Date().toLocaleTimeString();
    this.debugLogs = [...this.debugLogs, `[${timestamp}] ${message}`];
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  get userOptions() {
    return this.testUsers.map((user) => ({
      label: user.Name + " (" + user.Email + ")",
      value: user.Id
    }));
  }

  get featureOptions() {
    return this.features.map((f) => ({
      label: f,
      value: f
    }));
  }

  get debugInfoJson() {
    return JSON.stringify(this.debugInfo, null, 2);
  }

  get panelButtonLabel() {
    return this.showPanel ? "Hide Debug Panel" : "Show Debug Panel";
  }
}