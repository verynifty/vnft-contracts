const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')

const NUMBER_OF_DROPS = 10;

let initial_leaves = []

function getRandomInt(max) {
    return Math.floor(Math.random() * Math.floor(max));
}

let test_proof = ""

// We generate NUMBER OF DROPS of keys
// To claim a NFT you'll need the index and a secret key that matches the index
// The secret key could be eventually replaced by the address of the claimer if we do 2 steps
for (let index = 0; index < NUMBER_OF_DROPS; index++) {
    let dropIndex = index
    let hashKey = getRandomInt(9999999) // This is a rand
    let original_proof = dropIndex + ';' + hashKey
    let proof = dropIndex.toString(16) + hashKey.toString(16)
    console.log('Original parameters', original_proof)
    test_proof = proof
    console.log('Parameters encoded (hex)', proof)
    initial_leaves.push(proof)
}

const final_leaves = initial_leaves.map(x => keccak256(x))
//console.log(final_leaves)
const tree = new MerkleTree(final_leaves, keccak256)
const root = tree.getRoot().toString('hex')

console.log('Merkle root to deploy contract', root)

const leaf = keccak256('wrongkey')
const proof = tree.getProof(leaf)
console.log(tree.verify(proof, leaf, root)) // false

const leaf2 = keccak256(test_proof).toString('hex')
const proof2 = tree.getProof(leaf2)
console.log(tree.verify(proof2, leaf2, root)) // true
