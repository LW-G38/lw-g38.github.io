/* al-folio prototype behaviour: theme cycling, mobile nav, back-to-top, abstract toggles. */
(function () {
  "use strict";

  var STORAGE_KEY = "al-folio-theme-setting"; // "system" | "light" | "dark"
  var root = document.documentElement;

  function systemPrefersDark() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  function readSetting() {
    try {
      var v = localStorage.getItem(STORAGE_KEY);
      return v === "light" || v === "dark" || v === "system" ? v : "system";
    } catch (e) {
      return "system";
    }
  }

  function writeSetting(value) {
    try {
      localStorage.setItem(STORAGE_KEY, value);
    } catch (e) {
      /* private mode / blocked storage: theme still applies for this page view */
    }
  }

  function applyTheme(setting) {
    var effective = setting === "system" ? (systemPrefersDark() ? "dark" : "light") : setting;
    root.setAttribute("data-theme", effective);
    root.setAttribute("data-theme-setting", setting);

    var btn = document.getElementById("theme-toggle");
    if (!btn) return;
    var icon = { system: "fa-circle-half-stroke", light: "fa-sun", dark: "fa-moon" }[setting];
    btn.innerHTML = '<i class="fa-solid ' + icon + '" aria-hidden="true"></i>';
    btn.setAttribute("aria-label", "Theme: " + setting + " (click to change)");
    btn.setAttribute("title", "Theme: " + setting);
  }

  // Apply before first paint where possible to avoid a light flash in dark mode.
  applyTheme(readSetting());

  if (window.matchMedia) {
    var mq = window.matchMedia("(prefers-color-scheme: dark)");
    var onChange = function () {
      if (readSetting() === "system") applyTheme("system");
    };
    if (mq.addEventListener) mq.addEventListener("change", onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }

  document.addEventListener("DOMContentLoaded", function () {
    applyTheme(readSetting());

    // Theme toggle: system -> light -> dark -> system
    var toggle = document.getElementById("theme-toggle");
    if (toggle) {
      toggle.addEventListener("click", function () {
        var order = ["system", "light", "dark"];
        var next = order[(order.indexOf(readSetting()) + 1) % order.length];
        writeSetting(next);
        applyTheme(next);
      });
    }

    // Mobile navbar
    var navToggler = document.querySelector(".navbar-toggler");
    var navCollapse = document.getElementById("navbar-collapse");
    if (navToggler && navCollapse) {
      navToggler.addEventListener("click", function () {
        var open = navCollapse.classList.toggle("show");
        navToggler.setAttribute("aria-expanded", open ? "true" : "false");
      });
    }

    // Abstract show/hide on publication entries
    document.querySelectorAll("[data-abstract-toggle]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var target = document.getElementById(btn.getAttribute("data-abstract-toggle"));
        if (!target) return;
        var open = target.hasAttribute("hidden");
        if (open) target.removeAttribute("hidden");
        else target.setAttribute("hidden", "");
        btn.setAttribute("aria-expanded", open ? "true" : "false");
      });
    });

    // ---------------------------------------------------------------------
    // Contact form
    //
    // GitHub Pages is static, so a form needs a third-party endpoint to
    // actually deliver mail. Set data-endpoint on the form (e.g. a Formspree
    // URL) and submissions POST there. With no endpoint configured the form
    // falls back to opening the visitor's mail client, pre-filled -- so the
    // page is useful before any signup.
    // ---------------------------------------------------------------------
    var contactForm = document.getElementById("contact-form");
    if (contactForm) {
      var status = document.getElementById("form-status");

      var setStatus = function (kind, message) {
        status.className = "form-status show " + kind;
        status.textContent = message;
      };

      var markInvalid = function (row, invalid) {
        row.classList.toggle("invalid", invalid);
        var field = row.querySelector(".form-control");
        if (field) field.setAttribute("aria-invalid", invalid ? "true" : "false");
      };

      var validate = function () {
        var ok = true;
        contactForm.querySelectorAll("[data-required]").forEach(function (field) {
          var row = field.closest(".form-row");
          var value = field.value.trim();
          var bad = !value;
          if (!bad && field.type === "email") {
            bad = !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
          }
          markInvalid(row, bad);
          if (bad) ok = false;
        });
        return ok;
      };

      contactForm.querySelectorAll(".form-control").forEach(function (field) {
        field.addEventListener("input", function () {
          var row = field.closest(".form-row");
          if (row.classList.contains("invalid")) markInvalid(row, false);
        });
      });

      contactForm.addEventListener("submit", function (event) {
        event.preventDefault();

        // Honeypot: a real person never fills this in.
        if (contactForm.querySelector(".honeypot input").value) return;

        if (!validate()) {
          setStatus("error", "Please fix the highlighted fields and try again.");
          return;
        }

        // Use namedItem: form.name resolves to the form's own name attribute,
        // not the field called "name".
        var fields = contactForm.elements;
        var valueOf = function (fieldName) {
          var field = fields.namedItem(fieldName);
          return field ? field.value.trim() : "";
        };

        var data = {
          name: valueOf("name"),
          email: valueOf("email"),
          subject: valueOf("subject") || "Message from your website",
          message: valueOf("message"),
        };

        // Web3Forms routes on this key; harmless for other providers.
        var accessKey = valueOf("access_key");
        if (accessKey) {
          data.access_key = accessKey;
          data.from_name = valueOf("from_name") || "Website contact form";
        }

        var endpoint = (contactForm.dataset.endpoint || "").trim();
        var submitBtn = contactForm.querySelector(".btn-submit");

        if (!endpoint) {
          var body =
            "From: " + data.name + " <" + data.email + ">\n\n" + data.message;
          window.location.href =
            "mailto:" +
            contactForm.dataset.email +
            "?subject=" +
            encodeURIComponent(data.subject) +
            "&body=" +
            encodeURIComponent(body);
          setStatus(
            "success",
            "Opening your email app with the message ready to send. If nothing happened, email " +
              contactForm.dataset.email +
              " directly."
          );
          return;
        }

        submitBtn.disabled = true;
        submitBtn.textContent = "Sending…";

        fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify(data),
        })
          .then(function (response) {
            // Web3Forms answers 200 with {success:false} on a rejected
            // submission, so check the payload as well as the status.
            return response
              .json()
              .catch(function () {
                return {};
              })
              .then(function (payload) {
                if (!response.ok || payload.success === false) {
                  throw new Error(payload.message || "Request failed: " + response.status);
                }
                contactForm.reset();
                setStatus("success", "Thanks — your message has been sent. I'll reply by email.");
              });
          })
          .catch(function () {
            setStatus(
              "error",
              "Sorry, the message could not be sent. Please email " +
                contactForm.dataset.email +
                " instead."
            );
          })
          .then(function () {
            submitBtn.disabled = false;
            submitBtn.textContent = "Send message";
          });
      });
    }

    // Back to top
    var backToTop = document.getElementById("back-to-top");
    if (backToTop) {
      var onScroll = function () {
        backToTop.classList.toggle("show", window.scrollY > 300);
      };
      window.addEventListener("scroll", onScroll, { passive: true });
      onScroll();
      backToTop.addEventListener("click", function () {
        window.scrollTo({ top: 0, behavior: "smooth" });
      });
    }
  });
})();
