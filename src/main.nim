import std/[options, strformat]
import args, cli
import commands/[use]
import commands/config/[list]

func help(): string =
  return "TODO: Create a usable help message :) (Ideally auto-generated)"

proc main(): int =
  let args = newArgs()
  let cli = newCli(
    "tool-manager",
    @[
      newCommand(
        "use",
        "Install a new tool",
        execUse,
        short = "u"
      ),
      newCommand(
        "config",
        "Config related operations",
        @[
          newCommand(
            "list",
            "List all settings",
            execConfigList
          )
        ]
      )
    ]
  )

  let err = cli.run(args)
  if err.isNone():
    return 0

  echo help()

  let value = get err
  case value.kind:
  of CommandError.NotProvided:
    echo "ERROR: Subcommand not provided"
  of CommandError.Unknown:
    echo &"ERROR: Unknown subcommand \"{value.cmd}\""

  
when isMainModule:
  quit(main())
