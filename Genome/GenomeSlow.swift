// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

protocol HasGenomeProtocol {
    var genome: Genome { get }
}

class Genome {
    enum Combination { case clone, duplex, miracle }

    var gausser = Randomer(.gaussian)
    var randomer = Randomer(.random)

    let cGenes: Int
    let combination: Combination
    let genes: UnsafeBufferPointer<Float>

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    init(cGenes: Int, heap: UnsafeMutableBufferPointer<Float>) {
        self.cGenes = cGenes
        self.combination = .miracle

        _ = heap.initialize(from: randomer)

        self.genes = UnsafeBufferPointer(heap)
    }

    /// Create a genome using the specified gene sequence
    /// - Parameter genes: The gene values
    init(genes: UnsafeBufferPointer<Float>) {
        self.cGenes = genes.count
        self.combination = .miracle
        self.genes = genes
    }

    /// Create a genome that is a clone of the parent. Cloning involves
    /// a pass through the mutator, which mutates the outputs depending on
    /// configuration settings.
    /// - Parameter parent: The genome from which to clone
    init(
        cloneFrom parent: HasGenomeProtocol, mutationProbability: Float,
        heap: UnsafeMutableBufferPointer<Float>
    ) {
        self.cGenes = parent.genome.cGenes
        self.combination = .clone

        // Mark 1's where we want the parent alleles to go, based
        // on mutation probability
        Genome.generateMutationMap(cGenes, mutationProbability, heap: heap)

        for ss in 0..<cGenes {
            heap[ss] *= gausser.next()!
            heap[ss] += parent.genome.genes[ss]
            heap[ss] = max(-1, min(heap[ss], 1))
        }

        self.genes = UnsafeBufferPointer(heap)
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    /// - Parameter heap: The destination of the new genome
    init(exactCopyFrom parent: HasGenomeProtocol, heap: UnsafeMutableBufferPointer<Float>) {
        self.cGenes = parent.genome.cGenes
        self.combination = .clone

        _ = heap.initialize(from: randomer)

        self.genes = UnsafeBufferPointer(heap)
    }

    /// Create a genome that is the result of mating the two parent
    /// genomes, with mutations applied according to the mutator
    /// configuration.
    /// - Parameters:
    ///   - parent0: One of the parents
    ///   - parent1: The other parent
    init(
        mate parent0: HasGenomeProtocol, with parent1: HasGenomeProtocol?,
        parent0Weight: Float,
        heap: UnsafeMutableBufferPointer<Float>,
        mutationProbability: Float = 0.8
    ) {
        self.cGenes = parent0.genome.cGenes
        self.combination = .duplex

        for ss in 0..<cGenes {
            let takeParent0Gene = randomer.inRange(0..<1) < parent0Weight
            let yesMutate = randomer.inRange(0..<1) < mutationProbability

            heap[ss] = takeParent0Gene || parent1 == nil ?
                parent0.genome.genes[ss] : parent1!.genome.genes[ss]

            if yesMutate { heap[ss] += gausser.next()! }

            heap[ss] = max(-1, min(heap[ss], 1))
        }

        self.genes = UnsafeBufferPointer(heap)
    }
}

private extension Genome {
    static func generateMutationMap(
        _ cGenes: Int, _ mutationProbability: Float,
        heap: UnsafeMutableBufferPointer<Float>
    ) {
        var randomer = Randomer(.random)

        for ss in 0..<cGenes {
            heap[ss] = (randomer.next()! > mutationProbability) ? 0 : 1
        }
    }
}
