import
  asyncdispatch,
  osproc,
  streams,
  strformat,
  strutils,
  nim_utils/logline

proc asyncRunInShell*(x: seq[string]): Future[string] =
  ## This function doesn't work properly
  ## /home/tnelson/code/tiny-container-manager/tests/tasyncexec.nim(11) tasyncexec
  ## /home/tnelson/.choosenim/toolchains/nim-1.6.10/lib/pure/asyncdispatch.nim(1961) waitFor
  ## /home/tnelson/.choosenim/toolchains/nim-1.6.10/lib/pure/asyncdispatch.nim(1653) poll
  ## /home/tnelson/.choosenim/toolchains/nim-1.6.10/lib/pure/asyncdispatch.nim(1350) runOnce
  ## /home/tnelson/.choosenim/toolchains/nim-1.6.10/lib/pure/ioselects/ioselectors_epoll.nim(429) selectInto
  ## /home/tnelson/.choosenim/toolchains/nim-1.6.10/lib/pure/selectors.nim(283) raiseIOSelectorsError
  ## Error: unhandled exception: Resource temporarily unavailable (code: 11) [IOSelectorsException]
  let process = x[0]
  let args = x[1..^1]
  logInfo fmt"Starting {process=} with {args=}"
  let p = startProcess(process, args=args, options={poUsePath})
  let f = newFuture[string](fromProc="asyncRunInShell")
  logInfo fmt"started. {p.processID=}"
  proc cb(_: AsyncFD): bool  =
    logInfo "In the callback for the {process=}"
    defer: p.close()
    let exitCode = p.peekExitCode
    logInfo fmt"Trying to read results of {process=}"
    if exitCode == -1:
      {.gcsafe.}: logError("Process never started, something's wrong")
    if exitCode != 0:
      f.fail(newException(IOError, p.errorStream().readAll()))
      return false
    f.complete(p.outputStream().readAll())
    return true

  addProcess(p.processID, cb)
  return f

const procWaitMillis = 50

proc asyncRunAndWait*(x: seq[string]): Future[string] {.async.} =
  let process = x[0]
  let args = x[1..^1]
  let p = startProcess(process, args=args, options={poUsePath})
  while p.running:
    await sleepAsync(procWaitMillis)
  defer: p.close()
  let exitCode = p.peekExitCode
  case exitCode
  of -1:
    logError "process never started, something's wrong"
    raise newException(IOError, "Process never started")
  of 0:
    return p.outputStream().readAll()
  else:
    raise newException(IOError, p.errorStream().readAll())

proc asyncExec*(command: string): Future[string] = command.split.asyncRunAndWait()

proc createFile*(filename: string) =
  open(filename, fmWrite).close()

proc installSnap*() {.async.} =
  discard await asyncExec("snap install core")
  discard await asyncExec("snap refresh core")

proc installCertbot*() {.async.} =
  await installSnap()
  discard await asyncExec("snap install --classic certbot")

proc installNginx*() {.async.} =
  discard await asyncExec("apt-get update")
  discard await asyncExec("apt-get install -y nginx")

proc restartNginx*() {.async.} =
  let restartNginxCmd = fmt"systemctl restart nginx"
  discard await restartNginxCmd.asyncExec()

proc reloadNginx*() {.async.} =
  let cmd = fmt"systemctl reload nginx"
  discard await cmd.asyncExec()

proc setupFirewall*() {.async.} =
  discard await asyncExec("ufw default deny incoming")
  discard await asyncExec("ufw default allow outgoing")
  discard await asyncExec("ufw allow ssh")
  # Vagrant ssh
  discard await asyncExec("ufw allow 2222")
  discard await asyncExec("ufw allow http")
  discard await asyncExec("ufw allow https")
  discard await asyncExec("ufw enable")

proc checkNginxService*(): Future[bool] {.async.} =
  # let cmd = "systemctl status nginx.service"
  let cmd = "service nginx status"
  try:
    logInfo "Checking nginx service"
    let res =  await cmd.asyncExec()
    logInfo fmt"{res=}"
    return true
  except:
    return false
  finally:
    logInfo "Done checking nginx service"
