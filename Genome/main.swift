// We are a way for the cosmos to know itself. -- C. Sagan

import Foundation

print("Hello, World!")

enum World {
    static let cSamples = 10_000
    static let staticRandomer = StaticRandomer(cSamples)
}

func testBellCurveishness() {
    // Output from this loop should look bell-curve-ish.
    // Don't forget the generator is really noisy
    var iter = StaticRandomerIterator(randomer: World.staticRandomer, .gaussian)
    let cBuckets = 10
    var buckets = [Double](repeating: 0, count: cBuckets)

    for _ in 0..<10_000 {
        let raw = iter.next()!
        let sample = Double(raw + 1) / 2  // -1..<1 scaled to 0..<1
        let bucket = Int(sample * Double(cBuckets))
        buckets[bucket] += 1
    }

    print(buckets)
}

func testRandomLookingness() {
    // Output from this loop should look like random (similar counts in each bucket)
    var iter = StaticRandomerIterator(randomer: World.staticRandomer, .random)
    let cBuckets = 10
    var buckets = [Double](repeating: 0, count: cBuckets)

    for _ in 0..<10_000 {
        let raw = iter.next()!
        let sample = Double(raw + 1) / 2  // -1..<1 scaled to 0..<1
        let bucket = Int(sample * Double(cBuckets))
        buckets[bucket] += 1
    }

    print(buckets)
}

testBellCurveishness()
testRandomLookingness()
