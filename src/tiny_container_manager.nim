import
  asynchttpserver,
  asyncdispatch,
  httpclient,
  strformat,
  os,
  prometheus as prom,
  strutils,
  sequtils,
  sugar,
  tiny_container_manager/container,
  tiny_container_manager/metrics as metrics,
  tiny_container_manager/shell_utils

let email = "tanelso2@gmail.com"

let client = newHttpClient(maxRedirects=0)

proc runCertbotForAll(containers: seq[Container]) =
  var domainFlags = ""
  let domains = containers.map(proc(c: Container): string = c.host)
  let domainsWithFlags = domains.map((x) => fmt"-d {x}")
  let d = domainsWithFlags.join(" ")
  let certbotCmd = fmt"certbot run --nginx -n --keep {d} --email {email} --agree-tos"
  echo certbotCmd
  echo certbotCmd.simpleExec()

proc isConfigFile(filename: string): bool =
  result = filename.endsWith(".yaml") or filename.endsWith(".yml")

proc getContainerConfigs(directory: string): seq[Container] =
  discard directory.existsOrCreateDir
  var containers: seq[Container] = @[]
  for path in walkFiles(fmt"{directory}/*"):
    echo fmt"walking down {path}"
    if path.isConfigFile():
      containers.add(path.parseContainer())
  echo fmt"containers is {containers}"
  return containers

proc testWebsiteWithCurl(website: string) =
  let httpUrl = fmt"http://{website}"
  let httpsUrl = fmt"https://{website}"
  let httpOut = fmt"curl {httpUrl}".simpleExec()
  let httpsOut = fmt"curl {httpsUrl}".simpleExec()


proc checkDiskUsage() =
  let x = "df -i".simpleExec()
  let y: string = x.split("\n").filter(z => z.contains("/dev/vda1"))[0]


proc mainLoop() =
  echo "Starting loop"
  installNginx()
  installCertbot()
  setupFirewall()
  let configDir = "/opt/tiny-container-manager"
  while true:
    let containers = getContainerConfigs(configDir)
    for c in containers:
      c.ensureContainer()
    echo "sleep 30".simpleExec()


proc testLoop() =
  echo "hey hey hey"
  let image = "gcr.io/kubernetes-221218/personal-website:travis-9a64ae5"
  let containerPort = 80
  let host = "thomasnelson.me"
  let c2 = Container(name: "tnelson-personal-website", image: image, containerPort: containerPort, host: host)
  echo fmt"{c2.name} is running? {c2.isHealthy}"
  c2.ensureContainer

# proc testGetConfig() =
#   echo "Testing reading the config"
#   discard getContainerConfigs("/opt/tiny-capn")
#
#
proc main() =
  var loopThread: Thread[void]
  createThread(loopThread, mainLoop)

  while true:
    echo "hello from other thread"
    echo "sleep 5".simpleExec()
  # Running the webserver on the same async dispatch loop seems
  # risky? Especially because I don't think my shell_utils are async safe


when isMainModule:
  #testLoop()
  #testGetConfig()
  #testLoop()
  main()
  # metrics.uptimeMetric.labels("blahblah.com").inc()
  # echo metrics.getOutput()
