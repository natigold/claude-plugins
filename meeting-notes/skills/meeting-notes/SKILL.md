---
name: meeting-notes
description: Summarize meeting transcripts or notes into structured professional meeting notes
user_invocable: true
---

# /meeting-notes

Summarize a meeting transcript or raw notes into structured professional meeting notes. Also accepts an audio/video recording, which it transcribes with Amazon Transcribe first.

## Usage

```
/meeting-notes <paste transcript or notes>
/meeting-notes <path to audio/video file>
```

## Instructions

The skill accepts direct instructions in one of two forms. Detect which one was given:

- **Audio/video file**: the input is (or references) a path ending in `.mp3`, `.mp4`, `.m4a`, `.wav`, `.flac`, `.ogg`, or `.webm`. Run the transcription pre-step below, then delegate.
- **Transcript or notes**: anything else (pasted text, an `audio_segments` JSON, plain notes). Skip straight to delegation.

### Pre-step: transcribe an audio/video file

Run this only when the input is an audio/video file. This step requires AWS credentials with Amazon Transcribe and S3 access.

Configuration comes from the plugin's userConfig (set at install time, reconfigurable via the plugin manager):
- `input_bucket` = `${user_config.input_bucket}`
- `input_prefix` = `${user_config.input_prefix}`
- `output_bucket` = `${user_config.output_bucket}` (blank = reuse input bucket)
- `output_prefix` = `${user_config.output_prefix}`
- `region` = `${user_config.region}`
- `profile` = `${user_config.profile}` (blank = use current credentials)

When reading any value above, treat both an empty string and a literal unsubstituted `${user_config...}` placeholder as **unset/blank** (a field left empty at install time renders as the raw placeholder).

1. **Determine the bucket** (free text, NOT AskUserQuestion):
   - If `input_bucket` is set, use it without asking.
   - If it is blank, ask the user in plain text for an existing S3 bucket name and wait for their reply. Do NOT create a bucket - the user supplies an existing one.

2. **Ask language and speakers** with the AskUserQuestion tool (these are multiple-choice):
   - **Language**: ask for the spoken language. Map the answer:
     - `he` -> `he-IL`
     - `en` -> `en-US`
     - `auto` -> automatic multi-language identification (use for mixed-language meetings)
   - **Speakers**: ask whether to enable speaker partitioning. Either a **number of speakers** (passed as `MaxSpeakerLabels`), or **none** (omit speaker labels).

3. **Run the script**: invoke `transcribe.sh` in this skill directory with the collected values, passing the prefixes/output bucket from config:
   ```
   ./transcribe.sh --file <path> --input-bucket <bucket> --language <he-IL|en-US|auto> \
                   --input-prefix <input_prefix> --output-prefix <output_prefix> \
                   --region <region> [--output-bucket <output_bucket>] [--profile <profile>] [--speakers N]
   ```
   Omit `--output-bucket` if `output_bucket` in config is blank (the script reuses the input bucket). Omit `--speakers` if the user chose none. Omit `--profile` if `profile` in config is blank (the script then uses current credentials).

4. **Capture the transcript**: the script prints `TRANSCRIPT_PATH=<path>` on its last line. That file is the transcript input for the agent. Do NOT parse, transform, or extract from it with Python, `jq`, or any other tool - hand the raw file to the agent and let it do the parsing.

### Delegate to the agent

1. **Invoke the agent**: Use the Agent tool with:
   ```
   subagent_type: "meeting-notes:meeting-notes"
   ```
   Provide the transcript or notes to the agent:
   - **Pasted text or notes**: pass the content directly in the prompt.
   - **Transcript from the pre-step**: give the agent the `TRANSCRIPT_PATH` and instruct it to read that file itself with the Read tool. Do not read or inline the contents yourself - transcripts can be large, and the agent handles parsing the `audio_segments` array.

   Note the agent's name or ID from the spawn result - the review pass needs it.

2. **Review the draft for tightness**: the first draft is not the deliverable. Check it against the "Tightness budgets" section of the agent definition (`agents/meeting-notes.md`), which holds the authoritative numbers, trim rules, and cut tests. Do not restate those rules here - read them from the agent file.

   Produce a list of SPECIFIC violations. Generic instructions like "make it tighter" do not work; the critique must name its targets. For each violation give the exact location and the exact fix:
   - subsections to delete, by number and label
   - items to merge, by number
   - items over the word cap, by number, with their measured word count
   - the measured MoM body word count against budget

   If the draft is within every budget, skip to step 4.

3. **Request the revision**: send the violation list to the same agent with SendMessage, addressed by the name or ID from step 1. The agent still holds the draft in its context - do not resend the transcript or notes, and do not ask the agent to re-read the transcript file.

   Run at most one review pass. If the revision still has violations, output it as-is - do not loop.

4. **Return results**: Output the final text verbatim. The agent already follows its own formatting rules. Do not reformat, restructure, add tables, or insert extra sections, and do not add a preamble, trailing commentary, verification caveats, transcript or file paths, or an offer of next steps. Never show the user the first draft or your violation list - only the final version. If you have a caveat worth raising, the review pass is where it belongs, not appended to the output.
