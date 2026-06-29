#!/usr/bin/env bash
# Screen recorder built on gpu-screen-recorder (GPU/VAAPI accelerated).
# Supports: start/stop (toggle), pause/resume, and a replay buffer.
#
# Actions (flags):
#   (none)                start a normal recording; run again to STOP
#   --fullscreen          record the focused monitor (default target is also the monitor)
#   --region "X,Y WxH"    record an explicit region (slurp format, as from the snip tool)
#   --audio MODE          none | system | mic | both   (overrides config)
#   --mic / --sound       shorthand for --audio mic / --audio system
#   --pause               toggle pause/resume on the running recording (SIGUSR2)
#   --replay              toggle the replay buffer on/off (keeps the last N seconds)
#   --save-replay         save the current replay buffer to a file (SIGUSR1)
#   --stop                stop whatever is running
#
# Config (~/.config/illogical-impulse/config.json .screenRecord.*):
#   savePath, audio, fps, videoCodec(=-k), audioCodec(=-ac), quality(=-q),
#   extension, replayDuration (seconds), micSource, systemSource, extraArgs
#
# Signals (gpu-screen-recorder): SIGINT = stop+save, SIGUSR1 = save replay,
#   SIGUSR2 = toggle pause. State for the bar indicator lives in $STATE_DIR.

set -u

REC_BIN="gpu-screen-recorder"
CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/ii-recorder"
STARTED_FILE="$STATE_DIR/started"   # epoch recording/replay began
MODE_FILE="$STATE_DIR/mode"         # "record" | "replay"
PAUSED_FILE="$STATE_DIR/paused"     # present while paused
PIDFILE="$STATE_DIR/pid"            # PID of the running gpu-screen-recorder
mkdir -p "$STATE_DIR"

notify() { notify-send -a 'Recorder' "$1" "${2:-}" & disown; }
jq_get() { jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null; }
getdate() { date '+%Y-%m-%d_%H.%M.%S'; }
focused_monitor() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name'; }
# Track by PID, not pgrep: the kernel truncates comm to 15 chars
# ("gpu-screen-reco"), so `pgrep -x gpu-screen-recorder` never matches.
rec_pid() { cat "$PIDFILE" 2>/dev/null; }
running() { local p; p="$(rec_pid)"; [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }
cleanup_state() { rm -f "$STARTED_FILE" "$MODE_FILE" "$PAUSED_FILE" "$PIDFILE"; }

if ! command -v "$REC_BIN" >/dev/null; then
    notify "Recorder unavailable" "Install gpu-screen-recorder (see packages.txt)"
    exit 1
fi

# --- parse flags ------------------------------------------------------------
ACTION="record"      # record | replay | pause | save-replay | stop
REGION=""
FULLSCREEN=0
AUDIO_MODE=""
ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
    case "${ARGS[i]}" in
        --region)      REGION="${ARGS[i+1]:-}"; ((i++)) ;;
        --fullscreen)  FULLSCREEN=1 ;;
        --audio)       AUDIO_MODE="${ARGS[i+1]:-none}"; ((i++)) ;;
        --mic)         AUDIO_MODE="mic" ;;
        --sound)       AUDIO_MODE="system" ;;
        --pause)       ACTION="pause" ;;
        --replay)      ACTION="replay" ;;
        --save-replay) ACTION="save-replay" ;;
        --stop)        ACTION="stop" ;;
    esac
done

# --- act on a RUNNING instance ---------------------------------------------
if running; then
    PID="$(rec_pid)"
    case "$ACTION" in
        pause)
            kill -USR2 "$PID" 2>/dev/null
            if [ -f "$PAUSED_FILE" ]; then rm -f "$PAUSED_FILE"; notify "Recording resumed";
            else touch "$PAUSED_FILE"; notify "Recording paused"; fi
            ;;
        save-replay)
            if [ "$(cat "$MODE_FILE" 2>/dev/null)" = "replay" ]; then
                kill -USR1 "$PID" 2>/dev/null; notify "Replay saved" "$(jq_get '.screenRecord.savePath')"
            else
                notify "No replay buffer" "Start the replay buffer first"
            fi
            ;;
        *)  # any start request, --stop, or --replay while running => STOP
            kill -CONT "$PID" 2>/dev/null   # un-pause so it can finalize
            kill -INT  "$PID" 2>/dev/null
            notify "Recording stopped" "Saved"
            # the owning instance's EXIT trap clears the state once it exits
            ;;
    esac
    exit 0
fi

# --- nothing running: signal-only actions are no-ops ------------------------
case "$ACTION" in
    pause|save-replay|stop) notify "Not recording"; exit 0 ;;
esac

# --- config defaults --------------------------------------------------------
SAVE_PATH="$(jq_get '.screenRecord.savePath')"; [ -z "$SAVE_PATH" ] && SAVE_PATH="$HOME/Videos"
[ -z "$AUDIO_MODE" ] && AUDIO_MODE="$(jq_get '.screenRecord.audio')"
[ -z "$AUDIO_MODE" ] && AUDIO_MODE="none"
FPS="$(jq_get '.screenRecord.fps')";            [ -z "$FPS" ] && FPS="60"
QUALITY="$(jq_get '.screenRecord.quality')";    [ -z "$QUALITY" ] && QUALITY="very_high"
VCODEC="$(jq_get '.screenRecord.videoCodec')";  [ -z "$VCODEC" ] && VCODEC="auto"
ACODEC="$(jq_get '.screenRecord.audioCodec')";  [ -z "$ACODEC" ] && ACODEC="opus"
EXT="$(jq_get '.screenRecord.extension')";      [ -z "$EXT" ] && EXT="mp4"
REPLAY_SECS="$(jq_get '.screenRecord.replayDuration')"; [ -z "$REPLAY_SECS" ] && REPLAY_SECS="30"
MIC_SRC="$(jq_get '.screenRecord.micSource')"
SYS_SRC="$(jq_get '.screenRecord.systemSource')"
EXTRA="$(jq_get '.screenRecord.extraArgs')"
mkdir -p "$SAVE_PATH"

# --- capture target ---------------------------------------------------------
TARGET=()
if [[ -n "$REGION" ]]; then
    # slurp gives "X,Y WxH" -> gpu-screen-recorder wants "WxH+X+Y"
    xy="${REGION%% *}"; wh="${REGION##* }"
    TARGET=(-w region -region "${wh}+${xy/,/+}")
else
    mon="$(focused_monitor)"; [ -z "$mon" ] && mon="screen"
    TARGET=(-w "$mon")
fi

# --- audio tracks (gpu-screen-recorder merges with '|' in one -a) ------------
SYS="${SYS_SRC:-default_output}"
MIC="${MIC_SRC:-default_input}"
AUDIO=()
case "$AUDIO_MODE" in
    none)   ;;
    system) AUDIO=(-a "$SYS") ;;
    mic)    AUDIO=(-a "$MIC") ;;
    both)   AUDIO=(-a "${SYS}|${MIC}") ;;
    *)      notify "Recording cancelled" "Unknown audio mode: $AUDIO_MODE"; exit 1 ;;
esac

# --- interactive region fallback (normal record only, no flag/region) -------
if [[ "$ACTION" == "record" && $FULLSCREEN -eq 0 && -z "$REGION" ]]; then
    if region="$(slurp 2>/dev/null)"; then
        xy="${region%% *}"; wh="${region##* }"
        TARGET=(-w region -region "${wh}+${xy/,/+}")
    else
        notify "Recording cancelled" "Selection cancelled"; exit 1
    fi
fi

# --- common encoder args ----------------------------------------------------
ENC=(-f "$FPS" -q "$QUALITY" -k "$VCODEC" -ac "$ACODEC")
# shellcheck disable=SC2206
[ -n "$EXTRA" ] && ENC+=($EXTRA)

trap cleanup_state EXIT
date +%s > "$STARTED_FILE"

# Run gpu-screen-recorder in the background so we can record its exact PID
# (for stop/pause/save signals), then wait on it. The EXIT trap clears state.
if [[ "$ACTION" == "replay" ]]; then
    # Replay buffer: -o is a directory; SIGUSR1 saves the last N seconds.
    echo "replay" > "$MODE_FILE"
    notify "Replay buffer armed" "Last ${REPLAY_SECS}s · Super+Alt+V to save"
    "$REC_BIN" "${TARGET[@]}" "${AUDIO[@]}" "${ENC[@]}" -r "$REPLAY_SECS" -o "$SAVE_PATH" &
else
    echo "record" > "$MODE_FILE"
    OUTFILE="$SAVE_PATH/recording_$(getdate).$EXT"
    [ "$AUDIO_MODE" = none ] && notify "Recording started" "$(basename "$OUTFILE")" \
        || notify "Recording started" "$(basename "$OUTFILE") · audio: $AUDIO_MODE"
    "$REC_BIN" "${TARGET[@]}" "${AUDIO[@]}" "${ENC[@]}" -o "$OUTFILE" &
fi
REC_PID=$!
echo "$REC_PID" > "$PIDFILE"
wait "$REC_PID"
# EXIT trap clears the indicator state once the recorder exits
