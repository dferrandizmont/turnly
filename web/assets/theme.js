/* Turnly web: light or dark, with the same sun/moon toggle as the other sites. Loaded in <head> without defer so
   the theme is on <html> before the first paint. With no saved choice the page follows the system
   (prefers-color-scheme) and changes with it. The button [data-theme-toggle] comes hidden in the HTML and only
   shows with this file; it is a toggle (aria-pressed = dark is on). If the chosen theme is the one the system
   already has, the saved choice is dropped, so going back to the system theme is going back to automatic.
   The only thing kept is «turnly-theme» = «light» | «dark» in localStorage (never a cookie, never sent
   anywhere), always inside try/catch. Without JS the toggle stays hidden and the page follows the system. */
(function () {
  "use strict";
  var KEY = "turnly-theme";
  var root = document.documentElement;
  /* .js lets the stylesheet tell the page that scripts run (the demo replaces the static screenshot, the tour gets its tabs). */
  root.classList.add("js");
  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function stored() {
    try {
      var value = window.localStorage.getItem(KEY);
      return value === "light" || value === "dark" ? value : null;
    } catch (e) { return null; }
  }
  function store(value) {
    try {
      if (value) window.localStorage.setItem(KEY, value);
      else window.localStorage.removeItem(KEY);
    } catch (e) { /* storage blocked: applies to this page only */ }
  }
  function system() {
    return media && media.matches ? "dark" : "light";
  }

  var choice = stored();
  function current() {
    return choice || system();
  }
  function apply() {
    var theme = current();
    root.setAttribute("data-theme", theme);
    var buttons = document.querySelectorAll("[data-theme-toggle]");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    }
  }
  apply();

  function onSystemChange() {
    if (!choice) apply();
  }
  if (media) {
    if (media.addEventListener) media.addEventListener("change", onSystemChange);
    else if (media.addListener) media.addListener(onSystemChange);
  }
  window.addEventListener("storage", function (event) {
    if (event.key !== KEY && event.key !== null) return;
    choice = stored();
    apply();
  });

  function toggle() {
    var next = current() === "dark" ? "light" : "dark";
    choice = next === system() ? null : next;
    store(choice);
    /* On a press (not on load) the colours fade for ~400 ms: styles.css transitions them while .theme-anim is on. */
    if (!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches)) {
      root.classList.add("theme-anim");
      window.clearTimeout(toggle.timer);
      toggle.timer = window.setTimeout(function () { root.classList.remove("theme-anim"); }, 420);
    }
    apply();
  }

  function wire() {
    var buttons = document.querySelectorAll("[data-theme-toggle]");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].hidden = false;
      buttons[i].addEventListener("click", toggle);
    }
    apply();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", wire);
  else wire();
})();
