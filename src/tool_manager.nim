import std/[options, strformat]
import ./[args, cli]

proc execHelp(args: Args): void =
  echo fmt"Hello from help: {args}"

proc main(): int =
  let args = newArgs()
  let cli = newCli(
    "tool-manager",
    @[
      newCommand("help", execHelp),
    ]
  )

  let err = cli.run(args)
  if err.isNone():
    return 0

  let value = get err
  case value.kind:
  of CmdError.NotProvided:
    echo "ERROR: Required subcommand not provided"
  of CmdError.Unknown:
    echo &"ERROR: Unknown subcommand \"{value.cmd}\""
  
when isMainModule:
  quit(main())
