#!/bin/zsh
# Regenerates the README screenshots in docs/. Run: ./scripts/screenshots.sh
# Shelfy is launched in demo mode with sample files; the snapshots use a plain
# background because the glass effect can't be captured offscreen.
set -e
cd "${0:A:h}/.."

./build.sh >/dev/null
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc -O scripts/frame.swift -o "$WORK/frame"

# Neutral sample files.
SAMPLES="$WORK/samples"
mkdir -p "$SAMPLES/Design Assets"
"$WORK/frame" --sample-image "$SAMPLES/Sunset.png"
printf 'Trip plan\n\nDay 1: Arrive, check in\nDay 2: Old town walking tour\nDay 3: Beach\n' > "$SAMPLES/Trip Plan.txt"
cupsfilter "$SAMPLES/Trip Plan.txt" > "$SAMPLES/Trip Plan.pdf" 2>/dev/null
printf '# Meeting notes\n\n- Ship v1\n- Collect feedback\n' > "$SAMPLES/Meeting Notes.md"

snap() { # snap <name> <files...>
    local name=$1; shift
    local files=$(IFS=:; echo "$*")
    SHELFY_DEMO_SNAPSHOT="$WORK/$name.png" SHELFY_DEMO_FILES="$files" ./Shelfy.app/Contents/MacOS/Shelfy &
    local pid=$!
    for i in {1..50}; do [[ -f "$WORK/$name.png" ]] && break; sleep 0.2; done
    kill $pid
    wait $pid 2>/dev/null || true
    "$WORK/frame" "$WORK/$name.png" "docs/$name.png"
    echo "docs/$name.png"
}

mkdir -p docs
snap shelf-multiple "$SAMPLES/Sunset.png" "$SAMPLES/Trip Plan.pdf" "$SAMPLES/Meeting Notes.md" "$SAMPLES/Design Assets"
snap shelf-single "$SAMPLES/Sunset.png"
