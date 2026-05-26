// WS Racing UI — RDR2 theme, slimmed for performance
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ws-racing';
const app        = document.getElementById('app');
const lobbyModal = document.getElementById('lobby-modal');
const startModal = document.getElementById('start-modal');

const state = {
  role: 'player',
  lobby: { active: false, raceId: null, raceData: null, participants: [], betAmount: 0 },
  savedRaces: [], globalLeaderboard: [], recentRaces: [],
  create: { name:'', raceType:'circuit', maxParticipants:10, minLevel:0, laps:3, collision:true, checkpoints:[], startPositions:[] },
  lobbyPendingRace: null,
  playerStats: { wins:0, losses:0, totalRaces:0, score:0 },
};

function nui(name, data = {}) {
  return fetch(`https://${resource}/${name}`, {
    method:'POST', headers:{'Content-Type':'application/json; charset=UTF-8'}, body:JSON.stringify(data)
  });
}

function p2(n){ return String(n).padStart(2,'0'); }
function fmt$(v){ return `$${Number(v||0).toLocaleString()}`; }
function fmtCoord(v){ return Number(v).toFixed(1); }
function setTxt(id,v){ const e=document.getElementById(id); if(e) e.textContent=v; }

// Real-time clock removed from UI
function startClock(){}
function stopClock(){}

function getTierFromScore(score){
  const s=Number(score||0);
  if(s>=2000) return {label:'Legend',  cls:'tier-legend',  icon:'★★★★★'};
  if(s>=1000) return {label:'Platinum',cls:'tier-platinum',icon:'★★★★'};
  if(s>=500)  return {label:'Gold',    cls:'tier-gold',    icon:'★★★'};
  if(s>=200)  return {label:'Silver',  cls:'tier-silver',  icon:'★★'};
  return              {label:'Bronze', cls:'tier-bronze',  icon:'★'};
}

function switchTab(tabId){
  document.querySelectorAll('.nav-item').forEach(el=>el.classList.toggle('active',el.dataset.tab===tabId));
  document.querySelectorAll('.section-view').forEach(el=>el.classList.add('hidden'));
  const sec=document.getElementById(tabId); if(sec) sec.classList.remove('hidden');
  const titles={dashboard:'Dashboard',lobby:'Race Lobby',create:'Create Race',saved:'Saved Tracks',leaderboard:'Hall of Fame',stats:'Rider Stats'};
  setTxt('page-title-crumb',titles[tabId]||'');
  if(tabId==='saved')       nui('requestAdminRaces');
  if(tabId==='leaderboard') nui('requestGlobalLeaderboard');
  if(tabId==='lobby')       renderLobbyInTab();
  if(tabId==='dashboard')   nui('requestRecentRaces');
  if(tabId==='stats')       nui('requestMyStats');
}

function renderDashboard(){
  const race=state.lobby.raceData, parts=state.lobby.participants||[], run=state.lobby.active;
  setTxt('hero-badge-text', run?'Race Running' : (race?'Lobby Open':'No active race'));
  setTxt('hero-title', race?race.name : 'Ride Into Victory');
  setTxt('hero-subtitle', race?`${parts.length} rider(s) joined · Pot: ${fmt$(state.lobby.betAmount)}` : 'Use /racemenu to open this here panel.');
  setTxt('stat-players', String(parts.length));
  setTxt('stat-bet', fmt$(state.lobby.betAmount));
  const stxt = run?'Running' : (race?'Waiting':'Idle');
  setTxt('stat-status', stxt);
  setTxt('stat-race', race?race.name:'None');
  setTxt('qc-race', race?race.name:'None');
  setTxt('qc-players', race?`${parts.length}/${race.max_participants||10}`:'0/0');
  setTxt('qc-bet', fmt$(state.lobby.betAmount));
  setTxt('qc-status', stxt);
  const lv=document.getElementById('tb-live'); if(lv) lv.classList.toggle('hidden',!run);
  buildLobbyBlock(document.getElementById('dashboard-lobby-section'));
}

function buildLobbyBlock(el){
  if(!el) return;
  const race=state.lobby.raceData, parts=state.lobby.participants||[], run=state.lobby.active;
  if(!race){
    el.innerHTML='<div class="empty-blk"><div class="empty-txt">No race lobby is open. Wait for the marshal to open one.</div></div>';
    return;
  }
  const chips = parts.length
    ? parts.map(p=>`<div class="player-chip"><span class="chip-name">${p.name}</span></div>`).join('')
    : '<div class="muted-t" style="padding:6px">No riders joined yet.</div>';
  const admin = state.role==='admin'
    ? `<div class="lp-admin">${!run?`<button class="btn btn-gold" onclick="openStartModal()">Start Race</button>`:''}<button class="btn btn-danger" onclick="nui('cancelRace')">${run?'Force Stop':'Cancel Lobby'}</button></div>`
    : '';
  el.innerHTML = `<div class="lp"><div class="lp-hd"><div><div class="lp-name">${race.name}</div><div class="race-meta"><span>Max ${race.max_participants||10}</span><span>Laps ${race.laps||1}</span><span>${fmt$(state.lobby.betAmount)} Pot</span><span class="${run?'badge-running':'badge-open'}">${run?'● Running':'● Open'}</span></div></div>${!run&&state.role!=='admin'?`<button class="btn btn-gold" onclick="joinRace()">Join Race</button>`:''}</div><div class="lp-players"><div class="lpp-title">Joined Riders <span class="players-count">${parts.length}/${race.max_participants||10}</span></div><div class="players-grid">${chips}</div></div>${admin}${state.role!=='admin'?`<div style="padding:10px 18px;border-top:1px solid var(--paper3)"><button class="btn btn-ghost" onclick="nui('playerLeave')">Leave Race</button></div>`:''}</div>`;
}

function renderLobbyInTab(){ const el=document.getElementById('lobby-tab-body'); if(el) buildLobbyBlock(el); }

function renderSavedRaces(){
  const list=document.getElementById('saved-race-list'); if(!list) return;
  if(!state.savedRaces.length){ list.innerHTML='<div class="empty-blk"><div class="empty-txt">No saved races. Create one first.</div></div>'; return; }
  const aId=state.lobby.raceData?Number(state.lobby.raceData.id):null;
  list.innerHTML='';
  state.savedRaces.forEach(r=>{
    const act = aId===Number(r.id);
    const card=document.createElement('div');
    card.className='race-card'+(act?' race-card-active':'');
    const left=document.createElement('div'); left.className='race-left';
    left.innerHTML='<div class="race-icon">'+(act?'●':'☆')+'</div>'
      +'<div><div class="race-title">'+r.name+'</div>'
      +'<div class="race-meta"><span>Max '+(r.max_participants||10)+'</span>'
      +'<span>Laps '+(r.laps||1)+'</span>'
      +(act?'<span class="badge-open">● LOBBY OPEN · '+(state.lobby.participants||[]).length+' joined</span>':'')
      +'</div></div>';
    const actions=document.createElement('div'); actions.className='race-actions';
    if(act){
      const s=document.createElement('button'); s.className='btn btn-gold'; s.textContent='Start'; s.addEventListener('click', openStartModal);
      const cl=document.createElement('button'); cl.className='btn btn-ghost'; cl.textContent='Close'; cl.addEventListener('click',()=>nui('cancelRace'));
      actions.appendChild(s); actions.appendChild(cl);
    } else {
      const bl=document.createElement('button'); bl.className='btn btn-gold'; bl.textContent='Open Lobby'; bl.addEventListener('click',()=>openLobbyModal(r.id));
      const bd=document.createElement('button'); bd.className='btn btn-danger'; bd.textContent='Delete'; bd.addEventListener('click',()=>deleteRace(r.id,r.name));
      actions.appendChild(bl); actions.appendChild(bd);
    }
    card.appendChild(left); card.appendChild(actions); list.appendChild(card);
  });
}

function renderGlobalLeaderboard(){
  const el=document.getElementById('global-leaderboard-list'), rows=state.globalLeaderboard; if(!el) return;
  if(!rows.length){ el.innerHTML='<div class="empty-blk"><div class="empty-txt">No data yet. Race to earn points.</div></div>'; return; }
  const maxS=Number(rows[0].score||1);
  el.innerHTML=rows.map((row,i)=>{
    const score=Number(row.score||0), wins=Number(row.wins||0), races=Number(row.total_races||0);
    const pct=Math.round((score/maxS)*100), tier=getTierFromScore(score);
    const cls=i===0?'lb-first':'';
    return `<div class="lb-row ${cls}"><div class="lb-rank">${i+1}</div><div class="lb-info"><div class="lb-name">${row.player_name}</div><div class="lb-sub">${races} race${races!==1?'s':''} · ${wins} win${wins!==1?'s':''}</div><span class="rank-tier-badge">${tier.icon} ${tier.label}</span><div class="lb-bar-wrap"><div class="lb-bar" style="width:${pct}%"></div></div></div><div class="lb-score-box"><div class="lb-score">${score.toLocaleString()}</div><div class="lb-score-label">pts</div></div></div>`;
  }).join('');
}

function renderPlayerStats(){
  const s=state.playerStats, tier=getTierFromScore(s.score||0);
  setTxt('rank-icon',tier.icon); setTxt('rank-tier-name',tier.label);
  setTxt('rank-pts',(s.score||0).toLocaleString()+' pts');
  setTxt('rs-wins',String(s.wins||0)); setTxt('rs-losses',String(s.losses||0)); setTxt('rs-races',String(s.totalRaces||0));
  const wr=s.totalRaces>0?Math.round((s.wins/s.totalRaces)*100):0; setTxt('rs-winrate',wr+'%');
  const pts=[0,200,500,1000,2000], nxt=[200,500,1000,2000,2000];
  const idx=['Bronze','Silver','Gold','Platinum','Legend'].indexOf(tier.label);
  const from=pts[idx]||0, to=nxt[idx]||2000;
  const pct=to>from?Math.min(100,Math.round(((s.score-from)/(to-from))*100)):100;
  const fill=document.getElementById('rank-prog-fill'); if(fill) fill.style.width=pct+'%';
  setTxt('rp-from',tier.label);
  setTxt('rp-to',idx<4?['Silver','Gold','Platinum','Legend','MAX'][idx]+' →':'MAX');
  const si=document.getElementById('sb-tier-ico'); if(si) si.textContent=tier.icon;
}

function renderCreateState(){
  const el=(id)=>document.getElementById(id);
  if(el('create-name'))  el('create-name').value=state.create.name||'';
  if(el('create-max'))   el('create-max').value=state.create.maxParticipants||10;
  if(el('create-level')) el('create-level').value=state.create.minLevel||0;
  if(el('create-collision')) el('create-collision').checked=!!state.create.collision;
  if(el('lap-display'))  el('lap-display').textContent=state.create.laps||3;
  if(el('create-laps'))  el('create-laps').value=state.create.laps||3;
  if(el('mm-cp-count'))  el('mm-cp-count').textContent=state.create.checkpoints.length+' CP';
  if(el('checkpoint-list')) el('checkpoint-list').innerHTML=state.create.checkpoints.length
    ?state.create.checkpoints.map((cp,i)=>`<div class="coord-row"><strong>CP ${i+1}</strong><span>${fmtCoord(cp.x)}, ${fmtCoord(cp.y)}, ${fmtCoord(cp.z)}</span></div>`).join('')
    :'<div class="muted-t">No checkpoints yet.</div>';
  if(el('start-list')) el('start-list').innerHTML=state.create.startPositions.length
    ?state.create.startPositions.map((sp,i)=>`<div class="coord-row"><strong>Start ${i+1}</strong><span>${fmtCoord(sp.x)}, ${fmtCoord(sp.y)}, ${fmtCoord(sp.z)}</span></div>`).join('')
    :'<div class="muted-t">No start positions yet.</div>';
  renderMiniMap();
}

function renderMiniMap(){
  const svg=document.getElementById('mm-svg'); if(!svg) return;
  const cps=state.create.checkpoints;
  if(cps.length<2){ svg.innerHTML='<text x="142" y="88" text-anchor="middle" font-size="11" fill="rgba(120,90,40,.4)" font-family="IM Fell English, serif">No Track Loaded</text>'; return; }
  const xs=cps.map(c=>c.x),ys=cps.map(c=>c.y);
  const mnX=Math.min(...xs),mxX=Math.max(...xs),mnY=Math.min(...ys),mxY=Math.max(...ys);
  const pd=20,W=285-pd*2,H=165-pd*2,sX=mxX!==mnX?W/(mxX-mnX):1,sY=mxY!==mnY?H/(mxY-mnY):1,sc=Math.min(sX,sY);
  const tx=x=>(pd+(x-mnX)*sc).toFixed(1),ty=y=>(pd+(y-mnY)*sc).toFixed(1);
  const pts=cps.map(c=>`${tx(c.x)},${ty(c.y)}`).join(' ');
  const sp=state.create.startPositions[0],sx=sp?tx(sp.x):tx(cps[0].x),sy=sp?ty(sp.y):ty(cps[0].y);
  svg.innerHTML=`<polyline points="${pts}" fill="none" stroke="#a8853c" stroke-width="2" stroke-dasharray="5,3"/>${cps.map(c=>`<circle cx="${tx(c.x)}" cy="${ty(c.y)}" r="3" fill="#7a6028"/>`).join('')}<circle cx="${sx}" cy="${sy}" r="5" fill="#5e7a3a"/><circle cx="${tx(cps[cps.length-1].x)}" cy="${ty(cps[cps.length-1].y)}" r="5" fill="#8b2a1a"/>`;
}

function renderAll(){
  const isAdmin=state.role==='admin';
  document.querySelectorAll('.admin-only').forEach(el=>el.classList.toggle('hidden',!isAdmin));
    setTxt('profile-role','');
  renderDashboard(); renderSavedRaces(); renderGlobalLeaderboard(); renderCreateState(); renderPlayerStats(); renderLobbyInTab();
}

window.adjLaps=function(d){
  const inp=document.getElementById('create-laps'),disp=document.getElementById('lap-display');
  let v=Math.max(1,Math.min(20,(parseInt(inp?.value)||3)+d));
  if(inp) inp.value=v; if(disp) disp.textContent=v; state.create.laps=v;
};

window.openLobbyModal=function(raceId){
  const race=state.savedRaces.find(r=>Number(r.id)===Number(raceId)); if(!race) return;
  state.lobbyPendingRace=race;
  setTxt('lobby-modal-race-name',race.name);
  document.getElementById('lobby-max').value=race.max_participants||10;
  document.getElementById('lobby-bet').value=0;
  document.getElementById('lobby-laps').value=race.laps||1;
  document.getElementById('lobby-collision').checked=race.collision!==0;
  lobbyModal.classList.remove('hidden');
};
window.closeLobbyModal=function(){ lobbyModal.classList.add('hidden'); state.lobbyPendingRace=null; };
window.openStartModal=function(){
  const parts=state.lobby.participants||[];
  setTxt('start-modal-info',`${parts.length} rider(s) ready · Pot: ${fmt$(state.lobby.betAmount)}`);
  startModal.classList.remove('hidden');
};
function closeStartModal(){ startModal.classList.add('hidden'); }

window.joinRace=()=>nui('playerJoin');
window.deleteRace=(id,name)=>{ if(confirm(`Delete "${name}"? Cannot be undone.`)){ nui('deleteRace',{raceId:id}); setTimeout(()=>nui('requestAdminRaces'),500); } };

// ─────────── Cinematic countdown SFX (Web Audio) ───────────
let __cdAudioCtx=null;
function __cdCtx(){
  if(!__cdAudioCtx){ try{ __cdAudioCtx = new (window.AudioContext||window.webkitAudioContext)(); }catch(e){} }
  if(__cdAudioCtx && __cdAudioCtx.state==='suspended'){ try{ __cdAudioCtx.resume(); }catch(e){} }
  return __cdAudioCtx;
}
function playCountdownBeep(isGo){
  const ctx=__cdCtx(); if(!ctx) return;
  const now=ctx.currentTime;
  // Low cinematic boom
  const o1=ctx.createOscillator(), g1=ctx.createGain();
  o1.type='sine'; o1.frequency.setValueAtTime(isGo?160:110, now);
  o1.frequency.exponentialRampToValueAtTime(isGo?80:55, now+0.6);
  g1.gain.setValueAtTime(0.0001, now);
  g1.gain.exponentialRampToValueAtTime(isGo?1.0:0.8, now+0.02);
  g1.gain.exponentialRampToValueAtTime(0.0001, now+(isGo?1.4:0.9));
  o1.connect(g1).connect(ctx.destination);
  o1.start(now); o1.stop(now+(isGo?1.5:1.0));
  // Bright tone on top
  const o2=ctx.createOscillator(), g2=ctx.createGain();
  o2.type=isGo?'sawtooth':'triangle';
  o2.frequency.setValueAtTime(isGo?880:520, now);
  if(isGo) o2.frequency.exponentialRampToValueAtTime(1320, now+0.4);
  g2.gain.setValueAtTime(0.0001, now);
  g2.gain.exponentialRampToValueAtTime(isGo?0.5:0.35, now+0.02);
  g2.gain.exponentialRampToValueAtTime(0.0001, now+(isGo?1.2:0.6));
  o2.connect(g2).connect(ctx.destination);
  o2.start(now); o2.stop(now+(isGo?1.3:0.7));
}
let __cdHideT=null;
function showCountdown(value){
  const ov=document.getElementById('countdown-overlay');
  const num=document.getElementById('countdown-number');
  if(!ov||!num) return;
  const isGo = (String(value).toUpperCase()==='GO!'||String(value).toUpperCase()==='GO');
  num.textContent = isGo ? 'GO!' : String(value);
  num.classList.remove('cd-go'); void num.offsetWidth;
  if(isGo) num.classList.add('cd-go');
  // restart animation
  num.style.animation='none'; void num.offsetWidth; num.style.animation='';
  ov.classList.remove('hidden');
  playCountdownBeep(isGo);
  if(__cdHideT) clearTimeout(__cdHideT);
  __cdHideT=setTimeout(()=>{ ov.classList.add('hidden'); }, isGo?1200:950);
}

window.addEventListener('message',event=>{
  const msg=event.data||{};
  if(msg.action==='open'){
    app.classList.remove('hidden');
    state.role=msg.role||'player'; state.lobby=msg.data||state.lobby;
    if(msg.stats) state.playerStats=msg.stats;
    if(msg.playerName) setTxt('profile-name', msg.playerName);
    startClock();
    switchTab('dashboard'); renderAll();
    nui('requestRecentRaces');
  }
  if(msg.action==='close'){ app.classList.add('hidden'); window.closeLobbyModal(); closeStartModal(); stopClock(); }
  if(msg.action==='updateLobby'){ state.role=msg.role||state.role; state.lobby=msg.data||state.lobby; renderAll(); }
  if(msg.action==='receiveAdminRaces'){ state.savedRaces=msg.races||[]; renderSavedRaces(); }
  if(msg.action==='receiveGlobalLeaderboard'){ state.globalLeaderboard=msg.rows||[]; renderGlobalLeaderboard(); }
  if(msg.action==='receiveRecentRaces'){ state.recentRaces=msg.races||[]; renderRecentRaces(); }
  if(msg.action==='updateParticipants'){ state.lobby.participants=msg.participants||[]; renderDashboard(); renderSavedRaces(); renderLobbyInTab(); }
  if(msg.action==='createState'){ state.create=msg.create||state.create; renderCreateState(); }
  if(msg.action==='lobbyOpened'){ window.closeLobbyModal(); switchTab('dashboard'); renderAll(); }
  if(msg.action==='updatePlayerStats'){ state.playerStats=msg.stats||state.playerStats; renderPlayerStats(); }
  if(msg.action==='receiveStats'){
    const rows=msg.stats||[];
    // If the server sends raw history rows, aggregate them; if already aggregated, use directly.
    if(Array.isArray(rows)){
      const agg={ wins:0, losses:0, totalRaces:rows.length, score:0 };
      const pts=[100,75,50,40,30,25,20,15,10,5];
      rows.forEach(r=>{
        const pos=Number(r.position||0);
        if(pos===1) agg.wins++; else if(pos>1) agg.losses++;
        agg.score+= pos>=1&&pos<=9 ? (pts[pos-1]||5) : (pos>0?5:0);
      });
      state.playerStats=agg;
    } else {
      state.playerStats=rows;
    }
    renderPlayerStats();
  }
  if(msg.action==='countdown'){ showCountdown(msg.value); }
  if(msg.action==='raceAnnounce'){
    const el=document.getElementById('race-announce');
    const list=document.getElementById('ra-list');
    if(!el||!list) return;
    if(!msg.show){ el.style.display='none'; return; }
    const medals=['1st','2nd','3rd']; const badgeCls=['ra-b1','ra-b2','ra-b3'];
    list.innerHTML='';
    (msg.racers||[]).forEach((r,i)=>{
      const row=document.createElement('div'); row.className='ra-row';
      row.innerHTML='<div class="ra-badge '+(badgeCls[i]||'')+'">'+(medals[i]||(i+1))+'</div><div class="ra-name">'+(r.name||'')+'</div>';
      list.appendChild(row);
    });
    el.style.display='block';
  }
  if(msg.action==='raceHUD'){
    const hud=document.getElementById('race-hud'); if(!hud) return;
    const ranking=document.getElementById('race-ranking');
    if(!msg.show){ hud.style.display='none'; if(ranking) ranking.style.display='none'; return; }
    hud.style.display='block';
    setTxt('rh-pos',  msg.position||'P1');
    setTxt('rh-lap',  msg.lap||'1/1');
    setTxt('rh-speed',String(msg.speed||0));
    setTxt('rh-speed-unit', msg.speedUnit||'MPH');
    setTxt('rh-cp',   msg.checkpts||'0/0');
    setTxt('rh-timer',msg.timer||'00:00');
    setTxt('rh-timer-big', msg.timerBig||'00:00.000');
    const rtBadge=document.getElementById('rh-type-badge');
    if(rtBadge && msg.raceType){
      const labels={circuit:'Circuit',sprint:'Sprint',timetrial:'Time Trial'};
      rtBadge.textContent = labels[msg.raceType] || msg.raceType;
    }
    const ttWrap=document.getElementById('rh-bestlap-wrap');
    if(ttWrap){
      if(msg.raceType==='timetrial' && msg.bestLap){ ttWrap.style.display='block'; setTxt('rh-bestlap-time', msg.bestLap); }
      else ttWrap.style.display='none';
    }
    if(ranking && msg.racers && Array.isArray(msg.racers)){
      ranking.style.display='block';
      const list=document.getElementById('rr-list');
      if(list){
        const top=msg.racers.slice(0,10);
        list.innerHTML='';
        top.forEach(r=>{
          const row=document.createElement('div'); row.className='rr-row'+(r.isMe?' rr-me':'');
          const pos=r.position; let bc='';
          if(pos===1) bc='rr-b1'; else if(pos===2) bc='rr-b2'; else if(pos===3) bc='rr-b3';
          row.innerHTML='<div class="rr-badge '+bc+'">'+pos+'</div><div class="rr-name">'+(r.name||'Unknown')+'</div><div class="rr-gap">'+(r.gap||'')+'</div>';
          list.appendChild(row);
        });
      }
    } else if(ranking && !msg.racers){ ranking.style.display='none'; }
  }
});

// LISTENERS
document.querySelectorAll('.nav-item').forEach(el=>el.addEventListener('click',()=>switchTab(el.dataset.tab)));
document.getElementById('close-btn').addEventListener('click',()=>nui('closeUI'));

document.getElementById('create-start').addEventListener('click',()=>nui('startCreateRoute',{
  name:document.getElementById('create-name').value, maxParticipants:document.getElementById('create-max').value,
  minLevel:document.getElementById('create-level').value, laps:document.getElementById('create-laps').value,
  raceType:'circuit', collision:document.getElementById('create-collision').checked,
  mountClass:'open', vehicleClass:'open'
}));
document.getElementById('add-checkpoint').addEventListener('click',()=>nui('addCheckpoint'));
document.getElementById('add-start').addEventListener('click',()=>nui('addStart'));
document.getElementById('save-race-ui').addEventListener('click',()=>nui('saveCreatedRace'));
document.getElementById('cancel-create-ui').addEventListener('click',()=>nui('cancelCreate'));
document.getElementById('refresh-saved-races').addEventListener('click',()=>nui('requestAdminRaces'));
document.getElementById('refresh-leaderboard').addEventListener('click',()=>nui('requestGlobalLeaderboard'));
document.getElementById('refresh-recent').addEventListener('click',()=>nui('requestRecentRaces'));
document.getElementById('race-detail-modal').addEventListener('click',e=>{ if(e.target===document.getElementById('race-detail-modal')) window.closeRaceDetailModal(); });

document.getElementById('lobby-cancel').addEventListener('click',window.closeLobbyModal);
document.getElementById('lobby-open').addEventListener('click',()=>{
  if(!state.lobbyPendingRace) return;
  nui('openLobby',{raceId:state.lobbyPendingRace.id, maxParticipants:Number(document.getElementById('lobby-max').value)||10, betAmount:Number(document.getElementById('lobby-bet').value)||0, laps:Number(document.getElementById('lobby-laps').value)||1, raceType:'circuit', collision:document.getElementById('lobby-collision').checked});
  window.closeLobbyModal();
});
document.getElementById('start-cancel').addEventListener('click',closeStartModal);
document.getElementById('start-confirm').addEventListener('click',()=>{
  if(!state.lobby.raceData) return;
  nui('startRace',{raceId:state.lobby.raceData.id,betAmount:state.lobby.betAmount||0}); closeStartModal();
});
document.querySelectorAll('.modal').forEach(modal=>modal.addEventListener('click',e=>{ if(e.target===modal){ modal.classList.add('hidden'); if(modal.id==='lobby-modal') state.lobbyPendingRace=null; } }));
document.addEventListener('keyup',e=>{ if(e.key==='Escape'){ if(!lobbyModal.classList.contains('hidden')){ window.closeLobbyModal(); return; } if(!startModal.classList.contains('hidden')){ closeStartModal(); return; } nui('closeUI'); } });

// RECENT
function fmtTime(secs){ if(!secs||secs<=0) return 'DNF'; const m=Math.floor(secs/60), s=secs%60; return `${m}:${String(s).padStart(2,'0')}`; }

function renderRecentRaces(){
  const el=document.getElementById('recent-races-list'); if(!el) return;
  const races=state.recentRaces||[];
  if(!races.length){ el.innerHTML='<div class="empty-blk" style="grid-column:1/-1"><div class="empty-txt">No completed races yet.</div></div>'; return; }
  el.innerHTML=races.map((r,ri)=>{
    const winner=r.top10&&r.top10[0];
    const pot=Number(r.total_pot||0);
    const bestTime=fmtTime(Number(r.best_time||0));
    const potHtml=pot>0?'<span class="rc-tag" style="color:#7a6028">'+fmt$(pot)+'</span>':'';
    const winnerHtml=winner?'<div class="rc-winner"><span class="rc-winner-name">'+(winner.player_name||'?')+'</span><span class="rc-winner-time">'+fmtTime(winner.finish_time)+'</span></div>':'';
    return '<div class="rc-card" onclick="openRaceDetailModal('+ri+')">'
      +'<div class="rc-name">'+(r.name||'Unknown Race')+'</div>'
      +'<div class="rc-meta"><span class="rc-tag">LAPS '+(r.laps||1)+'</span>'+potHtml+'</div>'
      +'<div class="rc-stats"><div class="rc-stat"><div class="rc-stat-val">'+(r.total_finishers||0)+'</div><div class="rc-stat-lbl">FINISHERS</div></div>'
      +'<div class="rc-stat"><div class="rc-stat-val" style="color:#7a6028">'+bestTime+'</div><div class="rc-stat-lbl">BEST TIME</div></div></div>'
      +winnerHtml+'<div class="rc-view-btn">VIEW DETAILS →</div></div>';
  }).join('');
}

function openRaceDetailModal(idx){
  const r=state.recentRaces[idx]; if(!r) return;
  document.getElementById('rdm-title').textContent=r.name||'Race';
  document.getElementById('rdm-laps').textContent='LAPS '+(r.laps||1);
  const pot=Number(r.total_pot||0);
  document.getElementById('rdm-pot').textContent=pot>0?fmt$(pot)+' POT':'';
  const top10El=document.getElementById('rdm-top10');
  const top10=r.top10||[];
  if(!top10.length){ top10El.innerHTML='<div class="muted-t">No results yet.</div>'; }
  else {
    top10El.innerHTML=top10.map((p,i)=>{
      const pos=i+1, cls=pos===1?'rdm-top1':'';
      const prize=Number(p.prize||0);
      const prizeHtml=prize>0?'<div class="rdm-prize">+'+fmt$(prize)+'</div>':'';
      return '<div class="rdm-row '+cls+'"><div class="rdm-pos">'+pos+'</div><div class="rdm-name">'+(p.player_name||'?')+'</div>'+prizeHtml+'<div class="rdm-time">'+fmtTime(p.finish_time)+'</div></div>';
    }).join('');
  }
  const partEl=document.getElementById('rdm-participants');
  document.getElementById('rdm-count').textContent=top10.length;
  if(!top10.length){ partEl.innerHTML='<div class="muted-t">No data.</div>'; }
  else {
    partEl.innerHTML=top10.map((p,i)=>`<div class="rdm-row"><div class="rdm-pos">${i+1}</div><div class="rdm-name">${p.player_name||'?'}</div><div class="rdm-time">${fmtTime(p.finish_time)}</div></div>`).join('');
  }
  document.getElementById('race-detail-modal').classList.remove('hidden');
}
window.openRaceDetailModal = openRaceDetailModal;
window.closeRaceDetailModal=()=>document.getElementById('race-detail-modal').classList.add('hidden');
