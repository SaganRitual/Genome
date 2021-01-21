// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import GameplayKit

class Mutator {
    var gausser = FastRandomerIterator(.gaussian)
    var randomer = FastRandomerIterator(.random)

    static var mutationProbability: Float = 0.8

    func maybeMutate(from gene: Float) -> Float {

        let yesMutate = randomer.inRange(0.0..<1.0) < Mutator.mutationProbability
        let newValue = gene + (yesMutate ? gausser.next()! : 0)

        return newValue
    }

    @discardableResult
    func mutate(
        from parentStrand: UnsafeBufferPointer<Float>,
        to offspringStrand: UnsafeMutableBufferPointer<Float>,
        cGenes: Int
    ) -> Bool {
        var didMutate = false

        (0..<cGenes).forEach {
            let result = maybeMutate(from: parentStrand[$0])
            offspringStrand[$0] = result

            if !didMutate { didMutate = result != parentStrand[$0] }
        }

        return didMutate
    }
}
