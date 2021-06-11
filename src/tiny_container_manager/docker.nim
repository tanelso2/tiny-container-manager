import
  httpcore,
  json,
  net,
  strutils,
  strformat

type
  DPort* = object
    PrivatePort*: int
    PublicPort*: int
    Type*: string

type
  DContainer* = object
    Id*: string
    Image*: string
    Ports*: seq[DPort]
    Names*: seq[string]

let dockerSocketFile = "/var/run/docker.sock"
let dockerSocketUrl = "unix:///var/run/docker.sock"

proc getDockerSocket(): Socket =
  result = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  result.connectUnix(dockerSocketFile)

proc makeRequest(s: Socket, httpMethod = "GET", path = "/", timeout = 10_000): JsonNode =
  let headerString = &"{httpMethod} {path} HTTP/1.1\c\nConnection: Keep-Alive\c\nHost: unix\c\n\c\n"
  s.send(headerString)

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

proc main() =
  let socket = getDockerSocket()
  let resp = socket.makeRequest(path = "/containers/json")
  discard socket.makeRequest(path = "/")

when isMainModule:
  echo getContainers()
  main()
