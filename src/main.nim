import std/[options, strformat]
import ./[args, cli]

proc execUse(args: Args): void =
  echo "TODO: Implement Use"

proc main(): int =
  let args = newArgs()
  let cli = newCli(
    "tool-manager",
    @[
      newCommand("use", "Install a new command", execUse)
    ]
  )

  let err = cli.run(args)
  if err.isNone():
    return 0

  echo cli.help()

  let value = get err
  case value.kind:
  of CmdError.NotProvided:
    echo "ERROR: Subcommand not provided"
  of CmdError.Unknown:
    echo &"ERROR: Unknown subcommand \"{value.cmd}\""

  
when isMainModule:
  quit(main())
