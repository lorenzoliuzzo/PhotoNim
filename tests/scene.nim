import std/unittest
import ../src/[scene, shape, geometry, color, pcg, material]

from std/sequtils import toSeq

#---------------------------------------#
#           Scene test suite            #
#---------------------------------------#
suite "Scene":

    setup:
        let
            rs: RandomSetup = (42.uint64, 54.uint64) 
            mat = newMaterial(newDiffuseBRDF(newUniformPigment(WHITE)))

            tri1 = newTriangle(
                [newPoint3D(0, -2, 0), newPoint3D(2, 1, 1), newPoint3D(0, 3, 0)],  mat
                )

            tri2 = newTriangle(
                [newPoint3D(0, -2, 0), newPoint3D(2, 1, 1), newPoint3D(0, 3, 0)], 
                mat, transformation = newTranslation(newVec3(1, 1, -2))
                )

            sc1 = newScene(BLACK, @[tri1, tri2], tkBinary, 1, rs)
            sc2 = newScene( newColor(1, 0.3, 0.7), @[
                    newSphere(ORIGIN3D, 3, mat), 
                    newUnitarySphere(newPoint3D(4, 4, 4), mat)
                    ], tkBinary, 1, rs
                )

            sc3 = newScene(BLACK, @[
                    newUnitarySphere(newPoint3D(3, 3, 3), mat), tri1
                ], tkBinary, 1, rs)
    
    teardown:
        discard rs
        discard mat
        discard sc1
        discard sc2
        discard sc3
        discard tri1
        discard tri2

    
    test "newScene proc":
        # Checking newScene proc

        # First scene --> only triangles
        check sc1.bgColor == BLACK
        check sc1.tree.handlers.len == 2
        check sc1.tree.handlers[0].shape.kind == skTriangle and sc1.tree.handlers[1].shape.kind == skTriangle
        check areClose(sc1.tree.handlers[0].shape.vertices[0], newPoint3D(0, -2, 0))
        check areClose(apply(sc1.tree.handlers[1].transformation, sc1.tree.handlers[1].shape.vertices[0]), newPoint3D(1, -1, -2))

        # Second scene --> only Spheres
        check sc2.bgColor == newColor(1, 0.3, 0.7)
        check sc2.tree.handlers.len == 2
        check sc2.tree.handlers[0].shape.kind == skSphere and sc2.tree.handlers[1].shape.kind == skSphere
        check areClose(sc2.tree.handlers[0].shape.radius, 3)
        check areClose(sc2.tree.handlers[1].shape.radius, 1)
        check areClose(apply(sc2.tree.handlers[0].transformation, ORIGIN3D), ORIGIN3D)
        check areClose(apply(sc2.tree.handlers[1].transformation, ORIGIN3D), newPoint3D(4, 4, 4))

        # Third scene --> one Sphere and one Triangle
        # Checking newScene proc
        check sc3.bgColor == BLACK
        check sc3.tree.handlers.len == 2
        check sc3.tree.handlers[0].shape.kind == skSphere and sc3.tree.handlers[1].shape.kind == skTriangle
        check areClose(sc3.tree.handlers[0].shape.radius, 1)
        check areClose(apply(sc3.tree.handlers[0].transformation, ORIGIN3D), newPoint3D(3, 3, 3))
        check areClose(sc3.tree.handlers[1].shape.vertices[0], newPoint3D(0, -2, 0))


    test "newBVHNode proc":
        var sceneTree: BVHNode

        # First scene, only triangles
        sceneTree = newBVHNode(@[tri1, tri2].pairs.toSeq, 2, 1, rs)
        check areClose(sceneTree.aabb.min, newPoint3D(0, -2, -2))
        check areClose(sceneTree.aabb.max, newPoint3D(3, 4, 1))


        # Second scene, only spheres
        sceneTree = newBVHNode(@[
                newSphere(ORIGIN3D, 3, mat), 
                newUnitarySphere(newPoint3D(4, 4, 4), mat)
                ].pairs.toSeq,
            2, 1, rs
        )
        check areClose(sceneTree.aabb.min, newPoint3D(-3, -3, -3))
        check areClose(sceneTree.aabb.max, newPoint3D(5, 5, 5))


        # Third scene, one sphere and one triangle
        sceneTree = newBVHNode(
            @[newUnitarySphere(newPoint3D(3, 3, 3), mat), tri1].pairs.toSeq
            , 2, 1, rs
        )
        check areClose(sceneTree.aabb.min, newPoint3D(0, -2, 0))
        check areClose(sceneTree.aabb.max, newPoint3D(4, 4, 4))
