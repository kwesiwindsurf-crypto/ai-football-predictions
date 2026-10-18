# ⚽ AI Football Predictions & Live Match Analytics

Automated real-time AI football predictions, match probabilities, live scores, accuracy tracker, and betting analytics powered by deep match data from ESPN and Cloudflare Edge.

---

## 🌐 Live Web Dashboard

You can access the live prediction dashboard directly in your browser:
👉 https://kwesiwindsurf-crypto.github.io/ai-football-predictions

### 📊 Features on the Web Dashboard:
* 🎯 **Dynamic Win Rate & Scorecard**: Real-time accuracy percentage, wins, losses, and draw-covered bets calculated automatically as matches finish.
* 🏆 **Global Competitions**: UEFA Champions League, UEFA Europa League, UEFA Conference League, English Premier League, Spanish La Liga, Italian Serie A, German Bundesliga, French Ligue 1, and global tournaments.
* 🤖 **AI Match Probability Distribution**: 1X2 win probabilities (`Home %`, `Draw %`, `Away %`) and tailored betting recommendations (e.g. *Over 1.5 Goals*, *Draw No Bet*, *Direct Win*).
* ↗️ **Direct Match Site Links**: Tap **"Match Overview ↗"** on any card to view official match statistics, head-to-head records, and lineups on ESPN.
* 🔍 **Live Search & Filter**: Search by team name or filter by date (*Today*, *Yesterday*, *Tomorrow*) and match status (*Live*, *Final*, *Upcoming*).

---

## 📡 Live Data Sources & Architecture

The system uses a smart **dual-stream architecture** so the mobile app stays lightning fast while the web dashboard accumulates historical records:

```
                            ┌─────────────────────────────────┐
                            │  GitHub Actions Scraper (.mjs)  │
                            └────────────────┬────────────────┘
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     ▼                                               ▼
       ┌───────────────────────────┐                   ┌───────────────────────────┐
       │     FLUTTER APP STREAM    │                   │   WEB DASHBOARD STREAM    │
       │   (Rolling 7-Day Window)  │                   │  (Permanent History ++)   │
       ├───────────────────────────┤                   ├───────────────────────────┤
       │ • Endpoint: KV matchesData│                   │ • Endpoint: KV + Git JSON │
       │ • Yesterday + Today + 6d  │                   │ • docs/data/history.json  │
       │ • ~350 matches max        │                   │ • All past weeks & months │
       │ • Ultra fast on mobile    │                   │ • Lifetime win-rate stats │
       └───────────────────────────┘                   └───────────────────────────┘
```

### 1. Live Edge API Endpoint (Cloudflare Worker)
* **URL**: `https://ai-football-bot.xantechs00.workers.dev`
* **Response format**: JSON
* **CORS**: Enabled (`*`)
* **Contents**:
  * `matchesData.matches`: Current rolling 7-day fixtures for the Flutter app.
  * `historicalMatches`: Accumulated permanent history of completed matches.

### 2. Static Git Archive (GitHub Pages)
* **File path**: `docs/data/history.json`
* **URL**: `https://kwesiwindsurf-crypto.github.io/ai-football-predictions/data/history.json`
* **Purpose**: Auto-commits completed matches after full time so match history grows permanently on GitHub as days progress (`days ++`).

---

## ⚙️ How to Turn On the Website on GitHub (1-Time Setup)

1. Push this repository to GitHub:
   ```bash
   git add .
   git commit -m "feat: complete website dashboard, UCL support, and history archive"
   git push origin main
   ```
2. In your GitHub repository:
   * Go to **Settings** (top tab) ➔ **Pages** (in the left sidebar).
   * Under **Build and deployment**:
     * **Source**: `Deploy from a branch`
     * **Branch**: `main`
     * **Folder**: `/docs`
   * Click **Save**.
3. Within 1–2 minutes, your website will be live at:
   **`https://kwesiwindsurf-crypto.github.io/ai-football-predictions/`**

---

## 🤖 GitHub Actions Workflow

* Runs automatically on schedule (`.github/workflows/scrape.yml`):
  * **Every 20 mins** during match hours (`10:00 - 23:00 UTC`).
  * **Hourly** overnight (`00:00 - 09:00 UTC`).
  * **On every `git push`** to the `bot/` directory.
* Automatically fetches fixtures, calculates predictions, syncs Cloudflare KV, and archives completed games to `docs/data/history.json`.
