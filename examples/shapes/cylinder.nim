import PhotoNim

from std/times import cpuTime
from std/strformat import fmt
from std/streams import newFileStream, close
from std/osproc import execCmd


let 
    timeStart = cpuTime()
    (width, height) = (1600, 900)
    filename = "assets/images/examples/cylinder"

var 
    cam = newPerspectiveCamera(width / height, 1.0, newTranslation(newVec3(float32 -2, 0, 0)))
    tracer = newImageTracer(width, height, cam, sideSamples = 2)
    scenary = newWorld()

scenary.shapes.add newCylinder(transform = newTranslation(newVec3(float32 0.0, 0.0, 1.5)))
scenary.shapes.add newUnitarySphere(center=newPoint3D(0.0, 0.0, 0.0))

tracer.fire_all_rays(scenary, proc(ray: Ray): Color = newColor(1.0, 0.0, 1.0))

echo fmt"Successfully rendered image in {cpuTime() - timeStart} seconds."

var stream = newFileStream(filename & ".pfm", fmWrite)
stream.writePFM tracer.image
stream.close

pfm2png(filename & ".pfm", filename & ".png", 0.18, 1.0, 0.1)
discard execCmd fmt"open {filename}.png"