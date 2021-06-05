import yaml/serialization, streams
import
  strformat,
  os,
  osproc,
  strutils,
  sequtils,
  sugar
# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.
type
  Container = object of RootObj
    name*: string
    image: string
    containerPort: int
    host: string

let email = "tanelso2@gmail.com"

proc runInShell(x: openArray[string]): string =
  let process = x[0]
  let args = x[1..^1]
  return execProcess(process, args=args, options={poUsePath}).strip

proc simpleExec(command: string): string = command.split.runInShell

proc isRunning(target: Container): bool =
  let containers = "docker container ls".simpleExec
  for line in containers.split("\n")[1..^1]:
    if line.contains(target.name):
      return true
  return false

proc createContainer(target: Container) =
  # TODO: check if running
  let pullCmd = fmt"docker pull {target.image}"
  echo pullCmd
  echo pullCmd.simpleExec()
  let portArgs = fmt"-p {target.containerPort}"
  let cmd = fmt"docker run --name {target.name} -d {portArgs} {target.image}"
  echo cmd
  echo cmd.simpleExec()

proc createFile(filename: string) =
  open(filename, fmWrite).close()

proc localPort(target: Container): int =
  let containers = "docker container ls".simpleExec
  proc findline(): string =
    for line in containers.split("\n")[1..^1]:
      if line.contains(target.name):
        return line
  let targetLine = findline()
  for word in targetLine.split(" "):
    if word.contains("0.0.0.0"):
      return word.split("->")[0].split("0.0.0.0:")[1].parseInt()

proc restartNginx() =
  let restartNginxCmd = fmt"systemctl restart nginx"
  echo restartNginxCmd
  echo restartNginxCmd.simpleExec()

proc createNginxConfig(target: Container) =
  let port = 80
  let host = target.host
  let containerPort = target.localPort
  let x = fmt("""
  server {
    listen 0.0.0.0:80;
    listen [::]:80;

    server_name <host>;

    location / {
      proxy_pass http://127.0.0.1:<containerPort>;
    }
  }
  """, '<', '>')
  let filename = fmt"/etc/nginx/sites-available/{target.name}"
  filename.createFile
  writeFile(filename, x)
  let enabledFile = fmt"/etc/nginx/sites-enabled/{target.name}"
  if not enabledFile.symlinkExists:
    createSymlink(filename, enabledFile)
  restartNginx()

proc runCertbotForAll(containers: seq[Container]) =
  var domainFlags = ""
  let domains = containers.map(proc(c: Container): string = c.host)
  let domainsWithFlags = domains.map((x) => fmt"-d {x}")
  let d = domainsWithFlags.join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {d} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()

proc installSnap() =
  echo simpleExec("sudo snap install core")
  echo simpleExec("sudo snap refresh core")

proc installCertbot(): void =
  installSnap()
  echo simpleExec("sudo snap install --classic certbot")

proc installNginx() =
  echo simpleExec("sudo apt-get update")
  echo simpleExec("sudo apt-get install -y nginx")

proc isConfigFile(filename: string): bool =
  return true

proc parseContainer(filename: string): Container =
  var ret: Container
  var s = newFileStream(filename)
  load(s, ret)
  s.close()
  return ret


proc getContainerConfigs(directory: string): seq[Container] =
  discard directory.existsOrCreateDir
  var containers: seq[Container] = @[]
  for path in walkFiles(fmt"{directory}/*"):
    echo fmt"walking down {path}"
    if path.isConfigFile():
      containers.add(path.parseContainer())
  echo fmt"containers is {containers}"
  return containers

proc runCertbot(target: Container) =
  let certbotCmd = fmt"certbot run --nginx -n --keep -d {target.host} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()


proc ensureContainer(target: Container) =
  if not target.isRunning:
    target.createContainer
  target.createNginxConfig()
  target.runCertbot()

proc mainLoop() =
  installNginx()
  installCertbot()
  let configDir = "/opt/tiny-container-manager"
  while true:
    let containers = getContainerConfigs(configDir)
    for c in containers:
      c.ensureContainer()
    #runCertbotForAll(containers)
    echo "sleep 15".simpleExec()


proc testLoop() =
  echo "hey hey hey"
  installNginx()
  installCertbot()
  let image = "gcr.io/kubernetes-221218/personal-website:travis-9a64ae5"
  let containerPort = 80
  let host = "thomasnelson.me"
  let c2 = Container(name: "tnelson-personal-website", image: image, containerPort: containerPort, host: host)
  echo fmt"{c2.name} is running? {c2.isRunning}"
  c2.ensureContainer

proc testGetConfig() =
  echo "Testing reading the config"
  discard getContainerConfigs("/opt/tiny-capn")


when isMainModule:
  #testLoop()
  #testGetConfig()
  mainLoop()
