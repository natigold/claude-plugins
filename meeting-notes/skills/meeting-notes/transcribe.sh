#!/bin/zsh
# transcribe.sh - Upload an audio/video file to S3, run Amazon Transcribe,
# and download the resulting transcript JSON locally.
#
# This script is non-interactive. The meeting-notes skill collects the
# bucket, language, and speaker settings, then invokes this script with flags.
#
# Input and output may live in different buckets and/or prefixes. If the
# output bucket is omitted, the input bucket is reused.
#
# Usage:
#   transcribe.sh --file <path> --input-bucket <name> --language <he-IL|en-US|auto> \
#                 [--input-prefix <prefix>] [--output-bucket <name>] [--output-prefix <prefix>] \
#                 [--speakers N] [--region <region>] [--profile <profile>]
#
# On success, prints the local path of the downloaded transcript JSON on the
# last line as: TRANSCRIPT_PATH=<path>

set -euo pipefail

file=""
input_bucket=""
input_prefix=""
output_bucket=""
output_prefix=""
language=""
speakers=""
region=""
profile=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)          file="$2"; shift 2 ;;
    --input-bucket)  input_bucket="$2"; shift 2 ;;
    --input-prefix)  input_prefix="$2"; shift 2 ;;
    --output-bucket) output_bucket="$2"; shift 2 ;;
    --output-prefix) output_prefix="$2"; shift 2 ;;
    --language)      language="$2"; shift 2 ;;
    --speakers)      speakers="$2"; shift 2 ;;
    --region)        region="$2"; shift 2 ;;
    --profile)       profile="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$file" || -z "$input_bucket" || -z "$language" ]]; then
  echo "Error: --file, --input-bucket, and --language are required" >&2
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "Error: file not found: $file" >&2
  exit 1
fi

# Default the output bucket to the input bucket when not given separately
[[ -z "$output_bucket" ]] && output_bucket="$input_bucket"

# Build common AWS CLI args (region/profile are optional; fall back to env/defaults)
aws_args=()
[[ -n "$region" ]]  && aws_args+=(--region "$region")
[[ -n "$profile" ]] && aws_args+=(--profile "$profile")

# Derive a unique job name and S3 keys
base="$(basename "$file")"
ext="${base##*.}"
stem="${base%.*}"
input_prefix="${input_prefix%/}"     # strip any trailing slash
output_prefix="${output_prefix%/}"
# Transcribe job names allow only [A-Za-z0-9._-]; sanitize the filename stem
safe_stem="$(printf '%s' "$stem" | LC_ALL=C sed 's/[^A-Za-z0-9._-]/_/g')"
job_name="${safe_stem}-$(date +%Y%m%d%H%M%S)"
# Prepend prefix only when set, so a blank prefix doesn't yield a leading slash
media_key="${input_prefix:+${input_prefix}/}${job_name}.${ext}"
output_key="${output_prefix:+${output_prefix}/}${job_name}.json"

echo "Uploading ${file} to s3://${input_bucket}/${media_key} ..." >&2
aws "${aws_args[@]}" s3 cp "$file" "s3://${input_bucket}/${media_key}" >&2

# Assemble Transcribe settings
settings_args=()
if [[ -n "$speakers" ]]; then
  settings_args=(--settings "ShowSpeakerLabels=true,MaxSpeakerLabels=${speakers}")
fi

lang_args=()
if [[ "$language" == "auto" ]]; then
  # Multi-language identification for mixed Hebrew/English meetings
  lang_args=(--identify-multiple-languages --language-options "he-IL" "en-US")
else
  lang_args=(--language-code "$language")
fi

echo "Starting transcription job ${job_name} ..." >&2
aws "${aws_args[@]}" transcribe start-transcription-job \
  --transcription-job-name "$job_name" \
  --media "MediaFileUri=s3://${input_bucket}/${media_key}" \
  --output-bucket-name "$output_bucket" \
  --output-key "$output_key" \
  "${lang_args[@]}" \
  "${settings_args[@]}" >&2

echo "Waiting for job to complete (polling every 15s) ..." >&2
while true; do
  job_status="$(aws "${aws_args[@]}" transcribe get-transcription-job \
    --transcription-job-name "$job_name" \
    --query 'TranscriptionJob.TranscriptionJobStatus' --output text)"
  case "$job_status" in
    COMPLETED) echo "Job completed." >&2; break ;;
    FAILED)
      reason="$(aws "${aws_args[@]}" transcribe get-transcription-job \
        --transcription-job-name "$job_name" \
        --query 'TranscriptionJob.FailureReason' --output text)"
      echo "Transcription job failed: ${reason}" >&2
      exit 1 ;;
    *) sleep 15 ;;
  esac
done

# Download the transcript JSON locally (next to the source file)
raw_out="${file:r}.transcript.raw.json"
local_out="${file:r}.transcript.json"
echo "Downloading transcript to ${raw_out} ..." >&2
aws "${aws_args[@]}" s3 cp "s3://${output_bucket}/${output_key}" "$raw_out" >&2

# Amazon Transcribe output includes per-word `items` and `speaker_labels` arrays
# that bloat the file ~14x. The agent only needs `audio_segments` (speaker-labelled
# text). Slim it down so the transcript fits comfortably in the agent's context.
# Prefer jq; fall back to python3 (one of the two is present on virtually any host,
# and python3 ships with uv, already a prerequisite).
echo "Slimming transcript to audio_segments only ..." >&2
if command -v jq >/dev/null 2>&1; then
  jq '{audio_segments: .results.audio_segments}' "$raw_out" > "$local_out"
  rm -f "$raw_out"
elif command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); json.dump({"audio_segments": d["results"]["audio_segments"]}, open(sys.argv[2],"w"), ensure_ascii=False)' "$raw_out" "$local_out"
  rm -f "$raw_out"
else
  echo "Error: neither jq nor python3 found - cannot slim transcript. Install one and retry." >&2
  rm -f "$raw_out"
  exit 1
fi

echo "TRANSCRIPT_PATH=${local_out}"
