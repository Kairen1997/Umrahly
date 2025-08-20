// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Custom hook for file uploads
const FileUploadHook = {
  mounted() {
    console.log("FileUploadHook mounted", this.el);
    this.el.addEventListener("change", (e) => {
      console.log("File selected:", e.target.files[0]);
    });
  }
};

// Custom hook for form validation
const FormValidationHook = {
  mounted() {
    console.log("FormValidationHook mounted", this.el);
    
    this.el.addEventListener("submit", (e) => {
      const formData = new FormData(this.el);
      const profileData = {};
      
      // Extract profile fields
      for (let [key, value] of formData.entries()) {
        if (key.startsWith("profile[")) {
          const fieldName = key.replace("profile[", "").replace("]", "");
          profileData[fieldName] = value;
        }
      }
      
      // Check if at least one field has a value
      const hasValues = Object.values(profileData).some(value => value && value.trim() !== "");
      
      if (!hasValues) {
        e.preventDefault();
        alert("Please fill in at least one field to save your profile.");
        return false;
      }
      
      console.log("Form validation passed, submitting...");
    });
  }
};

// Custom hook for auto-dismissing flash messages
const AutoDismissFlash = {
  mounted() {
    console.log("AutoDismissFlash mounted", this.el);
    
    // Auto-dismiss after 10 seconds (increased from 5 seconds)
    setTimeout(() => {
      this.el.style.opacity = "0";
      this.el.style.transform = "translateX(100%)";
      
      // Remove from DOM after transition
      setTimeout(() => {
        if (this.el.parentNode) {
          this.el.parentNode.removeChild(this.el);
        }
      }, 300);
    }, 10000);
    
    // Add hover pause functionality
    this.el.addEventListener("mouseenter", () => {
      this.el.dataset.paused = "true";
    });
    
    this.el.addEventListener("mouseleave", () => {
      this.el.dataset.paused = "false";
    });
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    FileUploadHook,
    FormValidationHook,
    AutoDismissFlash
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

