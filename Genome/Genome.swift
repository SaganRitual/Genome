// We are a way for the cosmos to know itself. -- C. Sagan

import Accelerate
import Foundation

class Genome {
    enum Combination { case clone, duplex, miracle }

    let combination: Combination
    let genes: UnsafeBufferPointer<Float>

    static func clipBuffer(
        inBuffer: UnsafeBufferPointer<Float>,
        outBuffer: inout UnsafeMutableBufferPointer<Float>
    ) {
        let slightlyNotOne: Float = 1 - 1e-6
        let weDislikeOnes = -slightlyNotOne...slightlyNotOne

        vDSP.clip(inBuffer, to: weDislikeOnes, result: &outBuffer)
    }

    /// Create a genome with all random values
    /// - Parameter cGenes: The count of genes to create in the genome, that
    ///                     is, the length of the genome.
    /// - Parameter genes: optional buffer, managed by client; genome
    ///                     copies the genetic data to the buffer. Set to nil
    ///                     for genome to mange the buffer itself
    init(cGenes: Int, genes: UnsafeMutableBufferPointer<Float>? = nil) {
        self.combination = .miracle
        let randomValues = World.staticRandomer.getBuffer(.random, cElements: cGenes)

        // If caller hasn't specified his own buffer, just point our
        // genes pointer to the randomer's internal buffer
        guard let callerBuffer = genes else { self.genes = randomValues; return }

        // Caller specified his own buffer; we have to copy into it
        cblas_scopy(
            Int32(cGenes),
            UnsafePointer(randomValues.baseAddress!), 1,
            UnsafeMutablePointer<Float>(mutating: callerBuffer.baseAddress!), 1
        )

        self.genes = UnsafeBufferPointer(callerBuffer)
    }

    /// Create a genome that is a clone of the parent, mutating at
    /// the indicated rate
    ///
    /// Gene data is written directly into the caller-owned buffer
    /// - Parameter parent: The genome from which to clone
    /// - Parameter mutationProbability: The odds that each gene will be
    ///             mutated away from the parent's copy; a value of 0.85
    ///             will cause ~85% of the genes to be mutated; a value of
    ///             1.0 will mutate all, 0 will mutate none
    /// - Parameter genes: Caller-supplied buffer to hold the new genes
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

        Genome.clipBuffer(inBuffer: UnsafeBufferPointer(genes), outBuffer: &genes)

        self.genes = .init(rebasing: genes[...])
    }

    /// Create a genome that is the combination of two parent genoems
    ///
    /// - Gene data is written directly into the caller-owned buffer
    /// - Mutation occurs after the parent allele is selected
    /// - Parameter parent0: One of the parents
    /// - Parameter parent1: The other parent
    /// - Parameter parent0Weight: Bias toward parent0's alleles; a value of
    ///                             0.70 will cause the offspring to get
    ///                             ~70% of parent0's alleles and ~30% of
    ///                             parent1's
    /// - Parameter mutationProbability: The odds that each gene will be
    ///             mutated away from its parent's alleles; a value of 0.85
    ///             will cause ~85% of the genes to be mutated; a value of
    ///             1.0 will mutate all, 0 will mutate none
    /// - Parameter genes: Caller-supplied buffer to hold the new genes
    init(
        mate parent0: Genome, with parent1: Genome,
        parent0Weight: Float, mutationProbability: Float,
        genes: inout UnsafeMutableBufferPointer<Float>
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

        Genome.clipBuffer(inBuffer: UnsafeBufferPointer(genes), outBuffer: &genes)

        self.genes = .init(rebasing: genes[...])
    }

    /// Create a genome using the specified gene sequence
    ///
    /// Gene data is written directly into the caller-owned buffer
    /// - Parameter genes: The gene values in caller-supplied buffer
    init(genes: UnsafeBufferPointer<Float>) {
        self.combination = .miracle
        self.genes = genes
    }

    /// Create a geome that is an exact copy of the parent. No mutations.
    ///
    /// Gene data is copied into the caller-owned buffer
    /// - Parameter parent: The genome from which to copy
    /// - Parameter genes: The destination of the new genome
    init(
        exactCopyFrom parent: Genome,
        genes: inout UnsafeMutableBufferPointer<Float>
    ) {
        self.combination = .clone
        self.genes = .init(rebasing: genes[...])

        // Strange that vDSP doesn't have a copy; fortunately this works
        cblas_scopy(
            Int32(parent.genes.count),
            UnsafePointer(parent.genes.baseAddress!), 1,
            UnsafeMutablePointer<Float>(genes.baseAddress!), 1
        )
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
