import fs from 'fs';

async function testLoad() {
  const cf = await fetch('https://ai-football-bot.xantechs00.workers.dev');
  const json = await cf.json();
  const rollingMatches = json.matchesData?.matches || json.matches || [];
  const historicalMatches = Array.isArray(json.historicalMatches) ? json.historicalMatches : [];
  
  const historyPath = 'docs/data/history.json';
  let staticHistory = [];
  if (fs.existsSync(historyPath)) {
    staticHistory = JSON.parse(fs.readFileSync(historyPath, 'utf8'));
  }
  
  console.log('staticHistory count:', staticHistory.length);
  console.log('rollingMatches count:', rollingMatches.length);
  
  const matchMap = new Map();
  [...staticHistory, ...historicalMatches].forEach(m => {
    if (m && m.id) matchMap.set(m.id, m);
  });
  rollingMatches.forEach(m => {
    if (m && m.id) matchMap.set(m.id, m);
  });
  
  const allMatches = Array.from(matchMap.values());
  console.log('Total allMatches:', allMatches.length);
  
  const toLocalDateStr = (d) => {
    const date = new Date(d);
    if (isNaN(date)) return '';
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  const now = new Date();
  const todayIso = toLocalDateStr(now);
  console.log('now:', now.toISOString(), 'local:', now.toString());
  console.log('todayIso:', todayIso);
  
  const todayMatches = allMatches.filter(m => toLocalDateStr(m.date) === todayIso);
  console.log('todayMatches with toLocalDateStr:', todayMatches.length);
  
  const dateCounts = {};
  allMatches.forEach(m => {
    const d = toLocalDateStr(m.date);
    dateCounts[d] = (dateCounts[d] || 0) + 1;
  });
  console.log('\nDate counts around today:');
  Object.keys(dateCounts).sort().slice(-15).forEach(k => console.log(k, ':', dateCounts[k]));
}
testLoad();
