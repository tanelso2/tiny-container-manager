import
    jester,
    strformat,
    ./auth,
    ./json_utils,
    ./metrics,
    ./container,
    nim_utils/logline

var debugMode* = false

template swallowErrors*(body: untyped) =
  try:
    body
  except:
    if debugMode:
      resp Http500, fmt"Something bad happened: {getCurrentExceptionMsg()}", contentType = "text/plain"
    else:
      resp Http500, fmt"An error occurred", contentType = "text/plain"

template respText*(s: string) =
  resp s, contentType = "text/plain"

template respOk* =
  respText "OK"

router application:
  get "/metrics":
    respText metrics.getOutput()
  get "/containers":
    swallowErrors:
      authRequired:
        let containers = getContainerConfigs()
        jsonResp containers
  post "/container":
    swallowErrors:
      authRequired:
        logInfo fmt"Got a POST"
        let spec = request.jsonBody(Container)
        try:
          spec.add()
        except ErrAlreadyExists:
          resp Http409, fmt"A container with name {spec.name} already exists"
        respOk
  delete "/container/@name":
    swallowErrors:
      authRequired:
        let name = @"name"
        try:
          deleteNamedContainer(name)
        except ErrDoesNotExist:
          resp Http404
        resp Http204
  patch "/container/@name/image":
    swallowErrors:
      authRequired:
        let name = @"name"
        let maybeContainer = getContainerByName(name)
        if maybeContainer.isNone():
          resp Http404
        let c = maybeContainer.get()
        let newImage = request.body
        let newC = Container(name: c.name,
                             image: newImage,
                             host: c.host,
                             containerPort: c.containerPort)
        newC.writeFile()
        respOk

proc runServer* =
  logInfo "Starting server"
  let portNum = 6969
  let port = Port(portNum)
  let settings = newSettings(port=port)
  var jester = initJester(application, settings=settings)
  jester.serve()