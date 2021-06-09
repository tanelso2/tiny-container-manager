import
  strformat,
  os,
  strutils,
  sequtils,
  sugar,
  tiny_container_manager/container,
  tiny_container_manager/shell_utils


let email = "tanelso2@gmail.com"

proc runCertbotForAll(containers: seq[Container]) =
  var domainFlags = ""
  let domains = containers.map(proc(c: Container): string = c.host)
  let domainsWithFlags = domains.map((x) => fmt"-d {x}")
  let d = domainsWithFlags.join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {d} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()

proc isConfigFile(filename: string): bool =
  # TODO
  return true


proc getContainerConfigs(directory: string): seq[Container] =
  discard directory.existsOrCreateDir
  var containers: seq[Container] = @[]
  for path in walkFiles(fmt"{directory}/*"):
    echo fmt"walking down {path}"
    if path.isConfigFile():
      containers.add(path.parseContainer())
  echo fmt"containers is {containers}"
  return containers


proc mainLoop() =
  installNginx()
  installCertbot()
  let configDir = "/opt/tiny-container-manager"
  while true:
    let containers = getContainerConfigs(configDir)
    for c in containers:
      c.ensureContainer()
    echo "sleep 15".simpleExec()


# proc testLoop() =
#   echo "hey hey hey"
#   installNginx()
#   installCertbot()
#   let image = "gcr.io/kubernetes-221218/personal-website:travis-9a64ae5"
#   let containerPort = 80
#   let host = "thomasnelson.me"
#   let c2 = Container(name: "tnelson-personal-website", image: image, containerPort: containerPort, host: host)
#   echo fmt"{c2.name} is running? {c2.isRunning}"
#   c2.ensureContainer

# proc testGetConfig() =
#   echo "Testing reading the config"
#   discard getContainerConfigs("/opt/tiny-capn")

when isMainModule:
  #testLoop()
  #testGetConfig()
  mainLoop()
