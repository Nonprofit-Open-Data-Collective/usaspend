(function(){
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const lin = (d0,d1,r0,r1) => { const f = v => r0 + (v-d0)/(d1-d0)*(r1-r0); f.inv = p => d0 + (p-r0)/(r1-r0)*(d1-d0); return f; };
function ticks(max,n){const raw=max/n,p=Math.pow(10,Math.floor(Math.log10(raw))),m=raw/p,s=(m<1.5?1:m<3?2:m<7?5:10)*p;const o=[];for(let v=0;v<max+s*0.999;v+=s)o.push(+v.toFixed(6));return o;}
function showTip(e,html){tip.innerHTML=html;tip.style.opacity=1;const w=tip.offsetWidth,h=tip.offsetHeight;let x=e.clientX+14,y=e.clientY+14;if(x+w>innerWidth-8)x=e.clientX-w-14;if(y+h>innerHeight-8)y=e.clientY-h-14;tip.style.left=x+"px";tip.style.top=y+"px";}
function hideTip(){tip.style.opacity=0;}
const esc = s => String(s==null?"":s).replace(/&/g,"&amp;").replace(/</g,"&lt;");
const n0 = v => Math.round(v).toLocaleString("en-US");
const f1 = v => v==null?"–":(Math.abs(v)<10?v.toFixed(1):Math.round(v).toLocaleString("en-US"));
const M = V.meta;
document.getElementById("m-end").textContent = M.data_end;
document.getElementById("m-win").textContent = M.window_days;
document.getElementById("m-built").textContent = M.built;
document.getElementById("m-n").textContent = n0(M.n25)+" awards active on 20 Jan 2025 · "+n0(M.n23)+" on 20 Jan 2023";

const CATS = [["none","Not disrupted","--s-none"],["terminated (formal)","Terminated (formal)","--s-term"],["terminated (quiet truncation)","Terminated (quiet)","--s-quiet"],["reduced","Reduced","--s-red"],["stalled","Stalled","--s-stall"]];
const TYPES = [["funding","Funding actions (+$)"],["zero_dollar_other","$0 administrative actions"],["deobligation","De-obligations (−$)"],["end_cut","End-date cuts"],["termination","Termination notices"],["extension","Extensions"]];
const LASTM = M.last_complete_m;
const mlab = m => m===0 ? "Month 0 (cohort start)" : (m>0?"+":"")+m+" months";
const MT = [[-24,"−24"],[-12,"−12"],[0,"0"],[12,"+12"],[18,"+18"]];
function smooth(p){return p.map((q,i)=>{const w=p.slice(Math.max(0,i-1),i+2);return [q[0],w.reduce((a,b)=>a+b[1],0)/w.length];});}
function idx(rows,keyf){const o={};rows.forEach(r=>{o[keyf(r)]=(o[keyf(r)]||0)+r.per1k;});return o;}

/* ---------- line chart with crosshair ---------- */
function lineChart(host,o){
  const W=o.w||300,H=o.h||180,m=Object.assign({t:10,r:o.rlab?96:10,b:24,l:36},o.m||{});
  const svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":o.aria||""},host);
  let ymax=o.ymax;if(ymax==null){ymax=0;o.series.forEach(s=>s.pts.forEach(p=>{if(p[1]>ymax)ymax=p[1];}));}
  const yt=ticks(ymax||1,o.yn||3);ymax=yt[yt.length-1];
  const xs=lin(o.x0,o.x1,m.l,W-m.r),ys=lin(0,ymax,H-m.b,m.t);
  if(o.shade!=null&&o.shade<o.x1)el("rect",{x:xs(o.shade),y:m.t,width:xs(o.x1)-xs(o.shade),height:H-m.b-m.t,fill:css("--rule-2")},svg);
  yt.forEach(v=>{el("line",{x1:m.l,x2:W-m.r,y1:ys(v),y2:ys(v),class:v?"grid":"axis"},svg);txt(svg,m.l-5,ys(v)+4,o.yf?o.yf(v):f1(v),{"text-anchor":"end",class:"tiny"});});
  (o.xt||[]).forEach(t=>txt(svg,xs(t[0]),H-m.b+15,t[1],{"text-anchor":t[0]===o.x1?"end":"middle",class:"tiny"}));
  if(o.vline!=null)el("line",{x1:xs(o.vline),x2:xs(o.vline),y1:m.t,y2:H-m.b,stroke:css("--ink-3"),"stroke-dasharray":"2 3"},svg);
  o.series.forEach(s=>{if(!s.pts.length)return;
    el("path",{d:s.pts.map((p,i)=>(i?"L":"M")+xs(p[0]).toFixed(1)+","+ys(p[1]).toFixed(1)).join(""),fill:"none",stroke:s.color,"stroke-width":s.w||2,"stroke-dasharray":s.dash||"","stroke-linejoin":"round","stroke-linecap":"round"},svg);
    if(o.rlab){const p=s.pts[s.pts.length-1];s._y=ys(p[1]);s._x=xs(p[0]);}});
  if(o.rlab){const L=o.series.filter(s=>s._y!=null).sort((a,b)=>a._y-b._y);for(let i=1;i<L.length;i++)if(L[i]._y-L[i-1]._y<13)L[i]._y=L[i-1]._y+13;L.forEach(s=>txt(svg,s._x+7,s._y+4,s.name,{class:"lab"}));}
  const ch=el("line",{y1:m.t,y2:H-m.b,stroke:css("--ink-3"),visibility:"hidden"},svg);
  const dots=o.series.map(s=>el("circle",{r:3.5,fill:s.color,stroke:css("--paper"),"stroke-width":1.5,visibility:"hidden"},svg));
  const hit=el("rect",{x:m.l,y:m.t,width:W-m.l-m.r,height:H-m.t-m.b,fill:"transparent"},svg);
  const X=[...new Set(o.series.flatMap(s=>s.pts.map(p=>p[0])))].sort((a,b)=>a-b);
  hit.addEventListener("pointermove",e=>{const pt=svg.createSVGPoint();pt.x=e.clientX;pt.y=e.clientY;const lp=pt.matrixTransform(svg.getScreenCTM().inverse());
    const xv=xs.inv(lp.x);let b=X[0];X.forEach(x=>{if(Math.abs(x-xv)<Math.abs(b-xv))b=x;});
    ch.setAttribute("x1",xs(b));ch.setAttribute("x2",xs(b));ch.setAttribute("visibility","visible");let rows="";
    o.series.forEach((s,i)=>{const p=s.pts.find(p=>p[0]===b);if(p){dots[i].setAttribute("cx",xs(b));dots[i].setAttribute("cy",ys(p[1]));dots[i].setAttribute("visibility","visible");rows+=`<div><span style="display:inline-block;width:8px;height:8px;border-radius:2px;background:${s.color};margin-right:6px"></span>${s.name}: <b>${o.yf?o.yf(p[1]):f1(p[1])}</b></div>`;}else dots[i].setAttribute("visibility","hidden");});
    showTip(e,`<div style="font-weight:600">${o.xl?o.xl(b):b}${o.shade!=null&&b>=o.shade?" (incomplete)":""}</div>${rows}`);});
  hit.addEventListener("pointerleave",()=>{hideTip();ch.setAttribute("visibility","hidden");dots.forEach(d=>d.setAttribute("visibility","hidden"));});
}

/* ---------- tiles + text ---------- */
const ec = {}; V.event_cohort.forEach(r=>{ec[r.cohort+"|"+r.type+"|"+r.m]=r.per1k;});
const sumEC=(c,t,a,b)=>{let s=0;for(let m=a;m<=b;m++)s+=ec[c+"|"+t+"|"+m]||0;return s;};
const post=Math.min(LASTM,18);
const fund25=sumEC("2025","funding",0,post),fund23=sumEC("2023","funding",0,post);
const term25=sumEC("2025","termination",0,post),term23=sumEC("2023","termination",0,post);
const cut25=sumEC("2025","end_cut",0,post),cut23=sumEC("2023","end_cut",0,post);
const z25=sumEC("2025","zero_dollar_other",0,post),z23=sumEC("2023","zero_dollar_other",0,post);
const contAll=c=>V.continuation.filter(r=>r.agency==="All"&&r.cohort===c);
const at=(c,d)=>{const r=contAll(c).find(r=>r.day===d);return r?r.pct:null;};
const shN={};V.shift_n.forEach(r=>{shN[r.cohort]=(shN[r.cohort]||0)+r.n;});
const cutShare=c=>100*V.shift.filter(r=>r.cohort===c&&r.bin<-3).reduce((s,r)=>s+r.N,0)/shN[c];
document.getElementById("tiles").innerHTML=[
  [(term25/term23).toFixed(1)+"×","termination notices per award in the 19 months after the cohort start, vs 2023"],
  [(fund25<fund23?"−":"+")+Math.abs(100*(fund25/fund23-1)).toFixed(0)+"%","change in funding actions per award over the same months, vs 2023"],
  [cutShare("2025").toFixed(1)+"%","of 2025 awards had their end date cut by more than 3 months (2023: "+cutShare("2023").toFixed(1)+"%)"],
  [at("2025",0).toFixed(0)+"%","of 2025 continuations funded by the due date (2023: "+at("2023",0).toFixed(0)+"%)"]
].map(t=>`<div class="tile"><div class="v">${t[0]}</div><div class="l">${t[1]}</div></div>`).join("");
document.getElementById("ev-text").textContent=`Same awards, same calendar months on either side of the cohort start, two years apart. Before month 0 the two cohorts move together. After it, the 2025 cohort records ${(term25/term23).toFixed(1)} times as many termination notices and ${(cut25/cut23).toFixed(1)} times as many end-date cuts per award, ${Math.abs(100*(fund25/fund23-1)).toFixed(0)}% ${fund25<fund23?"fewer":"more"} funding actions, and ${Math.abs(100*(z25/z23-1)).toFixed(0)}% ${z25>z23?"more":"fewer"} $0 administrative actions.`;
document.getElementById("ct-text").textContent=`On the due date, ${at("2025",0).toFixed(0)}% of 2025 continuations had been funded against ${at("2023",0).toFixed(0)}% in 2023. Ninety days later the figures were ${at("2025",90).toFixed(0)}% and ${at("2023",90).toFixed(0)}%. In aggregate the money mostly came, but later; the agency panels show where the delay lasted.`;

/* ---------- swimlanes ---------- */
const AT={funding:["Funding (+$)","--ink-3","circle"],zero_dollar_other:["$0 administrative action","--ink-3","ring"],deobligation:["De-obligation (−$)","--warn","down"],end_cut:["End-date cut","--s-quiet","left"],termination:["Termination notice","--s-term","x"],extension:["Extension","--accent","right"]};
function mark(g,s,x,y,c){const p=css("--paper");
  if(s==="circle")return el("circle",{cx:x,cy:y,r:4,fill:c,stroke:p,"stroke-width":1.5},g);
  if(s==="ring")return el("circle",{cx:x,cy:y,r:3.5,fill:p,stroke:c,"stroke-width":1.5},g);
  if(s==="x")return el("path",{d:`M${x-5},${y-5}L${x+5},${y+5}M${x+5},${y-5}L${x-5},${y+5}`,stroke:c,"stroke-width":2.6,"stroke-linecap":"round"},g);
  const d={down:`M${x-5},${y-4}L${x+5},${y-4}L${x},${y+5}Z`,left:`M${x+4},${y-5}L${x+4},${y+5}L${x-5},${y}Z`,right:`M${x-4},${y-5}L${x-4},${y+5}L${x+5},${y}Z`}[s];
  return el("path",{d,fill:c,stroke:p,"stroke-width":1},g);}
function drawLanes(){const host=document.getElementById("c-lanes");host.innerHTML="";
  document.getElementById("l-lanes").innerHTML=Object.values(AT).map(a=>`<span><i style="background:${a[2]==="ring"?"transparent":`var(${a[1]})`};${a[2]==="ring"?"border:1.5px solid var(--ink-3);":""}border-radius:${a[2]==="circle"||a[2]==="ring"?"50%":"2px"}"></i>${a[0]}</span>`).join("")+`<span><i style="background:var(--seq-2)"></i>Cash paid in the quarter</span>`;
  const A=V.lanes.awards,W=880,m={t:26,l:210,r:12},rh=46,H=m.t+A.length*rh+4;
  const svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":"Award timelines"},host);
  const t0=Date.parse("2023-10-01"),t1=Date.parse("2027-12-31"),xs=lin(t0,t1,m.l,W-m.r),T0=Date.parse("2025-01-20"),DE=Date.parse(M.data_end);
  for(let y=2024;y<=2027;y++){const x=xs(Date.parse(y+"-01-01"));el("line",{x1:x,x2:x,y1:m.t-8,y2:H,class:"grid"},svg);txt(svg,x+3,m.t-12,String(y),{class:"tiny"});}
  el("line",{x1:xs(T0),x2:xs(T0),y1:m.t-8,y2:H,stroke:css("--ink"),"stroke-dasharray":"3 3"},svg);txt(svg,xs(T0)+4,m.t-12,"20 Jan 2025",{class:"tiny",style:"fill:var(--ink)"});
  el("line",{x1:xs(DE),x2:xs(DE),y1:m.t-8,y2:H,stroke:css("--ink-3"),"stroke-dasharray":"1 3"},svg);txt(svg,xs(DE)+4,m.t-12,"data end",{class:"tiny"});
  const qd=(fy,fq)=>Date.parse(`${fq===1?fy-1:fy}-${["10","01","04","07"][fq-1]}-01`);
  A.forEach((a,i)=>{const y0=m.t+i*rh,cy=y0+15;
    if(i)el("line",{x1:0,x2:W,y1:y0,y2:y0,stroke:css("--rule-2")},svg);
    const cat=CATS.find(c=>c[0]===a.category);
    el("rect",{x:0,y:cy-11,width:3,height:30,rx:1.5,fill:css(cat[2])},svg);
    txt(svg,10,cy-1,a.story,{class:"grp"});
    txt(svg,10,cy+14,a.agency+" · $"+(a.oblig_T>=1e6?(a.oblig_T/1e6).toFixed(1)+"M":Math.round(a.oblig_T/1e3)+"K")+" obligated",{class:"tiny"});
    const sE=Date.parse(a.sched_end_T),wE=Date.parse(a.sched_end_w);
    el("rect",{x:xs(t0),y:cy-4,width:Math.max(0,xs(Math.min(sE,t1))-xs(t0)),height:8,rx:3,fill:css("--rule")},svg);
    el("rect",{x:xs(t0),y:cy-1.25,width:Math.max(0,xs(Math.min(wE,t1))-xs(t0)),height:2.5,rx:1.25,fill:css("--ink-2")},svg);
    if(sE>t1)txt(svg,W-m.r,cy-6,"→ "+a.sched_end_T.slice(0,4),{"text-anchor":"end",class:"tiny"});
    const outs=V.lanes.outlays.filter(o=>o.award_key===a.award_key),mx=Math.max(1,...outs.map(o=>o.outlay));
    outs.forEach(o=>{if(o.outlay<=0)return;const xa=xs(qd(o.fy,o.fq)),xb=xs(qd(o.fy,o.fq)+91*864e5),h=Math.max(1.5,10*o.outlay/mx);el("rect",{x:xa+1,y:cy+16-h,width:xb-xa-2,height:h,rx:1,fill:css("--seq-2")},svg);});
    const lf=V.lanes.tx.filter(t=>t.award_key===a.award_key&&t.amt>0).map(t=>t.d).sort().pop();
    const mo=d=>new Date(d+"T00:00:00").toLocaleString("en-US",{month:"short",year:"numeric"});
    const note=[a.category==="stalled"||a.category==="none"?(lf?"last new money "+mo(lf):"no new money since Oct 2023"):"",a.note].filter(Boolean).join(" · ");
    txt(svg,m.l,y0+rh-4,note,{class:"ann"});
    V.lanes.tx.filter(t=>t.award_key===a.award_key).forEach(t=>{const at=AT[t.type],x=xs(Date.parse(t.d));mark(svg,at[2],x,cy-10,css(at[1]));
      const h=el("circle",{cx:x,cy:cy-10,r:8,fill:"transparent"},svg);
      h.addEventListener("pointermove",e=>showTip(e,`<b>${at[0]}</b> · ${t.d}<br>Obligation: ${t.amt<0?"−":""}$${Math.abs(t.amt).toLocaleString("en-US")}<br><span style="opacity:.8">${esc(t.desc)}</span>`));h.addEventListener("pointerleave",hideTip);});
    const lh=el("rect",{x:0,y:y0,width:m.l-6,height:rh,fill:"transparent"},svg);
    lh.addEventListener("pointermove",e=>showTip(e,`<b>${esc(a.sub_agency)}</b><br><span class="mono">${esc(a.award_key)}</span><br>Category: ${cat[1]}<br>End date on 20 Jan 2025: ${a.sched_end_T}<br>End date now: ${a.sched_end_w}<br>Recipient size: ${a.size}`));lh.addEventListener("pointerleave",hideTip);});}

/* ---------- event multiples ---------- */
function drawEv(){const host=document.getElementById("c-ev");host.innerHTML="";
  TYPES.forEach(([k,l])=>{const b=document.createElement("div");b.innerHTML=`<p class="mt">${l}</p>`;const c=document.createElement("div");c.className="chart";b.appendChild(c);host.appendChild(b);
    const ser=["2023","2025"].map(co=>{const p=[];for(let m=-24;m<=18;m++)p.push([m,ec[co+"|"+k+"|"+m]||0]);return {name:co+" cohort",color:css(co==="2023"?"--base":"--accent"),dash:co==="2023"?"4 3":"",pts:smooth(p)};});
    lineChart(c,{x0:-24,x1:18,series:ser,xt:MT,vline:0,shade:LASTM+0.5,xl:mlab,aria:l});});}
function drawEg(){const host=document.getElementById("c-eg");host.innerHTML="";
  const gn={};V.group_n.forEach(r=>gn[r.grp]=r.awards);
  document.getElementById("l-eg").innerHTML=CATS.map(c=>`<span><i class="ln" style="background:var(${c[2]})"></i>${c[1]} (${n0(gn[c[0]]||0)})</span>`).join("");
  const eg={};V.event_group.forEach(r=>{const t=r.type==="termination"?"end_cut":r.type;const key=r.grp+"|"+t+"|"+r.m;eg[key]=(eg[key]||0)+r.per1k;});
  [["funding","Funding actions (+$)"],["zero_dollar_other","$0 administrative actions"],["deobligation","De-obligations (−$)"],["end_cut","End-date cuts and termination notices"]].forEach(([k,l])=>{
    const b=document.createElement("div");b.innerHTML=`<p class="mt">${l}</p>`;const c=document.createElement("div");c.className="chart";b.appendChild(c);host.appendChild(b);
    const ser=CATS.map(([g,n,col])=>{const p=[];for(let m=-24;m<=18;m++)p.push([m,eg[g+"|"+k+"|"+m]||0]);return {name:n,color:css(col),w:g==="none"?2.6:1.8,pts:smooth(p)};});
    lineChart(c,{x0:-24,x1:18,series:ser,xt:MT,vline:0,shade:LASTM+0.5,xl:mlab,aria:l});});
  const pre=(g,t)=>{let s=0;for(let m=-12;m<0;m++)s+=eg[g+"|"+t+"|"+m]||0;return s/12;},pos=(g,t)=>{let s=0;for(let m=1;m<=Math.min(12,LASTM);m++)s+=eg[g+"|"+t+"|"+m]||0;return s/Math.min(12,LASTM);};
  const r=(g,t)=>pos(g,t)/Math.max(pre(g,t),1e-9);
  document.getElementById("eg-text").textContent=`Inside the 2025 cohort, compare each category's year after January 2025 with its year before. Funding actions fell to ${(100*r("terminated (formal)","funding")).toFixed(0)}% of their earlier pace on formally terminated awards and ${(100*r("stalled","funding")).toFixed(0)}% on stalled ones, against ${(100*r("none","funding")).toFixed(0)}% on awards that were not disrupted. De-obligations rose ${r("reduced","deobligation").toFixed(1)}-fold on reduced awards and ${r("terminated (quiet truncation)","deobligation").toFixed(1)}-fold on quietly truncated ones.`;}

/* ---------- agency heatmap ---------- */
function drawAg(){const host=document.getElementById("c-ag");host.innerHTML="";
  const C=CATS.slice(1),ags=[...new Set(V.agency.map(r=>r.agency))],g=(a,c)=>V.agency.find(r=>r.agency===a&&r.category===c);
  const tsum=a=>(g(a,C[0][0]).p25-g(a,C[0][0]).p23)+(g(a,C[1][0]).p25-g(a,C[1][0]).p23);ags.sort((a,b)=>tsum(b)-tsum(a));
  const nm={};V.agency_names.forEach(r=>nm[r.agency]=r.name);
  const W=720,m={t:30,l:150},cw=(W-m.l)/4,rh=26,H=m.t+ags.length*rh+4,svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":"Agency by category change"},host);
  const hx=s=>{s=s.replace("#","");return [0,2,4].map(i=>parseInt(s.slice(i,i+2),16));},mix=(a,b,t)=>{const A=hx(a),B=hx(b);return "rgb("+A.map((v,i)=>Math.round(v+(B[i]-v)*t)).join(",")+")";};
  const up=css("--div-up"),dn=css("--div-dn"),mid=css("--div-mid");
  C.forEach((c,j)=>txt(svg,m.l+j*cw+cw/2,m.t-11,c[1],{"text-anchor":"middle",class:"lab",style:"font-weight:600"}));
  ags.forEach((a,i)=>{const y=m.t+i*rh;txt(svg,m.l-10,y+rh/2+4,a,{"text-anchor":"end",class:"lab"});
    C.forEach((c,j)=>{const r=g(a,c[0]),d=r.p25-r.p23,sig=Math.abs(r.z)>=2,t=Math.pow(Math.min(1,Math.abs(d)/10),.7);
      const rc=el("rect",{x:m.l+j*cw+1,y:y+1,width:cw-2,height:rh-2,rx:3,fill:mix(mid,d>0?up:dn,t),"fill-opacity":sig?1:.35},svg);
      const strong=sig&&t>.55;txt(svg,m.l+j*cw+cw/2,y+rh/2+4,(d>0?"+":d<0?"−":"")+Math.abs(d).toFixed(1),{"text-anchor":"middle",style:`fill:${strong?"#fff":css(sig?"--ink":"--ink-3")};font-variant-numeric:tabular-nums`});
      rc.addEventListener("pointermove",e=>showTip(e,`<b>${esc(nm[a]||a)}</b> · ${c[1]}<br>2023: ${r.p23.toFixed(1)}% of ${n0(r.n_2023)} (${n0(r.x_2023)})<br>2025: ${r.p25.toFixed(1)}% of ${n0(r.n_2025)} (${n0(r.x_2025)})<br>Change: ${(d>0?"+":"")+d.toFixed(1)} pts · z = ${r.z.toFixed(1)}`));rc.addEventListener("pointerleave",hideTip);});});
  const top=ags[0],tr=g(top,C[0][0]);const st=V.agency.filter(r=>r.category==="stalled").sort((a,b)=>(b.p25-b.p23)-(a.p25-a.p23))[0];
  const redDown=V.agency.filter(r=>r.category==="reduced"&&r.p25<r.p23&&Math.abs(r.z)>=2).map(r=>r.agency);
  document.getElementById("ag-text").textContent=`Subtracting each agency's 2023 rate keeps large, routinely busy agencies from dominating by volume. ${nm[top]||top} leads on formal terminations (${tr.p23.toFixed(1)}% → ${tr.p25.toFixed(1)}%). The largest rise in stalled awards is at ${nm[st.agency]||st.agency} (${st.p23.toFixed(1)}% → ${st.p25.toFixed(1)}%). Reductions fell significantly at ${redDown.length} agencies, consistent with awards being terminated outright rather than trimmed.`;}

/* ---------- schedule shift ---------- */
function drawSh(fam){const host=document.getElementById("c-sh");host.innerHTML="";
  const rows=V.shift.filter(r=>fam==="all"||r.family===fam),N={};V.shift_n.filter(r=>fam==="all"||r.family===fam).forEach(r=>N[r.cohort]=(N[r.cohort]||0)+r.n);
  const share=(c,b)=>100*rows.filter(r=>r.cohort===c&&r.bin===b).reduce((s,r)=>s+r.N,0)/N[c];
  const bins=[];for(let b=-36;b<=36;b+=3)bins.push(b);
  const W=720,rowH=130,m={t:8,l:100,r:10,b:26},H=m.t+2*rowH+m.b,svg=el("svg",{viewBox:`0 0 ${W} ${H}`,role:"img","aria-label":"End date shift"},host);
  const xs=lin(-36,39,m.l,W-m.r),bw=xs(3)-xs(0),ymax=Math.max(...["2023","2025"].flatMap(c=>bins.map(b=>share(c,b))));
  ["2023","2025"].forEach((c,i)=>{const base=m.t+(i+1)*rowH-10,ys0=lin(0,Math.sqrt(ymax),base,base-rowH+30),ys=v=>ys0(Math.sqrt(v));
    txt(svg,m.l-12,base-rowH/2+10,c+" cohort",{"text-anchor":"end",class:"lab",style:"font-weight:600"});
    el("line",{x1:m.l,x2:W-m.r,y1:base,y2:base,class:"axis"},svg);
    bins.forEach(b=>{const v=share(c,b);if(!v)return;const h=base-ys(v),x=xs(b)+1;
      const r=el("path",{d:colPath(x,base-h,bw-2,h,3),fill:css(b<0?"--div-up":"--div-dn")},svg);
      const lab=b===36?"36+ months later":b===-36?"36+ months earlier":`${b<0?"":"+"}${b} to ${b<0?"":"+"}${b+3} months`;
      r.addEventListener("pointermove",e=>showTip(e,`<b>${c} cohort</b> · ${lab}<br>${v.toFixed(2)}% of active awards`));r.addEventListener("pointerleave",hideTip);});
    const cut=bins.filter(b=>b<-3).reduce((s,b)=>s+share(c,b),0),ext=bins.filter(b=>b>=3).reduce((s,b)=>s+share(c,b),0);
    txt(svg,xs(-36),base-rowH+38,`cut by more than 3 months: ${cut.toFixed(1)}%`,{class:"lab"});
    txt(svg,W-m.r,base-rowH+38,`extended 3+ months: ${ext.toFixed(1)}%`,{class:"lab","text-anchor":"end"});});
  [-36,-24,-12,0,12,24,36].forEach(v=>txt(svg,xs(v)+(v===36?bw/2:0),H-m.b+16,v===0?"0":(v>0?"+":"−")+Math.abs(v)+(Math.abs(v)===36?"+":""),{"text-anchor":"middle",class:"tiny"}));
  txt(svg,W-m.r,H-2,"months",{"text-anchor":"end",class:"tiny"});
  if(fam==="all"){const sc=V.shift_cats,tot=c=>sc.filter(r=>r.cohort===c).reduce((s,r)=>s+r.N,0),inc=c=>sc.filter(r=>r.cohort===c&&r.category.startsWith("terminated")).reduce((s,r)=>s+r.N,0);
    document.getElementById("sh-text").textContent=`Extensions look much the same in both cohorts. The change is on the left: ${cutShare("2025").toFixed(1)}% of 2025 awards had their schedule cut by more than three months, against ${cutShare("2023").toFixed(1)}% in 2023, and ${(100*inc("2025")/tot("2025")).toFixed(0)}% of the 2025 cuts belong to awards classed as terminated. Many cuts remove a year or more of planned work.`;}}
document.querySelectorAll("#seg-sh button").forEach(b=>b.addEventListener("click",()=>{document.querySelectorAll("#seg-sh button").forEach(x=>x.setAttribute("aria-pressed",x===b));drawSh(b.dataset.v);}));

/* ---------- continuation ---------- */
function drawCt(){const host=document.getElementById("c-ct");host.innerHTML="";
  const ags=["All",...[...new Set(V.continuation.filter(r=>r.agency!=="All"&&r.agency!=="Other").map(r=>r.agency))].sort((a,b)=>{const n=x=>(V.continuation.find(r=>r.agency===x&&r.cohort==="2025")||{n:0}).n;return n(b)-n(a);})];
  ags.forEach(a=>{const n=c=>(V.continuation.find(r=>r.agency===a&&r.cohort===c)||{n:0}).n;
    const b=document.createElement("div");b.innerHTML=`<p class="mt">${a==="All"?"All agencies":esc(a)} <span class="tiny" style="font-weight:400;color:var(--ink-3)">${n0(n("2025"))} / ${n0(n("2023"))} awards</span></p>`;const c=document.createElement("div");c.className="chart";b.appendChild(c);host.appendChild(b);
    const ser=["2023","2025"].map(co=>({name:co+" cohort",color:css(co==="2023"?"--base":"--accent"),dash:co==="2023"?"4 3":"",pts:V.continuation.filter(r=>r.agency===a&&r.cohort===co&&r.pct!=null).map(r=>[r.day,r.pct])}));
    lineChart(c,{x0:-90,x1:365,ymax:100,series:ser,yf:v=>v.toFixed(0)+"%",xt:[[-90,"−90"],[0,"due"],[180,"+180"],[365,"+365"]],vline:0,xl:d=>(d>0?"+":"")+d+" days from due",aria:"Continuation timing "+a});});}

function drawAll(){drawLanes();drawEv();drawEg();drawAg();drawSh(document.querySelector('#seg-sh button[aria-pressed="true"]').dataset.v);drawCt();}
drawAll();
matchMedia("(prefers-color-scheme: dark)").addEventListener("change",drawAll);
new MutationObserver(drawAll).observe(document.documentElement,{attributes:true,attributeFilter:["data-theme"]});
})();
