main(): Int64 {
    var checks = 0
    for (n in [0, 1, 7, 31, 32, 33, 63, 64, 65, 136, 4095, 4096, 4097]) {
        let data = Array<UInt8>(n + 2, repeat: b'a')
        let original = String.fromUtf8(data)
        let s = original[1..n + 1]
        if (s.size != n || s.indexOf("z").isSome() || s.indexOf(b'z').isSome()) {
            throw Exception("absent tail byte or slice boundary failed")
        }
        if (s.indexOf("a", n).isSome()) {
            throw Exception("search at size must be empty")
        }
        if (n > 0) {
            let lastData = Array<UInt8>(n, repeat: b'a')
            lastData[n - 1] = b'b'
            let last = String.fromUtf8(lastData)
            match (last.indexOf("b")) {
                case Some(index) => if (index != n - 1) { throw Exception("last byte index failed") }
                case None => throw Exception("last byte not found")
            }
        }
        checks++
    }
    println("STRING_TAIL_OK ${checks}")
    return 0
}
