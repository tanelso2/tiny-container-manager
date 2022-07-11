import
  asyncdispatch,
  osproc,
  streams,
  strformat,
  strutils,
  nim_utils/logline

proc runInShell*(x: openArray[string]): string =
  let process = x[0]
  let args = x[1..^1]
  let p = startProcess(process, args=args, options={poUsePath})
  defer: p.close()
  let exitCode = p.waitForExit()
  if exitCode != 0:
    logError("process failed")
    echo p.errorStream().readAll()
  return p.outputStream().readAll()


proc simpleExec*(command: string): string = command.split.runInShell

proc asyncRunInShell*(x: seq[string]): Future[string] =
  let process = x[0]
  let args = x[1..^1]
  let p = startProcess(process, args=args, options={poUsePath})
  let f = newFuture[string](fromProc="asyncRunInShell")
  proc cb(_: AsyncFD): bool  =
    defer: p.close()
    let exitCode = p.peekExitCode
    if exitCode == -1:
      {.gcsafe.}: logError("Process never started, something's wrong")
    if exitCode != 0:
      f.fail(newException(IOError, p.errorStream().readAll()))
      return false
    f.complete(p.outputStream().readAll())
    return true

  addProcess(p.processID, cb)
  return f

proc asyncExec*(command: string): Future[string] = command.split.asyncRunInShell

proc createFile*(filename: string) =
  open(filename, fmWrite).close()

proc installSnap*() {.async.} =
  echo await asyncExec("sudo snap install core")
  echo await asyncExec("sudo snap refresh core")

proc installCertbot*() {.async.} =
  await installSnap()
  echo await asyncExec("sudo snap install --classic certbot")

proc installNginx*() {.async.} =
  echo await asyncExec("sudo apt-get update")
  echo await asyncExec("sudo apt-get install -y nginx")

proc restartNginx*() {.async.} =
  let restartNginxCmd = fmt"systemctl restart nginx"
  echo restartNginxCmd
  echo await restartNginxCmd.asyncExec()

proc reloadNginx*() {.async.} =
  let cmd = fmt"systemctl reload nginx"
  discard await cmd.asyncExec()

proc setupFirewall*() {.async.} =
  echo await asyncExec("sudo ufw default deny incoming")
  echo await asyncExec("sudo ufw default allow outgoing")
  echo await asyncExec("sudo ufw allow ssh")
  echo await asyncExec("sudo ufw allow http")
  echo await asyncExec("sudo ufw allow https")
  echo await asyncExec("sudo ufw allow 6969/tcp")
  echo await asyncExec("sudo ufw enable")

proc checkNginxService*(): bool =
  let cmd = "systemctl status nginx.service"
  try:
    discard cmd.simpleExec()
    return true
  except:
    return false
