# Package
version       = "1.0.1"
author        = "lorenzoliuzzo & Negrini085"
description   = "A CPU raytracer written in Nim"
license       = "GPL-3.0-or-later"
bin           = @["PhotoNim"]

# Dependencies
requires "nim >= 2.0"
requires "docopt >= 0.6"
requires "nimPNG >= 0.3"


# Tasks
task build, "Build the `PhotoNim` executable\n":
  exec "nim c -d:release PhotoNim.nim"


task demo, """Run the `PhotoNim` demo

    Usage: 
            nimble demo (OnOff|Flat|Path)

    Options:
            persp | ortho          Camera kind: Perspective or Orthogonal
            OnOff | Flat | Path    Renderer kind: OnOff (only shows hit), Flat (flat renderer), Path (path tracer)
""":

    var 
        demoCommand = "nim c -d:release --hints:off -r PhotoNim.nim"
        commands: seq[string]

    for i in 0..paramCount(): commands.add paramStr(i)

    for i in commands.find("demo")..<commands.len: 

      if i == commands.find("demo"):
        demoCommand.add(" " & "rend")

      elif i == (commands.find("demo") + 1):
        demoCommand.add(" " & paramStr(i))
        demoCommand.add(" " & "examples/demo/demo.txt")
        demoCommand.add(" " & "examples/demo/images/demo" & paramStr(i))

      else:
        demoCommand.add(" " & paramStr(i))
      
    if commands[(commands.len - 1)] == "demo":
      echo "Need to specify renderer kind, choose between (OnOff|Flat|Path)"
      return

    if not (commands[(commands.len - 1)] in ["Path", "OnOff", "Flat"]):
      echo "Usage: nimble demo (OnOff|Flat|Path)"
      return

    exec demoCommand


task examples, "Run the `PhotoNim` examples":
  exec "nim c -d:release --hints:off -r examples/shapes/nspheres.nim"
  exec "nim c -d:release --hints:off -r examples/csg/csgUnion.nim"
  exec "nim c -d:release --hints:off -r examples/meshes/dragon.nim"
  exec "rm examples/shapes/nspheres examples/csg/csgUnion examples/meshes/dragon"


task test, "Run the `PhotoNim` tests":
  withDir "tests":   
    exec "nim c -d:release --hints:off -r pcg.nim"
    exec "nim c -d:release --hints:off -r geometry.nim" 
    exec "nim c -d:release --hints:off -r color.nim" 
    exec "nim c -d:release --hints:off -r hdrimage.nim"    
    exec "nim c -d:release --hints:off -r scene.nim"
    exec "nim c -d:release --hints:off -r shape.nim"
    exec "nim c -d:release --hints:off -r csg.nim"
    exec "nim c -d:release --hints:off -r ray.nim"
    exec "nim c -d:release --hints:off -r hitrecord.nim"
    exec "nim c -d:release --hints:off -r renderer.nim"
    exec "nim c -d:release --hints:off -r camera.nim"
    exec "nim c -d:release --hints:off -r lexer.nim"
    exec "nim c -d:release --hints:off -r parser.nim"
    exec "rm pcg geometry color hdrimage scene shape csg ray hitrecord renderer camera lexer parser"
