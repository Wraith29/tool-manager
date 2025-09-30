import std/[options, sugar]
import ./[args]


type ExecFn = (Args) -> void

type
  CmdError* = enum
    NotProvided
    Unknown

  CliError = ref object
    case kind*: CmdError
    of Unknown:
      cmd*: string
    else: nil


type Command = ref object
  name: string
  short: string
  exec: Option[ExecFn]
  children: seq[Command]


func newCommand*(name: string, exec: ExecFn): Command =
  return Command(
    name: name,
    exec: some(exec),
    children: newSeq[Command]()
  )


func newCommand*(name: string, commands: seq[Command]): Command =
  return Command(
    name: name,
    exec: none(ExecFn),
    children: commands
  )


func match(self: Command, cmd: string): bool = self.name == cmd or self.short == cmd


proc run(self: Command, args: Args): Option[CliError] =
  if self.exec.isSome():
    let fn = self.exec.get()

    fn(args)
    return none(CliError)

  let subcmd = args.next()
  if subcmd.isNone():
    return some CliError(kind: CmdError.NotProvided)

  for child in self.children:
    if child.match(get subcmd):
      return child.run(args)

  return some CliError(kind: CmdError.Unknown, cmd: get subcmd)


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
    return some CliError(kind: CmdError.NotProvided)

  for command in cli.commands:
    if command.match(get cmd):
      return command.run(args)

  return some CliError(kind: CmdError.Unknown, cmd: get cmd)