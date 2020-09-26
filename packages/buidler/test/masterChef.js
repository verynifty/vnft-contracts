const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

// here we can copy MasterChef tests to the framework we use for tests https://github.com/sushiswap/sushiswap/blob/master/test/AMasterChef.test.js