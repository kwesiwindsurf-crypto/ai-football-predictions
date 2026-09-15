const EXCLUDED_LEAGUE_KEYWORDS = [
  'women', 'woman', 'femenino', 'feminine', 'frauen', 'dames',
  'femmes', 'nwsl', 'wsl', 'nwsl', 'u17', 'u19', 'u20', 'u21', 'u23',
  'youth', 'reserve', 'friendlies', 'international friendly',
  'ncaa', 'college'
];

function isExcludedLeague(leagueName) {
  const lower = (leagueName || '').toLowerCase();
  return EXCLUDED_LEAGUE_KEYWORDS.find(kw => lower.includes(kw));
}

console.log(isExcludedLeague('Espanyol at Rayo Vallecano'));
console.log(isExcludedLeague('Valencia at Alavés'));
console.log(isExcludedLeague('Real Madrid at Elche'));
