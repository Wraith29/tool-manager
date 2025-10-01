import std/[options, strformat]
import ../[args]

type UseParams = ref object
  repository: string
  branch: Option[string]

func `$`*(self: UseParams): string =
  return fmt"UseParams(repository: {self.repository}, branch: {self.branch})"

func newParams(args: Args): UseParams {.raises: [ArgsException].} =
  let repository = args.next()
  if repository.isNone():
    raise ArgsException.newException(symbolName ArgsError.MissingRequiredParameter)

  return UseParams(
    repository: get repository,
  )

proc execUse*(args: Args): void {.raises: [ArgsException].} =
  let params = newParams(args)

  echo "Hello from use"
