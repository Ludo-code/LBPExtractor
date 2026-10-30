#!/usr/bin/env bash
# Test double for zenity: answers a fixed scenario via $ZENITY_MOCK_ANSWERS
# (newline-separated), prints canned answers on stdout for file-selection
# and input calls, and records the call sequence in $ZENITY_MOCK_LOG.
set -u
LOG=${ZENITY_MOCK_LOG:-/tmp/zenity_mock.log}
ANSWERS=${ZENITY_MOCK_ANSWERS:-}
: > "$LOG"
printf '%s\n' "$@" >> "$LOG"

# Consume the next scripted answer (one per invocation, in call order).
next_answer() {
    printf '%s\n' "$ANSWERS" | head -n "$1" | tail -n 1
}

mode="other"
for a in "$@"; do
    case "$a" in
        --file-selection) mode="fileselection" ;;
        --question) mode="question" ;;
        --warning|--info) mode="message" ;;
    esac
done

case "$mode" in
    fileselection)
        # first call: input dir, second call: output dir (empty = default)
        n=$(grep -c 'file-selection' "$LOG")
        if [ "$n" -le 1 ]; then
            next_answer 1
            exit 0
        else
            next_answer 2
            exit 0
        fi ;;
    question)
        n=$(grep -c 'question' "$LOG")
        # call 1 = --remove, call 2 = --separate : answer yes/no from script
        if [ "$n" -le 1 ]; then
            next_answer 3; [ "$(next_answer 3)" = "yes" ] && exit 0 || exit 1
        else
            next_answer 4; [ "$(next_answer 4)" = "yes" ] && exit 0 || exit 1
        fi ;;
    message)
        exit 0 ;;
esac
exit 0
