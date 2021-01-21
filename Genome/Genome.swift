// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

class Genome {
    enum Combination { case clone, duplex, miracle }

    let cGenes: Int
    let combination: Combination
    let genes: UnsafeBufferPointer<Float>
    let mutator = Mutator()
    let toDeallocate: UnsafeMutableBufferPointer<Float>

    deinit { toDeallocate.deallocate() }

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    init(cGenes: Int) {
        self.cGenes = cGenes
        self.combination = .miracle

        let genes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = genes
        self.genes = UnsafeBufferPointer(genes)

        (0..<cGenes).forEach {
            genes[$0] = mutator.randomer.inRange(-1.0..<1.0)
        }
    }

    /// Create a genome that is a clone of the parent. Cloning involves
    /// a pass through the mutator, which mutates the outputs depending on
    /// configuration settings.
    /// - Parameter parent: The genome from which to clone
    init(cloneFrom parent: Genome) {
        self.cGenes = parent.cGenes
        self.combination = .clone

        let genes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = genes
        self.genes = UnsafeBufferPointer(genes)

        mutator.mutate(from: parent.genes, to: genes, cGenes: parent.cGenes)
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    init(exactCopyFrom parent: Genome) {
        self.cGenes = parent.cGenes
        self.combination = .clone

        var genes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = genes
        self.genes = UnsafeBufferPointer(genes)

        // vDSP doesn't have a simple copy
        vDSP.add(0, parent.genes, result: &genes)
    }

    /// Create a genome that is the result of mating the two parent
    /// genomes, with mutations applied according to the mutator
    /// configuration.
    /// - Parameters:
    ///   - parent0: One of the parents
    ///   - parent1: The other parent
    init(mate parent0: Genome, with parent1: Genome) {
        self.cGenes = parent0.cGenes
        self.combination = .duplex

        let genes = makeUnsafeMutableBuffer(count: cGenes)
        self.toDeallocate = genes
        self.genes = UnsafeBufferPointer(genes)

        zip(parent0.genes.enumerated(), parent1.genes).forEach {
            let (index, lhsGene) = $0, rhsGene = $1
            genes[index] = combineDuplex(lhs: lhsGene, rhs: rhsGene)
        }
    }
}

extension Genome {
    func combineDuplex(lhs: Float, rhs: Float) -> Float {
        // select lhs/rhs, mutate/no
        // lhs + rhs average
        // w1 * lhs + (1 - w1) * rhs
        switch mutator.randomer.inRange(0..<8) {
        case 0:
            return lhs
        case 1:
            return rhs
        case 2:
            return mutator.maybeMutate(from: lhs)
        case 3:
            return mutator.maybeMutate(from: rhs)

        case 4:
            let LL = mutator.randomer.inRange(0.0..<1.0)
            let RR = 1 - LL
            let newAllele = LL * lhs + RR * rhs
            return newAllele

        case 5:
            let LL = mutator.randomer.inRange(0.0..<1.0)
            let RR = 1 - LL
            let newAllele = LL * lhs + RR * rhs
            return mutator.maybeMutate(from: newAllele)

        case 6:
            let newAllele = 0.5 * lhs + 0.5 * rhs
            return newAllele

        case 7:
            let newAllele = 0.5 * lhs + 0.5 * rhs
            return mutator.maybeMutate(from: newAllele)

        default: fatalError()
        }
    }
}
