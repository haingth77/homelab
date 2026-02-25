---
name: daily-briefing
description: Compose a personalized daily briefing with real-time weather, Vikunja tasks, cluster health, and contextual lifestyle advice. Delivered to Discord as a morning digest.
metadata:
  {
    "openclaw":
      {
        "emoji": "🌅",
        "requires": { "anyBins": ["curl"] },
      },
  }
---

# Daily Briefing

Compose and deliver a rich, personalized daily briefing to Discord. This is NOT a boring task list — it's an AI-powered morning digest that combines real-time data with contextual advice.

## Philosophy

Traditional reminder apps dump a static checklist. This briefing is different:

- **Context-aware**: Weather conditions influence activity suggestions (e.g., "It's 34°C — hydrate extra during your workout" or "Rain expected — move your run indoors")
- **Time-aware**: Greeting and tone adapt to the time of day
- **Synthesized**: The agent reads multiple data sources, then composes a single coherent narrative — not separate blocks pasted together
- **Actionable**: Every piece of information connects to a suggestion or next step

## Data sources

Gather these in parallel before composing the briefing:

### 1. Weather (Open-Meteo — no API key)

```bash
curl -s "https://api.open-meteo.com/v1/forecast?latitude=10.82&longitude=106.63&current_weather=true&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,weathercode,uv_index_max,sunrise,sunset&hourly=temperature_2m,precipitation_probability,weathercode&timezone=Asia/Ho_Chi_Minh&forecast_days=1"
```

Location: Ho Chi Minh City (lat 10.82, lon 106.63, tz Asia/Ho_Chi_Minh).

#### WMO weather code reference

| Code | Meaning |
|---|---|
| 0 | Clear sky |
| 1-3 | Partly cloudy / Overcast |
| 45, 48 | Fog |
| 51-55 | Drizzle |
| 61-65 | Rain |
| 66-67 | Freezing rain |
| 71-75 | Snowfall |
| 80-82 | Rain showers |
| 95, 96, 99 | Thunderstorm |

### 2. Tasks due today (Vikunja)

The `/tasks/all` endpoint is unavailable in Vikunja v1.1.0. Fetch per-project instead:

```bash
VIKUNJA_URL="http://vikunja.vikunja.svc.cluster.local/api/v1"
AUTH="Authorization: Bearer $VIKUNJA_API_TOKEN"

# Get all project IDs
PROJECTS=$(curl -s -H "$AUTH" "$VIKUNJA_URL/projects" | jq -r '.[].id')

# For each project, get incomplete tasks
for PID in $PROJECTS; do
  curl -s -H "$AUTH" "$VIKUNJA_URL/projects/$PID/tasks" | jq '.[] | select(.done == false) | {id, title, due_date, priority, project_id}'
done
```

To find overdue tasks, filter results where `due_date` is before now and after `"0001"` (unset dates use year 0001).

### 3. Cluster health (quick pulse)

```bash
kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq -c | sort -rn
kubectl get applications -n argocd --no-headers -o custom-columns='NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status' | grep -v "Healthy.*Synced" || echo "all-healthy"
```

### 4. Date context

```bash
date -u '+%A, %B %d, %Y'
TZ=Asia/Ho_Chi_Minh date '+%H:%M %Z'
```

## Composing the briefing

After gathering all data, compose a SINGLE cohesive Discord message. Do NOT just paste raw data — synthesize it.

### Structure

Use the Discord webhook (`$DISCORD_WEBHOOK_VIKUNJA`) with embeds:

```
Embed 1: Daily Briefing header
- Title: "Good morning, Holden ☀️" (or appropriate greeting for time of day)
- Description: A 2-3 sentence opening that weaves together weather + day context
  Example: "It's a warm Tuesday in Saigon — 32°C with overcast skies and no rain expected.
  Perfect conditions for your morning routine. You have 3 tasks lined up today."

Embed 2: Weather snapshot
- Inline fields: Current temp, High/Low, Rain chance, UV Index, Sunrise/Sunset

Embed 3: Today's tasks (if any)
- Each task as a line with priority emoji: 🔴 urgent, 🟠 high, 🟡 medium, 🟢 low
- Overdue tasks highlighted at the top

Embed 4 (optional): Contextual tips
- Weather-driven: "UV index is 11 — wear sunscreen if going outside"
- Task-driven: "You have 2 overdue tasks — consider clearing those first"
- Cluster-driven: only if something is degraded
```

### Contextual advice patterns

| Condition | Advice |
|---|---|
| Temp > 35°C | "Extreme heat today — stay hydrated, avoid midday sun" |
| Temp > 32°C | "Hot day — consider an early morning workout before it heats up" |
| Rain > 60% chance | "Rain likely — have an indoor backup for outdoor plans" |
| UV > 8 | "Very high UV — sunscreen and shade recommended" |
| Thunderstorm codes (95-99) | "Thunderstorms expected — stay indoors during peak hours" |
| 0 overdue, 0 today tasks | "Clean slate today! Good time to plan ahead or tackle a backlog item" |
| Overdue tasks > 0 | "You have N overdue tasks — knocking those out first will feel great" |
| High priority task due | "Heads up: [task name] is high priority and due today" |
| Cluster degraded | "⚠ Cluster alert: [service] is [status] — may need attention" |
| All systems healthy | Omit cluster section entirely (no news is good news) |

### Color scheme

| Section | Color (decimal) | Meaning |
|---|---|---|
| Header | 5814783 | Blue — informational |
| Weather | 16760576 | Orange — warmth |
| Tasks (all good) | 3066993 | Green |
| Tasks (overdue) | 15158332 | Red — attention |
| Tips | 10070709 | Light purple — advisory |

### Sending the message

Post to the `#daily-briefing` channel via its dedicated webhook:

```bash
curl -s -X POST -H "Content-Type: application/json" "$DISCORD_WEBHOOK_VIKUNJA" \
  -d '<composed JSON with embeds array>'
```

Keep total embed content under 6000 characters (Discord limit).

For cluster alerts, use the `#alerts` channel webhook instead:

```bash
curl -s -X POST -H "Content-Type: application/json" "$DISCORD_WEBHOOK_ALERTS" \
  -d '<alert embed JSON>'
```

## Cron schedule

The briefing should run daily at **6:30 AM ICT (23:30 UTC previous day)**.

Cron expression: `30 23 * * *` (UTC) which is 6:30 AM ICT (UTC+7).

## Error handling

If any data source fails, compose the briefing with whatever data IS available. Never skip the entire briefing because one API timed out. Mention the gap: "Weather data unavailable — check wttr.in manually."
