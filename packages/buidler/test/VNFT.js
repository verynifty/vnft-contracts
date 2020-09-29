const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("VNFT", function () {
    let myContract;

    it("Should deploy GameItem and dependencies", async function () {

        const _MuseToken = await ethers.getContractFactory("MuseToken");
        const VNFT = await ethers.getContractFactory("VNFT");


        MuseToken = await _MuseToken.deploy(1000)
        VNFT = await _VNFT.deploy(MuseToken.address)
    });
});
