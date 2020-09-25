const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("PetAirdrop", function () {
    let myContract;

    describe("PetAirdrop", function () {
        it("Should deploy PetAirdrop and dependencies", async function () {

            const _BaseToken = await ethers.getContractFactory("BaseToken");
            const _GameItem = await ethers.getContractFactory("GameItem");

            const _PetAirdrop = await ethers.getContractFactory("PetAirdrop");


            BaseToken = await _BaseToken.deploy("adamToken", "ada", 18, 1000, 100, true, false)
            GameItem = await _GameItem.deploy(BaseToken.address)
            PetAirdrop = await _PetAirdrop.deploy(GameItem.address, "0x8c08c19d6c6664be133a57b0917690a4e04473df54ef5bc6cd7341130a9b2ca3");
        });

        describe("Claim", function () {
            it("claim should not be claimed at initialization", async function () {
                expect(await PetAirdrop.isClaimed("0x0000000000000000000000000000000000000000000000000000000000000002")).to.equal(false);
            });
            it("claim should be claimable", async function () {
                await PetAirdrop.claim("0x0000000000000000000000000000000000000000000000000000000000000002",  [
                    '0x48d5463ce6afe14c20a53d0b72aaf9a52114035bc96f7a02ac7f13813111b3e6',
                    '0x89b23e55ffc2c98e5a2f45975fb6a506e303ba0caae59ec9dd0f0490137fa82a',
                    '0x1553fdf73c1853227dde3146eaed083762a0ede35b880c838cc7d213ece527f3',
                    '0xda7a05271b1303ee49e6e99b7753e829d0a7f416fa0cf33ef289f87ab7d0f698',
                    '0xabdba87b6a370b45de87e386286702cdfc59a5765370e369fc3e68fb8c6e3e91',
                    '0xca8ebdda2745574e6fae1948159433d0bd9d00a58cd7ce31a831de188c53820c'
                  ])
                //console.log(tx)
                    expect(await PetAirdrop.isClaimed("0x0000000000000000000000000000000000000000000000000000000000000002")).to.equal(true);
            });

        });
    });
});
