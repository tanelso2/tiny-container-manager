import
  os,
  std/options,
  std/strutils,
  std/sugar,
  std/tables,
  nim_utils/logline,
  yanyl

const defaultConfigFile* = "/opt/tiny-container-manager/config.yaml"
var defaultConfigFileCache = none(YNode)
proc fileConfig(): YNode =
  if defaultConfigFileCache.isNone():
    let f = open(defaultConfigFile)
    defer: f.close()
    let content = f.readAll()
    result = content.loadNode()
    defaultConfigFileCache = some result
  else:
    result = defaultConfigFileCache.get()

type
  ConfigOption*[T] = object of RootObj
    envVariable: Option[string]
    configFileProperty: Option[string]
    defaultValue: Option[T]
    parser: string -> T
  StringOpt* = ConfigOption[string]
  IntOpt* = ConfigOption[int]
  BoolOpt* = ConfigOption[bool]

proc id[T](x: T): T = x

proc contains(n: YNode, k: string): bool =
  assertYMap n
  return k in n.mapVal

proc stringOpt*(env: Option[string] = none(string), fileProperty = none(string), defaultValue = none(string)): StringOpt =
  return ConfigOption[string](envVariable : env,
                              configFileProperty : fileProperty,
                              defaultValue : defaultValue,
                              parser : id)

proc intOpt*(env: Option[string] = none(string), fileProperty = none(string), defaultValue = none(int)): IntOpt =
  return ConfigOption[int](envVariable: env,
                           configFileProperty: fileProperty,
                           defaultValue: defaultValue,
                           parser: parseInt)

proc boolOpt*(env = none(string), fileProperty = none(string), defaultValue = none(bool)): BoolOpt =
  return ConfigOption[bool](envVariable: env,
                            configFileProperty: fileProperty,
                            defaultValue: defaultValue,
                            parser: parseBool)

proc get*[T](opt: ConfigOption[T]): Option[T] =
  result = none(T)
  if opt.envVariable.isSome() and result.isNone():
    let envVar = opt.envVariable.get()
    if existsEnv(envVar):
      let val = getEnv(envVar)
      result = some(opt.parser(val))
  if opt.configFileProperty.isSome() and result.isNone():
    if fileExists(defaultConfigFile):
      let configResult = fileConfig()
      let prop = opt.configFileProperty.get()
      if prop in configResult:
        let val = configResult.getStr(prop)
        result = some(opt.parser(val))
  if opt.defaultValue.isSome() and result.isNone():
    result = opt.defaultValue

type
  TCMConfigOptions* = object
    email*: StringOpt = stringOpt(env = some("TCM_EMAIL"),
                                  fileProperty = some("email"),
                                  defaultValue = some("example@example.com"))
    configDir*: StringOpt = stringOpt(env = some "TCM_CONFIG_DIR",
                                      fileProperty = some("configDir"),
                                      defaultValue = some("/opt/tiny-container-manager"))
    host*: StringOpt = stringOpt(env = some "TCM_HOST",
                                 fileProperty = some "host",
                                 defaultValue = some "tcm.example.com")
    apiPort*: IntOpt = intOpt(env = some "TCM_API_PORT",
                              fileProperty = some "apiPort",
                              defaultValue = some 6060)
    httpsEnabled*: BoolOpt = boolOpt(env = some "TCM_HTTPS_ENABLED",
                                     fileProperty = some "httpsEnabled",
                                     defaultValue = some true)
    bindAll*: BoolOpt = boolOpt(env = some "TCM_BIND_ALL",
                                fileProperty = some "bindAll",
                                defaultValue = some false)

let
  opts = TCMConfigOptions()

proc email*(): string =
  {.gcsafe.}:
    return opts.email.get().get()

proc configDir*(): string =
  {.gcsafe.}:
    return opts.configDir.get().get()

proc keysDir*(): string =
  configDir() / "keys"

proc containerDir*(): string =
  configDir() / "containers"

proc tcmHost*(): string =
  {.gcsafe.}:
    return opts.host.get().get()

proc tcmApiPort*(): int =
  {.gcsafe.}:
    return opts.apiPort.get().get()

proc httpsEnabled*(): bool =
  {.gcsafe.}:
    return opts.httpsEnabled.get().get()

proc bindAll*(): bool =
  {.gcsafe.}:
    return opts.bindAll.get().get()
