import ../../[args, config]

proc execConfigList*(args: Args): void =
  let cfg = loadConfig()

  echo "Config Path: " & configPath.string & "\n"

  echo "Settings:"

  for key, val in cfg[].fieldPairs:
    echo "  " & key & ": " & val
