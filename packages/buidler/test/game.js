const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("GameItem", function () {
    let myContract;

    it("Should deploy GameItem and dependencies", async function () {

        const _BaseToken = await ethers.getContractFactory("BaseToken");
        const _GameItem = await ethers.getContractFactory("GameItem");


        BaseToken = await _BaseToken.deploy("adamToken", "ada", 18, 1000, 100, true, false)
        GameItem = await _GameItem.deploy(BaseToken.address)
    });
});
