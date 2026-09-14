package b17global
import std.sync.*

public class Box {
    public var value: Int64
    public init(value: Int64) { this.value = value }
}
public struct Payload {
    public var first: Box
    public var second: Box
    public var third: Box
    public init(value: Box) { first = value; second = value; third = value }
}
public var globalRoot: Box = Box(1)
public var globalPayload: Payload = Payload(Box(3))
public let atomicRoot = AtomicReference<Box>(Box(5))

public func replaceGlobal(next: Box): Unit { globalRoot = next }
public func replaceStruct(next: Payload): Unit { globalPayload = next }
public func replaceAtomic(next: Box): Unit { atomicRoot.store(next) }
main(): Int64 {
    let next = Box(9)
    replaceGlobal(next)
    replaceStruct(Payload(next))
    replaceAtomic(next)
    println(globalRoot.value + globalPayload.first.value + atomicRoot.load().value)
    return 0
}
