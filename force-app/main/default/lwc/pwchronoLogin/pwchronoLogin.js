import getPermissions from "@salesforce/apex/PWChrono_AuthController.getPermissions";
import sendOTP from "@salesforce/apex/PWChrono_AuthController.sendOTP";
import verifyOTP from "@salesforce/apex/PWChrono_AuthController.verifyOTP";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import TLG_SANTA_LOGO from "@salesforce/resourceUrl/tlg_santa";
import { setSession } from "c/pwchronoSession";
import { NavigationMixin } from "lightning/navigation";
import { LightningElement, track } from "lwc";

export default class PwchronoLogin extends NavigationMixin(LightningElement) {
  static renderMode = "light";

  uiAssetsLoadedKey = "__pwchronoUiAssetsLoaded";
  @track email = "";
  @track showOtpScreen = false;
  @track isLoading = false;
  @track isUiReady = false;
  @track errorMessage = "";
  @track countdown = 60;
  @track canResend = false;
  countdownAnimationFrame;
  countdownEndAtMs;
  resendEnableAtMs;

  tlgSantaLogoUrl = TLG_SANTA_LOGO;

  // SmartHR decorative images used by the reference login markup.
  // These files now live under the existing `smarthr_assets` static resource.
  bg01Url = `${smarthrAssets}/assets/img/bg/bg-01.svg`;
  bg02Url = `${smarthrAssets}/assets/img/bg/bg-02.svg`;
  bg03Url = `${smarthrAssets}/assets/img/bg/bg-03.svg`;
  authBg01Url = `${smarthrAssets}/assets/img/bg/authentication-bg-01.svg`;

  // Create OTP digit objects with unique keys
  @track otpDigits = [
    {
      id: "digit-1",
      name: "digit-1",
      value: "",
      index: 0,
      next: "digit-2",
      previous: undefined,
      inputClass: "rounded w-100 py-sm-3 py-2 text-center fs-26 fw-bold me-3"
    },
    {
      id: "digit-2",
      name: "digit-2",
      value: "",
      index: 1,
      next: "digit-3",
      previous: "digit-1",
      inputClass: "rounded w-100 py-sm-3 py-2 text-center fs-26 fw-bold me-3"
    },
    {
      id: "digit-3",
      name: "digit-3",
      value: "",
      index: 2,
      next: "digit-4",
      previous: "digit-2",
      inputClass: "rounded w-100 py-sm-3 py-2 text-center fs-26 fw-bold me-3"
    },
    {
      id: "digit-4",
      name: "digit-4",
      value: "",
      index: 3,
      next: "digit-5",
      previous: "digit-3",
      inputClass: "rounded w-100 py-sm-3 py-2 text-center fs-26 fw-bold me-3"
    },
    {
      id: "digit-5",
      name: "digit-5",
      value: "",
      index: 4,
      next: "digit-6",
      previous: "digit-4",
      inputClass: "rounded w-100 py-sm-3 py-2 text-center fs-26 fw-bold me-3"
    },
    {
      id: "digit-6",
      name: "digit-6",
      value: "",
      index: 5,
      next: undefined,
      previous: "digit-5",
      inputClass: "rounded w-100 py-sm-3 py-2 text-center fs-26 fw-bold"
    }
  ];

  connectedCallback() {
    // Render only after shared CSS is loaded to avoid a flash of unstyled content.
    this.isUiReady = Boolean(globalThis[this.uiAssetsLoadedKey]);
  }

  handleAssetsReady() {
    this.isUiReady = true;
  }

  getCommunityBasePath() {
    try {
      const path = globalThis.location?.pathname || "";
      // Pattern A: sites that use /s
      const idx = path.indexOf("/s/");
      if (idx >= 0) {
        return path.substring(0, idx) + "/s";
      }
      if (path.endsWith("/s")) {
        return path;
      }

      // Pattern B: sites without /s (e.g. /PulseWorkChrono/login)
      const parts = path.split("/").filter(Boolean);
      if (parts.length >= 1) {
        return "/" + parts[0];
      }
    } catch {
      // no-op
    }
    return "";
  }

  getAbsoluteUrl(relativePath) {
    try {
      const origin = globalThis.location?.origin;
      const p = String(relativePath || "/");
      const normalized = p.startsWith("/") ? p : "/" + p;
      return origin + normalized;
    } catch {
      return relativePath;
    }
  }

  redirectToHome() {
    const base = this.getCommunityBasePath();
    const targetPath = base ? `${base}/` : "/";
    const targetUrl = this.getAbsoluteUrl(targetPath);

    // First try SPA navigation (in case the site prefers named routes).
    try {
      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: { name: "Home" }
      });
    } catch {
      // no-op
    }

    // Force a hard redirect so the URL definitely leaves /login and Home loads fresh.
    try {
      globalThis.location?.assign(targetUrl);
    } catch {
      try {
        if (globalThis.location) {
          globalThis.location.href = targetUrl;
        }
      } catch {
        // no-op
      }
    }
  }

  // Handle email input
  handleEmailChange(event) {
    this.email = event.target.value;
    this.errorMessage = "";
  }

  // Single form submit handler to match the provided SmartHR structure.
  // Routes submit to either "send OTP" or "verify OTP" based on current step.
  async handleFormSubmit(event) {
    event.preventDefault();
    if (this.showOtpScreen) {
      await this.handleVerifyOtp();
    } else {
      await this.handleEmailSubmit();
    }
  }

  // Submit email and request OTP
  async handleEmailSubmit() {
    const normalizedEmail = this.normalizeEmail(this.email);

    if (!normalizedEmail || !this.validateEmail(normalizedEmail)) {
      this.errorMessage = "Please enter a valid email address.";
      return;
    }

    this.email = normalizedEmail;

    this.isLoading = true;
    this.errorMessage = "";

    try {
      const result = await sendOTP({ email: normalizedEmail });
      if (result === "Success") {
        this.showOtpScreen = true;
        this.startCountdown();
      } else if (result === "Success_NoEmail") {
        // Email failed but OTP is stored - proceed to OTP screen
        this.showOtpScreen = true;
        this.startCountdown();
        this.errorMessage =
          "Email delivery may have failed. Check debug logs for OTP code.";
      }
    } catch (error) {
      const serverMessage = error.body?.message;
      this.errorMessage =
        serverMessage === "Invalid email or password. Please try again."
          ? "We couldn't find an active account with that email. Please contact HR support if this continues."
          : serverMessage || "Failed to send OTP. Please try again.";
    } finally {
      this.isLoading = false;
    }
  }

  // Validate email format
  validateEmail(email) {
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailPattern.test(email);
  }

  normalizeEmail(email) {
    return String(email || "")
      .trim()
      .toLowerCase();
  }

  // Handle OTP input
  handleOtpInput(event) {
    const index = Number.parseInt(event.target.dataset.index, 10);
    const value = event.target.value;

    // Check if user pasted a full code (multiple digits)
    if (value && value.length > 1) {
      // Extract only digits
      const digits = value.replaceAll(/\D/g, "").slice(0, 6);
      if (digits.length > 0) {
        this.fillOtpFromString(digits);
        return;
      }
    }

    // Only allow single digit
    if (value && !/^\d$/.test(value)) {
      event.target.value = "";
      return;
    }

    this.otpDigits[index].value = value;

    // Auto-focus next input
    if (value && index < 5) {
      const nextInput = this.querySelector(
        `[data-index="${index + 1}"]`
      );
      if (nextInput) {
        nextInput.focus();
      }
    }

    this.errorMessage = "";
  }

  // Handle paste event for OTP inputs
  handleOtpPaste(event) {
    event.preventDefault();
    const pastedData = (
      event.clipboardData || globalThis.clipboardData
    ).getData("text");
    // Extract only digits from pasted content
    const digits = pastedData.replaceAll(/\D/g, "").slice(0, 6);
    if (digits.length > 0) {
      this.fillOtpFromString(digits);
    }
  }

  // Fill OTP boxes from a string of digits
  fillOtpFromString(digits) {
    const digitArray = digits.split("");
    this.otpDigits = this.otpDigits.map((d, i) => ({
      ...d,
      value: digitArray[i] || ""
    }));

    // Focus the next empty input or the last input
    const nextEmptyIndex = digitArray.length < 6 ? digitArray.length : 5;
    const targetInput = this.querySelector(
      `[data-index="${nextEmptyIndex}"]`
    );
    if (targetInput) {
      targetInput.focus();
    }

    this.errorMessage = "";
  }

  // Handle backspace for OTP inputs
  handleOtpKeydown(event) {
    const index = Number.parseInt(event.target.dataset.index, 10);

    if (event.key === "Backspace") {
      if (!this.otpDigits[index].value && index > 0) {
        // Move to previous input if current is empty
        const prevInput = this.querySelector(
          `[data-index="${index - 1}"]`
        );
        if (prevInput) {
          prevInput.focus();
          prevInput.select();
        }
      }
    }
  }

  handleOtpFocus(event) {
    // SmartHR CSS supports `.otp-input input.active`.
    try {
      event.target?.classList?.add("active");
    } catch {
      // no-op
    }
  }

  handleOtpBlur(event) {
    try {
      event.target?.classList?.remove("active");
    } catch {
      // no-op
    }
  }

  // Verify OTP
  async handleVerifyOtp() {
    // Build OTP from the DOM inputs at submit time (most reliable source of truth).
    // This avoids edge cases where the last keystroke isn't reflected in tracked state yet.
    let otp = "";
    try {
      const inputs = Array.from(
        this.querySelectorAll("input[data-index]")
      );
      inputs.sort((a, b) => {
        const ai = Number.parseInt(a.dataset.index, 10);
        const bi = Number.parseInt(b.dataset.index, 10);
        return ai - bi;
      });
      otp = inputs.map((el) => el?.value || "").join("");
    } catch {
      otp = this.otpDigits.map((d) => d.value).join("");
    }

    // Sanitize to digits only
    otp = String(otp || "").replaceAll(/\D/g, "");

    if (otp.length !== 6) {
      this.errorMessage = "Please enter all 6 digits.";
      return;
    }

    this.isLoading = true;
    this.errorMessage = "";

    try {
      const user = await verifyOTP({ email: this.email, otp: otp });

      if (user) {
        // Fetch Permissions
        const permissions = await getPermissions({
          profileId: user.Portal_User_Profile__c
        });

        // Store user info, permissions, and the server-issued session token.
        // (Required for Guest runtime authorization on subsequent Apex calls.)
        setSession(user, permissions, user.Session_Token__c);

        // Dispatch event for parent components (bubbles + composed to cross shadow DOM)
        // This event is cancelable so a parent (pwchronoMainLayout) can prevent default
        // and handle navigation itself.
        const loginEvent = new CustomEvent("login", {
          detail: { user, permissions, sessionToken: user.Session_Token__c },
          bubbles: true,
          composed: true,
          cancelable: true
        });

        // Dispatch as a signal only (some hosts may listen).
        // Navigation is handled here to guarantee a real URL change.
        this.dispatchEvent(loginEvent);

        // Force the route change so the URL updates and Home page content loads.
        this.redirectToHome();
      } else {
        this.errorMessage = "Login failed. Please try again.";
      }
    } catch (error) {
      this.errorMessage =
        error.body?.message || "Invalid OTP. Please try again.";
      // Clear OTP inputs on error
      this.otpDigits = this.otpDigits.map((d) => ({ ...d, value: "" }));
      const firstInput = this.querySelector("[data-index='0']");
      if (firstInput) {
        firstInput.focus();
      }
    } finally {
      this.isLoading = false;
    }
  }

  // Resend OTP
  async handleResendOtp() {
    if (!this.canResend) return;

    const normalizedEmail = this.normalizeEmail(this.email);
    if (!normalizedEmail) {
      this.errorMessage = "Please enter a valid email address.";
      return;
    }

    this.email = normalizedEmail;

    this.isLoading = true;
    this.errorMessage = "";

    try {
      const result = await sendOTP({ email: normalizedEmail });
      if (result === "Success") {
        this.otpDigits = this.otpDigits.map((d) => ({ ...d, value: "" }));
        this.startCountdown();

        const firstInput = this.querySelector("[data-index='0']");
        if (firstInput) {
          firstInput.focus();
        }
      } else if (result === "Success_NoEmail") {
        this.otpDigits = this.otpDigits.map((d) => ({ ...d, value: "" }));
        this.startCountdown();
        this.errorMessage =
          "Email delivery may have failed. Check debug logs for OTP code.";
      }
    } catch (error) {
      this.errorMessage =
        error.body?.message || "Failed to resend OTP. Please try again.";
    } finally {
      this.isLoading = false;
    }
  }

  // Start countdown timer
  startCountdown() {
    // Match the Sample.html UI which shows a ~10 minute countdown, while
    // still allowing resend after a shorter waiting period.
    const OTP_EXPIRY_SECONDS = 10 * 60;
    const RESEND_ENABLE_AFTER_SECONDS = 60;

    // Start at 09:59 instead of 10:00 for visual parity with the sample.
    this.countdown = OTP_EXPIRY_SECONDS - 1;
    this.canResend = false;

    this.clearCountdownLoop();

    const now = Date.now();
    this.countdownEndAtMs = now + OTP_EXPIRY_SECONDS * 1000;
    this.resendEnableAtMs = now + RESEND_ENABLE_AFTER_SECONDS * 1000;

    this.runCountdownLoop();
  }

  runCountdownLoop() {
    if (typeof globalThis.requestAnimationFrame !== "function") {
      // Fallback: keep the displayed start value if RAF isn't available.
      return;
    }

    const tick = () => {
      const now = Date.now();
      const secondsRemaining = Math.ceil((this.countdownEndAtMs - now) / 1000);
      this.countdown = Math.max(0, secondsRemaining);
      this.canResend = now >= this.resendEnableAtMs;

      if (this.countdown > 0) {
        this.countdownAnimationFrame = globalThis.requestAnimationFrame(tick);
      } else {
        this.clearCountdownLoop();
      }
    };

    this.countdownAnimationFrame = globalThis.requestAnimationFrame(tick);
  }

  clearCountdownLoop() {
    if (this.countdownAnimationFrame) {
      globalThis.cancelAnimationFrame(this.countdownAnimationFrame);
      this.countdownAnimationFrame = null;
    }
  }

  // Cleanup timer on disconnect
  disconnectedCallback() {
    this.clearCountdownLoop();
  }

  // Computed properties
  get formattedCountdown() {
    const minutes = Math.floor(this.countdown / 60);
    const seconds = this.countdown % 60;
    return `${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  }

  get maskedEmail() {
    if (!this.email) return "";
    const parts = this.email.split("@");
    if (parts.length !== 2) return this.email;

    const username = parts[0];
    const domain = parts[1];
    const maskedUsername =
      username.length > 4
        ? username.substring(0, 4) + "*".repeat(username.length - 4)
        : username;

    return `${maskedUsername}@${domain}`;
  }

  get resendButtonClass() {
    // Bootstrap-friendly link button styling.
    return this.canResend && !this.isLoading
      ? "btn btn-link p-0 text-primary"
      : "btn btn-link p-0 text-primary disabled";
  }

  get globalLoaderStyle() {
    // Show a fullscreen centered loader.
    // We use inline styles (instead of relying solely on #global-loader in SmartHR CSS)
    // so the loader is correctly centered even on the very first paint before styles load.
    if (!this.isLoading && this.isUiReady) {
      return "display: none";
    }

    // Dim + blur the background while loading.
    // Note: `backdrop-filter` is supported in modern browsers; where unsupported,
    // the translucent background still provides a clear loading state.
    return [
      "position: fixed",
      "inset: 0",
      "z-index: 999999",
      "display: flex",
      "align-items: center",
      "justify-content: center",
      "background: rgba(255, 255, 255, 0.35)",
      "backdrop-filter: blur(8px)",
      "-webkit-backdrop-filter: blur(8px)"
    ].join("; ");
  }

  get resendDisabled() {
    return this.isLoading || !this.canResend;
  }

  get appShellStyle() {
    return this.isUiReady ? "" : "visibility: hidden;";
  }
}