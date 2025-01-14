import geometry, material, scene

from std/math import sgn, floor, arccos, arctan2, PI, pow, sqrt
from std/sequtils import mapIt, concat


proc getAABB*(shape: Shape): AABB {.inline.} =
    ## Get the local AABB for a `Shape`.

    case shape.kind
    of skAABox: shape.aabb
    of skTriangle: newAABB(shape.vertices)
    of skSphere: (newPoint3D(-shape.radius, -shape.radius, -shape.radius), newPoint3D(shape.radius, shape.radius, shape.radius))
    of skCylinder: (newPoint3D(-shape.R, -shape.R, shape.zSpan.min), newPoint3D(shape.R, shape.R, shape.zSpan.max))
    of skPlane: (newPoint3D(-Inf, -Inf, -Inf), newPoint3D(Inf, Inf, 0))
    of skEllipsoid: (newPoint3D(-shape.axis.a,-shape.axis.b,-shape.axis.c), newPoint3D(shape.axis.a, shape.axis.b, shape.axis.c))
    
proc getVertices(shape: Shape): seq[Point3D] {.inline.} = 
    case shape.kind
    of skAABox: shape.aabb.getVertices
    of skTriangle: shape.vertices
    else: shape.getAABB.getVertices

proc getWorldAABB*(shape: Shape, trans: Transformation): AABB = 
    # Procedure to get a World AABB, in order to be sure that the plane is actually
    # encapsulated in its aabb, we just want to set it as world itself (we do one more check, 
    # but we are sure about the solution we will find)

    let kind = shape.kind
    case kind
    of skPlane:
        if trans.kind == tkIdentity:
            return shape.getAABB
        return (newPoint3D(-Inf, -Inf, -Inf), newPoint3D(Inf, Inf, Inf))
    else:
        return newAABB shape.getVertices.mapIt(apply(trans, it))


proc newShapeHandler*(shape: Shape, material: Material, transformation: Transformation): ObjectHandler {.inline.} =
    ObjectHandler(
        kind: hkShape, 
        aabb: getWorldAABB(shape, transformation),
        transformation: transformation, 
        shape: shape, 
        material: material
    )

proc newSphere*(center: Point3D, radius: float32; material: Material): ObjectHandler {.inline.} =   
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skSphere`, a `Material` and a `Transformation`.
    newShapeHandler(Shape(kind: skSphere, radius: radius), material, if not areClose(center, ORIGIN3D): newTranslation(center) else: Transformation.id)

proc newUnitarySphere*(center: Point3D; material: Material): ObjectHandler {.inline.} = 
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skSphere`, a `Material` and a `Transformation`.
    newShapeHandler(Shape(kind: skSphere, radius: 1.0), material, if not areClose(center, ORIGIN3D): newTranslation(center) else: Transformation.id)

proc newPlane*(material: Material, transformation = Transformation.id): ObjectHandler {.inline.} = 
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skPlane`, a `Material` and a `Transformation`.
    newShapeHandler(Shape(kind: skPlane), material, transformation)

proc newBox*(aabb: Interval[Point3D], material: Material, transformation = Transformation.id): ObjectHandler {.inline.} =
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skBox`, a `Material` and a `Transformation`.
    newShapeHandler(Shape(kind: skAABox, aabb: aabb), material, transformation)

proc newTriangle*(vertices: array[3, Point3D]; material: Material, transformation = Transformation.id): ObjectHandler {.inline.} = 
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skTriangle`, a `Material` and a `Transformation`.
    newShapeHandler(Shape(kind: skTriangle, vertices: @vertices), material, transformation)

proc newCylinder*(R = 1.0, zMin = 0.0, zMax = 1.0, phiMax = 2.0 * PI; material: Material, transformation = Transformation.id): ObjectHandler {.inline.} =
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skCylinder`, a `Material` and a `Transformation`.
    newShapeHandler(Shape(kind: skCylinder, R: R, zSpan: (zMin.float32, zMax.float32), phiMax: phiMax), material, transformation)

proc newEllipsoid*(a, b, c: SomeNumber, material: Material,transformation = Transformation.id): ObjectHandler = 
    ## Creare a new `ObjectHandler` from a `Shape` of kind `skEllipsoid`, a `Material` and a `Transformation`.
    newShapeHandler(
        Shape(
            kind: skEllipsoid, axis:(
                    a: when a is float32: a else: a.float32, 
                    b: when b is float32: b else: b.float32, 
                    c: when c is float32: c else: c.float32
                )
            ),
        material, transformation
    )

proc getUV*(shape: Shape; pt: Point3D): Point2D = 
    ## Get the UV mapping of a `Shape` from a `Point2D`.

    case shape.kind
    of skAABox:
        if pt.x == shape.aabb.min.x: 
            return newPoint2D((pt.y - shape.aabb.min.y) / (shape.aabb.max.y - shape.aabb.min.y), (pt.z - shape.aabb.min.z) / (shape.aabb.max.z - shape.aabb.min.z))
        elif pt.x == shape.aabb.max.x: 
            return newPoint2D((pt.y - shape.aabb.min.y) / (shape.aabb.max.y - shape.aabb.min.y), (pt.z - shape.aabb.min.z) / (shape.aabb.max.z - shape.aabb.min.z))
        elif pt.y == shape.aabb.min.y: 
            return newPoint2D((pt.x - shape.aabb.min.x) / (shape.aabb.max.x - shape.aabb.min.x), (pt.z - shape.aabb.min.z) / (shape.aabb.max.z - shape.aabb.min.z))
        elif pt.y == shape.aabb.max.y: 
            return newPoint2D((pt.x - shape.aabb.min.x) / (shape.aabb.max.x - shape.aabb.min.x), (pt.z - shape.aabb.min.z) / (shape.aabb.max.z - shape.aabb.min.z))
        elif pt.z == shape.aabb.min.z: 
            return newPoint2D((pt.x - shape.aabb.min.x) / (shape.aabb.max.x - shape.aabb.min.x), (pt.y - shape.aabb.min.y) / (shape.aabb.max.y - shape.aabb.min.y))
        elif pt.z == shape.aabb.max.z: 
            return newPoint2D((pt.x - shape.aabb.min.x) / (shape.aabb.max.x - shape.aabb.min.x), (pt.y - shape.aabb.min.y) / (shape.aabb.max.y - shape.aabb.min.y))
        else:
            return newPoint2D(0, 0)

    of skTriangle:
        let 
            (x_ptA, x_BA, x_CA) = ((pt.x - shape.vertices[0].x), (shape.vertices[1].x - shape.vertices[0].x), (shape.vertices[2].x - shape.vertices[0].x))
            (y_ptA, y_BA, y_CA) = ((pt.y - shape.vertices[0].y), (shape.vertices[1].y - shape.vertices[0].y), (shape.vertices[2].y - shape.vertices[0].y))
            (u_num, u_den) = (x_ptA * y_CA - y_ptA * x_CA, xBA * y_CA - y_BA * x_CA)
            (v_num, v_den) = (x_ptA * y_BA - y_ptA * xBA, x_CA * y_BA - y_CA * xBA)
        return newPoint2D(u_num / u_den, v_num / v_den)
        
    of skSphere:
        var u = arctan2(pt.y, pt.x) / (2 * PI)
        if u < 0.0: u += 1.0
        return newPoint2D(u, arccos(pt.z) / PI)

    of skCylinder:
        var phi = arctan2(pt.y, pt.x)
        if phi < 0.0: phi += 2.0 * PI
        return newPoint2D(phi / shape.phiMax, (pt.z - shape.zSpan.min) / (shape.zSpan.max - shape.zSpan.min))

    of skPlane: return newPoint2D(pt.x - floor(pt.x), pt.y - floor(pt.y))

    of skEllipsoid: 
        let scal = newScaling(1/shape.axis.a, 1/shape.axis.b, 1/shape.axis.c)
        return getUV(Shape(kind: skSphere, radius: 1), apply(scal, pt))


proc getNormal*(shape: Shape; pt: Point3D, dir: Vec3): Normal {.inline.} =
    ## Get the `Normal` of a `Shape` from a `Point3D` and a `Vec` representing the direction vector.

    case shape.kind
    of skAABox:
        if   areClose(pt.x, shape.aabb.min.x, 1e-6) or areClose(pt.x, shape.aabb.max.x, 1e-6): result = Normal(eX)
        elif areClose(pt.y, shape.aabb.min.y, 1e-6) or areClose(pt.y, shape.aabb.max.y, 1e-6): result = Normal(eY)
        elif areClose(pt.z, shape.aabb.min.z, 1e-6) or areClose(pt.z, shape.aabb.max.z, 1e-6): result = Normal(eZ)
        else: quit "Something went wrong in calculating the normal for an AABox."
        return sgn(-dot(result.Vec3, dir)) * result

    of skTriangle:
        let cross = cross(shape.vertices[1] - shape.vertices[0], shape.vertices[2] - shape.vertices[0])
        return sgn(-dot(cross, dir)) * newNormal(cross)
        
    of skSphere: return sgn(-dot(pt.Vec3, dir)) * newNormal(pt.x, pt.y, pt.z)

    of skCylinder: return newNormal(pt.x, pt.y, 0.0)

    of skPlane: return newNormal(0, 0, sgn(-dir[2]))

    of skEllipsoid: 
        let 
            scal = newScaling(1/shape.axis.a, 1/shape.axis.b, 1/shape.axis.c)
            nSp = getNormal(Shape(kind: skSphere, radius: 1), apply(scal, pt), apply(scal, dir).normalize)

        return apply(scal.inverse, nSp).normalize
