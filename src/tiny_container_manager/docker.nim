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
    memory_stats*: MemoryStats
  MemoryStats* = object
    usage*: int
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
  let statusCode = httpLine.split(" ")[1]
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

proc getContainerStats*(name: string, oneShot = true) =
  # Unfinished - using docker stats CLI instead
  let resJson = makeRequest(path = &"/containers/{name}/stats?stream=false&one-shot={oneShot}")
  logInfo $resJson
  logDebug $to(resJson, DContainerStats)

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

proc observeDockerStats*() {.async.} =
  let stats = await getDockerCLIStats()
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
  #getContainerStats("nginx")
  logInfo $(waitFor getDockerCLIStats())
  waitFor observeDockerStats()
  logInfo metrics.getOutput()
  # main()
