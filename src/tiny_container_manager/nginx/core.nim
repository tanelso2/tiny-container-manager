import
    ../shell_utils,
    nim_utils/[
        logline
    ],
    asyncdispatch

const nginxAvailableDir* = "/etc/nginx/sites-available"
const nginxEnabledDir* = "/etc/nginx/sites-enabled"

proc onNginxChange*() {.async.} =
  if checkNginxService():
    logDebug "Reloading nginx"
    await reloadNginx()
  else:
    logDebug "Restarting nginx"
    await restartNginx()