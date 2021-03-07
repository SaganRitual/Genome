// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

protocol HasGenomeProtocol {
    var genome: Genome { get }
}

class GRandorator {
    static var randorator = FastRandomer(Config.randomerCSamplesToGenerate)

    func makeIterator(
        _ mode: FastRandomerIterator.Mode, bufferSize: Int? = nil
    ) -> UnsafeBufferPointer<Double> {
        FastRandomerIterator(
            randomer: GRandorator.randorator, mode, bufferSize: bufferSize
        ).asBuffer!
    }
}

class Genome {
    enum Combination { case clone, duplex, miracle }

    var randorator = GRandorator()

    let cGenes: Int
    let combination: Combination
    let genes: UnsafeBufferPointer<Double>

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    init(cGenes: Int, genes: inout UnsafeMutableBufferPointer<Double>) {
        self.cGenes = cGenes
        self.combination = .miracle

        let r = randorator.makeIterator(.random, bufferSize: cGenes)

        // Because vDSP doesn't have a simple copy
        vDSP.add(0, r, result: &genes)

        self.genes = .init(rebasing: genes[...])
    }

    /// Create a genome using the specified gene sequence
    /// - Parameter genes: The gene values
    init(genes: UnsafeBufferPointer<Double>) {
        self.cGenes = genes.count
        self.combination = .miracle
        self.genes = genes
    }

    /// Create a genome that is a clone of the parent. Cloning involves
    /// a pass through the mutator, which mutates the outputs depending on
    /// configuration settings.
    /// - Parameter parent: The genome from which to clone
    init(
        cloneFrom parent: Genome, mutationProbability: Double,
        genes: inout UnsafeMutableBufferPointer<Double>
    ) {
        self.cGenes = parent.cGenes
        self.combination = .clone

        let g = randorator.makeIterator(.gaussian, bufferSize: cGenes)

        // Mark 1's where we want the parent alleles to go, based
        // on mutation probability
        Genome.generateMutationMap(randorator, cGenes, mutationProbability, genes: &genes)

        vDSP.multiply(g, genes, result: &genes)
        vDSP.add(parent.genes, genes, result: &genes)
        vDSP.clip(genes, to: -1...1, result: &genes)

        self.genes = .init(rebasing: genes[...])
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    /// - Parameter genes: The destination of the new genome
    init(exactCopyFrom parent: Genome, genes: inout UnsafeMutableBufferPointer<Double>) {
        self.cGenes = parent.cGenes
        self.combination = .clone

        // vDSP doesn't have a simple copy; I've looked a million times
        vDSP.add(0, parent.genes, result: &genes)

        self.genes = .init(rebasing: genes[...])
    }

    /// Create a genome that is the result of mating the two parent
    /// genomes, with mutations applied according to the mutator
    /// configuration.
    /// - Parameters:
    ///   - parent0: One of the parents
    ///   - parent1: The other parent
    init(
        mate parent0: Genome, with parent1: Genome,
        parent0Weight: Double,
        genes: inout UnsafeMutableBufferPointer<Double>,
        mutationProbability: Double = 0.5
    ) {
        self.cGenes = parent0.cGenes
        self.combination = .duplex

        var randomer = FastRandomerIterator(randomer: GRandorator.randorator, .random)
        var gaussian = FastRandomerIterator(randomer: GRandorator.randorator, .gaussian)

        for ss in 0..<cGenes {
            let takeParent0Gene = randomer.inRange(0..<1) < parent0Weight
            let yesMutate = randomer.inRange(0..<1) < mutationProbability

            genes[ss] = takeParent0Gene ? parent0.genes[ss] : parent1.genes[ss]

            if yesMutate { genes[ss] += gaussian.next()! }
        }

        vDSP.clip(genes, to: -1...1, result: &genes)

        self.genes = .init(rebasing: genes[...])
    }
}

extension Genome {
    static private func generateMutationMap(
        _ randorator: GRandorator,
        _ cGenes: Int, _ mutationProbability: Double,
        genes: inout UnsafeMutableBufferPointer<Double>
    ) {
        let s = randorator.makeIterator(.randomPositive, bufferSize: cGenes)
        (0..<s.count).forEach { genes[$0] = (s[$0] > mutationProbability) ? 0 : 1 }
    }
}
