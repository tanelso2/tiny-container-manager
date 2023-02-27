import
  asyncdispatch,
  asyncfutures,
  logging,
  os,
  strutils,
  segfaults,
  sequtils,
  strformat,
  tiny_container_manager/[
    api_server,
    container_collection,
    config,
    events,
    handlers,
    json_utils,
    nginx/config_collection,
    nginx/enabled_collection,
    shell_utils
  ],
  nim_utils/logline,
  jester

var debugMode = false

proc loopSetup() {.async.} =
  logInfo("Setting up loop")
  logInfo("Making sure nginx is installed")
  await installNginx()
  logInfo("Making sure certbot is installed")
  await installCertbot()
  logInfo("Setting up the firewall")
  await setupFirewall()

proc mainLoop(disableSetup = false, useHttps = true) {.async.} =
  let em = newManager()
  let cc = newContainersCollection()
  let ncc = newConfigsCollection(cc, dir = "/etc/nginx/sites-available", useHttps=useHttps)
  let nec = newEnabledCollection(ncc, enabledDir = "/etc/nginx/sites-enabled")

  await eventEmitterSetup(em)
  await eventHandlerSetup(em,cc,ncc,nec)

  if not disableSetup:
    await loopSetup()

  # Wait and quit to try and get the profiler to work
  await sleepAsync(60 * 1000)
  quit 0



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
  let useHttps = not opts.disable_https and defaultConfig.httpsEnabled
  if opts.debug:
    debugMode = true
    setLogFilter(lvlDebug)
  else:
    setLogFilter(lvlInfo)
  if opts.no_management:
    logInfo "No management mode enabled, not starting the mainLoop"
  else:
    asyncCheck mainLoop(disableSetup=disableSetup, useHttps=useHttps)
  # runServerThreaded()
  while true:
    try:
      runForever()
      # runServer()
    except:
      let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
      logError fmt"Got exception {repr(e)} with message {msg}"

when defined(memProfiler):
  import nimprof

when isMainModule:
  main()
