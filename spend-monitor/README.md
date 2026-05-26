# spend-monitor

AWS spend monitoring plugin for Claude Code. Analyzes consolidated org spend with MoM, YoY, and trailing period comparisons. Flags threshold breaches, surfaces anomalies, and optionally sends Slack alerts.

## Features

- Monthly full analysis: MoM, YoY same-month, YoY annual, trailing N-month comparisons
- Daily pulse check: MTD pace, projected MoM breach, daily spikes, recent anomalies
- GenAI Insight: dedicated section for Bedrock, marketplace AI models, and AI service spend
- HTML report output (dark theme, card-based layout)
- Slack notifications on threshold breaches
- Consolidated org-wide or single-account scoping

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [uv](https://docs.astral.sh/uv/getting-started/installation/) installed (`brew install uv` on macOS)
- AWS credentials configured with Cost Explorer access (`ce:GetCostAndUsage`, `ce:GetAnomalies`)

## Installation

### 1. Add the marketplace (one-time)

```
/plugin marketplace add natigold/claude-plugins
```

### 2. Install the plugin

```
/plugin install spend-monitor@nati-plugins
```

### 3. Configure

The plugin prompts for AWS profile, region, and Slack channel at install time.

### 4. Configure thresholds and Slack

On first run, the plugin automatically creates a config file at `~/.claude/plugins/data/spend-monitor-nati-plugins/spend-config.json` from the bundled template. Edit that file to set your thresholds, Slack channel, and preferences. This file persists across plugin updates.

## Usage

From within Claude Code:

```
/spend-monitor:spend-monitor                          # monthly, consolidated
/spend-monitor:spend-monitor --daily                  # daily pulse check
/spend-monitor:spend-monitor --account 123456789012   # scope to one account
/spend-monitor:spend-monitor --format html            # HTML report to ~/Downloads
/spend-monitor:spend-monitor --format html ~/Reports  # HTML to custom path
/spend-monitor:spend-monitor --slack                  # send Slack alert if breached
/spend-monitor:spend-monitor --marketplace            # include marketplace spend
/spend-monitor:spend-monitor --mom --yoy-month        # specific dimensions only
```

## Configuration

`spend-config.json` fields:

| Field | Description | Default |
|-------|-------------|---------|
| `exclude_credits_refunds` | Exclude Credit/Refund record types | `true` |
| `exclude_marketplace` | Exclude non-AI marketplace spend | `true` |
| `thresholds.mom_pct` | MoM breach threshold (%) | `15` |
| `thresholds.yoy_month_pct` | YoY same-month breach threshold (%) | `25` |
| `thresholds.yoy_annual_pct` | YoY annual breach threshold (%) | `25` |
| `thresholds.trailing_pct` | Trailing period breach threshold (%) | `25` |
| `thresholds.service_pct` | Per-service alert threshold (%) | `30` |
| `thresholds.min_service_spend_usd` | Minimum spend to flag a service ($) | `50` |
| `thresholds.min_delta_usd` | Minimum dollar change to flag ($) | `1000` |
| `dimensions.trailing.months` | Trailing comparison window | `3` |
| `slack.notify_on` | When to notify: `breaches_only`, `always`, `never` | `"breaches_only"` |

The Slack channel is configured via plugin settings (prompted at install time), not in this file.

## Architecture

```
spend-monitor/
  .claude-plugin/plugin.json   # Plugin manifest (references .mcp.json)
  .mcp.json                    # MCP server config (billing-mcp via uvx)
  agents/spend-monitor.md      # Agent: 2-round fetch-then-SQL workflow
  skills/spend-monitor/
    SKILL.md                   # Skill: orchestrates agent, computes dates
    spend-config.json          # User config (thresholds, slack, etc.)
    spend-config.example.json  # Template config
```

The plugin uses the public [awslabs.billing-cost-management-mcp-server](https://awslabs.github.io/mcp/servers/billing-cost-management-mcp-server) which provides:
- `cost-explorer` - Cost Explorer API (GetCostAndUsage, GetCostForecast, etc.)
- `cost-anomaly` - Cost anomaly detection
- `session-sql` - SQL queries against fetched data (SQLite session)
