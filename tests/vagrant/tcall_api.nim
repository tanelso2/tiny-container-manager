import
    os,
    osproc,
    times,
    unittest,
    nim_utils/logline

proc checkApi() =
    let retVal = execCmd "curl --fail localhost:6969/metrics"
    assert retVal == 0

template waitForChecks(timeoutSeconds: Natural, body: untyped) =
  let startTime = cpuTime()
  while cpuTime() - startTime < toFloat(timeoutSeconds):
    try:
        `body`
        logInfo "Hooray we passed"
        break # We passed everything, break out
    except AssertionDefect:
        sleep(1000)

waitForChecks 300:
    checkApi()