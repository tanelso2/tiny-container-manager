import
  asynchttpserver

import
  asyncdispatch,
  httpclient,
  json,
  logging,
  strformat,
  os,
  prometheus as prom,
  strutils,
  sequtils,
  sugar,
  times,
  tiny_container_manager/[
    auth,
    container_collection,
    collection,
    config,
    container,
    json_utils,
    metrics,
    nginx/config_collection,
    nginx/enabled_collection,
    shell_utils
  ],
  nim_utils/logline,
  jester

var debugMode = false

let client = newHttpClient(maxRedirects=0)

proc runCertbotForAll(containers: seq[Container]) =
  var domainFlags = ""
  let domains = containers.map(proc(c: Container): string = c.host)
  let domainsWithFlags = domains.map((x) => fmt"-d {x}")
  let d = domainsWithFlags.join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {d} --email {config.email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()

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
  logInfo("Making sure nginx is installed")
  await installNginx()
  logInfo("Making sure certbot is installed")
  await installCertbot()
  logInfo("Setting up the firewall")
  await setupFirewall()

proc mainLoop(disableSetup = false, useHttps = true) {.async.} =
  if not disableSetup:
    await loopSetup()
  let cc = newContainersCollection()
  let ncc = newConfigsCollection(cc, dir = "/etc/nginx/sites-available", useHttps=useHttps)
  let nec = newEnabledCollection(ncc, enabledDir = "/etc/nginx/sites-enabled")
  logInfo("Starting loop")
  var i = 0
  while true:
    metrics.incRuns()
    {.gcsafe.}: metrics.iters.set(i)

    try:
      # TODO: These don't need to run sequentially...
      logInfo "Running containersCollection"
      discard await cc.ensure()
      logInfo "Running nginx configs collection"
      discard await ncc.ensure()
      logInfo "Running nginx enabled symlinks collection"
      discard await  nec.ensure()
    except:
      let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
      logError fmt"Got exception {repr(e)} with message {msg}"

    logInfo("Cleaning up the letsencrypt backups")
    cleanUpLetsEncryptBackups()

    if not checkNginxService():
      await restartNginx()

    logInfo("Going to sleep")
    # Make sure log messages are displayed promptly
    flushFile(stdout)
    i+=1
    await sleepAsync(loopSeconds * 1000)

template swallowErrors*(body: untyped) =
  try:
    body
  except:
    if debugMode:
      resp Http500, fmt"Something bad happened: {getCurrentExceptionMsg()}", contentType = "text/plain"
    else:
      resp Http500, fmt"An error occurred", contentType = "text/plain"

template respText*(s: string) =
  resp s, contentType = "text/plain"

template respOk* =
  respText "OK"

router application:
  get "/metrics":
    respText metrics.getOutput()
  get "/containers":
    swallowErrors:
      authRequired:
        let containers = getContainerConfigs()
        jsonResp containers
  post "/container":
    swallowErrors:
      authRequired:
        logInfo fmt"Got a POST"
        let spec = request.jsonBody(Container)
        try:
          spec.add()
        except ErrAlreadyExists:
          resp Http409, fmt"A container with name {spec.name} already exists"
        respOk
  delete "/container/@name":
    swallowErrors:
      authRequired:
        let name = @"name"
        try:
          deleteNamedContainer(name)
        except ErrDoesNotExist:
          resp Http404
        resp Http204
  patch "/container/@name/image":
    swallowErrors:
      authRequired:
        let name = @"name"
        let maybeContainer = getContainerByName(name)
        if maybeContainer.isNone():
          resp Http404
        let c = maybeContainer.get()
        let newImage = request.body
        let newC = Container(name: c.name,
                             image: newImage,
                             host: c.host,
                             containerPort: c.containerPort)
        newC.writeFile()
        respOk

proc runServer =
  logInfo "Starting server"
  let portNum = 6969
  let port = Port(portNum)
  let settings = newSettings(port=port)
  var jester = initJester(application, settings=settings)
  jester.serve()
  logInfo fmt"Server is listening on port {portNum}"

# proc runServer {.async.} =
#   logInfo "Starting server"
#   var server = newAsyncHttpServer()
#   let portNum = 6969
#   let port = Port(portNum)
#   server.listen port
#   logInfo fmt"Server is listening on port {portNum}"
#   while true:
#     if server.shouldAcceptRequest():
#       await server.acceptRequest()
#     else:
#       poll()
import argparse
var p = newParser:
  flag("--no-management", help="Run the API server only")
  flag("--disable-setup", help="Disable the setup and go straight to the main loop")
  flag("--disable-https", help="Disable https")
  flag("-d", "--debug", help="Enable debug messaging")

var serverThread: Thread[void]

proc runServerThreaded: void =
  logInfo "What is going on"
  let f = proc () {.thread.} = runServer()
  logInfo "Starting server thread"
  createThread(serverThread, f)

proc main() =
  var opts = p.parse(commandLineParams())

  let disableSetup = opts.disable_setup
  let useHttps = not opts.disable_https
  if opts.debug:
    debugMode = true
    setLogFilter(lvlDebug)
  else:
    setLogFilter(lvlInfo)
  if opts.no_management:
    logInfo "No management mode enabled, not starting the mainLoop"
    runServer()
  else:
    asyncCheck mainLoop(disableSetup=disableSetup, useHttps=useHttps)
  runServerThreaded()
  # asyncCheck runServer()

  runForever()


when isMainModule:
  main()
  # metrics.uptimeMetric.labels("blahblah.com").inc()
  # echo metrics.getOutput()
