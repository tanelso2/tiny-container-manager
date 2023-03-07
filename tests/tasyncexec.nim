import
    asyncdispatch,
    asyncfutures,
    sugar,
    tiny_container_manager/procinfo,
    tiny_container_manager/shell_utils

let fut1 = "systemctl status --no-pager nginx.service".asyncExec()
let fut2 = "echo hello".asyncExec()
let fut3 = "ls".asyncExec()

echo countOpenFiles()

let x = waitFor all(fut1, fut2, fut3)
for s in x:
    echo s

echo countOpenFiles()
discard waitFor(asyncExec("sudo service nginx status"))
echo countOpenFiles()