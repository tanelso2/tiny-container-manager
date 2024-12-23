import
  asyncdispatch,
  json,
  net,
  options,
  os,
  strutils,
  strformat,
  tables,
  nim_utils/[
    logline,
    shell_utils
  ],
  ./[
    metrics,
    shell_utils
  ]

type
  DContainer* = object
    Id*: string
    Image*: string
    Ports*: seq[DPort]
    Names*: seq[string]
  DPort* = object
    PrivatePort*: int
    PublicPort*: Option[int]
    Type*: string
  DContainerStats* = object
    cpu_stats*: CPUStats
    precpu_stats*: CPUStats
    memory_stats*: MemoryStats
    pids_stats*: PIDStats
  PIDStats* = object
    current*: int
  CPUStats* = object
    system_cpu_usage*: int
    online_cpus*: int
    cpu_usage*: CPUUsage
  CPUUsage* = object
    total_usage*: int
  MemoryStats* = object
    usage*: int
    limit*: int
    stats*: MemoryStatsDetailed
  MemoryStatsDetailed* = object
    inactive_file*: int
  DockerCLIStatsRaw* = object
    BlockIO*: string
    CPUPerc*: string
    Container*: string
    ID*: string
    MemPerc*: string
    MemUsage*: string
    Name*: string
    NetIO*: string
    PIDs*: string
  DockerCLIStats* = object
    CPUPerc*: float
    ID*: string
    Name*: string
    MemPerc*: float
    PIDs*: int
  DockerStats* = object
    CPUPerc*: float
    Name*: string
    MemPerc*: float
    PIDs*: int

type
  Headers* = Table[string, string]


const dockerSocketFile = "/var/run/docker.sock"
const dockerSocketUrl = "unix:///var/run/docker.sock"

proc dockerSocketFileExists*(): bool =
  dockerSocketFile.fileExists()

proc dockerRunning*(): bool =
  tryExec "docker ps"

proc getDockerSocket(): Socket =
  result = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  result.connectUnix(dockerSocketFile)

proc makeHeaderString(h: Headers): string =
  let requiredHeaders: Headers = {"Connection": "Keep-Alive", "Host": "unix"}.toTable
  result = ""
  for k,v in h.pairs:
    result.add(&"{k}: {v}\c\n")
  for k,v in requiredHeaders.pairs:
    result.add(&"{k}: {v}\c\n")

const httpNewline = "\c\n"

proc emptyHeaders(): Headers = initTable[string,string]()

proc makeRequest(headers = emptyHeaders(), body: JsonNode = nil, httpMethod = "GET", path = "/", timeout = 10_000): JsonNode =
  let s = getDockerSocket()
  defer: s.close()
  let introString = &"{httpMethod} {path} HTTP/1.1\c\n"
  s.send(introString)
  let headerString = headers.makeHeaderString()
  # if body == nil:
  #   echo "NIL NIL NIL"
  # echo &"headerString is {headerString}"
  s.send(headerString)
  s.send(httpNewline)
  # TODO: POST bodys?
  #
  #
  # Start receive
  let httpLine = s.recvLine(timeout)
  let statusCode: int = parseInt(httpLine.split(" ")[1])
  if statusCode != 200:
    logWarn fmt"Failed to fetch {path}. Status code: {statusCode}"
  # TODO: Headers and error handling
  # Read headers
  var chunkedTransfer = false
  while true:
    let line = s.recvLine(timeout)
    if line.contains("Transfer-Encoding") and line.contains("chunked"):
      chunkedTransfer = true
    if line == httpNewLine:
      break
  var body = ""
  if chunkedTransfer:
    while true:
      let chunkLength = s.recvLine(timeout)
      let chunk = s.recvLine(timeout)
      body.add(chunk)
      if chunk == httpNewLine or chunk == "":
        break
      # Consume another blank line in between chunks
      discard s.recvLine(timeout)
  else:
    body = s.recvLine(timeout)
  return parseJson(body)

proc getContainers*(): seq[DContainer] =
  let resJson = makeRequest(path = "/containers/json")
  #logInfo $resJson
  return to(resJson, seq[DContainer])

proc getContainer*(name: string): DContainer =
  let resJson = makeRequest(path = &"/containers/{name}/json")
  return to(resJson, DContainer)

proc getContainerStats*(name: string, oneShot = false): Option[DockerStats] =
  try:
    let resJson = makeRequest(path = &"/containers/{name}/stats?stream=false&one-shot={oneShot}")
    # logInfo $resJson
    # logInfo $resJson["cpu_stats"]
    # logInfo $resJson["precpu_stats"]
    # logInfo $resJson["memory_stats"]
    # logInfo $to(resJson["cpu_stats"], CPUStats)
    let data = to(resJson, DContainerStats)
    # Conversion between API and CLI stats provided by:
    # https://docs.docker.com/reference/api/engine/version/v1.47/#tag/Container/operation/ContainerStats
    # These instructions aren't accurate to the most recent version of Docker though.
    # percpu_stats no longer exists, need to use online_cpus instead
    # memory_stats.stats.cache does not exist anymore, need to use inactive_file instead
    let
      used_memory = data.memory_stats.usage - data.memory_stats.stats.inactive_file
      available_memory = data.memory_stats.limit
      memory_usage_percent = float(used_memory / available_memory) * 100.0
      cpu_delta = data.cpu_stats.cpu_usage.total_usage - data.precpu_stats.cpu_usage.total_usage
      system_cpu_delta = data.cpu_stats.system_cpu_usage - data.precpu_stats.system_cpu_usage
      number_cpus = data.cpu_stats.online_cpus
      cpu_usage_percent = (cpu_delta / system_cpu_delta) * float(number_cpus) * 100.0
      pids = data.pids_stats.current
    return some(DockerStats(
      CPUPerc: cpu_usage_percent,
      Name: name,
      MemPerc: memory_usage_percent,
      PIDs: pids
    ))
  except:
    let e = getCurrentException()
    logError fmt"Failed to fetch container stats. Error message: {e.msg}"
    return none(DockerStats)

proc parsePercent(s: string): float =
  parseFloat(s[0..^2]) # Remove last character

proc convert(r: DockerCLIStatsRaw): DockerCLIStats =
  DockerCLIStats(
    CPUPerc: parsePercent(r.CPUPerc),
    ID: r.ID,
    Name: r.Name,
    MemPerc: parsePercent(r.MemPerc),
    PIDs: parseInt(r.PIDs)
  )

proc getDockerCLIStats*(): Future[seq[DockerCLIStats]] {.async.} =
  let cmd = "docker stats --format json --no-stream"
  let res = (await cmd.asyncExec()).strip()
  result = @[]
  for r in res.splitLines():
    let stats = r.parseJson().to(DockerCLIStatsRaw).convert()
    result.add(stats)

proc getDockerStats*(): seq[DockerStats] =
  let containers = getContainers()
  result = @[]
  for c in containers:
    var name = c.Names[0]
    if name.startsWith('/'):
      name = name[1..^1]
    let stats = getContainerStats(name)
    if stats.isSome():
      result.add(stats.get())
    else:
      logError fmt"Unable to get container stats for container {name}"


proc observeDockerStats*() =
  let stats = getDockerStats()
  for s in stats:
    metrics.containerCPUPerc.labels(s.Name).set(s.CPUPerc)
    metrics.containerMemPerc.labels(s.Name).set(s.MemPerc)
    metrics.containerPIDs.labels(s.Name).set(s.PIDs)

proc main() =
  let socket = getDockerSocket()
  defer: socket.close()
  let resp = makeRequest(path = "/containers/json")
  discard makeRequest(path = "/")

when isMainModule:
  #echo getContainers()
  # logInfo $getContainerStats("nginx")
  # logInfo $(waitFor getDockerCLIStats())
  logInfo $getDockerStats()
  observeDockerStats()
  logInfo metrics.getOutput()
  # main()
