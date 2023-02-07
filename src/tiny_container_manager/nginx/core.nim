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
  let serviceStatus = await checkNginxService()
  if serviceStatus:
    logInfo "Reloading nginx"
    await reloadNginx()
  else:
    logInfo "Restarting nginx"
    await restartNginx()