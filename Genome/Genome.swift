// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

class Genome {
    enum Combination { case clone, duplex, miracle }

    var gausser = FastRandomerIterator(.gaussian)
    var randomer = FastRandomerIterator(.random)

    let cGenes: Int
    let combination: Combination
    let genes: UnsafeBufferPointer<Float>

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    init(cGenes: Int, heap: UnsafeMutableRawPointer) {
        gameCore.preconditionIsOnSerialQueue()

        self.cGenes = cGenes
        self.combination = .miracle

        let r = FastRandomerIterator(.random, bufferSize: cGenes).asBuffer!

        var m = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        // Because vDSP doesn't have a simple copy
        vDSP.add(0, r, result: &m)

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
    }

    /// Create a genome using the specified gene sequence
    /// - Parameter genes: The gene values
    init(genes: UnsafeBufferPointer<Float>) {
        gameCore.preconditionIsOnSerialQueue()

        self.cGenes = genes.count
        self.combination = .miracle
        self.genes = genes
    }

    /// Create a genome that is a clone of the parent. Cloning involves
    /// a pass through the mutator, which mutates the outputs depending on
    /// configuration settings.
    /// - Parameter parent: The genome from which to clone
    init(
        cloneFrom parent: Genome, mutationProbability: Float,
        heap: UnsafeMutableRawPointer
    ) {
        gameCore.preconditionIsOnSerialQueue()

        self.cGenes = parent.cGenes
        self.combination = .clone

        var m = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        let g = FastRandomerIterator(.gaussian, bufferSize: cGenes).asBuffer!

        // Mark 1's where we want the parent alleles to go, based
        // on mutation probability
        Genome.generateMutationMap(cGenes, mutationProbability, heap: m)

        vDSP.multiply(g, m, result: &m)
        vDSP.add(parent.genes, m, result: &m)
        vDSP.clip(m, to: -1...1, result: &m)

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    /// - Parameter heap: The destination of the new genome
    init(exactCopyFrom parent: Genome, heap: UnsafeMutableRawPointer) {
        gameCore.preconditionIsOnSerialQueue()

        self.cGenes = parent.cGenes
        self.combination = .clone

        var m = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        // vDSP doesn't have a simple copy; I've looked a million times
        vDSP.add(0, parent.genes, result: &m)

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
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
        heap: UnsafeMutableRawPointer,
        mutationProbability: Float = 0.8
    ) {
        gameCore.preconditionIsOnSerialQueue()

        self.cGenes = parent0.cGenes
        self.combination = .duplex

        var m = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        var randomer = FastRandomerIterator(.random)
        var gaussian = FastRandomerIterator(.gaussian)

        for ss in 0..<cGenes {
            let takeParent0Gene = randomer.inRange(0..<1) < parent0Weight
            let yesMutate = randomer.inRange(0..<1) < mutationProbability

            m[ss] = takeParent0Gene ? parent0.genes[ss] : parent1.genes[ss]

            if yesMutate { m[ss] += gaussian.next()! }
        }

        vDSP.clip(m, to: -1...1, result: &m)

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
    }
}

extension Genome {
    static private func generateMutationMap(
        _ cGenes: Int, _ mutationProbability: Float,
        heap: UnsafeMutableBufferPointer<Float>
    ) {
        let s = FastRandomerIterator(.randomPositive, bufferSize: cGenes).asBuffer!
        (0..<s.count).forEach { heap[$0] = (s[$0] > mutationProbability) ? 0 : 1 }
    }
}
