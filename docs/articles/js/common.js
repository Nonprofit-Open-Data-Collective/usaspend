const fmt = {
  n: v => v == null ? "–" : Math.round(v).toLocaleString("en-US"),
  p: (v, d = 1) => v == null ? "–" : v.toFixed(d) + "%",
  B: v => v == null ? "–" : "$" + (v >= 100 ? Math.round(v) : v.toFixed(1)) + "B",
  M: v => v == null ? "–" : v >= 1000 ? "$" + (v / 1000).toFixed(1) + "B" : "$" + Math.round(v) + "M",
  K: v => v == null ? "–" : v >= 1000 ? "$" + (v / 1000).toFixed(1) + "M" : "$" + Math.round(v) + "K",
  x: v => v.toFixed(1) + "×"
};
const NS = "http://www.w3.org/2000/svg";
function el(tag, attrs = {}, parent) {
  const e = document.createElementNS(NS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
function txt(parent, x, y, s, attrs = {}) { const t = el("text", { x, y, ...attrs }, parent); t.textContent = s; return t; }
const tip = document.createElement("div"); tip.id = "tip"; document.body.appendChild(tip);
function hover(node, html) {
  node.addEventListener("mousemove", e => {
    tip.innerHTML = html; tip.style.opacity = 1;
    const w = tip.offsetWidth, x = e.clientX + 14 + w > innerWidth ? e.clientX - w - 14 : e.clientX + 14;
    tip.style.left = x + "px"; tip.style.top = (e.clientY + 14) + "px";
  });
  node.addEventListener("mouseleave", () => tip.style.opacity = 0);
}
function niceMax(v) { const p = Math.pow(10, Math.floor(Math.log10(v))); for (const m of [1, 2, 2.5, 5, 10]) if (m * p >= v) return m * p; }
function barPath(x, y, w, h, r = 4) { // rounded data-end on the right, square at the baseline
  r = Math.min(r, w, h / 2); if (w <= 0) return "";
  return `M${x},${y}h${w - r}a${r},${r} 0 0 1 ${r},${r}v${h - 2 * r}a${r},${r} 0 0 1 ${-r},${r}h${-(w - r)}z`;
}
function colPath(x, y, w, h, r = 4) { // rounded top, square at the baseline
  r = Math.min(r, w / 2, h); if (h <= 0) return "";
  return `M${x},${y + h}v${-(h - r)}a${r},${r} 0 0 1 ${r},${-r}h${w - 2 * r}a${r},${r} 0 0 1 ${r},${r}v${h - r}z`;
}
/* Paired horizontal bars: rows [{label, a, b, tipA, tipB}], a = baseline (grey), b = focus (accent) */
function pairedBars(host, rows, { unit = v => fmt.p(v), labelW = 190, W = 860, max } = {}) {
  const bh = 11, gap = 2, rowH = 2 * bh + gap + 16, H = rows.length * rowH + 26;
  const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
  const x0 = labelW, x1 = W - 70, mx = max || niceMax(Math.max(...rows.flatMap(r => [r.a, r.b])));
  const sx = v => x0 + (x1 - x0) * v / mx;
  for (let i = 0; i <= 4; i++) {
    const v = mx * i / 4, x = sx(v);
    el("line", { x1: x, x2: x, y1: 0, y2: H - 22, class: "grid" }, svg);
    txt(svg, x, H - 6, unit(v), { "text-anchor": "middle" });
  }
  rows.forEach((r, i) => {
    const y = i * rowH + 6;
    txt(svg, x0 - 12, y + bh + 5, r.label, { "text-anchor": "end", class: "lab" });
    el("path", { d: barPath(x0, y, sx(r.a) - x0, bh), fill: "var(--base)" }, svg);
    el("path", { d: barPath(x0, y + bh + gap, sx(r.b) - x0, bh), fill: "var(--accent)" }, svg);
    txt(svg, sx(r.a) + 6, y + bh - 1.5, unit(r.a), { "font-size": 11 });
    txt(svg, sx(r.b) + 6, y + 2 * bh + gap - 1.5, unit(r.b), { class: "lab", "font-size": 11, "font-weight": 600 });
    const h = el("rect", { x: 0, y: y - 4, width: W, height: rowH - 4, class: "hit" }, svg);
    hover(h, r.tip);
  });
  el("line", { x1: x0, x2: x0, y1: 0, y2: H - 22, class: "axis" }, svg);
  host.appendChild(svg);
}
/* Dumbbell: rows [{label, a, b, tip}] */
function dumbbell(host, rows, { unit = v => fmt.p(v), labelW = 110, W = 860, max } = {}) {
  const rowH = 24, H = rows.length * rowH + 30;
  const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
  const x0 = labelW, x1 = W - 60, mx = max || niceMax(Math.max(...rows.flatMap(r => [r.a, r.b])));
  const sx = v => x0 + (x1 - x0) * v / mx;
  for (let i = 0; i <= 5; i++) {
    const v = mx * i / 5, x = sx(v);
    el("line", { x1: x, x2: x, y1: 0, y2: H - 24, class: "grid" }, svg);
    txt(svg, x, H - 7, unit(v), { "text-anchor": "middle" });
  }
  rows.forEach((r, i) => {
    const y = i * rowH + 12;
    txt(svg, x0 - 12, y + 4, r.label, { "text-anchor": "end", class: "lab" });
    el("line", { x1: sx(Math.min(r.a, r.b)), x2: sx(Math.max(r.a, r.b)), y1: y, y2: y, stroke: "var(--rule)", "stroke-width": 3 }, svg);
    el("circle", { cx: sx(r.a), cy: y, r: 5, fill: "var(--base)", stroke: "var(--paper)", "stroke-width": 2 }, svg);
    el("circle", { cx: sx(r.b), cy: y, r: 5.5, fill: "var(--accent)", stroke: "var(--paper)", "stroke-width": 2 }, svg);
    if (r.showLabel) txt(svg, sx(Math.max(r.a, r.b)) + 10, y + 4, unit(r.b), { class: "lab", "font-size": 11, "font-weight": 600 });
    const h = el("rect", { x: 0, y: y - rowH / 2, width: W, height: rowH, class: "hit" }, svg);
    hover(h, r.tip);
  });
  host.appendChild(svg);
}
/* Columns over time: rows [{label, v, tip}] */
function columns(host, rows, { W = 860, H = 230, every = 3, annotate } = {}) {
  const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
  const x0 = 40, x1 = W - 8, y0 = 12, y1 = H - 30, mx = niceMax(Math.max(...rows.map(r => r.v)));
  const bw = (x1 - x0) / rows.length, sy = v => y1 - (y1 - y0) * v / mx;
  for (let i = 0; i <= 4; i++) {
    const v = mx * i / 4, y = sy(v);
    el("line", { x1: x0, x2: x1, y1: y, y2: y, class: "grid" }, svg);
    txt(svg, x0 - 6, y + 4, fmt.n(v), { "text-anchor": "end" });
  }
  rows.forEach((r, i) => {
    const x = x0 + i * bw + 1;
    el("path", { d: colPath(x, sy(r.v), bw - 2, y1 - sy(r.v)), fill: "var(--accent)" }, svg);
    if (i % every === 0) txt(svg, x + (bw - 2) / 2, H - 12, r.label, { "text-anchor": "middle" });
    if (annotate && annotate(r, i)) txt(svg, x + (bw - 2) / 2, sy(r.v) - 6, fmt.n(r.v), { "text-anchor": "middle", class: "lab", "font-size": 11, "font-weight": 600 });
    const h = el("rect", { x: x - 1, y: y0, width: bw, height: y1 - y0, class: "hit" }, svg);
    hover(h, r.tip);
  });
  el("line", { x1: x0, x2: x1, y1: y1, y2: y1, class: "axis" }, svg);
  host.appendChild(svg);
}
/* 100% stacked horizontal bars: rows [{label, parts:[v...]}], keys, colors */
function stacked(host, rows, keys, colors, { W = 860, labelW = 90 } = {}) {
  const bh = 22, rowH = 34, H = rows.length * rowH + 6;
  const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
  const x0 = labelW, x1 = W - 4, sx = v => (x1 - x0) * v / 100;
  rows.forEach((r, i) => {
    const y = i * rowH + 4; let x = x0;
    txt(svg, x0 - 12, y + bh / 2 + 4, r.label, { "text-anchor": "end", class: "lab" });
    r.parts.forEach((v, k) => {
      const w = sx(v); if (w <= 0) return;
      const rect = el("rect", { x: x, y, width: Math.max(w - 2, 0.5), height: bh, fill: colors[k], rx: k === r.parts.length - 1 ? 3 : 0 }, svg);
      hover(rect, `<b>${r.label}</b> · ${keys[k]}<br>${fmt.p(v)} of awards`);
      x += w;
    });
  });
  host.appendChild(svg);
}
function table(host, cols, rows) {
  const w = document.createElement("div"); w.className = "tbl";
  const t = document.createElement("table");
  t.innerHTML = "<thead><tr>" + cols.map(c => `<th class="${c.cls || ""}">${c.h}</th>`).join("") + "</tr></thead><tbody>" +
    rows.map(r => "<tr>" + cols.map(c => `<td class="${c.cls || ""}">${c.f(r)}</td>`).join("") + "</tr>").join("") + "</tbody>";
  w.appendChild(t); host.appendChild(w);
}
const $ = s => document.querySelector(s);
/* Lines over time: series [{name, color, pts:[{label, v, n}]}]; shared x labels; direct labels at the end */
function lines(host, series, { W = 860, H = 280, max = 100, unit = v => Math.round(v) + "%", marker } = {}) {
  const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
  const labels = series[0].pts.map(p => p.label), n = labels.length;
  const x0 = 40, x1 = W - 170, y0 = 12, y1 = H - 34;
  const sx = i => x0 + (x1 - x0) * i / (n - 1), sy = v => y1 - (y1 - y0) * v / max;
  for (let i = 0; i <= 4; i++) {
    const v = max * i / 4, y = sy(v);
    el("line", { x1: x0, x2: x1, y1: y, y2: y, class: "grid" }, svg);
    txt(svg, x0 - 6, y + 4, unit(v), { "text-anchor": "end" });
  }
  labels.forEach((l, i) => { const [m, y] = l.split(" "); txt(svg, sx(i), H - 18, m, { "text-anchor": "middle", "font-size": 11 }); txt(svg, sx(i), H - 5, y, { "text-anchor": "middle", "font-size": 11 }); });
  if (marker != null) {
    const x = sx(marker);
    el("line", { x1: x, x2: x, y1: y0 - 4, y2: y1, stroke: "var(--ink-3)", "stroke-dasharray": "3 3" }, svg);
    txt(svg, x + 5, y0 + 6, "20 Jan 2025", { "font-size": 11 });
  }
  const ends = series.map(s => ({ s, y: sy(s.pts[n - 1].v) })).sort((a, b) => a.y - b.y);
  for (let i = 1; i < ends.length; i++) if (ends[i].y - ends[i - 1].y < 15) ends[i].y = ends[i - 1].y + 15;
  series.forEach(s => {
    el("path", { d: s.pts.map((p, i) => (i ? "L" : "M") + sx(i) + "," + sy(p.v)).join(""), fill: "none", stroke: s.color, "stroke-width": 2, "stroke-linejoin": "round", "stroke-dasharray": s.dash || "none" }, svg);
    s.pts.forEach((p, i) => el("circle", { cx: sx(i), cy: sy(p.v), r: i === n - 1 ? 4.5 : 3, fill: s.color, stroke: "var(--paper)", "stroke-width": 1.5 }, svg));
  });
  ends.forEach(e => txt(svg, x1 + 10, e.y + 4, `${e.s.name} ${unit(e.s.pts[n - 1].v)}`, { class: "lab", "font-size": 12 }));
  labels.forEach((l, i) => {
    const h = el("rect", { x: sx(i) - (x1 - x0) / (n - 1) / 2, y: y0, width: (x1 - x0) / (n - 1), height: y1 - y0, class: "hit" }, svg);
    hover(h, `<b>${l}</b><br>` + series.map(s => `${s.name}: ${unit(s.pts[i].v)} of ${fmt.n(s.pts[i].n)} awards`).join("<br>"));
  });
  host.appendChild(svg);
}
