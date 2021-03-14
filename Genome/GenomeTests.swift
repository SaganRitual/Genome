// We are a way for the cosmos to know itself. -- C. Sagan

import Foundation

func testAllRandomValuesGenome() -> Genome {
    let cGenes = 10
    let genes = UnsafeMutableBufferPointer<Float>.allocate(capacity: cGenes)
    let genome = Genome(cGenes: cGenes, genes: genes)

    // Should look randomy
    print(genome.genes.map { World.fprint($0) })

    return genome
}

func testCloneFromParent(_ parent: Genome) {
    var genes = UnsafeMutableBufferPointer<Float>.allocate(
        capacity: parent.genes.count
    )

    let clone = Genome(
        cloneFrom: parent, mutationProbability: 0.75, genes: &genes
    )

    // Should look cloney
    print(clone.genes.map { World.fprint($0) })
}

func testDuplex() {
    let p0 = Genome(cGenes: 10)
    let p1 = Genome(cGenes: 10)

    var offspringGenes = UnsafeMutableBufferPointer<Float>.allocate(
        capacity: p0.genes.count
    )

    let duplex = Genome(
        mate: p0, with: p1, parent0Weight: 0.7,
        mutationProbability: 0.85, genes: &offspringGenes
    )

    print("Parent 0 ", p0.genes.map { World.fprint($0) })
    print("Parent 1 ", p1.genes.map { World.fprint($0) })
    print("Offspring", duplex.genes.map { World.fprint($0) })
}
