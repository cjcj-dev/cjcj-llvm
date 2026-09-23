class Leaf {
    let value: Int64
    init(v: Int64) { value = v }
}
class Box {
    var ref: Leaf
    init(v: Leaf) { ref = v }
}
func choose(flag: Bool, left: Box, right: Box): Box {
    if (flag) { return left }
    return right
}
main(): Int64 {
    let first = Leaf(17)
    let second = Leaf(934)
    let local = Box(first)
    let boxes = Array<Box>(2, { _ => Box(first) })
    var sum: Int64 = 0
    for (i in 0..4) {
        let target = choose(i % 2 == 0, local, boxes[i % 2])
        target.ref = second
        sum += target.ref.value
    }
    println("B3_READBACK=${sum}")
    if (sum != 3736) { return 41 }
    return 0
}
