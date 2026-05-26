---
name: spend-monitor
description: Monitor AWS spend - MoM, YoY, trailing period analysis with threshold alerting
user_invocable: true
---

# /spend-monitor

Analyze consolidated AWS spend from your payer account. Detects MoM, YoY, and trailing period changes per service, flags threshold breaches, and optionally sends Slack alerts.

## Usage

```
/spend-monitor                          # monthly mode, consolidated org spend
/spend-monitor --daily                  # daily pulse check
/spend-monitor --account 123456789012   # scope to a specific linked account
/spend-monitor --mom --yoy-month        # monthly, specific dimensions only
/spend-monitor --trailing-months 6      # override trailing window (default: 3)
/spend-monitor --slack                  # send Slack/notification for breaches
/spend-monitor --marketplace            # include marketplace spend (overrides config default)
/spend-monitor --no-marketplace         # exclude marketplace spend (overrides config default)
/spend-monitor --format html            # export as HTML file to ~/Downloads
/spend-monitor --format html ~/Reports  # export HTML to custom path
```

## Instructions

When this skill is invoked:

1. **Read config**: Read `spend-config.json` from `~/.claude/plugins/data/spend-monitor-nati-plugins/`. If the file doesn't exist, copy `spend-config.example.json` from this skill's directory to that location first, then read it.

2. **Parse arguments**:
   - **Mode**: If `--daily` is present, run in daily mode. Otherwise, run in monthly mode (default).
   - **Account filter**: If `--account <id>` is present, scope queries to that linked account. Otherwise, query consolidated org spend (no LINKED_ACCOUNT filter).
   - **Dimension overrides** (monthly only): If `--mom`, `--yoy-month`, `--yoy-annual`, or `--trailing` flags are present, enable only those dimensions (plus anomalies and MTD which are always on unless config disables them). If no dimension flags, use all enabled dimensions from config.
   - **Trailing override** (monthly only): If `--trailing-months N` is provided, override `dimensions.trailing.months` for this run.
   - **Slack flag**: If `--slack` is present, send a Slack notification after the report.
   - **Marketplace override**: If `--marketplace` is present, include marketplace spend (sets `exclude_marketplace: false`). If `--no-marketplace` is present, exclude marketplace spend (sets `exclude_marketplace: true`). If neither flag, use config value `exclude_marketplace` (default: `true`).
   - **Format**: If `--format html` is present, pass `FORMAT: html` in the agent prompt (under Settings). The agent will output a complete HTML document instead of markdown. After the agent returns, write its HTML output to `~/Downloads/spend-report-{date}.html`. If a path follows the format flag (e.g., `--format html ~/Reports`), use that directory instead. Default format is `markdown` (no file written, output displayed inline).

3. **Compute date windows**: Based on today's date, compute all date ranges. The skill centralizes all date math — the agent receives pre-computed dates only.

   ```
   today               = (current date)
   first_of_this_month = first day of current month
   last_full_month     = first day of prior month → first_of_this_month
   prev_full_month     = first day of 2 months ago → first day of prior month
   same_month_ly       = first day of same month last year → first day of next month last year
   ytd_current         = Jan 1 current year → first_of_this_month
   ytd_prior           = Jan 1 prior year → same month/day prior year as first_of_this_month
   trailing_current    = first_of_this_month minus N months → first_of_this_month
   trailing_prior      = trailing_current shifted back 12 months
   three_months_ago    = first_of_this_month minus 3 months (for last 3 monthly totals)
   twelve_months_ago   = first_of_this_month minus 12 months (for trailing 12M total)
   fetch_start         = first_of_this_month minus 24 months
   anomaly_start       = today minus 90 days
   tomorrow            = today + 1 day (for MTD end_date, since end_date is exclusive)
   ```

   Detect if trailing window dates are identical to YTD dates and pass a `trailing_overlaps_ytd: true` hint so the agent can skip the duplicate.

   **Daily mode additional date windows:**
   ```
   yesterday           = today minus 1 day
   seven_days_ago      = today minus 7 days
   daily_start         = today minus 14 days (2 weeks of daily data)
   anomaly_start_daily = today minus 7 days
   days_elapsed        = today's day of month minus 1 (e.g., Apr 16 → 15 days elapsed)
   days_in_month       = total days in current month (e.g., 30 for April)
   ```

4. **Invoke a single spend-monitor agent**: Use `subagent_type: "spend-monitor:spend-monitor"`.

   **Monthly mode prompt template:**

   ```
   Analyze AWS spend.

   ## Scope
   SCOPE: {consolidated | account}
   ACCOUNT_ID: {12_digit_id or "all"}

   ## Date Windows
   FETCH_START: {fetch_start}
   FIRST_OF_CURRENT_MONTH: {first_of_this_month}
   TOMORROW: {tomorrow}
   CUR_MONTH_START: {last_full_month start}
   CUR_MONTH_LABEL: {e.g., "Mar 2026"}
   PREV_MONTH_START: {prev_full_month start}
   PREV_MONTH_LABEL: {e.g., "Feb 2026"}
   SAME_MONTH_LY_START: {same_month_ly start}
   SAME_MONTH_LY_LABEL: {e.g., "Mar 2025"}
   YTD_CURRENT_START: {ytd_current start}
   YTD_CURRENT_END: {ytd_current end}
   YTD_CURRENT_LABEL: {e.g., "Jan-Mar 2026"}
   YTD_PRIOR_START: {ytd_prior start}
   YTD_PRIOR_END: {ytd_prior end}
   YTD_PRIOR_LABEL: {e.g., "Jan-Mar 2025"}
   TRAILING_CURRENT_START: {trailing_current start}
   TRAILING_CURRENT_END: {trailing_current end}
   TRAILING_CURRENT_LABEL: {e.g., "Jan-Mar 2026"}
   TRAILING_PRIOR_START: {trailing_prior start}
   TRAILING_PRIOR_END: {trailing_prior end}
   TRAILING_PRIOR_LABEL: {e.g., "Jan-Mar 2025"}
   TRAILING_OVERLAPS_YTD: {true/false}
   THREE_MONTHS_AGO: {three_months_ago}
   TWELVE_MONTHS_AGO: {twelve_months_ago}
   M1_LABEL: {e.g., "Jan 2026"}
   M2_LABEL: {e.g., "Feb 2026"}
   M3_LABEL: {e.g., "Mar 2026"}
   ANOMALY_START: {anomaly_start}
   ANOMALY_END: {today}

   ## Enabled Dimensions
   {list of: mom, yoy_month, yoy_annual, trailing, anomalies, mtd_snapshot}

   ## Thresholds
   MOM_PCT: {mom_pct}
   YOY_MONTH_PCT: {yoy_month_pct}
   YOY_ANNUAL_PCT: {yoy_annual_pct}
   TRAILING_PCT: {trailing_pct}
   SERVICE_PCT: {service_pct}
   MIN_SERVICE_SPEND_USD: {min_service_spend_usd}
   MIN_DELTA_USD: {min_delta_usd}
   MIN_TOTAL_SPEND_USD: {min_total_spend_usd}

   ## Settings
   TRAILING_MONTHS: {N}
   EXCLUDE_CREDITS_REFUNDS: {true/false}
   EXCLUDE_MARKETPLACE: {true/false}
   ```

   **Daily mode prompt template** (use this instead of the monthly template when `--daily`):

   ```
   Analyze AWS spend.

   ## Mode
   MODE: daily

   ## Scope
   SCOPE: {consolidated | account}
   ACCOUNT_ID: {12_digit_id or "all"}

   ## Date Windows
   TODAY: {today}
   TOMORROW: {tomorrow}
   YESTERDAY: {yesterday}
   SEVEN_DAYS_AGO: {seven_days_ago}
   DAILY_START: {daily_start}
   FIRST_OF_CURRENT_MONTH: {first_of_this_month}
   PRIOR_MONTH_LABEL: {e.g., "Mar 2026"}
   PRIOR_MONTH_START: {first day of prior month}
   DAYS_ELAPSED: {days_elapsed}
   DAYS_IN_MONTH: {days_in_month}
   ANOMALY_START_DAILY: {anomaly_start_daily}

   ## Thresholds
   MOM_PCT: {mom_pct}
   SERVICE_PCT: {service_pct}
   MIN_SERVICE_SPEND_USD: {min_service_spend_usd}
   MIN_DELTA_USD: {min_delta_usd}

   ## Settings
   EXCLUDE_CREDITS_REFUNDS: {true/false}
   EXCLUDE_MARKETPLACE: {true/false}
   ```

5. **Present the agent's report directly**: The agent returns the full analysis. Present it to the user as-is.

6. **Slack notification** (if `--slack` was passed):
   Use Slack channel from `${user_config.slack_channel}`. Read `notify_on` from `spend-config.json`:
   - `"breaches_only"`: Only send if there's at least one flag (default)
   - `"always"`: Send on every run
   - `"never"`: Skip Slack

   **Silent unless flagged:**
   If there are no flags (no spikes, no projected breaches, no material anomalies) → **don't send anything**. No "all clear" noise.

   **Daily mode alert** (only when flagged):
   ```
   :warning: *AWS Daily Spend Alert* ({today})

   • MTD pace ${projected} → projected +{pct}% MoM (breach threshold: {mom_pct}%)
   • Top drivers: {top_drivers from DAILY_SUMMARY}
   • {optional: service spiked +{pct}% yesterday, cost anomaly details}
   ```

   **Monthly mode alert** (only when flagged):
   ```
   :warning: *AWS Monthly Spend Alert* ({cur_month_label})

   • MoM: +{pct}% (threshold: {mom_pct}%)
   • Top driver: {service} +${delta} (+{pct}%)
   ```

   Rules:
   - Show spikes as: service name, yesterday vs 7d avg, % change
   - Show projected breaches as: projected total, projected MoM %
   - Show anomalies as: service, TOTAL cumulative impact $, date range (never per-day)
   - No tables, no MTD breakdowns when healthy.
   - Use Slack mrkdwn formatting: `*bold*`, `_italic_`, `:warning:` emoji.

   **Sending via Slack MCP:**
   Use `mcp__slack-mcp__post_message` with the channel `${user_config.slack_channel}`:
   ```
   channel: "${user_config.slack_channel}"
   text: "{message}"
   ```
   If the channel is empty, note "Slack channel not configured — reconfigure the plugin to set it" and skip.
   The channel can be a DM channel ID (e.g., `D030G78377G`) or a regular channel (e.g., `#spend-alerts`).

## Scheduling

Recommended cadence:

| Cadence | Command | What it checks |
|---------|---------|----------------|
| **Daily** | `/spend-monitor --daily --slack` | Spikes, MTD pace, projected MoM breach, anomalies |
| **Monthly** | `/spend-monitor --slack` | Full MoM/YoY/trailing analysis (run on 2nd of each month) |

To set up recurring monitoring:

- **Claude Code cron (7-day limit)**:
  ```
  CronCreate: cron: "17 8 * * *", durable: true, prompt: "/spend-monitor --daily --slack"
  ```
  Note: Durable cron jobs auto-expire after 7 days. Re-create or use persistent option.

- **Persistent (external cron)**:
  ```bash
  # Daily pulse at 8:17am
  17 8 * * * claude --print "/spend-monitor --daily --slack" >> ~/spend-monitor-daily.log 2>&1
  # Monthly full report on the 2nd at 8:17am
  17 8 2 * * claude --print "/spend-monitor --slack" >> ~/spend-monitor-monthly.log 2>&1
  ```
