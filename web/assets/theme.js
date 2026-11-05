/* Turnly web: light/dark theme toggle. Loaded in <head> without defer so the saved theme is applied before the
   first paint. With no saved choice the page follows prefers-color-scheme (CSS). The choice is kept in
   localStorage («turnly-theme» = «light» | «dark»), never in a cookie, and is not sent anywhere. Without JS the
   toggle stays hidden and the page follows the system. */
(function () {
  "use strict";
  var KEY = "turnly-theme";
  var root = document.documentElement;
  var system = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function valid(value) {
    return value === "light" || value === "dark" ? value : null;
  }
  function read() {
    try { return valid(window.localStorage.getItem(KEY)); } catch (e) { return null; }
  }
  function save(value) {
    try { window.localStorage.setItem(KEY, value); } catch (e) { /* storage blocked: applies to this page only */ }
  }
  function apply(value) {
    if (value) root.setAttribute("data-theme", value);
    else root.removeAttribute("data-theme");
  }
  function current() {
    return valid(root.getAttribute("data-theme")) || (system && system.matches ? "dark" : "light");
  }

  apply(read());

  function connect() {
    var button = document.querySelector("[data-theme-toggle]");
    if (!button) return;
    function sync() {
      button.setAttribute("aria-pressed", current() === "dark" ? "true" : "false");
    }
    button.addEventListener("click", function () {
      var next = current() === "dark" ? "light" : "dark";
      apply(next);
      save(next);
      sync();
    });
    if (system) {
      if (system.addEventListener) system.addEventListener("change", sync);
      else if (system.addListener) system.addListener(sync);
    }
    window.addEventListener("storage", function (event) {
      if (event.key === KEY) { apply(valid(event.newValue)); sync(); }
    });
    sync();
    button.hidden = false;
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", connect);
  else connect();
})();
