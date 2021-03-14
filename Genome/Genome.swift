// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

class Genome {
    enum Combination { case clone, duplex, miracle }

    let combination: Combination
    let genes: UnsafeBufferPointer<Float>

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    init(cGenes: Int, genes: UnsafeMutableBufferPointer<Float>?) {
        self.combination = .miracle
        let randomValues = World.staticRandomer.getBuffer(.random, cElements: cGenes)

        // If caller hasn't specified his own buffer, just point our
        // genes pointer to the randomer's internal buffer. It's ok to
        // do this because no one ever changes the genes
        guard let callerBuffer = genes else { self.genes = randomValues; return }

        // Caller specified his own buffer; we have to copy into ot
        cblas_scopy(
            Int32(cGenes),
            UnsafePointer(randomValues.baseAddress!), 1,
            UnsafeMutablePointer<Float>(mutating: callerBuffer.baseAddress!), 1
        )

        self.genes = UnsafeBufferPointer(callerBuffer)
    }

    /// Create a genome using the specified gene sequence
    /// - Parameter genes: The gene values
    init(genes: UnsafeBufferPointer<Float>) {
        self.combination = .miracle
        self.genes = genes

        var g = UnsafeMutableBufferPointer(mutating: genes)
        vDSP.clip(g, to: -1...1, result: &g)
    }

    /// Create a genome that is a clone of the parent. Cloning involves
    /// a pass through the mutator, which mutates the outputs depending on
    /// configuration settings.
    /// - Parameter parent: The genome from which to clone
    init(
        cloneFrom parent: Genome, mutationProbability: Float,
        genes: inout UnsafeMutableBufferPointer<Float>
    ) {
        self.combination = .clone

        let cGenes = parent.genes.count
        let mutations = World.staticRandomer.getBuffer(.gaussian, cElements: cGenes)

        // Mark 1's where we want to mutate our copies of the parent genes
        Genome.generateMutationMap(cGenes, mutationProbability, genes: &genes)

        vDSP.multiply(parent.genes, mutations, result: &genes)
        vDSP.add(parent.genes, genes, result: &genes)
        vDSP.clip(genes, to: -1...1, result: &genes)

        self.genes = .init(rebasing: genes[...])
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    /// - Parameter parent: The genome from which to copy
    /// - Parameter genes: The destination of the new genome
    init(exactCopyFrom parent: Genome, genes: inout UnsafeMutableBufferPointer<Float>) {
        self.combination = .clone
        self.genes = .init(rebasing: genes[...])

        // Strange that vDSP doesn't have a copy; fortunately this works
        cblas_scopy(
            Int32(parent.genes.count),
            UnsafePointer(parent.genes.baseAddress!), 1,
            UnsafeMutablePointer<Float>(genes.baseAddress!), 1
        )
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
        genes: inout UnsafeMutableBufferPointer<Float>,
        mutationProbability: Float
    ) {
        self.combination = .duplex

        var randomIterator = StaticRandomerIterator(randomer: World.staticRandomer, .random)
        var gaussianIterator = StaticRandomerIterator(randomer: World.staticRandomer, .gaussian)

        for ss in 0..<parent0.genes.count {
            let takeParent0Gene = randomIterator.inRange(0..<1) < parent0Weight
            let yesMutate = randomIterator.inRange(0..<1) < mutationProbability

            genes[ss] = takeParent0Gene ? parent0.genes[ss] : parent1.genes[ss]

            if yesMutate { genes[ss] += gaussianIterator.next()! }
        }

        vDSP.clip(genes, to: -1...1, result: &genes)

        self.genes = .init(rebasing: genes[...])
    }
}

extension Genome {
    static private func generateMutationMap(
        _ cGenes: Int, _ mutationProbability: Float,
        genes: inout UnsafeMutableBufferPointer<Float>
    ) {
        let buffer = World.staticRandomer.getBuffer(.random, cElements: cGenes)

        buffer.enumerated().forEach {
            genes[$0] = ($1 > mutationProbability) ? 0 : 1
        }
    }
}
