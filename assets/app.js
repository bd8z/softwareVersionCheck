// version_data.js (window.versionMatrix) を使用して Host 行 / ソフト列マトリクス表示 (F5相当のページリロード対応)
(function(){
  const TARGET_SOFTWARE = ['Git','Matlab','Prometheus','gitlab-runner'];
  const btn = document.getElementById('reloadBtn');
  const tbody = document.querySelector('#logTable tbody');
  const hostFilterInput = document.getElementById('hostFilter');
  const clearBtn = document.getElementById('clearFilterBtn');
  const pageLoadEl = document.getElementById('pageLoadTime');

  const COLOR_POOL = ['#2d3f50','#374754','#3d4e59','#42545f','#485c66','#4e636d', '#566d77','#5d7580','#647d89','#6a8591','#728d9a','#7995a2'];
  const versionColorMap = new Map();
  let colorIndex = 0;

  function pad(n){ return n.toString().padStart(2,'0'); }
  function fmt(d){ return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }
  function classify(result){ if(!result) return 'blank'; if(/Not installed|failed/i.test(result)) return 'fail'; if(/Update|warning/i.test(result)) return 'warn'; return 'ok'; }
  function dedupeLatest(records){ const map = new Map(); records.forEach(r => map.set(r.host, r)); return Array.from(map.values()); }
  function shortText(val){ return !val ? '' : val.split(/\s+/).slice(0,6).join(' '); }
  function getVersionColor(raw){ if(!raw) return null; const norm = raw.trim(); if(!versionColorMap.has(norm)){ const c = COLOR_POOL[colorIndex % COLOR_POOL.length]; versionColorMap.set(norm,c); colorIndex++; } return versionColorMap.get(norm); }
  function parseTimestamp(ts){ if(!ts) return null; const m = ts.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/); if(!m) return null; return new Date(+m[1], +m[2]-1, +m[3], +m[4], +m[5], +m[6]); }
  function diffDays(fromDate, toDate){ if(!fromDate||!toDate) return ''; return ((toDate - fromDate)/86400000).toFixed(1); }
  function matchHost(host, filter){ if(!filter) return true; try { if(filter.startsWith('/') && filter.endsWith('/') && filter.length>2){ const pattern = filter.slice(1,-1); return new RegExp(pattern,'i').test(host);} if(/[.*+?^${}()|\\[\\]\\]/.test(filter)){ return new RegExp(filter,'i').test(host);} return host.toLowerCase().includes(filter.toLowerCase()); } catch(e){ return host.toLowerCase().includes(filter.toLowerCase()); } }
  function getFilteredRows(){ const vm = (window.versionMatrix || []); const rows = dedupeLatest(vm); const filter = hostFilterInput.value.trim(); return rows.filter(r=>matchHost(r.host, filter)); }
  function render(){ const vm = (window.versionMatrix||[]); if(vm.length===0){ tbody.innerHTML='<tr><td colspan="6" class="blank" style="text-align:left">データがありません。PowerShellを実行してください。</td></tr>'; return; } const rows = getFilteredRows(); rows.sort((a,b)=>a.host.localeCompare(b.host,'en',{numeric:true})); tbody.innerHTML=''; TARGET_SOFTWARE.forEach(sw=>{ const versions=[]; rows.forEach(r=>{ const v=r[sw]; if(v && !/Not installed|failed/i.test(v) && !versions.includes(v)) versions.push(v); }); versions.sort(); versions.forEach(v=>getVersionColor(v)); }); const now = new Date(); if(rows.length===0){ tbody.innerHTML='<tr><td colspan="6" class="blank" style="text-align:left">フィルタに一致するホストはありません。</td></tr>'; return; } rows.forEach(rec=>{ const tr=document.createElement('tr'); const hostTd=document.createElement('th'); hostTd.textContent=rec.host; hostTd.style.textAlign='left'; tr.appendChild(hostTd); const tsTd=document.createElement('td'); if(rec.timestamp){ const age=diffDays(parseTimestamp(rec.timestamp), now); tsTd.textContent=`${rec.timestamp}  (${age}d)`; } else { tsTd.textContent=''; } tr.appendChild(tsTd); TARGET_SOFTWARE.forEach(sw=>{ const td=document.createElement('td'); const val=rec[sw]; const statusClass=classify(val); td.className=statusClass+' ver-cell'; if(val){ const c=getVersionColor(val); if(c && statusClass==='ok'){ td.style.background=c; td.style.color='#d4d9e1'; td.style.borderColor='#2e3a46'; } td.textContent=shortText(val); if(val.length>60){ const sm=document.createElement('small'); sm.textContent=val.slice(0,60)+'…'; td.appendChild(sm);} } tr.appendChild(td); }); tbody.appendChild(tr); }); }
  function init(){ pageLoadEl.textContent = fmt(new Date()); render(); }
  // F5 相当: location.reload(true) は非推奨なので cache-busting を付与して再遷移
  function fullPageReload(){ try { const url = new URL(window.location.href); url.searchParams.set('_', Date.now()); window.location.replace(url.toString()); } catch(e){ window.location.reload(); } }
  btn.addEventListener('click', fullPageReload);
  hostFilterInput.addEventListener('input', render);
  clearBtn.addEventListener('click', ()=>{ hostFilterInput.value=''; render(); });
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
