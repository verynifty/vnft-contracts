const { keccak256, keccakFromString, bufferToHex, BN } = require('ethereumjs-util');

class MerkleTree {
  constructor (elements) {
    // Filter empty strings and hash elements
    this.elements = elements.filter(el => el).map(el => keccakFromString(el));

    // Sort elements
    this.elements.sort(Buffer.compare);
    // Deduplicate elements
    this.elements = this.bufDedup(this.elements);

    // Create layers
    this.layers = this.getLayers(this.elements);
  }

  getLayers (elements) {
    if (elements.length === 0) {
      return [['']];
    }

    const layers = [];
    layers.push(elements);

    // Get next layer until we reach the root
    while (layers[layers.length - 1].length > 1) {
      layers.push(this.getNextLayer(layers[layers.length - 1]));
    }

    return layers;
  }

  getNextLayer (elements) {
    return elements.reduce((layer, el, idx, arr) => {
      if (idx % 2 === 0) {
        // Hash the current element with its pair element
        layer.push(this.combinedHash(el, arr[idx + 1]));
      }

      return layer;
    }, []);
  }

  combinedHash (first, second) {
    if (!first) { return second; }
    if (!second) { return first; }

    return keccak256(this.sortAndConcat(first, second));
  }

  getRoot () {
    return this.layers[this.layers.length - 1][0];
  }

  getHexRoot () {
    return bufferToHex(this.getRoot());
  }

  getProof (el) {
    let idx = this.bufIndexOf(el, this.elements);

    if (idx === -1) {
      throw new Error('Element does not exist in Merkle tree');
    }

    return this.layers.reduce((proof, layer) => {
      const pairElement = this.getPairElement(idx, layer);

      if (pairElement) {
        proof.push(pairElement);
      }

      idx = Math.floor(idx / 2);

      return proof;
    }, []);
  }

  getHexProof (el) {
    const proof = this.getProof(el);

    return this.bufArrToHexArr(proof);
  }

  getPairElement (idx, layer) {
    const pairIdx = idx % 2 === 0 ? idx + 1 : idx - 1;

    if (pairIdx < layer.length) {
      return layer[pairIdx];
    } else {
      return null;
    }
  }

  bufIndexOf (el, arr) {
    let hash;

    // Convert element to 32 byte hash if it is not one already
    if (el.length !== 32 || !Buffer.isBuffer(el)) {
      hash = keccakFromString(el);
    } else {
      hash = el;
    }

    for (let i = 0; i < arr.length; i++) {
      if (hash.equals(arr[i])) {
        return i;
      }
    }

    return -1;
  }

  bufDedup (elements) {
    return elements.filter((el, idx) => {
      return idx === 0 || !elements[idx - 1].equals(el);
    });
  }

  bufArrToHexArr (arr) {
    if (arr.some(el => !Buffer.isBuffer(el))) {
      throw new Error('Array is not an array of buffers');
    }

    return arr.map(el => '0x' + el.toString('hex'));
  }

  sortAndConcat (...args) {
    return Buffer.concat([...args].sort(Buffer.compare));
  }
}

function decimalToHex(d, padding) {
    var hex = Number(d).toString(16);
    padding = typeof (padding) === "undefined" || padding === null ? padding = 2 : padding;

    while (hex.length < padding) {
        hex = "0" + hex;
    }

    return hex;
}

const NUMBER_OF_DROPS = 50;

let initial_leaves = []

let test_proof = ""

// We generate NUMBER OF DROPS of keys
// To claim a NFT you'll need the index and a secret key that matches the index
for (let index = 0; index < NUMBER_OF_DROPS; index++) {
    //console.log(initial_leaves)
    initial_leaves.push('0x' + decimalToHex(index, 66))
}

const merkleTree = new MerkleTree(initial_leaves);

const root = merkleTree.getHexRoot();

const proof = merkleTree.getHexProof(initial_leaves[2]);

const leaf = bufferToHex(keccakFromString(initial_leaves[2]));

console.log(bufferToHex(keccakFromString('0x0000000000000000000000000000000000000000000000000000000000000002')))
console.log(bufferToHex(keccakFromString('2')))
console.log(bufferToHex(keccakFromString('0000000000000000000000000000000000000000000000000000000000000002')))


console.log(root, proof, leaf)
console.log(keccakFromString(decimalToHex(2, 66)).toString('hex'))