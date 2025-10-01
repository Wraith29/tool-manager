import std/[appdirs, files, paths]
import jsony

const
  appName = "tool-manager"
  appDataDirPath = getDataDir() / Path(appName)
  configPath* = appDataDirPath / Path("config.json")


type Config* = ref object
  toolDataPath: string
  installerDataPath: string
  toolSrcPath: string
  toolBinPath: string


proc save*(self: Config): void =
  let jsonData = self.toJson()

  writeFile(string configPath, jsonData)


proc readConfigFromFile(): Config =
  return readFile(string configPath).fromJson(Config)


proc loadConfig*(): Config =
  if fileExists(configPath):
    return readConfigFromFile()

  let defaultCfg = Config(
    toolDataPath: string appDataDirPath / Path("tools"),
    installerDataPath: string appDataDirPath / Path("installers"),
    toolSrcPath: string appDataDirPath / Path("src"),
    toolBinPath: string appDataDirPath / Path("bin")
  )

  defaultCfg.save()

  return defaultCfg