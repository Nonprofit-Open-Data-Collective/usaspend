(function(){
const css=n=>getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const lin=(d0,d1,r0,r1)=>{const f=v=>r0+(v-d0)/(d1-d0)*(r1-r0);f.inv=p=>d0+(p-r0)/(r1-r0)*(d1-d0);return f;};
function ticks(max,n){const raw=max/n,p=Math.pow(10,Math.floor(Math.log10(raw))),m=raw/p,s=(m<1.5?1:m<3?2:m<7?5:10)*p;const o=[];for(let v=0;v<max+s*0.999;v+=s)o.push(+v.toFixed(6));return o;}
function showTip(e,html){tip.innerHTML=html;tip.style.opacity=1;const w=tip.offsetWidth,h=tip.offsetHeight;let x=e.clientX+14,y=e.clientY+14;if(x+w>innerWidth-8)x=e.clientX-w-14;if(y+h>innerHeight-8)y=e.clientY-h-14;tip.style.left=x+"px";tip.style.top=y+"px";}
function hideTip(){tip.style.opacity=0;}
const esc=s=>String(s==null?"":s).replace(/&/g,"&amp;").replace(/</g,"&lt;");
const M=T.meta; const FIT=new Set(M.fit_years);
document.getElementById("m-end").textContent=M.data_end; document.getElementById("m-built").textContent=M.built;
const MEAS={oblig:"Net obligations",n_new:"New awards",new_oblig:"Dollars obligated on new awards"};
const money=v=>{const a=Math.abs(v),s=v<0?"−":"";return a>=1e9?s+"$"+(a/1e9).toFixed(a>=1e10?0:1)+"B":a>=1e6?s+"$"+(a/1e6).toFixed(a>=1e8?0:1)+"M":a>=1e3?s+"$"+Math.round(a/1e3)+"K":s+"$"+Math.round(a);};
const cnt=v=>Math.round(v).toLocaleString("en-US");
let meas="oblig",dim="agency";
const fmtV=v=>v==null?"–":(meas==="n_new"?cnt(v):money(v));
const fmtAx=v=>meas==="n_new"?(v>=1000?(v/1000).toFixed(v>=1e4?0:1)+"K":String(v)):money(v);
const pctS=g=>g==null?"–":(g>0?"+":g<0?"−":"")+Math.abs(100*g).toFixed(0)+"%";
const rows=(d,g)=>T.trends.filter(r=>r.dim===d&&r.measure===meas&&(g==null||r.grp===g)).sort((a,b)=>a.fy-b.fy);

/* ---------- trend panel ---------- */
function trendChart(host,R,o){o=o||{};
  const W=o.w||720,H=o.h||300,m=Object.assign({t:14,r:o.small?8:60,b:24,l:o.small?40:58},o.m||{});
  const svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":o.aria||"trend"},host);
  const fy0=R[0].fy,fy1=R[R.length-1].fy,xs=lin(fy0-0.5,fy1+0.5,m.l,W-m.r);
  let ymax=0;R.forEach(r=>{ymax=Math.max(ymax,r.y||0,r.fy>=2025?(r.hi80||0):(r.pred||0));});const yt=ticks(ymax||1,o.small?3:4);ymax=yt[yt.length-1];
  const ys=lin(0,ymax,H-m.b,m.t);
  yt.forEach(v=>{el("line",{x1:m.l,x2:W-m.r,y1:ys(v),y2:ys(v),class:v?"grid":"axis"},svg);txt(svg,m.l-6,ys(v)+4,fmtAx(v),{"text-anchor":"end",class:o.small?"tiny":""});});
  R.forEach(r=>{if(o.small&&r.fy%2&&r.fy!==fy1)return;txt(svg,xs(r.fy),H-m.b+15,o.small?"'"+String(r.fy).slice(2):"FY"+String(r.fy).slice(2),{"text-anchor":"middle",class:o.small?"tiny":""});});
  const pj=R.filter(r=>r.fy>=2025&&r.pred!=null);
  pj.forEach(r=>{const x0=xs(r.fy)-(o.small?6:14),w=o.small?12:28;const yb=v=>ys(Math.min(Math.max(v,0),ymax));
    el("rect",{x:x0,y:yb(r.hi95),width:w,height:Math.max(0,yb(r.lo95)-yb(r.hi95)),rx:3,fill:css("--band2")},svg);
    el("rect",{x:x0,y:yb(r.hi80),width:w,height:Math.max(0,yb(r.lo80)-yb(r.hi80)),rx:3,fill:css("--band")},svg);});
  const fitR=R.filter(r=>r.pred!=null&&r.fy<=2024),proR=R.filter(r=>r.pred!=null&&r.fy>=2024);
  const path=a=>a.map((r,i)=>(i?"L":"M")+xs(r.fy).toFixed(1)+","+ys(Math.min(r.pred,ymax)).toFixed(1)).join("");
  if(fitR.length)el("path",{d:path(fitR),fill:"none",stroke:css("--accent"),"stroke-width":2},svg);
  if(proR.length)el("path",{d:path(proR),fill:"none",stroke:css("--accent"),"stroke-width":2,"stroke-dasharray":"5 4"},svg);
  R.forEach(r=>{if(r.y==null)return;const fitted=FIT.has(r.fy),below=r.fy>=2025&&r.y<r.lo95,above=r.fy>=2025&&r.y>r.hi95;
    const c=below?css("--div-up"):above?css("--div-dn"):css("--ink");
    el("circle",{cx:xs(r.fy),cy:ys(r.y),r:o.small?3.2:5,fill:fitted||r.fy>=2025?c:css("--paper"),stroke:fitted||r.fy>=2025?css("--paper"):css("--ink-3"),"stroke-width":1.5},svg);});
  if(!o.small){const r=R.find(r=>r.fy===fy1);if(r&&r.pred){el("line",{x1:xs(fy1)+18,x2:xs(fy1)+18,y1:ys(r.pred),y2:ys(r.y),stroke:css("--ink-2"),"stroke-width":1},svg);
    txt(svg,xs(fy1)+22,(ys(r.pred)+ys(r.y))/2+4,pctS(r.gap),{class:"lab",style:"font-weight:600"});}}
  R.forEach(r=>{const h=el("rect",{x:xs(r.fy)-(xs(1)-xs(0))/2,y:m.t,width:xs(1)-xs(0),height:H-m.t-m.b,fill:"transparent"},svg);
    h.addEventListener("pointermove",e=>showTip(e,`<b>FY${r.fy}</b> (Oct–May)${FIT.has(r.fy)?"":r.fy<2025?" · not fitted":" · projected"}<br>Actual: ${fmtV(r.y)}<br>Trend: ${fmtV(r.pred)}${r.fy>=2025?`<br>Gap: ${pctS(r.gap)}<br>80% range: ${fmtV(r.lo80)} – ${fmtV(r.hi80)}<br>95% range: ${fmtV(r.lo95)} – ${fmtV(r.hi95)}`:""}`));h.addEventListener("pointerleave",hideTip);});
}

/* ---------- tiles + overall ---------- */
function drawTop(){
  const tot=m=>T.trends.filter(r=>r.dim==="total"&&r.measure===m);
  const g=(m,fy)=>tot(m).find(r=>r.fy===fy);
  document.getElementById("tiles").innerHTML=["oblig","n_new","new_oblig"].map(m=>{const r=g(m,2026),r5=g(m,2025);const cls=r.y<r.lo95?"dn":r.y>r.hi95?"up":"";
    return `<div class="tile"><div class="v ${cls}">${pctS(r.gap)}</div><div class="l">${MEAS[m]} vs trend, FY2026 Oct–May</div><div class="d">${m==="n_new"?cnt(r.y)+" vs "+cnt(r.pred):money(r.y)+" vs "+money(r.pred)} expected · FY2025: ${pctS(r5.gap)}</div></div>`;}).join("");
  const R=rows("total","All grants and contracts");document.getElementById("tot-ft").textContent=MEAS[meas]+", October–May, all grants and contracts";
  const h=document.getElementById("c-tot");h.innerHTML="";trendChart(h,R,{aria:"Overall trend"});
  const r6=R.find(r=>r.fy===2026),r5=R.find(r=>r.fy===2025),sl=R.find(r=>r.slope!=null);
  document.getElementById("tot-text").textContent=`${MEAS[meas]} grew about ${sl?sl.slope.toFixed(1):"–"}% a year across the fitted years. On that path FY2026 would have reached ${fmtV(r6.pred)} by the end of May; it reached ${fmtV(r6.y)}, ${pctS(r6.gap)} against trend${r6.y<r6.lo95?", below the 95% prediction range":r6.y<r6.lo80?", below the 80% range":""}. FY2025, whose window straddles January 2025, came in ${pctS(r5.gap)}.`;
  const f=document.getElementById("c-fam");f.innerHTML="";
  ["Grants","Contracts"].forEach(gn=>{const RR=rows("family",gn);if(!RR.length)return;const r=RR.find(r=>r.fy===2026);
    const b=document.createElement("div");b.innerHTML=`<p class="mt">${gn}</p><p class="ms">FY2026 ${fmtV(r.y)} · trend ${fmtV(r.pred)} · ${pctS(r.gap)}</p>`;const c=document.createElement("div");c.className="chart";b.appendChild(c);f.appendChild(b);trendChart(c,RR,{small:true,w:340,h:150,aria:gn});});
}

/* ---------- gap chart ---------- */
function groupsFor(d){const G=[...new Set(T.trends.filter(r=>r.dim===d).map(r=>r.grp))];
  return G.map(g=>{const R=rows(d,g),r6=R.find(r=>r.fy===2026),r5=R.find(r=>r.fy===2025);return {g,R,r6,r5,base:(r6||{}).base||0};}).filter(o=>o.r6&&o.r6.pred>0);}
function drawGap(){const host=document.getElementById("c-gap");host.innerHTML="";
  const G=groupsFor(dim).sort((a,b)=>a.r6.gap-b.r6.gap);
  const rel=v=>v; // gaps are already relative
  const lim=Math.min(1.5,Math.max(0.6,...G.map(o=>Math.abs(o.r6.gap)),...G.map(o=>Math.abs(o.r6.lo95/o.r6.pred-1))));
  const W=720,rh=24,m={t:22,l:200,r:84,b:8},H=m.t+G.length*rh+m.b,svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":"Gap from trend"},host);
  const xs=lin(-Math.min(1,lim),lim,m.l,W-m.r),cl=v=>Math.max(-Math.min(1,lim),Math.min(lim,v));
  const tk=[-1,-0.5,-0.25,0,0.25,0.5,1,1.5].filter(v=>v>=-Math.min(1,lim)-1e-9&&v<=lim+1e-9);
  tk.forEach(v=>{el("line",{x1:xs(v),x2:xs(v),y1:m.t-4,y2:H-m.b,class:v?"grid":"axis",style:v?"":"stroke:var(--ink-3)"},svg);txt(svg,xs(v),m.t-8,pctS(v),{"text-anchor":"middle",class:"tiny"});});
  txt(svg,W-6,m.t-8,"FY22–24 avg",{"text-anchor":"end",class:"tiny"});
  G.forEach((o,i)=>{const y=m.t+i*rh+rh/2,r=o.r6,p=r.pred;
    txt(svg,m.l-10,y+4,o.g.length>30?o.g.slice(0,29)+"…":o.g,{"text-anchor":"end",class:"grp"});
    const b95=[cl(r.lo95/p-1),cl(r.hi95/p-1)],b80=[cl(r.lo80/p-1),cl(r.hi80/p-1)];
    el("rect",{x:xs(b95[0]),y:y-5,width:Math.max(1,xs(b95[1])-xs(b95[0])),height:10,rx:3,fill:css("--rule-2")},svg);
    el("rect",{x:xs(b80[0]),y:y-5,width:Math.max(1,xs(b80[1])-xs(b80[0])),height:10,rx:3,fill:css("--rule")},svg);
    if(o.r5&&o.r5.pred>0)el("circle",{cx:xs(cl(o.r5.gap)),cy:y,r:4,fill:"none",stroke:css("--ink-3"),"stroke-width":1.5},svg);
    const below=r.y<r.lo95,above=r.y>r.hi95,c=below?css("--div-up"):above?css("--div-dn"):css("--ink-2");
    el("circle",{cx:xs(cl(r.gap)),cy:y,r:5.5,fill:c,stroke:css("--paper"),"stroke-width":1.5},svg);
    if(Math.abs(r.gap)>lim)txt(svg,xs(cl(r.gap))+(r.gap>0?-10:10),y-7,pctS(r.gap),{"text-anchor":r.gap>0?"end":"start",class:"tiny"});
    txt(svg,W-6,y+4,meas==="n_new"?money(o.base):money(o.base),{"text-anchor":"end",class:"tiny"});
    const h=el("rect",{x:0,y:y-rh/2,width:W,height:rh,fill:"transparent"},svg);
    h.addEventListener("pointermove",e=>showTip(e,`<b>${esc(o.g)}</b><br>FY2026 actual: ${fmtV(r.y)}<br>Trend: ${fmtV(p)} (${pctS(r.gap)})<br>80% range: ${pctS(r.lo80/p-1)} to ${pctS(r.hi80/p-1)}<br>95% range: ${pctS(r.lo95/p-1)} to ${pctS(r.hi95/p-1)}${o.r5?`<br>FY2025 gap: ${pctS(o.r5.gap)}`:""}<br>Fit: ${r.model||"–"}${r.slope!=null?`, ${r.slope.toFixed(1)}%/yr`:""}`));h.addEventListener("pointerleave",hideTip);});
  const nb=G.filter(o=>o.r6.y<o.r6.lo95).length,na=G.filter(o=>o.r6.y>o.r6.hi95).length,worst=G[0],best=G[G.length-1];
  const dl={agency:"funding agencies",sub:"program offices",theme:"mission groups",region:"regions"}[dim];
  document.getElementById("gap-text").textContent=`Of ${G.length} ${dl}, ${nb} came in below their 95% range in FY2026 and ${na} above it. Furthest below: ${worst.g} (${pctS(worst.r6.gap)}). Furthest above: ${best.g} (${pctS(best.r6.gap)}).`;
  const sm=document.getElementById("c-sm");sm.innerHTML="";
  G.slice().sort((a,b)=>b.base-a.base).forEach(o=>{const r=o.r6;const b=document.createElement("div");b.innerHTML=`<p class="mt" title="${esc(o.g)}">${esc(o.g)}</p><p class="ms">FY2026 ${pctS(r.gap)} vs trend</p>`;const c=document.createElement("div");c.className="chart";b.appendChild(c);sm.appendChild(b);trendChart(c,o.R,{small:true,w:260,h:130,aria:o.g});});
}

/* ---------- state tile map ---------- */
const GRID={AK:[0,0],ME:[10,0],VT:[9,1],NH:[10,1],WA:[0,2],ID:[1,2],MT:[2,2],ND:[3,2],MN:[4,2],IL:[5,2],WI:[6,2],MI:[7,2],NY:[8,2],RI:[9,2],MA:[10,2],OR:[0,3],NV:[1,3],WY:[2,3],SD:[3,3],IA:[4,3],IN:[5,3],OH:[6,3],PA:[7,3],NJ:[8,3],CT:[9,3],CA:[0,4],UT:[1,4],CO:[2,4],NE:[3,4],MO:[4,4],KY:[5,4],WV:[6,4],VA:[7,4],MD:[8,4],DE:[9,4],AZ:[1,5],NM:[2,5],KS:[3,5],AR:[4,5],TN:[5,5],NC:[6,5],SC:[7,5],DC:[8,5],OK:[3,6],LA:[4,6],MS:[5,6],AL:[6,6],GA:[7,6],HI:[0,7],TX:[3,7],FL:[8,7],PR:[10,7]};
function drawMap(){const host=document.getElementById("c-map");host.innerHTML="";
  const hx=s=>{s=s.replace("#","");return [0,2,4].map(i=>parseInt(s.slice(i,i+2),16));},mix=(a,b,t)=>{const A=hx(a),B=hx(b);return "rgb("+A.map((v,i)=>Math.round(v+(B[i]-v)*t)).join(",")+")";};
  const up=css("--div-up"),dn=css("--div-dn"),mid=css("--div-mid");const col=g=>mix(mid,g<0?up:dn,Math.min(1,Math.abs(g)/0.5));
  document.getElementById("l-map").innerHTML=[-0.5,-0.25,0,0.25,0.5].map(g=>`<span><i style="background:${col(g)}"></i>${g===0?"on trend":pctS(g)+(Math.abs(g)===0.5?" or more":"")}</span>`).join("");
  const S=58,W=11*S+10,H=8*S+10,svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":"State gap map"},host);
  const st={};T.trends.filter(r=>r.dim==="state"&&r.measure===meas&&r.fy===2026).forEach(r=>st[r.grp]=r);
  let nb=0,nn=0;
  Object.entries(GRID).forEach(([s,[c,r]])=>{const d=st[s],x=5+c*S,y=5+r*S;const ok=d&&d.pred>0;
    const inside=ok&&d.y>=d.lo80&&d.y<=d.hi80;if(ok){nn++;if(d.y<d.lo95)nb++;}
    const rc=el("rect",{x:x+2,y:y+2,width:S-4,height:S-4,rx:5,fill:ok?col(d.gap):css("--rule-2"),"fill-opacity":ok&&!inside?1:.4},svg);
    const strong=ok&&!inside&&Math.abs(d.gap)>0.3;
    txt(svg,x+S/2,y+S/2-2,s,{"text-anchor":"middle",style:`font-weight:600;fill:${strong?"#fff":css("--ink")}`});
    txt(svg,x+S/2,y+S/2+13,ok?pctS(d.gap):"–",{"text-anchor":"middle",style:`font-size:10.5px;fill:${strong?"#fff":css("--ink-2")}`});
    rc.addEventListener("pointermove",e=>showTip(e,ok?`<b>${s}</b> · FY2026 Oct–May<br>Actual: ${fmtV(d.y)}<br>Trend: ${fmtV(d.pred)} (${pctS(d.gap)})<br>80% range: ${pctS(d.lo80/d.pred-1)} to ${pctS(d.hi80/d.pred-1)}${d.y<d.lo95?"<br><b>Below the 95% range</b>":""}`:`<b>${s}</b><br>No fitted trend`));rc.addEventListener("pointerleave",hideTip);});
  document.getElementById("map-text").textContent=`${nb} of ${nn} states and territories came in below their own 95% prediction range for ${MEAS[meas].toLowerCase()} in FY2026. Each state is measured against its own history, so a large state and a small one are on the same footing; small states have wide ranges, which the fading shows.`;}

/* ---------- month profile ---------- */
function drawMo(){const host=document.getElementById("c-mo");host.innerHTML="";
  const fys=[...new Set(T.months.map(r=>r.fy))].sort(),order=[10,11,12,1,2,3,4,5,6,7,8,9],mn=["Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"];
  const W=720,H=220,m={t:10,r:10,b:40,l:44},svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":"Monthly profile"},host);
  const tot={};T.months.forEach(r=>tot[r.fy]=(tot[r.fy]||0)+r.oblig);const ref=fys.filter(f=>f<2026);
  const share=(fy,mo)=>{const r=T.months.find(r=>r.fy===fy&&r.mo===mo);const base=fy===2026?ref.reduce((s,f)=>s+tot[f],0)/ref.length:tot[fy];return r?100*r.oblig/base:0;};
  const ymax=ticks(Math.max(...fys.flatMap(f=>order.map(mo=>share(f,mo)))),4);const yM=ymax[ymax.length-1],ys=lin(0,yM,H-m.b,m.t);
  const gw=(W-m.l-m.r)/12,bw=(gw-8)/fys.length;
  el("rect",{x:m.l,y:m.t,width:gw*8,height:H-m.b-m.t,fill:css("--tint")},svg);txt(svg,m.l+6,m.t+12,"comparison window",{class:"tiny"});
  ymax.forEach(v=>{el("line",{x1:m.l,x2:W-m.r,y1:ys(v),y2:ys(v),class:v?"grid":"axis"},svg);txt(svg,m.l-6,ys(v)+4,v+"%",{"text-anchor":"end",class:"tiny"});});
  const shades=["--seq-1","--seq-2","--seq-3","--seq-4"];
  order.forEach((mo,i)=>{txt(svg,m.l+i*gw+gw/2,H-m.b+15,mn[i],{"text-anchor":"middle",class:"tiny"});
    fys.forEach((f,j)=>{const v=share(f,mo);if(!v)return;const x=m.l+i*gw+4+j*bw,h=H-m.b-ys(v);const p=el("path",{d:colPath(x,ys(v),bw-1,h,2),fill:css(shades[j%4])},svg);
      p.addEventListener("pointermove",e=>showTip(e,`<b>FY${f}</b> · ${mn[i]}<br>${v.toFixed(1)}% of ${f===2026?"an average FY2023–25 year":"the year"}`));p.addEventListener("pointerleave",hideTip);});});
  fys.forEach((f,j)=>{const x=m.l+j*110;el("rect",{x,y:H-14,width:10,height:10,rx:2,fill:css(shades[j%4])},svg);txt(svg,x+14,H-5,"FY"+f+(f===2026?" (vs FY23–25 avg)":""),{class:"tiny"});});}

function drawAll(){drawTop();drawGap();drawMap();drawMo();}
document.querySelectorAll("#seg-m button").forEach(b=>b.addEventListener("click",()=>{document.querySelectorAll("#seg-m button").forEach(x=>x.setAttribute("aria-pressed",x===b));meas=b.dataset.v;drawAll();}));
document.querySelectorAll("#seg-d button").forEach(b=>b.addEventListener("click",()=>{document.querySelectorAll("#seg-d button").forEach(x=>x.setAttribute("aria-pressed",x===b));dim=b.dataset.v;drawGap();}));
drawAll();
matchMedia("(prefers-color-scheme: dark)").addEventListener("change",drawAll);
new MutationObserver(drawAll).observe(document.documentElement,{attributes:true,attributeFilter:["data-theme"]});
})();
