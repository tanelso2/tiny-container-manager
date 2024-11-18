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

proc setupTcm() {.async.} =
  logInfo("Making sure nginx is installed")
  await installNginx()
  logInfo("Making sure certbot is installed")
  await installCertbot()
  logInfo("Setting up the firewall")
  await setupFirewall()

proc quitEarly*() {.async.} =
  let waitTimeSec = 5 * 60
  logWarn fmt"Will be quitting in {waitTimeSec} seconds"
  await sleepAsync(waitTimeSec * 1000)
  logWarn "HERE'S JOHNNY!"
  quit 0

proc startTcm(disableSetup = false, useHttps = true) {.async.} =
  if not disableSetup:
    await setupTcm()

  let em = newManager()
  let cc = newContainersCollection()
  let ncc = newConfigsCollection(cc, dir = "/etc/nginx/sites-available", useHttps=useHttps)
  let nec = newEnabledCollection(ncc, enabledDir = "/etc/nginx/sites-enabled")

  await eventEmitterSetup(em)
  await eventHandlerSetup(em,cc,ncc,nec)

  when defined(quitEarly):
    asyncCheck quitEarly()


import argparse
var p = newParser:
  flag("--disable-management", help="Run the API server only")
  flag("--disable-setup", help="Disable the setup (installing packages) and run the tcm tasks")
  flag("--disable-https", help="Disable https")
  flag("-d", "--debug", help="Enable debug messaging")

# var serverThread: Thread[void]

# proc runServerThreaded: void =
#   let f = proc () {.thread.} = runServer()
#   logInfo "Starting server thread"
#   createThread(serverThread, f)

proc main() =
  var opts = p.parse(commandLineParams())

  let disableSetup = opts.disable_setup
  let useHttps = not opts.disable_https and config.httpsEnabled()
  if opts.debug:
    debugMode = true
    setLogFilter(lvlDebug)
  else:
    setLogFilter(lvlInfo)
  if opts.disable_management:
    logWarn "No management mode enabled, not starting the main tcm tasks"
  else:
    asyncCheck startTcm(disableSetup=disableSetup, useHttps=useHttps)
  # runServerThreaded()
  while true:
    try:
      # runForever()
      runServer()
    except:
      let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
      logError fmt"Got exception {repr(e)} with message {msg}"

when defined(memProfiler):
  import nimprof

when isMainModule:
  main()
