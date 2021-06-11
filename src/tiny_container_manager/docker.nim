import
  asyncdispatch,
  httpcore,
  json,
  strutils,
  strformat,
  sugar

import net

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
  # Read headers
  while true:
    let line = s.recvLine(timeout)
    echo line
    if line == httpNewLine:
      break
  let body = s.recvLine()
  return parseJson(body)



proc main() =
  let socket = getDockerSocket()
  let resp = socket.makeRequest(path = "/containers/json")
  discard socket.makeRequest(path = "/")


main()
