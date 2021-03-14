// We are a way for the cosmos to know itself. -- C. Sagan

import Foundation

print("Hello, World!")

enum World {
    static let cSamples = 10_000
    static let staticRandomer = StaticRandomer(cSamples)

    static func fprint(_ value: Float) -> String {
        String(format: "% .8f", value)
    }
}

testBellCurveishness()
testRandomLookingness()

let randomGenome = testAllRandomValuesGenome()
testCloneFromParent(randomGenome)
testDuplex()
