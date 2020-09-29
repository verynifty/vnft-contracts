const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("PetAirdrop", function () {
    let myContract;

    describe("PetAirdrop", function () {
        it("Should deploy PetAirdrop and dependencies", async function () {

            const _MuseToken = await ethers.getContractFactory("MuseToken");
            const _VNFT = await ethers.getContractFactory("VNFT");

            const _PetAirdrop = await ethers.getContractFactory("PetAirdrop");


            MuseToken = await _MuseToken.deploy(1000)
            VNFT = await _VNFT.deploy(MuseToken.address)
            PetAirdrop = await _PetAirdrop.deploy(VNFT.address, "0xebd4cffa6f14c56c3e6d74761b9f9e00ecc5b0eb81c34b77b8d50bee6652fcb5");
        });

        describe("Claim", function () {
            it("claim should not be claimed at initialization", async function () {
                expect(await PetAirdrop.isClaimed(2)).to.equal(false);
            });
            it("claim should be claimable", async function () {
                await PetAirdrop.claim("2", [
                    '0x4a2cc91ee622da3bc833a54c37ffcb6f3ec23b7793efc5eaf5e71b7b406c5c06',
                    '0x580dfe3570c1a53c14a13253311cf05c9803002b3c1f440ffe914d7b22b3e57e',
                    '0x8b2963c10fa7e1a1145e014319f2d71f0761928e9f3bffc003fa13e86f15f8af',
                    '0x3cd893ef600fd84df77bd1da725dd6556a716adf105ba19b9129912534268d50',
                    '0x02f5092c911d47103c0059e81d78d0181957245fd5bcbea452138239b923f5ff',
                    '0x3ac1504079b0687f285dbadfa63c10926fa23a1fd451f2d35780375cdb3ce229'
                ])
                expect(await PetAirdrop.isClaimed("2")).to.equal(true);
            });
            it("claim 3 should not be claimed after claiming another claim", async function () {
                expect(await PetAirdrop.isClaimed(3)).to.equal(false);
            });
            it("claim 3 should be claimable", async function () {
                await PetAirdrop.claim("3", [
                    '0xc54045fa7c6ec765e825df7f9e9bf9dec12c5cef146f93a5eee56772ee647fbc',
                    '0x908eea487f7e03012b034047763fc6dab3c8a6e295463c73dfd2b840915b6d1c',
                    '0x5109ac346632824bd8043ce24ac1ffc022e2299b516d929393985d953490998c',
                    '0x7b3a9aa09db8b2c124cb135b5310b300d3722ee50dd44aaa1d0985d681b4304a',
                    '0x599b5b3e642afe03df05b36f7fdb145cc4ae8958fec6884cafe44f9e32e41f28',
                    '0x3e9ace454ef357e90a6c9b24c5b569c7af55730e6385aeadce1e655e3b023f0f'
                ])
                expect(await PetAirdrop.isClaimed("3")).to.equal(true);
            });
            it("claim 3 should not be able be claimable 2 times", async function () {
                try {
                    await PetAirdrop.claim("3", [
                        '0xc54045fa7c6ec765e825df7f9e9bf9dec12c5cef146f93a5eee56772ee647fbc',
                        '0x908eea487f7e03012b034047763fc6dab3c8a6e295463c73dfd2b840915b6d1c',
                        '0x5109ac346632824bd8043ce24ac1ffc022e2299b516d929393985d953490998c',
                        '0x7b3a9aa09db8b2c124cb135b5310b300d3722ee50dd44aaa1d0985d681b4304a',
                        '0x599b5b3e642afe03df05b36f7fdb145cc4ae8958fec6884cafe44f9e32e41f28',
                        '0x3e9ace454ef357e90a6c9b24c5b569c7af55730e6385aeadce1e655e3b023f0f'
                    ])
                } catch (err) {
                    expect(err.code).to.be.equal(-32603); // EVM revert error: already claimes
                }

            });

        });
    });
});
