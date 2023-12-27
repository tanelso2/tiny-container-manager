import
  ./shell_utils,
  ./docker,
  ./metrics,
  ./config,
  nim_utils/[
    files,
    logline
  ],
  macros,
  asyncdispatch,
  httpclient,
  os,
  prometheus as prom,
  sequtils,
  std/options,
  streams,
  strformat,
  strutils,
  yanyl

type
  MountKind* = enum
    mkHostDir = "hostdir"
  Mount* = object
    mountPoint*: string
    case kind*: MountKind
    of mkHostDir:
      hostDir*: string
  Container* = ref object of RootObj
    name*: string
    image*: string
    containerPort*: int
    host*: string
    mounts*: seq[Mount]

deriveYamls:
  MountKind
  Mount
  Container

proc matches*(target: Container, d: DContainer): bool =
  # Names are prefaced by a slash due to docker internals
  # https://github.com/moby/moby/issues/6705
  let nameMatch = d.Names.contains(fmt"/{target.name}")
  let imageMatch = d.Image == target.image

  return nameMatch and imageMatch

proc allHosts*(target: Container): seq[string] =
  return @[target.host, fmt"www.{target.host}"]

proc tryStopContainerByName*(name: string) {.async.} =
  try:
    let stopCmd = fmt"docker stop {name}"
    discard await stopCmd.asyncExec()
  except:
    discard # TODO: Only discard if failed because container didn't exist

proc tryStopContainer*(target: Container) {.async.} =
  await tryStopContainerByName(target.name)

proc tryRemoveContainerByName*(name: string) {.async.} =
  try:
    let rmCmd = fmt"docker rm {name}"
    discard await rmCmd.asyncExec()
  except:
    discard

proc tryRemoveContainer*(target: Container) {.async.} =
  await tryRemoveContainerByName(target.name)

proc tryRemoveContainer*(target: DContainer) {.async.} =
  await tryRemoveContainerByName(target.Id)

proc tryStopContainer*(target: DContainer) {.async.} =
  await tryStopContainerByName(target.Id)

proc removeContainer*(dc: DContainer) {.async.} =
  logDebug fmt"Trying to remove container {dc.Names[0]}"
  await dc.tryStopContainer()
  await dc.tryRemoveContainer()

proc mountParams(target: Container): string =
  result = ""
  for m in target.mounts:
    case m.kind
    of mkHostDir:
      result.add("-v {m.hostDir}:{m.mountPoint} ")

proc createContainerCmd*(target: Container): string =
  let portArgs = fmt"-p {target.containerPort}"
  let mountArgs = target.mountParams()
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {mountArgs}{target.image}"
  cmd


proc createContainer*(target: Container) {.async.} =
  logDebug fmt"Trying to create container {target.name}"
  await target.tryStopContainer()
  await target.tryRemoveContainer()
  let pullCmd = fmt"docker pull {target.image}"
  logInfo pullCmd
  logInfo await pullCmd.asyncExec()
  let portArgs = fmt"-p {target.containerPort}"
  let mountArgs = target.mountParams()
  let cmd = target.createContainerCmd()
  logInfo cmd
  logInfo await cmd.asyncExec()
  {.gcsafe.}: metrics.containerStarts.labels(target.name).inc()

proc runningContainer*(target: Container): Option[DContainer] =
  let containers = getContainers()
  let matches = containers.filterIt(target.matches(it))
  if len(matches) == 0:
    return none(DContainer)
  else:
    return some(matches[0])

proc getRunningContainer*(target: Container): DContainer =
  return target.runningContainer.get()

proc localPort*(c: DContainer): int =
  return c.Ports[0].PublicPort

proc localPort*(target: Container): int =
  let c = target.getRunningContainer()
  return c.localPort

proc isHealthy*(target: Container): bool =
  let containers = getContainers()
  var found = false
  for c in containers:
    if target.matches(c):
      found = true
  result = found
  {.gcsafe.}:
    metrics
      .healthCheckStatus
      .labels(target.host, "docker", if result: "success" else: "failure")
      .inc()

# let client = newHttpClient(maxRedirects=0)
#

proc isWebsiteRunning*(target: Container): bool =
  try:
    let client = newHttpClient(maxRedirects=0)
    logInfo(fmt"Checking {target.host}")
    let website = target.host
    let httpUrl = fmt"http://{website}"
    let httpsUrl = fmt"https://{website}"
    let httpRet = client.request(httpUrl, httpMethod=HttpGet)
    # This check seems to throw exceptions every once in a while because of cert errors...
    # So while httpclient library says it doesn't check validity, it seems to be attempting to...
    let httpsRet = client.request(httpsUrl, httpMethod=HttpGet)
    let httpWorks = "301" in httpRet.status
    let httpsWorks = "200" in httpsRet.status
    result = httpWorks and httpsWorks
  except:
    logError(getCurrentExceptionMsg())
    result = false
  finally:
    {.gcsafe.}:
      metrics
        .healthCheckStatus
        .labels(target.host, "http", if result: "success" else: "failure")
        .inc()

proc parseContainer*(filename: string): Container =
  {.gcsafe.}:
    var s = readFile(filename)
    s.ofYamlStr(Container)

proc isConfigFile(filename: string): bool =
  result = filename.endsWith(".yaml") or filename.endsWith(".yml")

proc getContainerConfigs*(directory: string = config.containerDir): seq[Container] =
  discard directory.existsOrCreateDir
  var containers: seq[Container] = newSeq[Container]()
  for path in walkFiles(fmt"{directory}/*"):
    if path.isConfigFile():
      containers.add(path.parseContainer())
  return containers


proc filename*(spec: Container): string = fmt"{spec.name}.yaml"

type 
  ErrAlreadyExists* = object of ValueError
  ErrDoesNotExist* = object of OSError

proc deleteNamedContainer*(name: string, dir = config.containerDir) =
  let filename = fmt"{name}.yaml"
  let path = dir / filename
  if not path.fileExists:
    raise newException(ErrDoesNotExist, fmt"{path} doesn't exist")
  path.removePath()

proc writeFile*(c: Container, dir = config.containerDir) =
  let path = dir / c.filename
  var s = newFileStream(path, fmWrite)
  defer: s.close()
  s.write(c.toYaml().toString())

proc add*(c: Container, dir = config.containerDir) =
  let path = dir / c.filename
  if path.fileExists:
    raise newException(ErrAlreadyExists, fmt"{path} already exists")
  c.writeFile()

proc getContainerByName*(name: string, dir = config.containerDir): Option[Container] =
  let path = dir / fmt"{name}.yaml"
  if not path.fileExists:
    return none(Container)
  try:
    let container = path.parseContainer()
    return some(container)
  except:
    return none(Container)

