import 
  os

const email* = "tanelso2@gmail.com"
const configDir* = "/opt/tiny-container-manager"
const containerDir* = configDir / "containers"
const keysDir* = configDir / "keys"
const tcmHost* = "tcm.thomasnelson.me"
const tcmApiPort* = 6969
const bindAll* = true

type
  TCMConfig* = object
    email*: string
    configDir*: string
    containerDir*: string
    keysDir*: string
    tcmHost*: string
    tcmApiPort*: int
    httpsEnabled*: bool

const defaultConfig*: TCMConfig = TCMConfig(
  email: "tanelso2@gmail.com",
  configDir: "/opt/tiny-container-manager",
  containerDir: configDir / "containers",
  keysDir: configDir / "keys",
  tcmHost: "tcm.thomasnelson.me",
  tcmApiPort: 6969,
  httpsEnabled: false
)