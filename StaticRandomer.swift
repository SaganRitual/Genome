// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation
import GameplayKit

class StaticRandomer {
    typealias Element = Float

    enum Mode { case gaussian, random }

    let distributionRange = -10_000..<10_000

    let gaussianSamples: UnsafeBufferPointer<Element>
    let randomSamples: UnsafeBufferPointer<Element>

    let cSamplesToGenerate: Int

    deinit {
        gaussianSamples.deallocate()
        randomSamples.deallocate()
    }

    func gaussrand(_ cIterations: Int) -> Double {
        let c = Double(cIterations)

        return ((0..<cIterations).reduce(Double.zero) { subtotal, _ in
            subtotal + Double.random(in: -1...1)
        } - c / 2) / sqrt(c / 12)
    }

    init(_ cSamplesToGenerate: Int) {
        var gs = UnsafeMutableBufferPointer<Element>.allocate(capacity: cSamplesToGenerate)
        var rs = UnsafeMutableBufferPointer<Element>.allocate(capacity: cSamplesToGenerate)

        gaussianSamples = UnsafeBufferPointer(gs)
        randomSamples = UnsafeBufferPointer(rs)

        self.cSamplesToGenerate = cSamplesToGenerate

        let gaussianDistribution = GKGaussianDistribution(
            lowestValue: distributionRange.lowerBound + 1,
            highestValue: distributionRange.upperBound - 1
        )

        let randomDistribution = GKRandomDistribution(
            lowestValue: distributionRange.lowerBound + 1,
            highestValue: distributionRange.upperBound - 1
        )

        (0..<cSamplesToGenerate).forEach { sampleSS in
            gs[sampleSS] = Element(gaussianDistribution.nextInt())
            rs[sampleSS] = Element(randomDistribution.nextInt())
        }

        // Various hoop-jumping I've done to get smooth gaussian samples.
        // Nothing works, they're noisy as hell, the best thing to do is
        // generate a lot of them ahead of time and normalize them
        let mustBeLessThan1: Float = 1 + 1e-5
        let gmax = vDSP.maximumMagnitude(gs) * mustBeLessThan1
        let rmax = vDSP.maximumMagnitude(rs) * mustBeLessThan1

        vDSP.divide(gs, gmax, result: &gs)
        vDSP.divide(rs, rmax, result: &rs)
    }

    func getBuffer(_ mode: Mode, cElements: Int) -> UnsafeBufferPointer<Element> {
        precondition(cElements <= cSamplesToGenerate)
        let start = Int.random(in: 0..<(cSamplesToGenerate - cElements))
        let end = start + cElements

        switch mode {
        case .gaussian: return UnsafeBufferPointer(rebasing: gaussianSamples[start..<end])
        case .random:   return UnsafeBufferPointer(rebasing: randomSamples[start..<end])
        }
    }
}

struct StaticRandomerIterator: IteratorProtocol {
    typealias Element = StaticRandomer.Element

    var currentIx: Int
    let samples: UnsafeBufferPointer<Element>

    init(randomer: StaticRandomer, _ mode: StaticRandomer.Mode) {
        switch mode {
        case .gaussian: samples = randomer.gaussianSamples
        case .random: samples = randomer.randomSamples
        }

        self.currentIx = Int.random(in: 0..<samples.count)
    }

    mutating func next() -> Element? {
        defer { currentIx = (currentIx + 1) % samples.count }
        return samples[currentIx]
    }

    mutating func bool() -> Bool { next()! < 0 }
    mutating func positive() -> Element { abs(next()!) }

    mutating func inRange(_ range: Range<Int>) -> Int {
        let offset: Element = abs(next()!) * Element(range.count)
        return Int(offset) + range.lowerBound
    }

    mutating func inRange(_ range: Range<Element>) -> Element {
        let offset = abs(next()!) * Element(range.upperBound - range.lowerBound)
        return offset + Element(range.lowerBound)
    }
}
