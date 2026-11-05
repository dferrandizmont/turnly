/* Turnly web: keep the section when the language changes. On the home page the language links are plain links to
   the home page of each language (they work without JS); this script appends the current #hash to them, so
   /gl/#features -> Español lands on /#features. It rewrites the href (and not only the click), so opening the link
   in a new tab or copying it keeps the section too. Loaded with defer from a file of its own; no storage, no
   network. The links carry no hash of their own. */
(function () {
  "use strict";
  var nav = document.querySelector("[data-lang-switcher][data-keep-hash]");
  if (!nav) return;
  var links = Array.prototype.slice.call(nav.querySelectorAll("a[href]"));
  var bases = links.map(function (link) { return link.getAttribute("href").split("#")[0]; });

  function sync() {
    var hash = window.location.hash;
    links.forEach(function (link, index) {
      link.setAttribute("href", bases[index] + (hash.length > 1 ? hash : ""));
    });
  }

  sync();
  window.addEventListener("hashchange", sync);
  window.addEventListener("pageshow", sync);
})();
