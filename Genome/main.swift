// We are a way for the cosmos to know itself. -- C. Sagan

import Foundation

print("Hello, World!")

func testGenomeAndMutator() {
    let p1 = Genome(cGenes: 10)
    print(p1.genes.map { $0 })

    let p2 = Genome(exactCopyFrom: p1)
    print(p2.genes.map { $0 })

    let p3 = Genome(cloneFrom: p1)
    print(p3.genes.map { $0 })

    let p4 = Genome(mate: p1, with: p2)
    print(p4.genes.map { $0 })

    for _ in 0..<100 {
        let p = Genome(mate: p1, with: p2)
        print(p.genes.map { $0 })
    }
}

testGenomeAndMutator()
