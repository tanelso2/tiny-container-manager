#import yaml.serialization, streams
import
  strformat,
  os,
  osproc,
  strutils
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


proc createNginxConfig(target: Container) =
  let port = 80
  let host = target.host
  let containerPort = target.localPort
  let x = fmt("""
  server {
    listen <port> default_server;
    listen [::]:<port> default_server;

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
  let restartNginxCmd = fmt"systemctl restart nginx"
  echo restartNginxCmd
  echo restartNginxCmd.simpleExec()
  let certbotCmd = fmt"certbot run --nginx -n --domains {target.host} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()
  echo restartNginxCmd
  echo restartNginxCmd.simpleExec()

proc installSnap() =
  echo simpleExec("sudo snap install core")
  echo simpleExec("sudo snap refresh core")

proc installCertbot(): void =
  installSnap()
  echo simpleExec("sudo snap install --classic certbot")

proc installNginx() =
  echo simpleExec("sudo apt-get update")
  echo simpleExec("sudo apt-get install -y nginx")

when isMainModule:
  echo "hey hey hey"
  installNginx()
  installCertbot()
  let image = "gcr.io/kubernetes-221218/personal-website:travis-9a64ae5"
  let containerPort = 80
  let host = "thomasnelson.me"
  let c2 = Container(name: "tnelson-personal-website", image: image, containerPort: containerPort, host: host)
  echo fmt"{c2.name} is running? {c2.isRunning}"
  if not c2.isRunning:
    c2.createContainer
  c2.createNginxConfig()

