/* Turnly web: theme toggle with three states, system -> light -> dark -> system. Loaded in <head> without defer so
   the saved theme is applied before the first paint. «System» is no saved choice at all: the page follows
   prefers-color-scheme (CSS) and nothing is kept in localStorage. «Light» and «dark» are kept in localStorage
   («turnly-theme» = «light» | «dark»), never in a cookie, and are not sent anywhere. Without JS the toggle stays
   hidden and the page follows the system. */
(function () {
  "use strict";
  var KEY = "turnly-theme";
  var ORDER = [null, "light", "dark"];
  var root = document.documentElement;

  function valid(value) {
    return value === "light" || value === "dark" ? value : null;
  }
  function read() {
    try { return valid(window.localStorage.getItem(KEY)); } catch (e) { return null; }
  }
  function save(value) {
    try {
      if (value) window.localStorage.setItem(KEY, value);
      else window.localStorage.removeItem(KEY);
    } catch (e) { /* storage blocked: applies to this page only */ }
  }
  function apply(value) {
    if (value) root.setAttribute("data-theme", value);
    else root.removeAttribute("data-theme");
  }
  function current() {
    return valid(root.getAttribute("data-theme"));
  }

  apply(read());

  function connect() {
    var button = document.querySelector("[data-theme-toggle]");
    if (!button) return;
    var text = button.querySelector("[data-theme-text]");
    var labels = {
      system: button.getAttribute("data-text-system"),
      light: button.getAttribute("data-text-light"),
      dark: button.getAttribute("data-text-dark")
    };
    // The visible text is the accessible name, so the active theme is always announced.
    function sync() {
      if (text) text.textContent = labels[current() || "system"];
    }
    button.addEventListener("click", function () {
      var next = ORDER[(ORDER.indexOf(current()) + 1) % ORDER.length];
      apply(next);
      save(next);
      sync();
    });
    window.addEventListener("storage", function (event) {
      if (event.key === KEY || event.key === null) { apply(read()); sync(); }
    });
    sync();
    button.hidden = false;
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", connect);
  else connect();
})();
