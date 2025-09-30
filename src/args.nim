import std/[cmdline, options, strformat]

type Args* = ref object
  index: int
  args: seq[string]

proc newArgs*(): Args =
  return Args(
    index: 0,
    args: commandLineParams()
  )

func `$`*(self: Args): string =
  return fmt"Args(index: {self.index}, args: {self.args})"

func next*(self: Args): Option[string] =
  if self.index >= self.args.len:
    return none(string)

  defer: self.index+=1

  return some(self.args[self.index])
