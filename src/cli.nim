import std/[options, strformat, sugar]
import ./[args]

type
  ExecFn = (Args) -> void

  CommandError* = enum
    NotProvided
    Unknown

  CliError = ref object
    case kind*: CommandError
    of Unknown:
      cmd*: string
    else: nil

  CommandType = enum
    ctExe, ctParent

  Command* = ref object
    name*: string
    short*: string
    description*: string
    case kind: CommandType:
    of ctExe: exec*: ExecFn
    of ctParent: children*: seq[Command]


proc newCommand*(
  name: string,
  description: string,
  exec: ExecFn,
  short: string = "",
): Command =
  return Command(
    name: name,
    description: description,
    short: short,
    kind: ctExe,
    exec: exec
  )

proc newCommand*(
  name: string,
  description: string,
  children: seq[Command],
  short: string = ""
): Command =
  return Command(
    name: name,
    description: description,
    short: short,
    kind: ctParent,
    children: children
  )


func `$`*(self: Command): string =
  return fmt"Command(name: {self.name}, description: {self.description})"


func match(self: Command, cmd: string): bool =
  self.name == cmd or self.short == cmd


proc run(self: Command, args: Args): Option[CliError] =
  if self.kind == ctExe:
    self.exec(args)
    return none(CliError)

  let subcmd = args.next()
  if subcmd.isNone():
    return some CliError(kind: CommandError.NotProvided)

  for child in self.children:
    if child.match(get subcmd):
      return child.run(args)

  return some CliError(kind: CommandError.Unknown, cmd: get subcmd)


type Cli = ref object
  name: string
  commands: seq[Command]


func newCli*(name: string, commands: seq[Command]): Cli =
  return Cli(
    name: name,
    commands: commands
  )


proc run*(cli: Cli, args: Args): Option[CliError] =
  let cmd = args.next()
  if cmd.isNone():
    return some CliError(kind: CommandError.NotProvided)

  for command in cli.commands:
    if command.match(get cmd):
      return command.run(args)

  return some CliError(kind: CommandError.Unknown, cmd: get cmd)