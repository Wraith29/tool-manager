import std/[options, strformat, sugar, strutils]
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


type Command* = ref object
  name*: string
  short*: string
  description*: string
  exec*: Option[ExecFn]
  children*: seq[Command]


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
    exec: some exec,
    children: @[]
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
    exec: none(ExecFn),
    children: children
  )


func `$`*(self: Command): string =
  return fmt"Command(name: {self.name}, description: {self.description})"


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


proc help*(self: Cli): string =
  let underline = repeat('-', self.name.len)
  let cmdLengths = collect:
    for cmd in self.commands: cmd.name.len

  let longestCmdName = cmdLengths.max()

  let cmdHelp = collect:
    for cmd in self.commands:
      let space = repeat(' ', longestCmdName - cmd.name.len)
      let extra = if cmd.short.len > 0: fmt" ({cmd.short})" else: ""

      fmt"  {space}{cmd.name}{extra} - {cmd.description}"
  
  let commands = cmdHelp.join("\n")

  return fmt"""
  {self.name}
  {underline}

  Commands:
  {commands}
  """.dedent(2)


proc run*(cli: Cli, args: Args): Option[CliError] =
  let cmd = args.next()
  if cmd.isNone():
    return some CliError(kind: CmdError.NotProvided)

  for command in cli.commands:
    if command.match(get cmd):
      return command.run(args)

  return some CliError(kind: CmdError.Unknown, cmd: get cmd)