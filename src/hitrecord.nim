import geometry, scene, ray

from std/algorithm import sort, sorted, SortOrder
from std/sequtils import concat, mapIt, filterIt, keepItIf


type 
    HitInfo[T] = tuple[hit: T, t: float32] 

    HitPayload* = ref object
        info*: HitInfo[ObjectHandler]
        pt*: Point3D 
        rayDir*: Vec3


proc newHitInfo*(hit: BVHNode, ray: Ray): HitInfo[BVHNode] {.inline.} = (hit, ray.getBoxHit(hit.aabb))
proc newHitInfo*(hit: ObjectHandler, ray: Ray): HitInfo[ObjectHandler] {.inline.} = (hit, ray.getBoxHit(hit.aabb))

proc `<`[T](a, b: HitInfo[T]): bool {.inline.} = a.t < b.t


proc newHitPayload*(hit: ObjectHandler, ray: Ray, t: float32): HitPayload {.inline.} =
    HitPayload(info: (hit, t), pt: ray.at(t), rayDir: ray.dir)

proc splitted[T](inSeq: seq[T], condition: proc(t: T): bool): (seq[T], seq[T]) =
    for element in inSeq:
        if condition(element): result[0].add element
        else: result[1].add element


proc getClosestHit*(tree: BVHTree, worldRay: Ray): HitPayload =

    proc updateClosestHit(tCurrentHit: float32, handler: ObjectHandler, worldRay: Ray): HitPayload =
        let localInvRay = worldRay.transform(handler.transformation.inverse) 

        case handler.kind
        of hkShape: 
            let tShapeHit = localInvRay.getShapeHit(handler.shape)
            if tShapeHit >= tCurrentHit: return nil 
            result = newHitPayload(handler, localInvRay, tShapeHit)
            
        of hkMesh:
            let meshHit = handler.mesh.getClosestHit(localInvRay)
            if meshHit.info.hit.isNil or meshHit.info.t >= tCurrentHit: return nil
            result = meshHit
            result.pt = apply(handler.transformation, meshHit.pt)

        of hkCSG:
            case handler.csg.kind
            of csgkUnion:
                let csgHit = handler.csg.tree.getClosestHit(localInvRay)
                if csgHit.info.hit.isNil or csgHit.info.t >= tCurrentHit: return nil
                result = csgHit; result.pt = apply(handler.transformation, csgHit.pt)


    result = HitPayload(info: (hit: nil, t: Inf.float32), pt: worldRay.origin, rayDir: worldRay.dir)

    let planeSH = tree.planeHandlers
    var tPlane: float32
    if planeSH.len != 0:
        for i in planeSH:
            tPlane = worldRay.transform(i.transformation.inverse).getShapeHit(i.shape)
            if tPlane < result.info.t:
                result = updateClosestHit(result.info.t, i, worldRay) 

    let tRootHit = worldRay.getBoxHit(tree.root.aabb)
    if tRootHit == Inf and result.info.t == Inf: return result

    var nodesHitStack = newSeqOfCap[HitInfo[BVHNode]](tree.kind.int * tree.kind.int * tree.kind.int)
    nodesHitStack.add (tree.root, tRootHit) 

    while nodesHitStack.len > 0:    

        let currentNodeHitInfo = nodesHitStack.pop    
        case currentNodeHitInfo.hit.kind
        of nkLeaf:

            let (firstHandlersToVisit, secondHandlersToVisit) = currentNodeHitInfo.hit.indexes
                .mapIt(newHitInfo(tree.handlers[it], worldRay))
                .splitted(proc(info: HitInfo[ObjectHandler]): bool = info.hit.aabb.contains(worldRay.origin))

            var handlersHitStack = newSeqOfCap[HitInfo[ObjectHandler]](tree.mspl)
            handlersHitStack = concat(
                secondHandlersToVisit.filterIt(it.t < result.info.t).sorted(SortOrder.Descending),
                firstHandlersToVisit.sorted(SortOrder.Descending)
            )

            while handlersHitStack.len > 0:
                let updatedHit = updateClosestHit(result.info.t, handlersHitStack.pop.hit, worldRay)
                if updatedHit.isNil: continue 

                result = updatedHit
                handlersHitStack.keepItIf(it.t < result.info.t)

        of nkBranch: 

            let (firstNodesToVisit, secondNodesToVisit) = currentNodeHitInfo.hit.children
                .mapIt(newHitInfo(it, worldRay))
                .splitted(proc(info: HitInfo[BVHNode]): bool = info.hit.aabb.contains(worldRay.origin))

            if firstNodesToVisit.len > 0:
                let (leafsToVisit, branchesToVisit) = firstNodesToVisit
                    .splitted(proc(node: HitInfo[BVHNode]): bool = node.hit.kind == nkLeaf)
                
                var handlersHitStack = concat(leafsToVisit.mapIt(it.hit.indexes))
                    .mapIt(newHitInfo(tree.handlers[it], worldRay))
                    .filterIt(it.t < result.info.t)
                    .sorted(SortOrder.Descending)

                while handlersHitStack.len > 0:
                    let updatedHit = updateClosestHit(result.info.t, handlersHitStack.pop.hit, worldRay)
                    if updatedHit.isNil: continue 
                    
                    result = updatedHit
                    handlersHitStack.keepItIf(it.t < result.info.t)

                nodesHitStack.add branchesToVisit
                    .sorted(SortOrder.Descending)
                    .mapIt((hit: it.hit, t: -1.0.float32))

            nodesHitStack.add secondNodesToVisit.filterIt(it.t < result.info.t)
            
        nodesHitStack.sort(SortOrder.Descending)