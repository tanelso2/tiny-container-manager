import
    tiny_container_manager/container

proc testContainer*(): Container =
  Container(name: "test",
            image: "nginx:latest",
            containerPort: 80,
            host: "example.com")