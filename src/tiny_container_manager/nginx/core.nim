import
    ../shell_utils,
    nim_utils/[
        logline
    ],
    asyncdispatch

const nginxAvailableDir* = "/etc/nginx/sites-available"
const nginxEnabledDir* = "/etc/nginx/sites-enabled"

proc onNginxChange*() {.async.} =
  logInfo "Checking nginx status"
  if await checkNginxService():
    logInfo "Reloading nginx"
    await reloadNginx()
  else:
    logInfo "Restarting nginx"
    await restartNginx()