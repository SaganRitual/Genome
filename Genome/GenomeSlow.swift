// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

protocol HasGenomeProtocol {
    var genome: Genome { get }
}

protocol RandomerFactoryProtocol {

}

protocol RandomerProtocol {
    static 
    init(_ combintion: Genome.Combination)
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
    init(cGenes: Int, heap: UnsafeMutableRawPointer) {
        self.cGenes = cGenes
        self.combination = .miracle

        let g = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        for ss in 0..<cGenes { g[ss] = randomer.next()! }

        self.genes = SwiftPointer<Float>.bufferFrom(heap, elementCount: cGenes)
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
        heap: UnsafeMutableRawPointer
    ) {
        self.cGenes = parent.genome.cGenes
        self.combination = .clone

        let map = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        // Mark 1's where we want the parent alleles to go, based
        // on mutation probability
        Genome.generateMutationMap(cGenes, mutationProbability, heap: map)

        for ss in 0..<cGenes {
            map[ss] *= gausser.next()!
            map[ss] += parent.genome.genes[ss]
            map[ss] = max(-1, min(map[ss], 1))
        }

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    /// - Parameter heap: The destination of the new genome
    init(exactCopyFrom parent: HasGenomeProtocol, heap: UnsafeMutableRawPointer) {
        self.cGenes = parent.genome.cGenes
        self.combination = .clone

        let m = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        for ss in 0..<cGenes { m[ss] = parent.genome.genes[ss] }

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
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
        heap: UnsafeMutableRawPointer,
        mutationProbability: Float = 0.8
    ) {
        self.cGenes = parent0.genome.cGenes
        self.combination = .duplex

        let m = SwiftPointer<Float>.mutableBufferFrom(
            heap, pointee: Float.self, elementCount: cGenes
        )

        for ss in 0..<cGenes {
            let takeParent0Gene = randomer.inRange(0..<1) < parent0Weight
            let yesMutate = randomer.inRange(0..<1) < mutationProbability

            m[ss] = takeParent0Gene || parent1 == nil ?
                parent0.genome.genes[ss] : parent1!.genome.genes[ss]

            if yesMutate { m[ss] += gausser.next()! }

            m[ss] = max(-1, min(m[ss], 1))
        }

        self.genes = SwiftPointer.bufferFrom(heap, elementCount: cGenes)
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
