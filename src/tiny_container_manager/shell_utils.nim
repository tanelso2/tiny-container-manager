import
  osproc,
  streams,
  strformat,
  strutils


proc runInShell*(x: openArray[string]): string =
  let process = x[0]
  let args = x[1..^1]
  let p = startProcess(process, args=args, options={poUsePath})
  defer: p.close()
  let exitCode = p.waitForExit()
  if exitCode != 0:
    echo "Heya, that failed"
  return p.outputStream().readAll()


proc simpleExec*(command: string): string = command.split.runInShell

proc createFile*(filename: string) =
  open(filename, fmWrite).close()

proc installSnap*() =
  echo simpleExec("sudo snap install core")
  echo simpleExec("sudo snap refresh core")

proc installCertbot*(): void =
  installSnap()
  echo simpleExec("sudo snap install --classic certbot")

proc installNginx*() =
  echo simpleExec("sudo apt-get update")
  echo simpleExec("sudo apt-get install -y nginx")

proc restartNginx*() =
  let restartNginxCmd = fmt"systemctl restart nginx"
  echo restartNginxCmd
  echo restartNginxCmd.simpleExec()