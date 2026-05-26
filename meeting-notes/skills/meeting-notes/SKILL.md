---
name: meeting-notes
description: Summarize meeting transcripts or notes into structured professional meeting notes
user_invocable: true
---

# /meeting-notes

Summarize a meeting transcript or raw notes into structured professional meeting notes.

## Usage

```
/meeting-notes <paste transcript or notes>
```

## Instructions

When this skill is invoked, delegate the work to the `meeting-notes` agent:

1. **Invoke the agent**: Use the Agent tool with:
   ```
   subagent_type: "meeting-notes:meeting-notes"
   ```
   Pass the full transcript or notes content provided by the user.

2. **Return results**: Display the agent's output exactly as returned. Do not reformat, restructure, add tables, or insert extra sections - the agent already follows its own formatting rules.
