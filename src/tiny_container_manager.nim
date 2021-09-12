import
  asynchttpserver,
  asyncdispatch,
  httpclient,
  strformat,
  os,
  prometheus as prom,
  strutils,
  sequtils,
  sugar,
  tiny_container_manager/container,
  tiny_container_manager/metrics as metrics,
  tiny_container_manager/shell_utils

let email = "tanelso2@gmail.com"

let client = newHttpClient(maxRedirects=0)

proc runCertbotForAll(containers: seq[Container]) =
  var domainFlags = ""
  let domains = containers.map(proc(c: Container): string = c.host)
  let domainsWithFlags = domains.map((x) => fmt"-d {x}")
  let d = domainsWithFlags.join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {d} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()

proc isConfigFile(filename: string): bool =
  result = filename.endsWith(".yaml") or filename.endsWith(".yml")

proc getContainerConfigs(directory: string): seq[Container] =
  discard directory.existsOrCreateDir
  var containers: seq[Container] = @[]
  for path in walkFiles(fmt"{directory}/*"):
    echo fmt"walking down {path}"
    if path.isConfigFile():
      containers.add(path.parseContainer())
  echo fmt"containers is {containers}"
  return containers

proc testWebsiteWithCurl(website: string) =
  let httpUrl = fmt"http://{website}"
  let httpsUrl = fmt"https://{website}"
  let httpOut = fmt"curl {httpUrl}".simpleExec()
  let httpsOut = fmt"curl {httpsUrl}".simpleExec()


proc checkDiskUsage() =
  let x = "df -i".simpleExec()
  let y: string = x.split("\n").filter(z => z.contains("/dev/vda1"))[0]


const loopSeconds = 30


proc mainLoop() {.async.} =
  echo "Starting loop"
  await installNginx()
  await installCertbot()
  await setupFirewall()
  let configDir = "/opt/tiny-container-manager"
  var i = 0
  while true:
    echo await "echo OHBOYHEREWEGOAGAIN".asyncExec()
    metrics.incRuns()
    {.gcsafe.}: metrics.iters.set(i)
    let containers = getContainerConfigs(configDir)
    for c in containers:
      await c.ensureContainer()
    #TODO: I should find a logger that injects the file,line,and can be configured.
    # Lol or I should write one
    echo "Going to sleep"
    i+=1
    await sleepAsync(loopSeconds * 1000)
    #echo "sleep 30".simpleExec()

proc runServer {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    let headers = {"Content-Type": "text/plain"}
    await req.respond(Http200, metrics.getOutput(), headers.newHttpHeaders())
  server.listen Port(6969)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

# proc testGetConfig() =
#   echo "Testing reading the config"
#   discard getContainerConfigs("/opt/tiny-capn")
#
#
proc main() =
  asyncCheck mainLoop()
  asyncCheck runServer()

  runForever()

  # Running the webserver on the same async dispatch loop seems
  # risky? Especially because I don't think my shell_utils are async safe


when isMainModule:
  main()
  # metrics.uptimeMetric.labels("blahblah.com").inc()
  # echo metrics.getOutput()
