const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("BaseToken", function () {
    let myContract;

    it("Should deploy BaseToken and dependencies", async function () {

        const _BaseToken = await ethers.getContractFactory("BaseToken");
        BaseToken = await _BaseToken.deploy("adamToken", "ada", 18, 1000, 100, true, false);

    });
});
