import
  json,
  net,
  os,
  strutils,
  strformat,
  tables,
  nim_utils/[
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
    PublicPort*: int
    Type*: string

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

proc makeRequest(s: Socket, headers = emptyHeaders(), body: JsonNode = nil, httpMethod = "GET", path = "/", timeout = 10_000): JsonNode =
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
  let resJson = makeRequest(getDockerSocket(), path = "/containers/json")
  return to(resJson, seq[DContainer])

proc getContainer*(name: string): DContainer =
  let resJson = makeRequest(getDockerSocket(), path = &"/containers/{name}/json")
  return to(resJson, DContainer)

proc main() =
  let socket = getDockerSocket()
  let resp = socket.makeRequest(path = "/containers/json")
  discard socket.makeRequest(path = "/")

when isMainModule:
  echo getContainers()
  main()
