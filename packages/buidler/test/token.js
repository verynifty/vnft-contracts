const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("MuseToken", function () {
    let myContract;

    it("Should deploy MuseToken and dependencies", async function () {

        const _MuseToken = await ethers.getContractFactory("MuseToken");
        MuseToken = await _MuseToken.deploy(1000);

    });
});
