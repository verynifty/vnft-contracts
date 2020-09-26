const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("StakeForPets", function () {
    let myContract;

    it("Should deploy StakeForPets and dependencies", async function () {

        const _BaseToken = await ethers.getContractFactory("BaseToken");
        const _GameItem = await ethers.getContractFactory("GameItem");

        const _StakeForPets = await ethers.getContractFactory("StakeForPets");


        BaseToken = await _BaseToken.deploy("adamToken", "ada", 18, 1000, 100, true, false)
        GameItem = await _GameItem.deploy(BaseToken.address)
        StakeForPets = await _StakeForPets.deploy(GameItem.address, BaseToken.address);
    });
});
