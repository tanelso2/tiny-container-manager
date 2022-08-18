import
  ./shell_utils,
  ./docker,
  ./metrics,
  ./config,
  ./collection,
  nim_utils/logline,
  asyncdispatch,
  httpclient,
  os,
  prometheus as prom,
  sequtils,
  std/options,
  std/sugar,
  streams,
  strformat,
  strutils,
  sugar,
  yaml/serialization

# TODO: Figure out difference between object and ref object.
# I have read the docs before and I still don't get it
type
  ContainerSpec* = ref object of RootObj
    name*: string
    image*: string
    containerPort*: int
    host*: string
  Container* = ref object of ContainerSpec


proc newContainer*(spec: ContainerSpec): Container =
  return Container(name: spec.name,
                   image: spec.image,
                   containerPort: spec.containerPort,
                   host: spec.host)

proc matches(target: Container, d: DContainer): bool =
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
  await dc.tryStopContainer()
  await dc.tryRemoveContainer()

proc createContainer*(target: Container) {.async.} =
  await target.tryStopContainer()
  await target.tryRemoveContainer()
  let pullCmd = fmt"docker pull {target.image}"
  echo pullCmd
  echo await pullCmd.asyncExec()
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo await cmd.asyncExec()
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
    var spec: ContainerSpec
    var s = newFileStream(filename)
    load(s, spec)
    s.close()
    return newContainer(spec)


proc lookupDns(host: string): string =
  fmt"dig {host} +short".simpleExec()

proc lookupDns(target: Container): string =
  target.host.lookupDns()

proc isConfigFile(filename: string): bool =
  result = filename.endsWith(".yaml") or filename.endsWith(".yml")

proc getContainerConfigs*(directory: string = config.configDir): seq[Container] =
  discard directory.existsOrCreateDir
  var containers: seq[Container] = @[]
  for path in walkFiles(fmt"{directory}/*"):
    logInfo(fmt"walking down {path}")
    if path.isConfigFile():
      containers.add(path.parseContainer())
  return containers

type
  ContainersCollection* = ref object of ManagedCollection[Container, DContainer]


proc newContainersCollection*(dir = config.configDir):  ContainersCollection =
  proc getExpected(): Future[seq[Container]] {.async.} =
    return getContainerConfigs(dir)

  proc getWorldState(): Future[seq[DContainer]] {.async.} =
    return getContainers()

  ContainersCollection(
    getExpected: getExpected,
    getWorldState: getWorldState,
    matches: (c: Container, dc: DContainer) => c.matches(dc),
    remove: removeContainer,
    create: createContainer
  )
