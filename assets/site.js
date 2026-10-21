/* Infobulles des graphiques, images facultatives, copie de l'adresse e-mail. */
(function () {
  "use strict";

  // ---------------------------------------------------------------- infobulle
  var tip = document.createElement("div");
  tip.className = "tip";
  tip.hidden = true;
  tip.setAttribute("role", "status");
  document.body.appendChild(tip);

  function fill(el) {
    var parts = (el.getAttribute("data-tip") || "").split("|");
    while (tip.firstChild) tip.removeChild(tip.firstChild);
    var b = document.createElement("b");
    b.textContent = parts[0];
    tip.appendChild(b);
    for (var i = 1; i < parts.length; i++) {
      var s = document.createElement("span");
      s.textContent = parts[i];
      tip.appendChild(s);
      if (i < parts.length - 1) tip.appendChild(document.createElement("br"));
    }
  }

  function place(x, y) {
    var r = tip.getBoundingClientRect();
    var vw = document.documentElement.clientWidth;
    var vh = document.documentElement.clientHeight;
    var left = x + 14;
    var top = y - r.height - 12;
    if (left + r.width > vw - 8) left = x - r.width - 14;
    if (left < 8) left = 8;
    if (top < 8) top = y + 18;
    if (top + r.height > vh - 8) top = vh - r.height - 8;
    tip.style.left = left + "px";
    tip.style.top = top + "px";
  }

  var current = null;
  document.addEventListener("pointerover", function (e) {
    var el = e.target.closest ? e.target.closest("[data-tip]") : null;
    if (!el) return;
    current = el;
    fill(el);
    tip.hidden = false;
    place(e.clientX, e.clientY);
  });
  document.addEventListener("pointermove", function (e) {
    if (!current) return;
    var el = e.target.closest ? e.target.closest("[data-tip]") : null;
    if (el !== current) {
      if (!el) { current = null; tip.hidden = true; return; }
      current = el;
      fill(el);
    }
    place(e.clientX, e.clientY);
  });
  document.addEventListener("pointerout", function (e) {
    if (!current) return;
    var to = e.relatedTarget && e.relatedTarget.closest ? e.relatedTarget.closest("[data-tip]") : null;
    if (!to) { current = null; tip.hidden = true; }
  });
  document.addEventListener("focusin", function (e) {
    var el = e.target;
    if (!el.hasAttribute || !el.hasAttribute("data-tip")) return;
    fill(el);
    tip.hidden = false;
    var r = el.getBoundingClientRect();
    place(r.left + r.width / 2, r.top);
  });
  document.addEventListener("focusout", function (e) {
    if (e.target.hasAttribute && e.target.hasAttribute("data-tip")) tip.hidden = true;
  });
  window.addEventListener("scroll", function () { if (!current) tip.hidden = true; }, { passive: true });

  // ---------------------------------------------------------------- images facultatives
  // Une capture ajoutée plus tard (dossier assets/img) s'affiche ; absente, la figure reste masquée.
  var opt = document.querySelectorAll("img[data-optional]");
  Array.prototype.forEach.call(opt, function (img) {
    var fig = img.closest("figure");
    function hide() { if (fig) fig.hidden = true; }
    function show() { if (fig) fig.hidden = false; }
    img.addEventListener("error", hide);
    img.addEventListener("load", show);
    if (img.complete) { if (img.naturalWidth > 0) show(); else hide(); }
  });

  // ---------------------------------------------------------------- galerie de captures
  // Les captures sont listées dans assets/img/captures.txt, une par ligne : « nom-du-fichier.png | légende ».
  // Le début du nom (nordia-, helios-, vertier-, sportlife-) choisit la page où l'image s'affiche.
  var galleries = document.querySelectorAll(".gallery[data-case]");
  function plain(s) {
    return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  }
  function addShot(g, file, caption) {
    var fig = document.createElement("figure");
    fig.className = "shot";
    fig.hidden = true;
    var url = "assets/img/" + encodeURIComponent(file);
    var a = document.createElement("a");
    a.href = url;
    var img = document.createElement("img");
    img.src = url;
    img.alt = caption || "Capture d'écran";
    img.addEventListener("load", function () {
      fig.hidden = false;
      var sec = g.closest("section");
      if (sec) sec.hidden = false;
    });
    img.addEventListener("error", function () { fig.remove(); });
    a.appendChild(img);
    fig.appendChild(a);
    if (caption) {
      var fc = document.createElement("figcaption");
      fc.textContent = caption;
      fig.appendChild(fc);
    }
    g.appendChild(fig);
  }
  if (galleries.length && window.fetch) {
    fetch("assets/img/captures.txt", { cache: "no-cache" })
      .then(function (r) { return r.ok ? r.text() : ""; })
      .then(function (txt) {
        txt.split(/\r?\n/).forEach(function (line) {
          line = line.trim();
          if (!line || line.charAt(0) === "#") return;
          var i = line.indexOf("|");
          var file = (i >= 0 ? line.slice(0, i) : line).trim();
          var caption = i >= 0 ? line.slice(i + 1).trim() : "";
          if (!file || /[\\/]/.test(file) || file.indexOf("..") >= 0) return;
          if (!/\.(png|jpe?g|webp|gif)$/i.test(file)) return;
          var prefix = plain(file).split(/[-_ ]/)[0];
          Array.prototype.forEach.call(galleries, function (g) {
            if (g.getAttribute("data-case") === prefix) addShot(g, file, caption);
          });
        });
      })
      .catch(function () {});
  }

  // ---------------------------------------------------------------- copie de l'adresse
  Array.prototype.forEach.call(document.querySelectorAll("[data-copy]"), function (btn) {
    btn.hidden = false;
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");
      var done = function () {
        var old = btn.textContent;
        btn.textContent = "Copié";
        setTimeout(function () { btn.textContent = old; }, 1600);
      };
      var fallback = function () {
        var target = document.getElementById(btn.getAttribute("data-target"));
        if (!target) return;
        var range = document.createRange();
        range.selectNodeContents(target);
        var sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      };
      try {
        navigator.clipboard.writeText(text).then(done, fallback);
      } catch (err) {
        fallback();
      }
    });
  });
})();
