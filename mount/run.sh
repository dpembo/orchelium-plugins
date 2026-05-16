#!/usr/bin/env bash
# Orchelium mount plugin — run.sh
# INPUT_JSON is injected by the Orchelium hub as a variable prepended to this
# script. Falls back to $1 for direct / manual invocation.

set -uo pipefail

# Merge stderr into stdout — the agent only captures stdout to the logfile.
exec 2>&1

INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No input JSON provided"}'
  exit 1
fi

# ── Parse inputs ────────────────────────────────────────────────────────────────

parse_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" \
    <<< "$INPUT_JSON" 2>/dev/null || echo ""
}

OPERATION=$(parse_field operation)
MOUNT_TYPE=$(parse_field mount_type)
SOURCE=$(parse_field source)
TARGET=$(parse_field target)
OPTIONS=$(parse_field options)
CREDENTIALS_FILE=$(parse_field credentials_file)
LUKS_NAME=$(parse_field luks_name)
LUKS_KEYFILE=$(parse_field luks_keyfile)
CREATE_TARGET=$(parse_field create_target)
LAZY_UNMOUNT=$(parse_field lazy_unmount)
FORCE_UNMOUNT=$(parse_field force_unmount)

# Apply defaults
: "${OPERATION:=mount}"
: "${MOUNT_TYPE:=auto}"
: "${CREATE_TARGET:=yes}"
: "${LAZY_UNMOUNT:=no}"
: "${FORCE_UNMOUNT:=no}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$TARGET" ]; then
  echo '{"success":false,"error":"target (mount point) is required"}'
  exit 1
fi

if [ "$OPERATION" = "mount" ] || [ "$OPERATION" = "remount" ]; then
  if [ "$MOUNT_TYPE" != "tmpfs" ] && [ "$MOUNT_TYPE" != "bind" ] && [ -z "$SOURCE" ]; then
    echo '{"success":false,"error":"source is required for mount/remount operations"}'
    exit 1
  fi
fi

if [ "$MOUNT_TYPE" = "luks" ]; then
  if [ -z "$LUKS_NAME" ]; then
    echo '{"success":false,"error":"luks_name is required when mount_type is luks"}'
    exit 1
  fi
  if ! command -v cryptsetup &>/dev/null; then
    echo "[mount] ERROR: cryptsetup is not installed on this agent"
    echo '{"success":false,"error":"cryptsetup not found in PATH"}'
    exit 1
  fi
fi

# ── Helper: is_mounted ──────────────────────────────────────────────────────────

is_mounted() {
  local path="$1"
  mountpoint -q "$path" 2>/dev/null
}

# ── Execute ─────────────────────────────────────────────────────────────────────

START_TS=$(date +%s)
EXIT_CODE=0
WAS_MOUNTED="false"
IS_NOW_MOUNTED="false"
MOUNT_DEVICE=""
MOUNT_FSTYPE=""
MOUNT_OPTIONS_ACTUAL=""

case "$OPERATION" in

  # ── STATUS ──────────────────────────────────────────────────────────────────
  status)
    if is_mounted "$TARGET"; then
      echo "[mount] ${TARGET} is mounted"
      WAS_MOUNTED="true"
      IS_NOW_MOUNTED="true"
      # Capture details from /proc/mounts
      MOUNT_INFO=$(grep " ${TARGET} " /proc/mounts 2>/dev/null | tail -1 || echo "")
      MOUNT_DEVICE=$(echo "$MOUNT_INFO"  | awk '{print $1}')
      MOUNT_FSTYPE=$(echo "$MOUNT_INFO"  | awk '{print $3}')
      MOUNT_OPTIONS_ACTUAL=$(echo "$MOUNT_INFO" | awk '{print $4}')
    else
      echo "[mount] ${TARGET} is NOT mounted"
      WAS_MOUNTED="false"
      IS_NOW_MOUNTED="false"
    fi
    ;;

  # ── MOUNT ───────────────────────────────────────────────────────────────────
  mount)
    if is_mounted "$TARGET"; then
      echo "[mount] ${TARGET} is already mounted — skipping"
      WAS_MOUNTED="true"
      IS_NOW_MOUNTED="true"
    else
      WAS_MOUNTED="false"

      # Create target directory if needed
      if [ "$CREATE_TARGET" = "yes" ] && [ ! -d "$TARGET" ]; then
        echo "[mount] Creating mount point: ${TARGET}"
        mkdir -p "$TARGET"
      fi

      # Build mount args
      MOUNT_ARGS=()

      if [ "$MOUNT_TYPE" = "luks" ]; then
        # Open LUKS container first
        echo "[mount] Opening LUKS container: ${SOURCE} -> /dev/mapper/${LUKS_NAME}"
        CRYPTSETUP_ARGS=("luksOpen" "$SOURCE" "$LUKS_NAME")
        if [ -n "$LUKS_KEYFILE" ]; then
          CRYPTSETUP_ARGS+=("--key-file" "$LUKS_KEYFILE")
        elif [ -n "${LUKS_PASSPHRASE:-}" ]; then
          echo "$LUKS_PASSPHRASE" | cryptsetup luksOpen "$SOURCE" "$LUKS_NAME" --key-file=-
          EXIT_CODE=$?
          CRYPTSETUP_ARGS=()  # already ran
        fi
        if [ ${#CRYPTSETUP_ARGS[@]} -gt 0 ]; then
          cryptsetup "${CRYPTSETUP_ARGS[@]}"
          EXIT_CODE=$?
        fi
        if [ "$EXIT_CODE" -ne 0 ]; then
          echo "[mount] FAILED to open LUKS container (exit ${EXIT_CODE})"
          echo '{"success":false,"error":"cryptsetup luksOpen failed"}'
          exit "$EXIT_CODE"
        fi
        # Mount the mapped device
        EFFECTIVE_SOURCE="/dev/mapper/${LUKS_NAME}"
        MOUNT_ARGS+=("$EFFECTIVE_SOURCE" "$TARGET")
      elif [ "$MOUNT_TYPE" = "loop" ]; then
        MOUNT_ARGS+=("-o" "loop")
        [ -n "$OPTIONS" ] && MOUNT_ARGS[1]="${MOUNT_ARGS[1]},${OPTIONS}"
        MOUNT_ARGS+=("$SOURCE" "$TARGET")
      elif [ "$MOUNT_TYPE" = "bind" ]; then
        MOUNT_ARGS+=("--bind" "$SOURCE" "$TARGET")
      else
        # Generic: nfs, cifs, ext4, xfs, btrfs, vfat, tmpfs, auto
        [ "$MOUNT_TYPE" != "auto" ] && MOUNT_ARGS+=("-t" "$MOUNT_TYPE")

        # Build -o options string
        OPT_PARTS=()
        [ -n "$OPTIONS" ] && OPT_PARTS+=("$OPTIONS")
        [ -n "$CREDENTIALS_FILE" ] && OPT_PARTS+=("credentials=${CREDENTIALS_FILE}")
        if [ ${#OPT_PARTS[@]} -gt 0 ]; then
          OPT_STR=$(IFS=,; echo "${OPT_PARTS[*]}")
          MOUNT_ARGS+=("-o" "$OPT_STR")
        fi

        if [ "$MOUNT_TYPE" = "tmpfs" ]; then
          MOUNT_ARGS+=("tmpfs" "$TARGET")
        else
          MOUNT_ARGS+=("$SOURCE" "$TARGET")
        fi
      fi

      echo "[mount] Running: mount ${MOUNT_ARGS[*]}"
      mount "${MOUNT_ARGS[@]}"
      EXIT_CODE=$?

      if [ "$EXIT_CODE" -eq 0 ]; then
        echo "[mount] Successfully mounted ${SOURCE:-tmpfs} at ${TARGET}"
        IS_NOW_MOUNTED="true"
      else
        echo "[mount] FAILED with exit code ${EXIT_CODE}"
        IS_NOW_MOUNTED="false"
      fi
    fi
    ;;

  # ── UNMOUNT ─────────────────────────────────────────────────────────────────
  unmount)
    WAS_MOUNTED="false"
    if is_mounted "$TARGET"; then
      WAS_MOUNTED="true"
    else
      echo "[mount] ${TARGET} is not mounted — nothing to do"
      IS_NOW_MOUNTED="false"
    fi

    if [ "$WAS_MOUNTED" = "true" ]; then
      UMOUNT_ARGS=()
      [ "$LAZY_UNMOUNT"  = "yes" ] && UMOUNT_ARGS+=("-l")
      [ "$FORCE_UNMOUNT" = "yes" ] && UMOUNT_ARGS+=("-f")
      UMOUNT_ARGS+=("$TARGET")

      echo "[mount] Running: umount ${UMOUNT_ARGS[*]}"
      umount "${UMOUNT_ARGS[@]}"
      EXIT_CODE=$?

      if [ "$EXIT_CODE" -eq 0 ]; then
        echo "[mount] Successfully unmounted ${TARGET}"
        IS_NOW_MOUNTED="false"

        # If it was a LUKS mount, close the mapper device
        if [ "$MOUNT_TYPE" = "luks" ] && [ -n "$LUKS_NAME" ]; then
          if [ -e "/dev/mapper/${LUKS_NAME}" ]; then
            echo "[mount] Closing LUKS mapper: ${LUKS_NAME}"
            cryptsetup luksClose "$LUKS_NAME"
            LUKS_EXIT=$?
            [ "$LUKS_EXIT" -ne 0 ] && echo "[mount] WARNING: cryptsetup luksClose returned ${LUKS_EXIT}"
          fi
        fi
      else
        echo "[mount] FAILED to unmount ${TARGET} (exit ${EXIT_CODE})"
        IS_NOW_MOUNTED="true"
      fi
    fi
    ;;

  # ── REMOUNT ─────────────────────────────────────────────────────────────────
  remount)
    WAS_MOUNTED="false"
    if is_mounted "$TARGET"; then
      WAS_MOUNTED="true"
    fi

    REMOUNT_OPT="remount"
    [ -n "$OPTIONS" ] && REMOUNT_OPT="remount,${OPTIONS}"

    MOUNT_ARGS=("-o" "$REMOUNT_OPT" "$TARGET")
    echo "[mount] Running: mount ${MOUNT_ARGS[*]}"
    mount "${MOUNT_ARGS[@]}"
    EXIT_CODE=$?

    if [ "$EXIT_CODE" -eq 0 ]; then
      echo "[mount] Successfully remounted ${TARGET}"
      IS_NOW_MOUNTED="true"
    else
      echo "[mount] FAILED to remount ${TARGET} (exit ${EXIT_CODE})"
    fi
    ;;

  *)
    echo "[mount] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))

# ── Emit structured JSON summary ────────────────────────────────────────────────

python3 - <<PYEOF
import json

result = {
    "success":         $EXIT_CODE == 0,
    "exitCode":        $EXIT_CODE,
    "operation":       "$OPERATION",
    "mountType":       "$MOUNT_TYPE",
    "source":          "$SOURCE",
    "target":          "$TARGET",
    "wasMounted":      "$WAS_MOUNTED"    == "true",
    "isNowMounted":    "$IS_NOW_MOUNTED" == "true",
    "durationSeconds": $DURATION,
}

if "$MOUNT_DEVICE":
    result["device"]  = "$MOUNT_DEVICE"
    result["fstype"]  = "$MOUNT_FSTYPE"
    result["options"] = "$MOUNT_OPTIONS_ACTUAL"

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
