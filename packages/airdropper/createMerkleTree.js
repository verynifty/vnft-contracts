const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')

const NUMBER_OF_DROPS = 100;

let initial_leaves = []

for (let index = 0; index < NUMBER_OF_DROPS; index++) {
    let drop_index = index.toString(16);
    console.log(drop_index)
    initial_leaves.push(drop_index)
}

const final_leaves = initial_leaves.map(x => keccak256(x))
//console.log(final_leaves)
const tree = new MerkleTree(final_leaves, keccak256)
const root = tree.getRoot().toString('hex')
console.log(root)
const leaf = keccak256('3')
const proof = tree.getProof(leaf)
console.log(tree.verify(proof, leaf, root)) // true

const leaf2 = keccak256('aaa')
const proof2 = tree.getProof(leaf)
console.log(tree.verify(proof2, leaf2, root)) // true
