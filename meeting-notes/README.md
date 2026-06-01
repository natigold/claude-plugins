# meeting-notes

Claude Code plugin that summarizes meeting transcripts or raw notes into structured professional meeting notes. Optionally transcribes audio/video recordings with Amazon Transcribe first.

## Features

- Handles audio transcripts (speaker-segmented JSON), plain text notes, or audio/video files
- Transcribes audio/video recordings via Amazon Transcribe (optional, requires AWS)
- Produces structured output: Context, Notes, Follow-ups
- Translates non-English input to English output
- Identifies action items with owners
- Cleans up filler words and repetition from transcripts

## Prerequisites

- **Text/transcript input**: none - works out of the box.
- **Audio/video transcription** (optional path) additionally requires, on the machine running Claude Code:
  - `zsh` (the bundled `transcribe.sh` runs under zsh)
  - The AWS CLI (`aws`), configured with credentials that have Amazon Transcribe and S3 access
  - `jq` **or** `python3` (used to slim the transcript; `python3` ships with `uv`)

## Installation

### 1. Add the marketplace (one-time)

```
/plugin marketplace add natigold/claude-plugins
```

### 2. Install the plugin

```
/plugin install meeting-notes@nati-plugins
```

### 3. Configure transcription (optional)

The plugin prompts for transcription settings at install time. These only matter if you transcribe audio/video files - leave them blank for text-only use. Reconfigure anytime via the plugin manager.

| Setting | Description |
|---------|-------------|
| S3 Input Bucket | Existing S3 bucket for uploading the source recording (not auto-created) |
| S3 Input Prefix | Key prefix for uploaded recordings |
| S3 Output Bucket | S3 bucket for transcript output (blank = reuse input bucket) |
| S3 Output Prefix | Key prefix for transcript output |
| AWS Region | AWS region for Amazon Transcribe |
| AWS Profile | AWS profile name (blank = use current credentials) |

Transcription requires AWS credentials with Amazon Transcribe and S3 access. Text-only usage needs no AWS setup.

## Usage

```
/meeting-notes:meeting-notes <paste transcript or notes>
/meeting-notes:meeting-notes <path to audio/video file>
```

The plugin accepts:
- Raw meeting notes (bullet points, sentences, etc.)
- JSON transcript arrays from transcription services (speaker-segmented)
- Mixed input (transcript + additional handwritten notes)
- Audio/video files (`.mp3`, `.mp4`, `.m4a`, `.wav`, `.flac`, `.ogg`, `.webm`) - transcribed first

### Examples

Summarize pasted notes:
```
/meeting-notes:meeting-notes Synced with the platform team on the API migration.
Sarah: staging is ready, blocked on TLS certs from security. Mike to chase.
Decided to push prod cutover to Friday. Tom will add CloudWatch 5xx alarms.
```

Transcribe and summarize a recording (prompts for language and speaker count, then runs Amazon Transcribe):
```
/meeting-notes:meeting-notes ~/recordings/2026-06-01-standup.mp3
```

## Output Structure

1. **Context** - Meeting purpose, participants, date/time, framework
2. **Notes** - Key discussion points, decisions, important details (numbered)
3. **Follow-ups** - Action items formatted as `@Owner - [Verb-first task]`
