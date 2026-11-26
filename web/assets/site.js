/* Turnly web: the month you can paint (hero), the screens tour and the scroll reveals. Plain JS in a file of its own (the CSP forbids inline
   script and style=): nothing here writes a style attribute or a style property, every look comes from a class the stylesheet defines.
   The texts of the demo come from content/<language>.json through data-demo on #board (JSON in an attribute, never a script); the page works
   without any of this (the hero then shows a real screenshot, the tour lists every screen). */
(function () {
  "use strict";
  var doc = document, root = doc.documentElement;
  var reduceQuery = window.matchMedia ? window.matchMedia("(prefers-reduced-motion: reduce)") : null;
  function reduced() { return !!(reduceQuery && reduceQuery.matches); }
  function $(id) { return doc.getElementById(id); }
  function el(tag, cls, html) { var e = doc.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  function fmt(s, v) { return String(s).replace(/\{(\w+)\}/g, function (m, k) { return v && v[k] != null ? v[k] : m; }); }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function icon(name) { return '<svg class="ms" aria-hidden="true" focusable="false"><use href="#ms-' + name + '"></use></svg>'; }
  function restart(node, cls) { node.classList.remove(cls); void node.offsetWidth; node.classList.add(cls); }

  /* ---------------------------------------------------------------- the demo */
  function demo() {
    var board = $("board"); if (!board) return;
    var T = JSON.parse(board.getAttribute("data-demo"));
    var P = T.paint;
    /* Shift catalogue (schedule/domain/presets.dart). The id (M, T, N, G, D, L, S) is only for the logic here: what is shown is the
       language's own code and name (`code`, `name`), as the app does (catalogShift*Code and catalogShift*Name in app_<lang>.arb).
       `st` and `en` are the shift's start and end in minutes of the day (the end of a night is after midnight). */
    var SH = {
      M: { c: "m", hrs: 8, work: true, st: 360, en: 840 }, T: { c: "t", hrs: 8, work: true, st: 840, en: 1320 },
      N: { c: "n", hrs: 8, work: true, st: 1320, en: 1800 }, G: { c: "g", hrs: 24, work: true, st: 480, en: 1920 },
      D: { c: "d", hrs: 12, work: true, st: 480, en: 1200 }, L: { c: "l", hrs: 0, work: false }, S: { c: "s", hrs: 0, work: false }
    };
    Object.keys(SH).forEach(function (k) { var t = T.shifts[k]; SH[k].n = t.name; SH[k].code = t.code; SH[k].h = t.short || ""; SH[k].full = t.full || ""; });
    function seq(spec) { var a = []; spec.split(" ").forEach(function (tk) { var n = parseInt(tk.slice(1), 10) || 1; for (var i = 0; i < n; i++) a.push(tk.charAt(0)); }); return a; }
    /* The catalogue's own rotations and steps (presets.dart); `start` is the cycle day that December 1st falls on. */
    var ROTS = [
      { id: "correturnos", steps: seq("M5 L2 T5 L2 N5 L2"), start: 15 },
      { id: "24x72", steps: seq("G L3"), start: 0 },
      { id: "4x4", steps: seq("D4 L4"), start: 0 },
      { id: "6x4", steps: seq("M6 L4"), start: 0 },
      { id: "5x2", steps: seq("M5 L2"), start: 1 },
      { id: "2-2-3", steps: seq("D2 L2 D3 L2 D2 L3"), start: 0 },
      { id: "2x2", steps: seq("M2 L2"), start: 0 },
      { id: "3x1", steps: seq("M3 L"), start: 0 }
    ];
    var BRUSHES = ["M", "T", "N", "L", "S"];
    /* December 2026 starts on a Tuesday: cell 0 is Monday 30 November, cells 32-34 are 1-3 January. «Now» is a fixed example, 18:00 on the 24th. */
    var HOL = { 7: 1, 8: 1, 25: 1, 32: 1 }, TODAY = 24, CELLS = 35, NOW = 18 * 60;
    function dayNum(d) { return d === 0 ? 30 : d <= 31 ? d : d - 31; }
    function inMonth(d) { return d >= 1 && d <= 31; }
    function shiftText(k) { var s = SH[k]; return s.full ? s.n + ", " + s.full : s.n; }
    function same(a, b) { return a.length === b.length && a.every(function (x, i) { return x === b[i]; }); }
    function lenClass(k) { return "n" + Math.min(SH[k].code.length, 4); }

    var state = { rot: 0, start: ROTS[0].start, paint: {} };
    var undoStack = [], redoStack = [];
    var brush = null, doubling = false, tool = "pattern";

    function shiftsAt(d) {
      if (state.paint[d]) return state.paint[d];
      var r = ROTS[state.rot], len = r.steps.length;
      return [r.steps[((state.start + d - 1) % len + len) % len]];
    }

    /* ----- markup */
    board.innerHTML =
      '<div class="ph" id="ph" hidden><p class="ph-l" id="phL"></p><button class="ibtn" type="button" id="phPat" title="' + esc(P.pattern_button) + '" aria-label="' + esc(P.pattern_button) + '">' + icon("repeat") + '</button><button class="fbtn" type="button" id="done">' + esc(P.done) + "</button></div>" +
      '<div class="tcard" id="tcard" aria-live="polite"><div class="tc-main"><p class="tc-label" id="tcLabel"></p><p class="tc-name" id="tcName"></p><p class="tc-hours" id="tcHours"></p><span class="tc-count" id="tcCount" hidden></span><p class="tc-off" id="tcOff"></p></div><span class="tc-badge" id="tcBadge" aria-hidden="true"></span></div>' +
      '<div class="mh"><p class="mt" id="mt">' + esc(T.month) + '</p><span class="msum" id="msum"></span></div>' +
      '<div class="wk" aria-hidden="true">' + T.weekdays.map(function (w) { return "<span>" + esc(w) + "</span>"; }).join("") + "</div>" +
      '<div class="gbox"><div class="grid" id="grid" role="group" aria-labelledby="mt"></div></div>' +
      '<div class="tools"><div class="seg" role="group" aria-label="' + esc(T.tabs_label) + '"><button type="button" id="tabPat" aria-pressed="true">' + icon("repeat") + esc(T.tab_pattern) + '</button><button type="button" id="tabPaint" aria-pressed="false">' + icon("brush") + esc(T.tab_paint) + "</button></div>" +
      '<div class="panel" id="panPat"><div class="rots-box at-start" id="rotsBox"><ul class="rots" id="rots" aria-label="' + esc(T.pattern_label) + '"></ul><span class="edge-l" aria-hidden="true"></span><span class="edge-r" aria-hidden="true"></span></div>' +
      '<div class="seq"><div class="seq-h"><p class="bodyst">' + esc(T.sequence) + '</p><span class="meta" id="seqLen"></span></div><p class="meta">' + esc(T.cycle_hint) + '</p><div class="cs-wrap"><div class="cs" id="cs" role="group" aria-label="' + esc(T.sequence) + '"></div></div><p class="res" id="res" aria-live="polite"></p><ul class="legend" id="legend"></ul><button class="tbtn" type="button" id="clr" hidden>' + esc(T.clear_painted) + "</button></div></div>" +
      '<div class="panel" id="panPaint" hidden><div class="sheet" role="group" aria-label="' + esc(P.tools_label) + '"><div class="seg" id="modes"><button type="button" id="mRep" aria-pressed="true">' + icon("swap") + esc(P.mode_replace) + '</button><button type="button" id="mAdd" aria-pressed="false" aria-label="' + esc(P.mode_add_spoken) + '">' + icon("add-shift") + esc(P.mode_add) + "</button></div>" +
      '<div class="pv"><div class="pv-row" id="pv"></div><button class="rbtn" type="button" id="undo" aria-label="' + esc(P.undo) + '" title="' + esc(P.undo) + '" disabled>' + icon("undo") + '</button><button class="rbtn" type="button" id="redo" aria-label="' + esc(P.redo) + '" title="' + esc(P.redo) + '" disabled>' + icon("redo") + "</button></div>" +
      '<div class="pucks" id="pucks"></div></div><p class="hint" id="hint"></p></div></div>';

    var grid = $("grid"), rotsEl = $("rots"), csEl = $("cs"), pucksEl = $("pucks"), hint = $("hint");
    var ph = $("ph"), tcard = $("tcard"), undoBtn = $("undo"), redoBtn = $("redo"), clrBtn = $("clr");

    /* ----- month: DayCell (day_cell.dart). Each shift of the day is a band with its own tint, ink code and hours; two or more shifts use the
       smaller code (cellCodeMulti), the bar at the bottom is one segment per shift, and a third shift goes to a «+n» band. */
    var cells = [];
    for (var d = 0; d < CELLS; d++) {
      var w = el("div", "cellw"), c;
      if (inMonth(d)) {
        c = el("button", "cell" + (HOL[d] ? " hol" : "") + (d === TODAY ? " today" : ""), '<span class="dn">' + dayNum(d) + '</span><span class="bands"></span><span class="bar"></span>');
        c.type = "button"; c.setAttribute("data-d", d); c.tabIndex = d === TODAY ? 0 : -1;
      } else {
        c = el("span", "cell out" + (HOL[d] ? " hol" : ""), '<span class="dn">' + dayNum(d) + "</span>"); c.setAttribute("aria-hidden", "true");
      }
      w.appendChild(c); grid.appendChild(w); cells.push(c);
    }
    function bandHtml(k, multi) {
      var s = SH[k];
      return '<span class="bd s-' + s.c + '"><b class="cd ' + lenClass(k) + '">' + esc(s.code) + "</b>" + (s.h ? '<span class="hr">' + esc(s.h) + "</span>" : "") + "</span>";
    }
    function paintCell(d, animate) {
      if (!inMonth(d)) return;
      var ks = shiftsAt(d), c = cells[d], bands = c.querySelector(".bands"), bar = c.querySelector(".bar"), prev = c.getAttribute("data-k"), key = ks.join("");
      c.className = c.className.replace(/\b(s-\w|multi|b3|empty|pop)\b/g, "").replace(/\s+/g, " ").trim();
      c.setAttribute("data-k", key);
      var label, multi = ks.length > 1, html = "", segs = "";
      if (!ks.length) { c.classList.add("empty"); label = P.empty; }
      else {
        c.classList.add("s-" + SH[ks[0]].c); if (multi) c.classList.add("multi");
        /* day_cell.dart: at most three bands; from the fourth shift on, the first two and a neutral +n band for the ones not shown. The bar keeps
           one segment per shift whatever is shown. */
        var shown = ks.length > 3 ? ks.slice(0, 2) : ks;
        shown.forEach(function (k) { html += bandHtml(k, multi); });
        ks.forEach(function (k) { segs += '<i class="b-' + SH[k].c + '"></i>'; });
        if (ks.length > 3) html += '<span class="bd more"><b class="cd n2">+' + (ks.length - 2) + "</b></span>";
        if (shown.length + (ks.length > 3 ? 1 : 0) > 2) c.classList.add("b3");
        label = ks.map(shiftText).join(T.and);
      }
      bands.innerHTML = html; bar.innerHTML = segs;
      c.setAttribute("aria-label", fmt(T.day_label, { day: dayNum(d), shift: label }) + (d === TODAY ? T.day_today : ""));
      if (animate && prev !== key && !reduced()) c.classList.add("pop");
    }
    grid.addEventListener("animationend", function (e) { var c = e.target.closest && e.target.closest(".cell"); if (c && e.target.classList.contains("bands")) c.classList.remove("pop"); });

    function wave() { restart(grid, "wave"); clearTimeout(wave.t); wave.t = setTimeout(function () { grid.classList.remove("wave"); }, 2200); }
    function paintAll() { for (var d = 1; d <= 31; d++) paintCell(d, false); updateSummary(); updateToday(false); }

    function updateSummary() {
      var n = 0, h = 0;
      for (var d = 1; d <= 31; d++) shiftsAt(d).forEach(function (k) { if (SH[k].hrs) { n++; h += SH[k].hrs; } });
      $("msum").textContent = fmt(n === 1 ? T.summary_one : T.summary, { n: n, h: h });
    }
    /* TodayCard, expanded (today_card.dart): label, display name, hours on their own line, the countdown (from the fixed example time) and the next day off */
    /* The card follows today_status.dart: the shift in progress comes first (its end is the countdown); if none is, the next one that starts today
       (its start is). "Now" is the fixed example 18:00. The next day off is not announced when the shift in progress still lasts into that day
       (today_card.dart, activeShiftOverlaps). */
    function todayState(ks) {
      var cur = null, next = null, last = null;
      ks.forEach(function (k) {
        var s = SH[k]; if (!s.work) return; last = k;
        if (s.st <= NOW && s.en > NOW) cur = k;
        else if (s.st > NOW && (!next || s.st < SH[next].st)) next = k;
      });
      return { cur: cur, next: next, main: cur || next || last || ks[0] || null };
    }
    function fmtDur(m) { return fmt(T.duration_fmt, { h: Math.round(m / 60) }); }
    function updateToday(animate) {
      var ks = shiftsAt(TODAY), st = todayState(ks), lead = st.main, s = lead ? SH[lead] : null;
      tcard.className = "tcard" + (s ? " s-" + s.c : "");
      $("tcBadge").textContent = lead ? SH[lead].code : "–";
      $("tcBadge").className = "tc-badge " + (lead ? lenClass(lead) : "");
      $("tcLabel").textContent = st.cur ? T.now : lead === "N" ? T.tonight : T.today_label;
      $("tcName").textContent = lead ? SH[lead].n : P.empty;
      var hrs = $("tcHours"); hrs.textContent = lead ? SH[lead].full : ""; hrs.hidden = !hrs.textContent;
      var cnt = $("tcCount"), txt = st.cur ? fmt(T.ends_in, { duration: fmtDur(SH[st.cur].en - NOW) }) : st.next ? fmt(T.starts_in, { duration: fmtDur(SH[st.next].st - NOW) }) : "";
      cnt.hidden = !txt; cnt.textContent = txt;
      var off = "";
      for (var d = TODAY + 1; d < CELLS; d++) {
        var k = shiftsAt(d);
        if (!k.length || k.every(function (x) { return !SH[x].hrs; })) {
          /* the shift in progress reaches into this day: its end is on the card, the day off is not announced yet */
          if (st.cur && SH[st.cur].en > (d - TODAY) * 1440) break;
          off = d === TODAY + 1 ? T.off_tomorrow : fmt(T.off_on, { weekday: T.weekday_names[(d % 7 + 1) % 7], day: dayNum(d) }); break;
        }
      }
      $("tcOff").textContent = off; $("tcOff").hidden = !off;
      if (animate && !reduced()) restart(tcard, "tc-swap");
    }

    /* ----- rotations (PatternCard) */
    function chipHtml(k, big) { return '<li class="chip-o"><span class="sc s-' + SH[k].c + (big ? " big" : "") + " " + lenClass(k) + '">' + esc(SH[k].code) + "</span></li>"; }
    ROTS.forEach(function (r, i) {
      var t = T.rotations[r.id], li = el("li"), b = el("button", "pcard");
      b.type = "button"; b.setAttribute("aria-pressed", String(i === state.rot));
      b.innerHTML = '<span class="pc-h"><span class="pc-t"><span class="pc-n">' + esc(t.name) + '</span><span class="pc-l">' + esc(fmt(T.cycle_days, { n: r.steps.length })) + '</span></span><svg class="ms pc-ck" aria-hidden="true" focusable="false"><use href="#ms-check"></use></svg></span><span class="pc-d"></span>';
      b.querySelector(".pc-d").textContent = t.description;
      var ul = el("ul", "chips"); ul.setAttribute("aria-hidden", "true"); ul.innerHTML = r.steps.map(function (k) { return chipHtml(k, false); }).join(""); b.appendChild(ul);
      b.addEventListener("click", function () { chooseRot(i); });
      li.appendChild(b); rotsEl.appendChild(li);
    });
    /* Choosing a rotation or a cycle day keeps what was painted by hand (the app's wizard keeps the manual changes); «clear» is its own action */
    function chooseRot(i) {
      if (state.rot === i) return;
      push(); state.rot = i; state.start = ROTS[i].start; refresh(true);
    }
    var rotsBox = $("rotsBox");
    function edges() {
      var max = rotsEl.scrollWidth - rotsEl.clientWidth - 2;
      rotsBox.classList.toggle("at-start", rotsEl.scrollLeft <= 2); rotsBox.classList.toggle("at-end", rotsEl.scrollLeft >= max);
    }
    rotsEl.addEventListener("scroll", edges, { passive: true }); window.addEventListener("resize", edges); edges();

    /* ----- «Tu secuencia» (CycleStrip): the buttons are built once per rotation and only marked afterwards, so the focus stays where it is */
    var stripRot = -1, stripBtns = [];
    function buildStrip() {
      var r = ROTS[state.rot]; csEl.innerHTML = ""; stripBtns = []; stripRot = state.rot;
      $("seqLen").textContent = fmt(T.cycle_days, { n: r.steps.length });
      r.steps.forEach(function (k, i) {
        var b = el("button", "cs-c");
        b.type = "button";
        b.setAttribute("aria-label", fmt(T.cycle_day_label, { n: i + 1, total: r.steps.length, shift: shiftText(k) }));
        b.innerHTML = '<span class="chip-o"><span class="sc big s-' + SH[k].c + " " + lenClass(k) + '">' + esc(SH[k].code) + '</span></span><span class="cs-n">' + (i + 1) + "</span>";
        b.addEventListener("click", function () { if (state.start === i) return; push(); state.start = i; refresh(true); });
        csEl.appendChild(b); stripBtns.push(b);
      });
      /* PatternShiftLabel: a badge, the name and the hours of each shift of the cycle (sin horario for the days off) */
      var seen = {}, html = "";
      r.steps.forEach(function (k) {
        if (seen[k]) return; seen[k] = 1;
        html += '<li class="psl"><span class="sc s-' + SH[k].c + " " + lenClass(k) + '" aria-hidden="true">' + esc(SH[k].code) + '</span><span class="psl-t"><span class="psl-n">' + esc(SH[k].n) + '</span><span class="meta">' + esc(SH[k].full || T.no_times) + "</span></span></li>";
      });
      $("legend").innerHTML = html;
    }
    function renderStrip() {
      if (stripRot !== state.rot) buildStrip();
      var r = ROTS[state.rot];
      stripBtns.forEach(function (b, i) { b.setAttribute("aria-pressed", String(i === state.start)); b.firstChild.classList.toggle("on", i === state.start); b.lastChild.classList.toggle("on", i === state.start); });
      $("res").textContent = fmt(T.that_day, { shifts: shiftText(r.steps[state.start]) });
      [].forEach.call(rotsEl.querySelectorAll(".pcard"), function (b, j) { b.setAttribute("aria-pressed", String(j === state.rot)); });
      clrBtn.hidden = !Object.keys(state.paint).length;
    }
    clrBtn.addEventListener("click", function () { push(); state.paint = {}; refresh(true); if (stripBtns[state.start]) stripBtns[state.start].focus({ preventScroll: true }); });

    /* ----- tools: paint bar (PaintBar) */
    var pucks = [{ k: "erase" }].concat(BRUSHES.map(function (k) { return { k: k }; }));
    pucks.forEach(function (p) {
      var b = el("button", "puck" + (p.k === "erase" ? " erase" : " s-" + SH[p.k].c));
      b.type = "button"; b.setAttribute("data-k", p.k); b.setAttribute("aria-pressed", "false");
      b.innerHTML = '<span class="pd ' + (p.k === "erase" ? "" : lenClass(p.k)) + '" aria-hidden="true">' + (p.k === "erase" ? icon("eraser") : esc(SH[p.k].code)) + '</span><span class="pn">' + esc(p.k === "erase" ? P.eraser : SH[p.k].n) + "</span>";
      if (p.k !== "erase" && SH[p.k].full) b.setAttribute("aria-label", shiftText(p.k));
      b.addEventListener("click", function () { setBrush(brush === p.k ? null : p.k); });
      pucksEl.appendChild(b);
    });
    function miniCell(ks) {
      if (!ks.length) return '<span class="mini empty"></span>';
      return '<span class="mini s-' + SH[ks[0]].c + '">' + ks.map(function (k) { return '<b class="s-' + SH[k].c + '">' + esc(SH[k].code) + "</b>"; }).join("") + '<span class="bar" aria-hidden="true">' + ks.map(function (k) { return '<i class="b-' + SH[k].c + '"></i>'; }).join("") + "</span></span>";
    }
    function updatePreview() {
      var pv = $("pv");
      /* nothing to preview until a tool is chosen (the word empty is only the eraser's result) */
      if (!brush) { pv.innerHTML = ""; pv.removeAttribute("role"); pv.removeAttribute("aria-label"); return; }
      var chosen = brush !== "erase" ? brush : null, adding = !!chosen && doubling;
      var before = chosen === "M" ? "T" : "M", after = !brush ? [] : brush === "erase" ? [] : adding ? [before, chosen] : [chosen];
      var title = adding ? P.preview_title_double : P.preview_title;
      var effect = brush === "erase" ? P.effect_erase : adding ? P.effect_add : P.effect_replace;
      var hours = chosen && SH[chosen].full ? SH[chosen].full : "";
      /* read as the app reads it (paintPreviewSpoken / paintPreviewSpokenTimes of each language) */
      var spoken = fmt(hours ? P.preview_spoken_times : P.preview_spoken, { title: title, before: SH[before].n, after: after.length ? after.map(function (k) { return SH[k].n; }).join(T.and) : P.empty, times: hours, effect: effect });
      pv.setAttribute("role", "img"); pv.setAttribute("aria-label", spoken);
      pv.innerHTML = '<span class="pv-t" aria-hidden="true">' + esc(title) + "</span>" + miniCell([before]) + icon("becomes") + miniCell(after) + (hours ? '<span class="pv-h" aria-hidden="true">' + esc(hours) + "</span>" : "") + '<span class="pv-e" aria-hidden="true">' + esc(effect) + "</span>";
    }
    function setBrush(k) {
      brush = k; board.classList.toggle("painting", !!brush); ph.hidden = !brush;
      [].forEach.call(pucksEl.children, function (x) { x.setAttribute("aria-pressed", String(x.getAttribute("data-k") === brush)); });
      $("modes").classList.toggle("off", brush === "erase"); $("mRep").disabled = $("mAdd").disabled = brush === "erase";
      var lab = $("phL"), sw = k && k !== "erase" ? SH[k].c : "";
      ph.className = "ph" + (sw ? " s-" + sw : "");
      lab.innerHTML = "<b>" + esc(P.header) + "</b> · " + esc(brush === "erase" ? P.eraser : doubling ? P.mode_add : P.mode_replace);
      hint.classList.remove("flash");
      hint.textContent = !brush ? P.hint_idle : fmt(P.hint_painting, { name: brush === "erase" ? P.eraser : SH[brush].n });
      updatePreview();
    }
    function setMode(add) {
      doubling = add; $("mRep").setAttribute("aria-pressed", String(!add)); $("mAdd").setAttribute("aria-pressed", String(add));
      if (brush) setBrush(brush); else updatePreview();
    }
    $("mRep").addEventListener("click", function () { setMode(false); });
    $("mAdd").addEventListener("click", function () { setMode(true); });
    $("done").addEventListener("click", function () {
      var was = brush; setBrush(null);
      var p = was && pucksEl.querySelector('[data-k="' + was + '"]');
      (p || $("tabPaint")).focus({ preventScroll: true });
    });
    $("phPat").addEventListener("click", function () { setBrush(null); setTool("pattern"); $("tabPat").focus({ preventScroll: true }); });
    function setTool(t) {
      tool = t; $("panPat").hidden = t !== "pattern"; $("panPaint").hidden = t !== "paint";
      $("tabPat").setAttribute("aria-pressed", String(t === "pattern")); $("tabPaint").setAttribute("aria-pressed", String(t === "paint"));
      if (t === "pattern") edges();
    }
    $("tabPat").addEventListener("click", function () { if (brush) setBrush(null); setTool("pattern"); });
    $("tabPaint").addEventListener("click", function () { setTool("paint"); });
    function nudge() {
      if (tool !== "paint") setTool("paint");
      hint.textContent = P.hint_idle; restart(hint, "flash"); restart(pucksEl, "flash");
      clearTimeout(nudge.t); nudge.t = setTimeout(function () { pucksEl.classList.remove("flash"); }, 1400);
    }

    /* ----- history: one step per stroke, rotation or cycle day */
    function snap() { var p = {}; Object.keys(state.paint).forEach(function (d) { p[d] = state.paint[d].slice(); }); return { rot: state.rot, start: state.start, paint: p }; }
    function push() { undoStack.push(snap()); if (undoStack.length > 50) undoStack.shift(); redoStack = []; syncHistory(); }
    function syncHistory() { undoBtn.disabled = !undoStack.length; redoBtn.disabled = !redoStack.length; }
    function restore(s) { state = s; refresh(true); syncHistory(); }
    undoBtn.addEventListener("click", function () { var s = undoStack.pop(); if (!s) return; redoStack.push(snap()); restore(s); });
    redoBtn.addEventListener("click", function () { var s = redoStack.pop(); if (!s) return; undoStack.push(snap()); restore(s); });
    function refresh(animate) { renderStrip(); paintAll(); if (animate && !reduced()) wave(); }

    /* ----- painting. The brush's rules are the app's (schedule/domain/editing.dart, PaintTool; paint_controller.dart, toolFor): «cambiar» replaces the
       day's shifts; «añadir» keeps every shift already there, ignores one that is already there, and puts a work shift in the place of a lone «Libre»;
       the eraser leaves the day empty. */
    function applyBrush(cur) {
      if (brush === "erase") return [];
      if (!doubling) return [brush];
      if (cur.indexOf(brush) >= 0) return cur;
      if (SH[brush].work && cur.length === 1 && cur[0] === "L") return [brush];
      return cur.concat(brush);
    }
    var stroke = null, pushed = false, lastD = -1, suppressClick = false, suppressTimer = 0;
    function paintAtCell(c) {
      if (!c || !brush || c.classList.contains("out")) return;
      var d = +c.getAttribute("data-d"), cur = shiftsAt(d), next = applyBrush(cur);
      if (same(cur, next)) return;
      if (!pushed) { push(); pushed = true; }
      state.paint[d] = next; paintCell(d, true); updateSummary(); updateToday(false); clrBtn.hidden = false;
    }
    /* A fast swipe skips cells between two pointer events: fill the straight line between them on the seven-column grid. */
    function paintLine(c) {
      if (!c) return;
      var d = +c.getAttribute("data-d");
      if (lastD < 0 || d === lastD) { paintAtCell(c); lastD = d; return; }
      var r0 = Math.floor(lastD / 7), c0 = lastD % 7, r1 = Math.floor(d / 7), c1 = d % 7, n = Math.max(Math.abs(r1 - r0), Math.abs(c1 - c0));
      for (var i = 1; i <= n; i++) paintAtCell(cells[Math.round(r0 + (r1 - r0) * i / n) * 7 + Math.round(c0 + (c1 - c0) * i / n)]);
      lastD = d;
    }
    /* A drag is a stroke of one pointer (the primary one, the main button, whatever the device: a pen's side button or a second finger do not
       paint); it only starts when a brush is chosen. Only that press's own click is skipped (it already painted); a cancelled gesture (the page
       starts to scroll) or a press that did not paint leaves nothing behind, so a later click from the keyboard or a screen reader always paints. */
    function clearSuppress() { suppressClick = false; clearTimeout(suppressTimer); }
    grid.addEventListener("pointerdown", function (e) {
      if (stroke !== null || !e.isPrimary || e.button !== 0 || !brush) return;
      var c = e.target.closest && e.target.closest("button.cell"); if (!c) return;
      stroke = e.pointerId; pushed = false; lastD = -1; suppressClick = true; clearTimeout(suppressTimer);
      if (grid.setPointerCapture) { try { grid.setPointerCapture(e.pointerId); } catch (x) { /* a synthetic pointer: no capture */ } }
      paintLine(c); e.preventDefault();
    });
    grid.addEventListener("pointermove", function (e) {
      if (stroke === null || e.pointerId !== stroke) return;
      var t = doc.elementFromPoint(e.clientX, e.clientY); paintLine(t && t.closest ? t.closest("button.cell") : null);
    });
    function endStroke(e, cancelled) {
      if (stroke === null || (e && e.pointerId !== stroke)) return;
      stroke = null; updateToday(true);
      if (cancelled) clearSuppress(); else suppressTimer = setTimeout(clearSuppress, 600);
    }
    grid.addEventListener("pointerup", function (e) { endStroke(e, false); });
    grid.addEventListener("pointercancel", function (e) { endStroke(e, true); });
    grid.addEventListener("lostpointercapture", function (e) { endStroke(e, false); });
    grid.addEventListener("click", function (e) {
      if (suppressClick) { clearSuppress(); return; }
      var c = e.target.closest && e.target.closest("button.cell"); if (!c) return;
      if (!brush) { nudge(); return; }
      pushed = false; paintAtCell(c); updateToday(true);
    });
    /* Keyboard: the arrows move through the month; Enter and Space are the button's own click. */
    grid.addEventListener("keydown", function (e) {
      var c = e.target.closest && e.target.closest("button.cell"); if (!c) return;
      var d = +c.getAttribute("data-d"), to = d;
      if (e.key === "ArrowRight") to = d + 1; else if (e.key === "ArrowLeft") to = d - 1;
      else if (e.key === "ArrowDown") to = d + 7; else if (e.key === "ArrowUp") to = d - 7; else return;
      e.preventDefault();
      if (to < 1 || to > 31) return;
      c.tabIndex = -1; cells[to].tabIndex = 0; cells[to].focus();
    });

    renderStrip(); setBrush(null); paintAll(); setTool("pattern");
    /* The month paints itself, cell by cell, once the board has arrived; with reduced motion it just stands there painted. */
    if (!reduced()) wave();
    root.classList.add("demo-ready"); board.hidden = false;
  }

  /* ---------------------------------------------------------------- screens tour */
  function tour() {
    var box = $("tour"); if (!box) return;
    var slides = [].slice.call(box.querySelectorAll(".slide")); if (slides.length < 2) return;
    var label = box.getAttribute("data-label"), prevT = box.getAttribute("data-prev"), nextT = box.getAttribute("data-next");
    var posT = box.getAttribute("data-position"), cntT = box.getAttribute("data-count"), live = $("shotLive");
    var tabs = el("div", "tabs"), cur = 0, buttons = [];
    tabs.setAttribute("role", "tablist"); tabs.setAttribute("aria-label", label);
    slides.forEach(function (s, i) {
      var title = s.querySelector("h3").textContent, b = el("button", "tab");
      b.type = "button"; b.id = "tab-" + i; b.setAttribute("role", "tab"); b.setAttribute("aria-controls", "slide-" + i); b.textContent = title;
      b.addEventListener("click", function () { show(i, true); });
      tabs.appendChild(b); buttons.push(b);
      s.id = "slide-" + i; s.setAttribute("role", "tabpanel"); s.setAttribute("aria-labelledby", "tab-" + i);
      var txt = s.querySelector(".shot-txt");
      var n = el("span", "shot-n"); n.textContent = fmt(cntT, { n: i + 1, total: slides.length }); n.setAttribute("aria-hidden", "true"); txt.insertBefore(n, txt.firstChild);
      var st = el("div", "steps");
      var pb = el("button", "step", icon("left")), nb = el("button", "step", icon("right"));
      pb.type = nb.type = "button"; pb.setAttribute("aria-label", prevT); nb.setAttribute("aria-label", nextT); pb.setAttribute("data-dir", "prev"); nb.setAttribute("data-dir", "next");
      pb.addEventListener("click", function () { show(cur - 1, false, "prev"); }); nb.addEventListener("click", function () { show(cur + 1, false, "next"); });
      st.appendChild(pb); st.appendChild(nb); txt.appendChild(st);
    });
    box.insertBefore(tabs, box.firstChild); box.classList.add("tour-on");
    /* `keep` is the arrow that was pressed: its twin in the new screen takes the focus, so it never falls to the page when the old screen hides */
    function show(i, focusTab, keep) {
      cur = (i + slides.length) % slides.length;
      slides.forEach(function (s, j) { s.hidden = j !== cur; });
      buttons.forEach(function (b, j) { b.setAttribute("aria-selected", String(j === cur)); b.tabIndex = j === cur ? 0 : -1; });
      restart(slides[cur], "swap");
      if (live) live.textContent = fmt(posT, { n: cur + 1, title: buttons[cur].textContent, total: slides.length });
      if (focusTab) buttons[cur].focus();
      else if (keep) { var again = slides[cur].querySelector('.step[data-dir="' + keep + '"]'); if (again) again.focus({ preventScroll: true }); }
      /* keep the chosen tab in view in the scrolling row on phones, without moving the page */
      var b = buttons[cur];
      if (tabs.scrollTo && tabs.scrollWidth > tabs.clientWidth) tabs.scrollTo({ left: b.offsetLeft - tabs.clientWidth / 2 + b.clientWidth / 2, behavior: reduced() ? "auto" : "smooth" });
    }
    tabs.addEventListener("keydown", function (e) {
      var k = e.key, map = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };
      if (map[k]) { e.preventDefault(); show(cur + map[k], true); }
      else if (k === "Home") { e.preventDefault(); show(0, true); }
      else if (k === "End") { e.preventDefault(); show(slides.length - 1, true); }
    });
    show(0); if (live) live.textContent = "";
    slides[0].classList.remove("swap");
  }

  /* ---------------------------------------------------------------- scroll reveals */
  function reveals() {
    if (reduced() || !("IntersectionObserver" in window)) return;
    var vh = window.innerHeight;
    var items = [].slice.call(doc.querySelectorAll(".rv-me")).filter(function (n) { return n.getBoundingClientRect().top > vh * 0.92; });
    if (!items.length) return;
    var left = items.length, pending = false;
    function show(n) { if (!n.classList.contains("in")) { n.classList.add("in"); left--; } io.unobserve(n); if (!left) done(); }
    /* when every block is in, nothing is watched any more: the observer and the scroll listener go */
    function done() { io.disconnect(); window.removeEventListener("scroll", onScroll); }
    var io = new IntersectionObserver(function (entries) {
      /* a block scrolled past (an anchor jumped over it) must not stay hidden: above the viewport counts as seen */
      entries.forEach(function (en) { if (en.isIntersecting || en.boundingClientRect.top < 0) show(en.target); });
    }, { rootMargin: "0px 0px -8% 0px" });
    items.forEach(function (n) {
      var p = n.parentElement, idx = [].indexOf.call(p.children, n);
      if (p.classList.contains("flist")) n.classList.add("d" + (idx % 3));
      n.classList.add("rv"); io.observe(n);
    });
    /* An observer only reports a change: a block jumped over by an anchor (#features) or by dragging the scrollbar never changes, so a
       light sweep on scroll shows whatever is already above the viewport. */
    function sweep() { pending = false; items.forEach(function (n) { if (!n.classList.contains("in") && n.getBoundingClientRect().bottom < 0) show(n); }); }
    function onScroll() { if (!pending) { pending = true; window.requestAnimationFrame(sweep); } }
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ---------------------------------------------------------------- the 404 in the visitor's language */
  function lost() {
    var box = $("lost"); if (!box) return;
    var T = JSON.parse(box.getAttribute("data-lost")), m = /^\/(\w\w)(\/|$)/.exec(location.pathname), code = m && T[m[1]] ? m[1] : null;
    if (!code) return;
    var x = T[code];
    $("lostT").textContent = x.title; $("lostX").textContent = x.text;
    [].forEach.call(box.querySelectorAll(".lost-home"), function (n) { n.textContent = x.home; });
    var skip = doc.querySelector(".skip-link"); if (skip) skip.textContent = x.skip;
    root.setAttribute("lang", code); doc.title = x.title + " · " + box.getAttribute("data-name");
    [].forEach.call(doc.querySelectorAll(".langs a"), function (a) { if (a.getAttribute("hreflang") === code) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current"); });
  }

  try { demo(); } catch (e) { /* the screenshot stays: the page works without the demo */ if (window.console) console.warn("demo", e); }
  try { tour(); } catch (e2) { if (window.console) console.warn("tour", e2); }
  lost();
  reveals();
})();
