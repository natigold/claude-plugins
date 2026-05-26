# meeting-notes

Claude Code plugin that summarizes meeting transcripts or raw notes into structured professional meeting notes.

## Features

- Handles both audio transcripts (speaker-segmented JSON) and plain text notes
- Produces structured output: Context, Notes, Follow-ups
- Translates non-English input to English output
- Identifies action items with owners
- Cleans up filler words and repetition from transcripts

## Installation

### 1. Add the marketplace (one-time)

```
/plugin marketplace add natigold/claude-plugins
```

### 2. Install the plugin

```
/plugin install meeting-notes@nati-plugins
```

## Usage

```
/meeting-notes:meeting-notes <paste transcript or notes>
```

The plugin accepts:
- Raw meeting notes (bullet points, sentences, etc.)
- JSON transcript arrays from transcription services (speaker-segmented)
- Mixed input (transcript + additional handwritten notes)

## Output Structure

1. **Context** - Meeting purpose, participants, date/time, framework
2. **Notes** - Key discussion points, decisions, important details (numbered)
3. **Follow-ups** - Action items formatted as `@Owner - [Verb-first task]`
