// Managed readback across an explicitly requested relocation cycle.
import std.runtime.*

class Payload {
    let id: Int64
    init(id: Int64) { this.id = id }
}
class Slot {
    var ref: Payload
    init(p: Payload) { ref = p }
}

main(): Int64 {
    let count: Int64 = 16384
    let slots = Array<Slot>(count, { i => Slot(Payload(i)) })
    // Publish both generations through real heap stores, leaving ordinary
    // garbage and live references for the collector to relocate.
    for (i in 0..count) {
        slots[i].ref = Payload(i + count)
    }
    gc(heavy: true)
    var checksum: Int64 = 0
    for (i in 0..count) {
        let value = slots[i].ref.id
        if (value != i + count) { return 41 }
        checksum += value
    }
    let expected = count * count + count * (count - 1) / 2
    println("PRELOADED_READBACK=${checksum} expected=${expected}")
    if (checksum != expected) { return 42 }
    return 0
}
