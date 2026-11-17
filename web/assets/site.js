/* Turnly web: progressive enhancement. The page is whole and still without this file.
   1. The screenshots (data-tour) become one screen at a time: tabs on the right from 761 px and, on phones, a stepper (the
      capture, a bar with previous / next and "3 / 10", then the text). Without this file every screen is listed, capture
      on the left and text on the right.
   2. Blocks marked data-reveal come in when scrolled to. Only the ones below the fold at load are hidden, so nothing
      flickers. data-reveal="stagger" brings its children in 70 ms apart.
   3. Drawings marked data-play (the month that fills, the pattern that repeats) wait at their first frame and play
      once when they are mostly in view.
   No storage and no network. With "reduce motion" the tour still switches (without movement) and the rest does nothing. */
(function () {
  "use strict";
  /* 1. The screenshot tour. The list becomes tabs (wide screens) or a stepper (phones). Tabs follow the ARIA pattern:
     roving tabindex, arrows, Home and End, and the panel is the text next to the capture. The stepper is a group with two
     real buttons (previous and next, dimmed with aria-disabled at the ends, never wrapping) and a polite live region
     that says which screen is on, only after the visitor acts. */
  var tour = document.querySelector("[data-tour]");
  var list = tour && tour.querySelector(".tour-list");
  if (list && typeof window.matchMedia === "function") (function () {
    var slides = Array.prototype.slice.call(list.children);
    var label = tour.getAttribute("data-label") || "";
    var labelPrev = tour.getAttribute("data-prev") || "";
    var labelNext = tour.getAttribute("data-next") || "";
    var labelPos = tour.getAttribute("data-position") || "{n} / {total}: {title}";
    var wide = window.matchMedia("(min-width: 761px)");
    var dark = window.matchMedia("(prefers-color-scheme: dark)");
    var nav = null, tabs = [], current = 0;
    var bar = null, prevBtn = null, nextBtn = null, pos = null, live = null;
    var titleOf = function (slide) { return slide.querySelector(".slide-txt h3").textContent; };
    var inDark = function () {
      var theme = document.documentElement.getAttribute("data-theme");
      return theme === "dark" ? true : theme === "light" ? false : dark.matches;
    };
    /* The hidden theme's capture is lazy, so it is not fetched; the ones of the theme in use, for the screen shown and the
       ones next to it, are warmed up. (Hidden screens are display: none on phones, so the theme comes from the page, not
       from what is laid out.) */
    var warmSlide = function (slide) {
      if (!slide) return;
      Array.prototype.forEach.call(slide.querySelectorAll((inDark() ? ".by-d" : ".by-l") + " img[loading=lazy]"), function (img) {
        img.loading = "eager";
      });
    };
    var warm = function (index) { warmSlide(slides[index - 1]); warmSlide(slides[index]); warmSlide(slides[index + 1]); };

    /* Wide screens: tabs. */
    var select = function (index, focus) {
      var previous = current;
      current = index;
      slides.forEach(function (slide, i) {
        slide.classList.toggle("is-on", i === index);
        slide.classList.toggle("is-out", i === previous && i !== index);
      });
      tabs.forEach(function (tab, i) {
        tab.setAttribute("aria-selected", i === index ? "true" : "false");
        tab.tabIndex = i === index ? 0 : -1;
      });
      warm(index);
      if (focus) tabs[index].focus();
    };
    var build = function () {
      nav = document.createElement("div");
      nav.className = "tour-nav";
      nav.setAttribute("role", "tablist");
      nav.setAttribute("aria-orientation", "vertical");
      if (label) nav.setAttribute("aria-label", label);
      list.setAttribute("role", "none");
      slides.forEach(function (slide, i) {
        var panel = slide.querySelector(".slide-txt");
        var tab = document.createElement("button");
        var num = document.createElement("span");
        var name = document.createElement("span");
        tab.type = "button";
        tab.className = "tour-tab";
        tab.id = "tour-tab-" + i;
        tab.setAttribute("role", "tab");
        tab.setAttribute("aria-controls", "tour-panel-" + i);
        num.className = "n"; num.setAttribute("aria-hidden", "true"); num.textContent = (i < 9 ? "0" : "") + (i + 1);
        name.className = "t"; name.textContent = titleOf(slide);
        tab.title = name.textContent;
        tab.appendChild(num); tab.appendChild(name);
        tab.addEventListener("click", function () { select(i, false); });
        nav.appendChild(tab);
        tabs.push(tab);
        slide.setAttribute("role", "none"); slide.removeAttribute("tabindex");
        panel.id = "tour-panel-" + i;
        panel.setAttribute("role", "tabpanel");
        panel.setAttribute("aria-labelledby", tab.id);
        panel.tabIndex = 0;
      });
      nav.addEventListener("keydown", function (event) {
        var to = null, n = tabs.length;
        if (event.key === "ArrowDown" || event.key === "ArrowRight") to = (current + 1) % n;
        else if (event.key === "ArrowUp" || event.key === "ArrowLeft") to = (current - 1 + n) % n;
        else if (event.key === "Home") to = 0;
        else if (event.key === "End") to = n - 1;
        if (to === null) return;
        event.preventDefault();
        select(to, true);
      });
      tour.insertBefore(nav, list);
      tour.classList.add("tour-on", "tour-boot");
      select(current, false);
      window.requestAnimationFrame(function () { window.requestAnimationFrame(function () { tour.classList.remove("tour-boot"); }); });
    };
    var teardown = function () {
      var hadFocus = nav && nav.contains(document.activeElement);
      tour.classList.remove("tour-on", "tour-boot");
      if (nav) nav.parentNode.removeChild(nav);
      nav = null; tabs = [];
      list.removeAttribute("role");
      slides.forEach(function (slide) {
        var panel = slide.querySelector(".slide-txt");
        slide.classList.remove("is-on", "is-out");
        slide.removeAttribute("role");
        ["id", "role", "aria-labelledby", "tabindex"].forEach(function (a) { panel.removeAttribute(a); });
      });
      return hadFocus;
    };

    /* Phones: one screen at a time with previous / next. */
    var chevron = function (path) {
      var ns = "http://www.w3.org/2000/svg";
      var svg = document.createElementNS(ns, "svg");
      var d = document.createElementNS(ns, "path");
      svg.setAttribute("class", "i"); svg.setAttribute("viewBox", "0 0 24 24");
      svg.setAttribute("aria-hidden", "true"); svg.setAttribute("focusable", "false");
      d.setAttribute("d", path);
      svg.appendChild(d);
      return svg;
    };
    var step = function (index, announce) {
      var n = slides.length;
      current = index;
      slides.forEach(function (slide, i) { slide.classList.toggle("is-on", i === index); });
      var said = labelPos.replace("{n}", index + 1).replace("{total}", n).replace("{title}", titleOf(slides[index]));
      /* "3 / 10" is for the eyes; next to it, hidden from view, the same position in words, so a screen reader can
         read it at any time. The live region only speaks after the visitor acts. */
      pos.firstChild.textContent = (index + 1) + " / " + n;
      pos.lastChild.textContent = said;
      prevBtn.setAttribute("aria-disabled", index === 0 ? "true" : "false");
      nextBtn.setAttribute("aria-disabled", index === n - 1 ? "true" : "false");
      warm(index);
      if (announce) {
        tour.classList.add("tour-anim");
        live.textContent = said;
      }
    };
    var go = function (delta) {
      var to = current + delta;
      if (to < 0 || to >= slides.length) return;
      step(to, true);
    };
    var stepButton = function (name, cls, path, delta) {
      var button = document.createElement("button");
      button.type = "button";
      button.className = "tour-step-btn " + cls;
      if (name) button.setAttribute("aria-label", name);
      button.appendChild(chevron(path));
      button.addEventListener("click", function () { go(delta); });
      return button;
    };
    var buildStep = function () {
      bar = document.createElement("div");
      bar.className = "tour-bar";
      prevBtn = stepButton(labelPrev, "tour-prev", "M15 6l-6 6 6 6", -1);
      nextBtn = stepButton(labelNext, "tour-next", "M9 6l6 6-6 6", 1);
      pos = document.createElement("span");
      pos.className = "tour-pos";
      pos.appendChild(document.createElement("span")).setAttribute("aria-hidden", "true");
      pos.appendChild(document.createElement("span")).className = "vh";
      bar.appendChild(prevBtn); bar.appendChild(pos); bar.appendChild(nextBtn);
      bar.addEventListener("keydown", function (event) {
        if (event.key === "ArrowLeft") go(-1);
        else if (event.key === "ArrowRight") go(1);
        else return;
        event.preventDefault();
      });
      live = document.createElement("div");
      live.className = "vh"; live.setAttribute("aria-live", "polite"); live.setAttribute("aria-atomic", "true");
      list.setAttribute("role", "none");
      slides.forEach(function (slide) { slide.setAttribute("role", "none"); });
      tour.setAttribute("role", "group");
      if (label) tour.setAttribute("aria-label", label);
      tour.insertBefore(bar, list);
      tour.appendChild(live);
      tour.classList.add("tour-step");
      step(current, false);
    };
    var teardownStep = function () {
      var hadFocus = bar && bar.contains(document.activeElement);
      tour.classList.remove("tour-step", "tour-anim");
      if (bar) bar.parentNode.removeChild(bar);
      if (live) live.parentNode.removeChild(live);
      bar = prevBtn = nextBtn = pos = live = null;
      list.removeAttribute("role");
      tour.removeAttribute("role"); tour.removeAttribute("aria-label");
      slides.forEach(function (slide) { slide.classList.remove("is-on"); slide.removeAttribute("role"); });
      return hadFocus;
    };
    /* A horizontal swipe on a capture goes to the previous or next screen (40 px or more, mostly sideways). */
    var touchX = 0, touchY = 0, touching = false;
    list.addEventListener("touchstart", function (event) {
      touching = !!bar && event.touches.length === 1 && !!event.target.closest && !!event.target.closest(".slide-fig");
      if (touching) { touchX = event.touches[0].clientX; touchY = event.touches[0].clientY; }
    }, { passive: true });
    list.addEventListener("touchend", function (event) {
      if (!touching || !bar || !event.changedTouches.length) return;
      touching = false;
      var dx = event.changedTouches[0].clientX - touchX, dy = event.changedTouches[0].clientY - touchY;
      if (Math.abs(dx) >= 40 && Math.abs(dx) > 1.5 * Math.abs(dy)) go(dx < 0 ? 1 : -1);
    }, { passive: true });
    list.addEventListener("touchcancel", function () { touching = false; }, { passive: true });

    var apply = function () {
      if (wide.matches) {
        var hadStepFocus = bar ? teardownStep() : false;
        if (!nav) build();
        if (hadStepFocus && tabs[current]) tabs[current].focus();
      } else {
        var hadTabFocus = nav ? teardown() : false;
        if (!bar) buildStep();
        if (hadTabFocus) nextBtn.focus();
      }
    };
    apply();
    if (wide.addEventListener) wide.addEventListener("change", apply); else if (wide.addListener) wide.addListener(apply);
    /* When the theme changes (the button or the system), warm the new theme's captures around the screen in use. */
    var rewarm = function () { warm(current); };
    if (dark.addEventListener) dark.addEventListener("change", rewarm); else if (dark.addListener) dark.addListener(rewarm);
    if (typeof window.MutationObserver === "function") {
      new MutationObserver(rewarm).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    }
  })();

  if (!("IntersectionObserver" in window)) return;
  if (typeof window.matchMedia !== "function") return;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  var each = function (items, fn) { Array.prototype.forEach.call(items, fn); };

  var pending = Array.prototype.filter.call(document.querySelectorAll("[data-reveal]"), function (el) {
    return el.getBoundingClientRect().top > window.innerHeight;
  });
  if (pending.length) {
    var revealer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("in");
        revealer.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -12% 0px" });
    pending.forEach(function (el) {
      el.classList.add("reveal");
      if (el.getAttribute("data-reveal") === "stagger") el.classList.add("stagger");
      revealer.observe(el);
    });
  }

  var plays = document.querySelectorAll("[data-play]");
  if (plays.length) {
    var player = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("on");
        player.unobserve(entry.target);
      });
    }, { threshold: 0.45 });
    each(plays, function (el) {
      el.classList.add("arm");
      player.observe(el);
    });
  }
})();
