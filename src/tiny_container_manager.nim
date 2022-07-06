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
  times,
  tiny_container_manager/container,
  tiny_container_manager/log,
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
    logInfo(fmt"walking down {path}")
    if path.isConfigFile():
      containers.add(path.parseContainer())
  return containers

proc checkDiskUsage() =
  let x = "df -i".simpleExec()
  let y: string = x.split("\n").filter(z => z.contains("/dev/vda1"))[0]

proc cleanUpLetsEncryptBackups() =
  let dir = "/var/lib/letsencrypt/backups"
  let anHourAgo = getTime() + initTimeInterval(hours = -1)
  var filesDeleted = 0
  for (fileType, path) in walkDir(dir):
    # a < b if a happened before b
    if path.getCreationTime() < anHourAgo:
      if fileType == pcFile:
        path.removeFile()
      if fileType == pcDir:
        path.removeDir()
      filesDeleted += 1

  logDebug(fmt"Deleted {filesDeleted} backup files")
  metrics.letsEncryptBackupsDeleted.inc(filesDeleted)



const loopSeconds = 30

proc loopSetup() {.async.} =
  logInfo("Setting up loop")
  await installNginx()
  await installCertbot()
  await setupFirewall()

proc mainLoop() {.async.} =
  await loopSetup()
  logInfo("Starting loop")
  let configDir = "/opt/tiny-container-manager"
  var i = 0
  while true:
    metrics.incRuns()
    {.gcsafe.}: metrics.iters.set(i)

    let containers = getContainerConfigs(configDir)
    for c in containers:
      await c.ensureContainer()

    logInfo("Cleaning up the letsencrypt backups")
    cleanUpLetsEncryptBackups()

    if not checkNginxService():
      await restartNginx()

    logInfo("Going to sleep")
    # Make sure log messages are displayed promptly
    flushFile(stdout)
    i+=1
    await sleepAsync(loopSeconds * 1000)
    #echo "sleep 30".simpleExec()

proc runServer {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    let headers = {"Content-Type": "text/plain"}
    await req.respond(Http200, metrics.getOutput(), headers.newHttpHeaders())
  let port = Port(6969)
  server.listen port
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

proc main() =
  asyncCheck mainLoop()
  asyncCheck runServer()

  runForever()

# proc test() =
#   for _ in 1..10:
#     let c1 = Container(name: "test", image: "", containerPort: 9090, host: "thomasnelson.me")
#     echo c1.isWebsiteRunning()
#     let c2 = Container(name: "test", image: "", containerPort: 9090, host: "findmythesis.com")
#     echo c2.isWebsiteRunning()
#     let c3 = Container(name: "test", image: "", containerPort: 9090, host: "pureinvaders.com")
#     echo c3.isWebsiteRunning()

when isMainModule:
  # test()
  main()
  # metrics.uptimeMetric.labels("blahblah.com").inc()
  # echo metrics.getOutput()
