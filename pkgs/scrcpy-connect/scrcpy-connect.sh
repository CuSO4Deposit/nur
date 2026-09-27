target=""
if [ "$#" -gt 0 ]; then
  case "$1" in
    *:[0-9]*)
      target="$1"
      shift
      ;;
  esac
fi

adb start-server >/dev/null

if [ -n "$target" ]; then
  adb connect "$target" >/dev/null
fi

select_args=()
selected=""

if [ -n "$target" ]; then
  select_args=(-s "$target")
  selected="$target"
else
  usb=$(adb devices | awk '$2 == "device" && $1 !~ /:/ && $1 !~ /_adb-tls-connect/ { print $1; exit }')
  tcp=$(adb devices | awk '$2 == "device" && $1 ~ /:/ { print $1; exit }')
  mdns=$(adb devices | awk '$2 == "device" && $1 ~ /_adb-tls-connect/ { print $1; exit }')

  if [ -n "$usb" ]; then
    select_args=(-d)
    selected="$usb"
  elif [ -n "$tcp" ]; then
    select_args=(-s "$tcp")
    selected="$tcp"
  elif [ -n "$mdns" ]; then
    select_args=(-s "$mdns")
    selected="$mdns"
  fi
fi

if [ -z "$selected" ]; then
  echo "No connected phone found." >&2
  echo "First connection: scrcpy-connect <phone-ip:port>" >&2
  echo >&2
  adb devices >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  set -- --turn-screen-off --stay-awake
fi

echo "Using $selected" >&2
exec scrcpy "${select_args[@]}" "$@"
