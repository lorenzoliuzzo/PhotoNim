import PhotoNim

from std/times import cpuTime
from std/strformat import fmt
from std/osproc import execCmd


let 
    nSamples: int = 1
    aaSamples: int = 1
    nRays: int = 1
    depthLimit: int = 1
    rrLimit: int = 5
    rgSetUp: RandomSetUp = (7, 4)
    outFile = "assets/images/examples/meshes/airplane.png"

var 
    rg = newPCG(rgSetUp)
    handlers: seq[ObjectHandler]

let 
    lamp = newBox(
        (newPoint3D(0.5, -0.5, 1.9), newPoint3D(1.5, 0.5, 1.999)), 
        newEmissiveMaterial(
            newDiffuseBRDF(newUniformPigment(WHITE)),
            emittedRadiance = newUniformPigment(5 * WHITE)
        )
    ) 

    uwall = newBox(
        (newPoint3D(-2, -2, 2), newPoint3D(2, 2, 2)), 
        newMaterial(newDiffuseBRDF(newUniformPigment(WHITE)))
    ) 

    dwall = newBox(
        (newPoint3D(-2, -2, -2), newPoint3D(2, 2, -2)), 
        newMaterial(newDiffuseBRDF(newUniformPigment(WHITE)))
    ) 

    fwall = newBox(
        (newPoint3D(2, -2, -2), newPoint3D(2, 2, 2)), 
        newMaterial(newDiffuseBRDF(newUniformPigment(WHITE)))
    ) 

    lwall = newBox(
        (newPoint3D(-2, 2, -2), newPoint3D(2, 2, 2)), 
        newEmissiveMaterial(
            newDiffuseBRDF(newUniformPigment(GREEN)),
            emittedRadiance = newUniformPigment(0.2.float32 * GREEN)
        )
    ) 

    rwall = newBox(
        (newPoint3D(-2, -2, -2), newPoint3D(2, -2, 2)), 
        newEmissiveMaterial(
            newDiffuseBRDF(newUniformPigment(RED)),
            emittedRadiance = newUniformPigment(0.2.float32 * RED)
        )
    ) 


    box1 = newBox(
        (newPoint3D(-0.5, -1.0, -2), newPoint3D(0.5, -0.3, 0.7)), 
        newMaterial(newDiffuseBRDF(newUniformPigment(newColor(0.5, 0.5, 0.5)))),
        transformation = newComposition(newTranslation(0.5.float32 * eX), newRotation(40, axisZ))
    )

    box2 = newBox(
        (newPoint3D(-0.5, 0.9, -2), newPoint3D(0.5, 1.5, 0.4)), 
        newMaterial(newDiffuseBRDF(newUniformPigment(newColor(0.5, 0.5, 0.5)))),
        transformation = newRotation(-40, axisZ)
    )


var timeStart = cpuTime()
let airplane = newMesh(
    source = "assets/meshes/airplane.obj", 
    treeKind = tkOctonary, 
    maxShapesPerLeaf = 4, 
    newRandomSetUp(rg),
    newEmissiveMaterial(
        newDiffuseBRDF(newUniformPigment(newColor(0.8, 0.6, 0.2))),
        newUniformPigment(0.2 * newColor(0.8, 0.6, 0.2))
    ),
    transformation = newComposition(
        newTranslation(-0.3.float32 * eX - eY - 0.3.float32 * eZ), 
        newRotation(30, axisZ), newRotation(20, axisY), newRotation(10, axisX), 
        newScaling(3e-4)
    )
)

echo fmt"Successfully loaded mesh in {cpuTime() - timeStart} seconds"
timeStart = cpuTime()

handlers.add lamp
handlers.add uwall
handlers.add dwall
handlers.add fwall
handlers.add lwall
handlers.add rwall
handlers.add box1
handlers.add box2
handlers.add airplane


let
    scene = newScene(
        bgColor = BLACK, 
        handlers = handlers, 
        treeKind = tkQuaternary, 
        maxShapesPerLeaf = 2,
        newRandomSetUp(rg)
    )

    camera = newPerspectiveCamera(
        renderer = newPathTracer(nRays, depthLimit, rrLimit), 
        viewport = (600, 600), 
        distance = 1.0, 
        transformation = newTranslation(newPoint3D(-1.0, 0, 0))
    )

    image = camera.samples(scene, newRandomSetUp(rg), nSamples, aaSamples)


echo fmt"Successfully rendered image in {cpuTime() - timeStart} seconds."   
echo fmt"Image lum: {image.avLuminosity}"
image.savePNG(outFile, 0.18, 1.0, 0.1)
discard execCmd fmt"open {outFile}"