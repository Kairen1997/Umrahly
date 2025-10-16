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
import "./flash_config"

// Initialize Alpine.js for simple UI interactions (e.g., sidebar toggle)
import Alpine from "alpinejs"
window.Alpine = Alpine
Alpine.start()


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

// Custom hook for debugging form submissions
const FormDebug = {
  mounted() {
    console.log("FormDebug hook mounted for form:", this.el);
    
    this.el.addEventListener("submit", (e) => {
      console.log("Form submission triggered!");
      console.log("Form action:", this.el.action);
      console.log("Form method:", this.el.method);
      console.log("Form enctype:", this.el.enctype);
      
      const formData = new FormData(this.el);
      console.log("Form data entries:");
      for (let [key, value] of formData.entries()) {
        console.log(`  ${key}:`, value);
      }
      
      // Don't prevent default - let Phoenix handle it
      console.log("Allowing form submission to continue...");
    });
  }
};

// Custom hook for debugging button clicks
const DebugClick = {
  mounted() {
    console.log("DebugClick hook mounted for button:", this.el);
    console.log("Button data:", this.el.dataset);
    
    this.el.addEventListener("click", (e) => {
      console.log("Button clicked:", e);
      console.log("Button element:", this.el);
      console.log("Package ID:", this.el.dataset.packageId);
    });
  }
};

// Custom hook for date field updates
const DateFieldUpdate = {
  mounted() {
    console.log("DateFieldUpdate hook mounted for date field:", this.el);
    
    this.el.addEventListener("change", (e) => {
      const value = e.target.value;
      const index = this.el.dataset.index;
      const field = this.el.dataset.field;
      
      console.log("Date field changed:", { value, index, field });
      
      // Push the event to LiveView with the proper structure
      this.pushEvent("update_traveler_field", {
        value: value,
        index: index,
        field: field
      });
    });
  }
};


// Custom hook for payment gateway redirect
const PaymentGatewayRedirect = {
  mounted() {
    console.log("PaymentGatewayRedirect hook mounted");
    
    // Check if this is an online payment that requires immediate redirect
    const requiresOnlinePayment = this.el.dataset.requiresOnlinePayment === "true";
    const paymentGatewayUrl = this.el.dataset.paymentGatewayUrl;
    
    if (requiresOnlinePayment && paymentGatewayUrl) {
      console.log("Redirecting to payment gateway:", paymentGatewayUrl);
      
      // Small delay to show the success message before redirect
      setTimeout(() => {
        // Open payment gateway in new tab/window
        window.open(paymentGatewayUrl, '_blank');
        
        // Also redirect the current page to dashboard
        window.location.href = '/dashboard';
      }, 1500);
    }
  }
};

// Custom hook for receipt downloads
const DownloadReceipt = {
  mounted() {
    console.log("DownloadReceipt hook mounted");
    
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      
      const receiptId = this.el.dataset.receiptId;
      console.log("Download receipt clicked for ID:", receiptId);
      
      // Push event to LiveView to get receipt data
      this.pushEvent("download-receipt", { receipt_id: receiptId });
    });
    
    // Listen for the response from the server
    this.handleEvent("receipt_download_ready", (data) => {
      console.log("Receipt download ready:", data);
      this.downloadFile(data.file_path, data.filename);
    });
  },
  
  downloadFile(filePath, filename) {
    try {
      // Create a temporary link element
      const link = document.createElement('a');
      link.href = filePath;
      link.download = filename;
      link.style.display = 'none';
      
      // Append to body, click, and remove
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      console.log("File download initiated:", filename);
    } catch (error) {
      console.error("Error downloading file:", error);
      alert("Failed to download receipt. Please try again.");
    }
  }
};

// Custom hook for terms validation
const TermsValidation = {
  mounted() {
    console.log("TermsValidation hook mounted");
    
    const termsCheckbox = this.el;
    const confirmButton = document.getElementById("confirm-booking-btn");
    
    if (termsCheckbox && confirmButton) {
      const validateTerms = () => {
        if (termsCheckbox.checked) {
          confirmButton.disabled = false;
          confirmButton.classList.remove("opacity-50", "cursor-not-allowed");
        } else {
          confirmButton.disabled = true;
          confirmButton.classList.add("opacity-50", "cursor-not-allowed");
        }
      };
      
      // Initial validation
      validateTerms();
      
      // Add event listener
      termsCheckbox.addEventListener("change", validateTerms);
    }
  }
};

// Custom hook for auto-dismissing flash messages
const AutoDismissFlash = {
  mounted() {
    console.log("AutoDismissFlash mounted for:", this.el.id);
    
    // Get configuration
    this.config = window.FlashConfig || {
      autoDismissDelay: 5000,
      showProgressBar: true,
      animationDuration: 300,
      maxMessages: 3
    };
    
    // Set initial state
    this.isPaused = false;
    this.autoDismissTimer = null;
    this.progressTimer = null;
    this.dismissDelay = this.config.autoDismissDelay;
    
    // Mark as initialized to prevent double initialization
    this.el.setAttribute('data-hook-initialized', 'true');
    
    // Position this flash message
    this.positionFlashMessage();
    
    // Add progress bar if enabled
    if (this.config.showProgressBar) {
      this.addProgressBar();
    }
    
    // Setup close button
    this.setupCloseButton();
    
    // Setup click outside to dismiss
    this.setupClickOutside();
    
    // Setup hover pause functionality
    this.setupHoverPause();
    
    // Start auto-dismiss timer
    this.startAutoDismiss();
    
    console.log("AutoDismissFlash initialization completed for:", this.el.id);
  },
  
  destroyed() {
    console.log("AutoDismissFlash destroyed for:", this.el.id);
    this.clearAutoDismissTimer();
    this.clearProgressTimer();
  },
  
  positionFlashMessage() {
    // Get all existing flash messages
    const existingFlashes = document.querySelectorAll('.flash-message');
    const currentIndex = Array.from(existingFlashes).indexOf(this.el);
    
    // Check if we've exceeded the maximum number of messages
    if (existingFlashes.length > this.config.maxMessages) {
      // Remove the oldest flash message
      const oldestFlash = existingFlashes[0];
      if (oldestFlash && oldestFlash !== this.el) {
        oldestFlash.remove();
      }
    }
    
    // Recalculate position after potential removal
    const updatedFlashes = document.querySelectorAll('.flash-message');
    const updatedIndex = Array.from(updatedFlashes).indexOf(this.el);
    
    // Calculate position based on index
    const topOffset = 2 + (updatedIndex * 5); // 2rem + (index * 5rem)
    this.el.style.top = `${topOffset}rem`;
    
    // Add a small delay for staggered entrance
    if (updatedIndex > 0) {
      this.el.style.opacity = '0';
      this.el.style.transform = 'translateX(100%)';
      
      setTimeout(() => {
        this.el.style.opacity = '1';
        this.el.style.transform = 'translateX(0)';
      }, updatedIndex * 100);
    }
  },
  
  addProgressBar() {
    // Create progress bar element
    const progressBar = document.createElement('div');
    progressBar.className = 'flash-progress absolute bottom-0 left-0 h-1 bg-current opacity-20 transition-all duration-100';
    progressBar.style.width = '100%';
    this.el.appendChild(progressBar);
    this.progressBar = progressBar;
  },
  
  setupCloseButton() {
    const closeButton = this.el.querySelector('button[data-debug="close-button"]');
    if (closeButton) {
      closeButton.addEventListener('click', (e) => {
        e.stopPropagation();
        this.dismissFlash();
      });
    }
  },
  
  setupClickOutside() {
    // Allow clicking anywhere on the flash to dismiss it
    this.el.addEventListener('click', (e) => {
      // Don't dismiss if clicking on the close button
      if (e.target.closest('button')) {
        return;
      }
      this.dismissFlash();
    });
    
    // Add touch/swipe functionality for mobile
    this.setupTouchEvents();
  },
  
  setupTouchEvents() {
    let startX = 0;
    let startY = 0;
    let currentX = 0;
    let currentY = 0;
    
    this.el.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      startX = touch.clientX;
      startY = touch.clientY;
    }, { passive: true });
    
    this.el.addEventListener('touchmove', (e) => {
      const touch = e.touches[0];
      currentX = touch.clientX;
      currentY = touch.clientY;
      
      // Calculate swipe distance
      const deltaX = currentX - startX;
      const deltaY = currentY - startY;
      
      // If swiping right (positive deltaX), add visual feedback
      if (deltaX > 0) {
        const translateX = Math.min(deltaX * 0.5, 100);
        this.el.style.transform = `translateX(${translateX}px)`;
        this.el.style.opacity = Math.max(1 - (deltaX / 200), 0.3);
      }
    }, { passive: true });
    
    this.el.addEventListener('touchend', (e) => {
      const deltaX = currentX - startX;
      const deltaY = currentY - startY;
      
      // If swiped right more than 100px, dismiss the flash
      if (deltaX > 100 && Math.abs(deltaY) < 50) {
        this.dismissFlash();
      } else {
        // Reset position if not swiped enough
        this.el.style.transform = 'translateX(0)';
        this.el.style.opacity = '1';
      }
    }, { passive: true });
  },
  
  setupHoverPause() {
    this.el.addEventListener('mouseenter', () => {
      this.isPaused = true;
      this.clearAutoDismissTimer();
      this.clearProgressTimer();
    });
    
    this.el.addEventListener('mouseleave', () => {
      this.isPaused = false;
      this.startAutoDismiss();
    });
  },
  
  startAutoDismiss() {
    if (this.isPaused) return;
    
    console.log("Starting auto-dismiss timer for:", this.el.id, "Delay:", this.dismissDelay);
    
    // Start progress bar animation if enabled
    if (this.config.showProgressBar && this.progressBar) {
      this.startProgressBar();
    }
    
    // Auto-dismiss after specified delay
    this.autoDismissTimer = setTimeout(() => {
      if (!this.isPaused) {
        console.log("Auto-dismiss timer fired for:", this.el.id);
        this.dismissFlash();
      }
    }, this.dismissDelay);
  },
  
  startProgressBar() {
    if (!this.progressBar) return;
    
    const startTime = Date.now();
    
    this.progressTimer = setInterval(() => {
      if (this.isPaused) return;
      
      const currentTime = Date.now();
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / this.dismissDelay, 1);
      
      this.progressBar.style.width = `${(1 - progress) * 100}%`;
      
      if (progress >= 1) {
        this.clearProgressTimer();
      }
    }, 50);
  },
  
  clearAutoDismissTimer() {
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer);
      this.autoDismissTimer = null;
    }
  },
  
  clearProgressTimer() {
    if (this.progressTimer) {
      clearInterval(this.progressTimer);
      this.progressTimer = null;
    }
  },
  
  dismissFlash() {
    console.log("Dismissing flash:", this.el.id);
    
    // Clear timers
    this.clearAutoDismissTimer();
    this.clearProgressTimer();
    
    // Add dismissing class for CSS animation
    this.el.classList.add('dismissing');
    
    // Remove from DOM after animation
    setTimeout(() => {
      if (this.el.parentNode) {
        this.el.parentNode.removeChild(this.el);
      }
      
      // Reposition remaining flash messages
      this.repositionRemainingFlashes();
    }, this.config.animationDuration);
  },
  
  repositionRemainingFlashes() {
    const remainingFlashes = document.querySelectorAll('.flash-message');
    remainingFlashes.forEach((flash, index) => {
      const topOffset = 2 + (index * 5);
      flash.style.top = `${topOffset}rem`;
    });
  }
};

// Custom hook for package details scrolling
const PackageDetails = {
  mounted() {
    console.log("PackageDetails hook mounted");
    
    // Listen for the scroll event from the server
    this.handleEvent("scroll_to_package_details", () => {
      console.log("Scrolling to package details");
      
      // Smooth scroll to the package details section
      this.el.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'start',
        inline: 'nearest'
      });
    });
  }
};

// Custom hook for schedule details scrolling
const ScheduleDetails = {
  mounted() {
    console.log("ScheduleDetails hook mounted on element:", this.el);
    console.log("Element ID:", this.el.id);
    
    // Listen for the scroll event from the server
    this.handleEvent("scroll_to_schedule_details", (data) => {
      console.log("Received scroll_to_schedule_details event with data:", data);
      console.log("Scrolling to schedule details element:", this.el);
      
      // Smooth scroll to the schedule details section
      this.el.scrollIntoView({ 
        behavior: 'smooth', 
        block: 'start',
        inline: 'nearest'
      });
    });
  },
  
  updated() {
    console.log("ScheduleDetails hook updated on element:", this.el);
  }
};

// Custom hook for auto-scrolling to forms and sections
const AutoScroll = {
  mounted() {
    console.log("AutoScroll hook mounted");
    
    try {
      // Check if this element should be scrolled to
      const scrollableIds = ["itinerary-form", "package-details", "add-package-form", "edit-package-form"];
      
      if (scrollableIds.includes(this.el.id)) {
        // Add a small delay to ensure the element is fully rendered
        setTimeout(() => {
          try {
            console.log(`Auto-scrolling to ${this.el.id}`);
            
            // Check if element is still in DOM
            if (document.contains(this.el)) {
              // Calculate offset for any fixed headers (adjust as needed)
              const offset = 20;
              
              // Get element position
              const elementTop = this.el.offsetTop - offset;
              
              // Scroll to the element with offset
              window.scrollTo({
                top: elementTop,
                behavior: 'smooth'
              });
              
              // Add highlight effect
              this.el.classList.add('scroll-target');
              
              // Remove highlight class after animation
              setTimeout(() => {
                if (document.contains(this.el)) {
                  this.el.classList.remove('scroll-target');
                }
              }, 500);
            }
          } catch (error) {
            console.error(`Error during auto-scroll to ${this.el.id}:`, error);
          }
        }, 150); // Increased delay for better reliability
      }
    } catch (error) {
      console.error("Error in AutoScroll hook:", error);
    }
  }
};

// New hook to scroll to a target element by id
const ScrollTo = {
  mounted() {
    this.onClick = (e) => {
      e.preventDefault();
      const targetId = this.el.dataset.targetId;
      if (!targetId) return;
      const target = document.getElementById(targetId);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    };
    this.el.addEventListener('click', this.onClick);
  },
  destroyed() {
    if (this.onClick) {
      this.el.removeEventListener('click', this.onClick);
    }
  }
};

// New hook to toggle target visibility and optionally scroll when showing
const ToggleSection = {
  mounted() {
    this.onClick = (e) => {
      e.preventDefault();
      const toggleId = this.el.dataset.toggleId || this.el.dataset.targetId;
      const scrollId = this.el.dataset.scrollId || this.el.dataset.targetId;
      if (!toggleId) return;
      const toggleEl = document.getElementById(toggleId);
      if (!toggleEl) return;

      const isHidden = toggleEl.classList.contains('hidden');
      if (isHidden) {
        toggleEl.classList.remove('hidden');
        const hideText = this.el.dataset.hideText;
        if (hideText) this.el.textContent = hideText;
        // Scroll with offset to account for fixed headers
        const offset = parseInt(this.el.dataset.scrollOffset || '80', 10);
        const scrollEl = scrollId ? document.getElementById(scrollId) : toggleEl;
        if (scrollEl) {
          const rect = scrollEl.getBoundingClientRect();
          const top = rect.top + window.pageYOffset - offset;
          window.scrollTo({ top, behavior: 'smooth' });
        }
      } else {
        toggleEl.classList.add('hidden');
        const showText = this.el.dataset.showText;
        if (showText) this.el.textContent = showText;
      }
    };
    this.el.addEventListener('click', this.onClick);

    // Initialize button text based on current visibility
    const toggleId = this.el.dataset.toggleId || this.el.dataset.targetId;
    const showText = this.el.dataset.showText;
    const hideText = this.el.dataset.hideText;
    if (toggleId && (showText || hideText)) {
      const toggleEl = document.getElementById(toggleId);
      if (toggleEl) {
        if (toggleEl.classList.contains('hidden')) {
          if (showText) this.el.textContent = showText;
        } else {
          if (hideText) this.el.textContent = hideText;
        }
      }
    }
  },
  destroyed() {
    if (this.onClick) {
      this.el.removeEventListener('click', this.onClick);
    }
  }
};

// Custom hook for debugging Add Item button
const AddItemDebugHook = {
  mounted() {
    console.log("AddItemDebugHook mounted on:", this.el);
    
    this.el.addEventListener("click", (e) => {
      console.log("Add Item button clicked!", e);
      console.log("Button element:", this.el);
      console.log("phx-click attribute:", this.el.getAttribute("phx-click"));
      console.log("phx-value-day_index:", this.el.getAttribute("phx-value-day_index"));
    });
  }
};

// Booking Progress Hook - Disabled to fix step progression issue
const BookingProgress = {
  mounted() {
    this.step = this.el.dataset.step;
    this.packageId = this.el.dataset.packageId;
    this.scheduleId = this.el.dataset.scheduleId;
    
    // Disabled all progress saving to fix step progression
    console.log("BookingProgress hook mounted but disabled for debugging");
    
    // Notify when page is fully loaded
    if (document.readyState === "complete") {
      this.pushEvent("page_loaded", {});
    } else {
      window.addEventListener("load", () => {
        this.pushEvent("page_loaded", {});
      });
    }
  },
  
  destroyed() {
    // Clean up event listeners
    console.log("BookingProgress hook destroyed");
  },
  
  updated() {
    // Update step when it changes
    this.step = this.el.dataset.step;
    console.log("BookingProgress hook updated, new step:", this.step);
  }
};

// Travelers Form Hooks
const TravelersForm = {
  mounted() {
    this.setupFormValidation();
    this.setupConfirmationDialogs();
    this.setupSuccessMessage();
  },

  setupFormValidation() {
    const form = this.el;
    const inputs = form.querySelectorAll('input[required]');
    const saveButton = form.querySelector('button[type="submit"]');

    // Real-time validation
    inputs.forEach(input => {
      input.addEventListener('blur', () => {
        this.validateField(input);
      });
      
      input.addEventListener('input', () => {
        this.validateField(input);
      });
    });

    // Form submission validation
    form.addEventListener('submit', (e) => {
      if (!this.validateForm()) {
        e.preventDefault();
        this.showValidationError("Please complete all required fields before saving.");
      }
    });
  },

  setupConfirmationDialogs() {
    // Handle remove traveler confirmation
    this.handleEvent("remove_traveler", (event) => {
      const index = event.target.getAttribute('phx-value-index');
      const travelerName = event.target.closest('.border').querySelector('input[name*="[full_name]"]').value;
      
      if (travelerName && travelerName.trim() !== "") {
        return confirm(`Are you sure you want to remove ${travelerName}?`);
      } else {
        return confirm("Are you sure you want to remove this traveler?");
      }
    });
  },

  setupSuccessMessage() {
    // Listen for successful save events
    this.handleEvent("save_travelers_success", () => {
      this.showSuccessMessage();
    });
  },

  validateField(input) {
    const value = input.value.trim();
    const isValid = value !== "";
    
    if (isValid) {
      input.classList.remove('border-red-500');
      input.classList.add('border-green-500');
    } else {
      input.classList.remove('border-green-500');
      input.classList.add('border-red-500');
    }
    
    return isValid;
  },

  validateForm() {
    const requiredInputs = this.el.querySelectorAll('input[required]');
    let isValid = true;
    
    requiredInputs.forEach(input => {
      if (!this.validateField(input)) {
        isValid = false;
      }
    });
    
    return isValid;
  },

  showValidationError(message) {
    // Create or update error message
    let errorDiv = this.el.querySelector('.validation-error');
    if (!errorDiv) {
      errorDiv = document.createElement('div');
      errorDiv.className = 'validation-error bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mt-4';
      this.el.appendChild(errorDiv);
    }
    errorDiv.textContent = message;
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      if (errorDiv) {
        errorDiv.remove();
      }
    }, 3000);
  },

  showSuccessMessage() {
    const successMessage = document.getElementById('travelers-success-message');
    if (successMessage) {
      successMessage.classList.remove('hidden');
      
      // Auto-hide after 10 seconds
      setTimeout(() => {
        successMessage.classList.add('hidden');
      }, 3000);
    }
  }
};

// Register the hook
window.TravelersForm = TravelersForm;


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    // FormValidationHook, // Temporarily disabled to fix form issues
    FormDebug,
    AutoDismissFlash,
    PackageDetails,
    ScheduleDetails,
    AutoScroll,
    ScrollTo,
    ToggleSection,
    AddItemDebugHook,
    DebugClick,
    BookingProgress,
    TermsValidation,
    PaymentGatewayRedirect,
    DownloadReceipt,
    DateFieldUpdate,
    DateDropdown,
    DepartureDateChange,
    NotificationToggle,
  }
})

// Add debug logging for LiveView events
// Note: onMessage and onError are not available in current LiveView versions
// Using event listeners instead
document.addEventListener('phx:update', (event) => {
  console.log("LiveView update event:", event);
});


document.addEventListener('phx:error', (event) => {
  console.error("LiveView error event:", event);
});

// Listen for open-url events from LiveView
document.addEventListener('phx:open-url', (event) => {
  console.log("Received open-url event:", event.detail);
  if (event.detail && event.detail.url) {
    window.open(event.detail.url, '_blank');
  }
});



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

// Global function to manually initialize flash messages
window.initializeFlashMessages = function() {
  console.log("Manually initializing flash messages");
  
  const flashMessages = document.querySelectorAll('[data-flash-auto-dismiss="true"]:not([data-hook-initialized])');
  console.log("Found uninitialized flash messages:", flashMessages.length);
  
  if (flashMessages.length === 0) {
    console.log("No uninitialized flash messages found");
    return;
  }
  
  flashMessages.forEach((flashEl, index) => {
    console.log("Manually initializing flash message:", flashEl.id, "Element:", flashEl);
    console.log("Element classes:", flashEl.className);
    console.log("Element data attributes:", flashEl.dataset);
    
    // Create a mock hook context
    const mockHook = {
      el: flashEl,
      config: window.FlashConfig || {
        autoDismissDelay: 5000,
        showProgressBar: true,
        animationDuration: 300,
        maxMessages: 3
      },
      isPaused: false,
      autoDismissTimer: null,
      progressTimer: null,
      dismissDelay: 5000,
      
      // Mock methods
      positionFlashMessage() {
        console.log("Positioning flash message:", this.el.id);
        const existingFlashes = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
        const currentIndex = Array.from(existingFlashes).indexOf(this.el);
        
        if (existingFlashes.length > this.config.maxMessages) {
          const oldestFlash = existingFlashes[0];
          if (oldestFlash && oldestFlash !== this.el) {
            oldestFlash.remove();
          }
        }
        
        const updatedFlashes = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
        const updatedIndex = Array.from(updatedFlashes).indexOf(this.el);
        
        const topOffset = 2 + (updatedIndex * 5);
        this.el.style.top = `${topOffset}rem`;
        console.log("Set top offset to:", topOffset, "rem");
        
        if (updatedIndex > 0) {
          this.el.style.opacity = '0';
          this.el.style.transform = 'translateX(100%)';
          
          setTimeout(() => {
            this.el.style.opacity = '1';
            this.el.style.transform = 'translateX(0)';
          }, updatedIndex * 100);
        }
      },
      
      addProgressBar() {
        if (!this.config.showProgressBar) return;
        
        console.log("Adding progress bar to:", this.el.id);
        const progressBar = document.createElement('div');
        progressBar.className = 'flash-progress absolute bottom-0 left-0 h-1 bg-current opacity-20 transition-all duration-100';
        progressBar.style.width = '100%';
        this.el.appendChild(progressBar);
        this.progressBar = progressBar;
      },
      
      setupCloseButton() {
        const closeButton = this.el.querySelector('button[data-debug="close-button"]');
        if (closeButton) {
          console.log("Setting up close button for:", this.el.id);
          closeButton.addEventListener('click', (e) => {
            e.stopPropagation();
            this.dismissFlash();
          });
        } else {
          console.log("No close button found for:", this.el.id);
        }
      },
      
      setupClickOutside() {
        console.log("Setting up click outside for:", this.el.id);
        this.el.addEventListener('click', (e) => {
          if (e.target.closest('button')) {
            return;
          }
          this.dismissFlash();
        });
      },
      
      setupHoverPause() {
        console.log("Setting up hover pause for:", this.el.id);
        this.el.addEventListener('mouseenter', () => {
          this.isPaused = true;
          this.clearAutoDismissTimer();
          this.clearProgressTimer();
        });
        
        this.el.addEventListener('mouseleave', () => {
          this.isPaused = false;
          this.startAutoDismiss();
        });
      },
      
      startAutoDismiss() {
        if (this.isPaused) return;
        
        console.log("Starting auto-dismiss for:", this.el.id, "Delay:", this.dismissDelay);
        
        if (this.config.showProgressBar && this.progressBar) {
          this.startProgressBar();
        }
        
        this.autoDismissTimer = setTimeout(() => {
          if (!this.isPaused) {
            console.log("Auto-dismiss timer fired for:", this.el.id);
            this.dismissFlash();
          }
        }, this.dismissDelay);
      },
      
      startProgressBar() {
        if (!this.progressBar) return;
        
        console.log("Starting progress bar for:", this.el.id);
        const startTime = Date.now();
        
        this.progressTimer = setInterval(() => {
          if (this.isPaused) return;
          
          const currentTime = Date.now();
          const elapsed = currentTime - startTime;
          const progress = Math.min(elapsed / this.dismissDelay, 1);
          
          this.progressBar.style.width = `${(1 - progress) * 100}%`;
          
          if (progress >= 1) {
            this.clearProgressTimer();
          }
        }, 50);
      },
      
      clearAutoDismissTimer() {
        if (this.autoDismissTimer) {
          clearTimeout(this.autoDismissTimer);
          this.autoDismissTimer = null;
        }
      },
      
      clearProgressTimer() {
        if (this.progressTimer) {
          clearInterval(this.progressTimer);
          this.progressTimer = null;
        }
      },
      
      dismissFlash() {
        console.log("Dismissing flash:", this.el.id);
        
        this.clearAutoDismissTimer();
        this.clearProgressTimer();
        
        this.el.classList.add('dismissing');
        
        setTimeout(() => {
          if (this.el.parentNode) {
            this.el.parentNode.removeChild(this.el);
          }
          
          this.repositionRemainingFlashes();
        }, this.config.animationDuration);
      },
      
      repositionRemainingFlashes() {
        const remainingFlashes = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
        remainingFlashes.forEach((flash, index) => {
          const topOffset = 2 + (index * 5);
          flash.style.top = `${topOffset}rem`;
        });
      }
    };
    
    // Initialize the mock hook
    console.log("Initializing mock hook for:", flashEl.id);
    mockHook.positionFlashMessage();
    mockHook.addProgressBar();
    mockHook.setupCloseButton();
    mockHook.setupClickOutside();
    mockHook.setupHoverPause();
    mockHook.startAutoDismiss();
    
    // Mark as initialized
    flashEl.setAttribute('data-hook-initialized', 'true');
    console.log("Flash message initialized:", flashEl.id);
  });
};

// Initialize flash messages for regular Phoenix controllers (non-LiveView)
document.addEventListener('DOMContentLoaded', function() {
  console.log("DOM loaded, checking for flash messages");
  
  // Find all flash messages with the data attribute
  const flashMessages = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
  console.log("Found flash messages:", flashMessages.length);
  
  // Initialize each flash message
  flashMessages.forEach((flashEl, index) => {
    console.log("Initializing flash message:", flashEl.id, "at index:", index);
    
    // Create a mock hook context for regular Phoenix
    const mockHook = {
      el: flashEl,
      config: window.FlashConfig || {
        autoDismissDelay: 5000,
        showProgressBar: true,
        animationDuration: 300,
        maxMessages: 3
      },
      isPaused: false,
      autoDismissTimer: null,
      progressTimer: null,
      dismissDelay: 5000,
      
      // Mock methods
      positionFlashMessage() {
        // Position this flash message
        const existingFlashes = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
        const currentIndex = Array.from(existingFlashes).indexOf(this.el);
        
        // Check if we've exceeded the maximum number of messages
        if (existingFlashes.length > this.config.maxMessages) {
          const oldestFlash = existingFlashes[0];
          if (oldestFlash && oldestFlash !== this.el) {
            oldestFlash.remove();
          }
        }
        
        // Recalculate position after potential removal
        const updatedFlashes = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
        const updatedIndex = Array.from(updatedFlashes).indexOf(this.el);
        
        // Calculate position based on index
        const topOffset = 2 + (updatedIndex * 5);
        this.el.style.top = `${topOffset}rem`;
        
        // Add a small delay for staggered entrance
        if (updatedIndex > 0) {
          this.el.style.opacity = '0';
          this.el.style.transform = 'translateX(100%)';
          
          setTimeout(() => {
            this.el.style.opacity = '1';
            this.el.style.transform = 'translateX(0)';
          }, updatedIndex * 100);
        }
      },
      
      addProgressBar() {
        if (!this.config.showProgressBar) return;
        
        const progressBar = document.createElement('div');
        progressBar.className = 'flash-progress absolute bottom-0 left-0 h-1 bg-current opacity-20 transition-all duration-100';
        progressBar.style.width = '100%';
        this.el.appendChild(progressBar);
        this.progressBar = progressBar;
      },
      
      setupCloseButton() {
        const closeButton = this.el.querySelector('button[data-debug="close-button"]');
        if (closeButton) {
          closeButton.addEventListener('click', (e) => {
            e.stopPropagation();
            this.dismissFlash();
          });
        }
      },
      
      setupClickOutside() {
        console.log("Setting up click outside for flash message:", this.el.id);
        
        // Allow clicking anywhere on the flash to dismiss it
        this.el.addEventListener('click', (e) => {
          console.log("Flash message clicked:", this.el.id, e.target);
          
          // Don't dismiss if clicking on the close button
          if (e.target.closest('button')) {
            console.log("Click was on close button, not dismissing");
            return;
          }
          
          console.log("Clicking to dismiss flash message:", this.el.id);
          this.dismissFlash();
        });
      },
      
      setupHoverPause() {
        this.el.addEventListener('mouseenter', () => {
          this.isPaused = true;
          this.clearAutoDismissTimer();
          this.clearProgressTimer();
        });
        
        this.el.addEventListener('mouseleave', () => {
          this.isPaused = false;
          this.startAutoDismiss();
        });
      },
      
      startAutoDismiss() {
        if (this.isPaused) return;
        
        // Start progress bar animation if enabled
        if (this.config.showProgressBar && this.progressBar) {
          this.startProgressBar();
        }
        
        // Auto-dismiss after specified delay
        this.autoDismissTimer = setTimeout(() => {
          if (!this.isPaused) {
            this.dismissFlash();
          }
        }, this.dismissDelay);
      },
      
      startProgressBar() {
        if (!this.progressBar) return;
        
        const startTime = Date.now();
        
        this.progressTimer = setInterval(() => {
          if (this.isPaused) return;
          
          const currentTime = Date.now();
          const elapsed = currentTime - startTime;
          const progress = Math.min(elapsed / this.dismissDelay, 1);
          
          this.progressBar.style.width = `${(1 - progress) * 100}%`;
          
          if (progress >= 1) {
            this.clearProgressTimer();
          }
        }, 50);
      },
      
      clearAutoDismissTimer() {
        if (this.autoDismissTimer) {
          clearTimeout(this.autoDismissTimer);
          this.autoDismissTimer = null;
        }
      },
      
      clearProgressTimer() {
        if (this.progressTimer) {
          clearInterval(this.progressTimer);
          this.progressTimer = null;
        }
      },
      
      dismissFlash() {
        console.log("dismissFlash called for element:", this.el.id);
        console.log("Element exists:", !!this.el);
        console.log("Element parent:", this.el.parentNode);
        
        // Clear timers
        this.clearAutoDismissTimer();
        this.clearProgressTimer();
        
        // Add dismissing class for CSS animation
        console.log("Adding dismissing class");
        this.el.classList.add('dismissing');
        
        // Remove from DOM after animation
        console.log("Setting timeout to remove element after", this.config.animationDuration, "ms");
        setTimeout(() => {
          console.log("Timeout fired, removing element");
          if (this.el.parentNode) {
            console.log("Removing element from parent");
            this.el.parentNode.removeChild(this.el);
          } else {
            console.log("Element has no parent, cannot remove");
          }
          
          // Reposition remaining flash messages
          this.repositionRemainingFlashes();
        }, this.config.animationDuration);
      },
      
      repositionRemainingFlashes() {
        const remainingFlashes = document.querySelectorAll('[data-flash-auto-dismiss="true"]');
        remainingFlashes.forEach((flash, index) => {
          const topOffset = 2 + (index * 5);
          flash.style.top = `${topOffset}rem`;
        });
      }
    };
    
    // Initialize the mock hook
    mockHook.positionFlashMessage();
    mockHook.addProgressBar();
    mockHook.setupCloseButton();
    mockHook.setupClickOutside();
    mockHook.setupHoverPause();
    mockHook.startAutoDismiss();
    
    // Mark as initialized
    flashEl.setAttribute('data-hook-initialized', 'true');
  });
  
  // Also set up a fallback timer to check for new flash messages
  setTimeout(() => {
    window.initializeFlashMessages();
  }, 1000);
});

// Set up a mutation observer to automatically detect new flash messages
const flashObserver = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    if (mutation.type === 'childList') {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          // Check if the added node is a flash message
          if (node.matches && node.matches('[data-flash-auto-dismiss="true"]')) {
            console.log("Mutation observer detected new flash message:", node.id);
            // Small delay to ensure the element is fully rendered
            setTimeout(() => {
              window.initializeFlashMessages();
            }, 100);
          }
          
          // Check if any child elements are flash messages
          const childFlashes = node.querySelectorAll ? node.querySelectorAll('[data-flash-auto-dismiss="true"]') : [];
          if (childFlashes.length > 0) {
            console.log("Mutation observer detected flash messages in added node:", childFlashes.length);
            setTimeout(() => {
              window.initializeFlashMessages();
            }, 100);
          }
        }
      });
    }
  });
});

// Start observing the document body for changes
flashObserver.observe(document.body, {
  childList: true,
  subtree: true
});

console.log("Flash message mutation observer started");

// Also check for flash messages after LiveView navigation
document.addEventListener('phx:page-loading-stop', function() {
  console.log("LiveView navigation completed, checking for new flash messages");
  
  // Small delay to ensure DOM is updated
  setTimeout(() => {
    window.initializeFlashMessages();
  }, 100);
});

// Custom hook for date dropdown with custom date input
const DateDropdown = {
  mounted() {
    const select = this.el
    const customInput = document.getElementById(select.id.replace('-select', '-custom'))
    
    if (customInput) {
      select.addEventListener('change', (e) => {
        if (e.target.value === 'custom') {
          select.style.display = 'none'
          customInput.style.display = 'block'
          customInput.focus()
        }
      })
      
      customInput.addEventListener('blur', (e) => {
        if (e.target.value) {
          // Update the select with the custom value
          const option = document.createElement('option')
          option.value = e.target.value
          option.textContent = new Date(e.target.value).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            weekday: 'long'
          })
          option.selected = true
          
          // Remove custom option and add the new one
          const customOption = select.querySelector('option[value="custom"]')
          customOption.remove()
          select.appendChild(option)
          select.appendChild(customOption)
          
          // Show select, hide input
          select.style.display = 'block'
          customInput.style.display = 'none'
        }
      })
    }
  }
}

// Custom hook for departure date change
const DepartureDateChange = {
  mounted() {
    console.log("DepartureDateChange hook mounted for select:", this.el);
    
    this.el.addEventListener("change", (e) => {
      const selectedValue = e.target.value;
      console.log("Departure date changed to:", selectedValue);
      
      if (selectedValue) {
        // Get the form element
        const form = this.el.closest('form');
        if (form) {
          // Create FormData to capture all form fields
          const formData = new FormData(form);
          const packageScheduleData = {};
          
          // Extract all package_schedule fields
          for (let [key, value] of formData.entries()) {
            if (key.startsWith("package_schedule[")) {
              const fieldName = key.replace("package_schedule[", "").replace("]", "");
              packageScheduleData[fieldName] = value;
            }
          }
          
          console.log("Sending all form data:", packageScheduleData);
          
          // Push the event to LiveView with all form data
          this.pushEvent("departure_date_selected", {
            package_schedule: packageScheduleData
          });
        }
      }
    });
  }
};

// Modal handling
window.addEventListener("phx:show-modal", (e) => {
  console.log("Showing modal:", e.detail);
  const modalId = e.detail.modal_id;
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove("hidden");
    // Set the booking ID for the confirm button
    if (modalId === "cancel-booking-modal") {
      const confirmButton = document.getElementById("confirm-cancel-booking");
      if (confirmButton && e.detail.booking_id) {
        confirmButton.setAttribute("phx-value-id", e.detail.booking_id);
        console.log("Set booking ID:", e.detail.booking_id);
      }
    }
  }
});

window.addEventListener("phx:hide-modal", (e) => {
  console.log("Hiding modal:", e.detail);
  const modalId = e.detail.modal_id;
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add("hidden");
  }
});

// Close modal when clicking outside
document.addEventListener("click", (e) => {
  if (e.target.id === "cancel-booking-modal") {
    document.getElementById("cancel-booking-modal").classList.add("hidden");
  }
});

// Close modal with cancel button (fallback)
document.addEventListener("click", (e) => {
  if (e.target.id === "cancel-cancel-booking") {
    document.getElementById("cancel-booking-modal").classList.add("hidden");
  }
});

function showCancelModal(bookingId) {
  console.log("Showing cancel modal for booking:", bookingId);
  const modal = document.getElementById("cancel-booking-modal");
  const confirmButton = document.getElementById("confirm-cancel-booking");
  
  if (modal && confirmButton) {
    confirmButton.setAttribute("phx-value-id", bookingId);
    modal.classList.remove("hidden");
  }
}

// Custom hook for notification toggle
const NotificationToggle = {
  mounted() {
    console.log("NotificationToggle hook mounted");
    
    // Listen for the js:toggle-notifications event from LiveView
    this.handleEvent("js:toggle-notifications", () => {
      console.log("Received js:toggle-notifications event");
      
      const notificationMenu = document.getElementById('notification-menu');
      if (notificationMenu) {
        const isHidden = notificationMenu.classList.contains('hidden');
        if (isHidden) {
          notificationMenu.classList.remove('hidden');
        } else {
          notificationMenu.classList.add('hidden');
        }
      }
    });
  }
};

// Initialize Flatpickr on all date inputs with a consistent theme
function initializeDatePickers() {
  if (!window.flatpickr) return;
  const dateInputs = document.querySelectorAll('input[type="date"]');
  dateInputs.forEach((input) => {
    // Avoid double-init by replacing native date with text and attaching flatpickr
    if (input.dataset.fpInitialized === 'true') return;

    // Convert to text so Flatpickr renders consistently across browsers
    input.setAttribute('type', 'text');
    input.classList.add('flatpickr-input');

    const defaultValue = input.value;
    window.flatpickr(input, {
      dateFormat: 'Y-m-d',
      altInput: true,
      altFormat: 'F j, Y',
      allowInput: true,
      defaultDate: defaultValue || undefined,
      disableMobile: true,
    });

    input.dataset.fpInitialized = 'true';
  });
}

// Re-initialize on LiveView events
window.addEventListener('phx:page-loading-stop', () => {
  initializeDatePickers();
});

// Also run after initial load
document.addEventListener('DOMContentLoaded', () => {
  initializeDatePickers();
});

// Ensure pickers initialize when LiveView patches DOM
const datepickerObserver = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    if (mutation.addedNodes && mutation.addedNodes.length > 0) {
      initializeDatePickers();
      break;
    }
  }
});

if (document.body) {
  datepickerObserver.observe(document.body, { childList: true, subtree: true });
}