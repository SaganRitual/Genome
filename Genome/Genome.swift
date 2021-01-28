// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

class Genome {
    enum Combination { case clone, duplex, miracle }

    func generateMutationMap() -> UnsafeBufferPointer<Float> {
        let s = FastRandomerIterator(.randomPositive, bufferSize: Config.cGenes).asBuffer!
        let m = UnsafeMutableBufferPointer<Float>.allocate(capacity: Config.cGenes)

        (0..<s.count).forEach { m[$0] = s[$0] > Config.mutationProbability ? 0 : 1 }
        return UnsafeBufferPointer(m)
    }

    var gausser = FastRandomerIterator(.gaussian)
    var randomer = FastRandomerIterator(.random)
    var halfHalfer = FastRandomerIterator(.halfHalf, bufferSize: Config.cGenes).asBuffer!

    let cGenes: Int
    let combination: Combination
    let genes: UnsafeBufferPointer<Float>
    let toDeallocate: UnsafeMutableBufferPointer<Float>?

    deinit { toDeallocate?.deallocate() }

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    init(cGenes: Int) {
        self.cGenes = cGenes
        self.combination = .miracle

        var mGenes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = mGenes
        self.genes = UnsafeBufferPointer(mGenes)

        let r = FastRandomerIterator(.random, bufferSize: cGenes).asBuffer!

        vDSP.multiply(1, r, result: &mGenes)
    }

    /// Create a genome that is a clone of the parent. Cloning involves
    /// a pass through the mutator, which mutates the outputs depending on
    /// configuration settings.
    /// - Parameter parent: The genome from which to clone
    init(cloneFrom parent: Genome) {
        self.cGenes = parent.cGenes
        self.combination = .clone

        var mGenes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = mGenes
        self.genes = UnsafeBufferPointer(mGenes)

        let gaussian = FastRandomerIterator(.gaussian, bufferSize: cGenes).asBuffer!
        let map = generateMutationMap()

        vDSP.multiply(gaussian, map, result: &mGenes)
        vDSP.add(parent.genes, mGenes, result: &mGenes)
        vDSP.clip(mGenes, to: -1...1, result: &mGenes)
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    init(exactCopyFrom parent: Genome) {
        self.cGenes = parent.cGenes
        self.combination = .clone

        var genes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = genes
        self.genes = UnsafeBufferPointer(genes)

        // vDSP doesn't have a simple copy; I've looked a million times
        vDSP.add(0, parent.genes, result: &genes)
    }

    /// Create a genome that is the result of mating the two parent
    /// genomes, with mutations applied according to the mutator
    /// configuration.
    /// - Parameters:
    ///   - parent0: One of the parents
    ///   - parent1: The other parent
    init(
        mate parent0: Genome, with parent1: Genome,
        parent0Weight: Float,
        mutationProbability: Float = Config.mutationProbability
    ) {
        self.cGenes = Config.cGenes
        self.combination = .duplex

        var mGenes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = mGenes
        self.genes = UnsafeBufferPointer(mGenes)

        var randomer = FastRandomerIterator(.random)
        var gaussian = FastRandomerIterator(.gaussian)

        for ss in 0..<cGenes {
            let takeParent0Gene = randomer.inRange(0..<1) < parent0Weight
            let yesMutate = randomer.inRange(0..<1) < Config.mutationProbability

            mGenes[ss] = takeParent0Gene ? parent0.genes[ss] : parent1.genes[ss]

            if yesMutate { mGenes[ss] += gaussian.next()! }
        }

        vDSP.clip(mGenes, to: -1...1, result: &mGenes)
    }
}
