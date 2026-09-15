const fs = require('fs');

async function test() {
  const content = fs.readFileSync('matches_month_predictions.csv', 'utf8');
  const lines = content.split('\n').filter(l => l.trim() !== '');
  const matches = [];
  
  for (let i = 1; i < lines.length; i++) {
    const row = [];
    let cur = '';
    let inQuotes = false;
    for (const char of lines[i]) {
      if (char === '"') inQuotes = !inQuotes;
      else if (char === ',' && !inQuotes) { row.push(cur); cur = ''; }
      else cur += char;
    }
    row.push(cur);
    
    if (row.length < 14) {
      console.log('Short row at line ' + i + ': ' + row.length);
      continue;
    }
    
    try {
        matches.push({
          date: row[0],
          kickoff: row[1],
          league: row[2].replace(/^"|"$/g, '').trim(),
          homeName: row[3].replace(/^"|"$/g, '').trim(),
          awayName: row[4].replace(/^"|"$/g, '').trim(),
          homeScore: row[5],
          awayScore: row[6],
          pred: {
            rec: row[8].replace(/^"|"$/g, '').trim(),
            strategy: row[9].replace(/^"|"$/g, '').trim()
          },
          correct: row[13].replace(/^"|"$/g, '').trim(),
          status: 'FT' // CSV only has finished matches
        });
    } catch(e) {
        console.error('Error at line ' + i, e.message);
        console.log(row);
        break;
    }
  }
  console.log('Parsed matches:', matches.length);
}
test();
