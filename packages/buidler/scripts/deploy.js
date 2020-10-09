const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("@nomiclabs/buidler");



async function main() {
  console.log("📡 Deploy \n");
  // auto deploy to read contract directory and deploy them all (add ".args" files for arguments)
  // await autoDeploy();
  // OR
  // custom deploy (to use deployed addresses)


  const MuseToken = await deploy("MuseToken")
  const VNFT = await deploy("VNFT", [MuseToken.address])
  const MasterChef = await deploy("MasterChef", [MuseToken.address, 1, 1, 1])
  const StakeForVnfts = await deploy("StakeForVnfts", [VNFT.address, MuseToken.address])
  const PetAirdrop = await deploy("PetAirdrop", [VNFT.address, "0x331d49138d6f29e1a3e96b1179a95f6551f5c10daedea65c3230eb8ba4658556"])

  // grant minter role to PetAirdrop
  await VNFT.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", PetAirdrop.address);
  console.log("🚀 Granted VNFT Minter Role to PetAirdrop \n")

  // Grant Miner role to StakeForVnfts
  await VNFT.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", StakeForVnfts.address);
  console.log("🚀 Granted VNFT Minter Role to StakeForVnfts \n")

  // grant miner role to VNFT
  await MuseToken.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", VNFT.address)
  console.log("🚀 Granted MuseToken Minter Role to VNFT \n")

  // mint to other user to test erc1155 works

  await MuseToken.mint('0x821503f2d6990eb6E71fde0CeFf503cE5415b98c', 100000)

  // grant miner role to Master Chef
  await MuseToken.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", MasterChef.address)
  console.log("🚀 Granted MuseToken Minter Role to MasterChef \n")

  // reate an item with 5 points
  const threeDays = 60 * 60 * 24 * 3
  await VNFT.createItem("diamond", 5, 1, threeDays)
  console.log("🚀 added item diamond \n");


  // This is to accelerate ui tests
  await PetAirdrop.claim('7', '0x8a35acfbc15ff81a39ae7d344fd709f28e8600b4aa8c65c6b64bfe7fe36bd19bJ0xa8d08734ea7322e06e0a776297d6f37272e6f5a616160a77c77841e0759bf0caJ0x7c38699e734025992b773d48ab4f2ab731d02dd3ea60fdbb9fd3bd722f1a01dfJ0x599b5b3e642afe03df05b36f7fdb145cc4ae8958fec6884cafe44f9e32e41f28'.split('J'))

  await PetAirdrop.claim('8', '0xf652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3fJ0xf7d53e9113effbd163e93d1551923c280edec3d473135737ea978365d41bc83a'.split('J'))

  await PetAirdrop.claim('9', '0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5aceJ0x3196704a2b58fda17a75cb346654cda44776ee73f6ab009e295270a7f557ae1aJ0x7f7819f69ce525f1b994f0ef767c1d1db1d370e6f56a74ebacf120298f046290J0x599b5b3e642afe03df05b36f7fdb145cc4ae8958fec6884cafe44f9e32e41f28'.split('J'))

  // Test merkle tree rewards
  await VNFT.claimMiningRewards('0')
  await VNFT.claimMiningRewards('1')
  await VNFT.claimMiningRewards('2')
  console.log("🚀 Finished basic mining... \n")


  // // terst erc1155 implementation
  // const TestERC1155 = await deploy('TestERC1155', ["google.com"])
  // await TestERC1155.mint("0xeAD9C93b79Ae7C1591b1FB5323BD777E86e150d4", 1, 1, 0x0);

  // console.log("🚀 Minted sample ERC1155 token \n");

  // await VNFT.addNft(TestERC1155.address, 1155);
  // console.log("🚀 Added TEST ERC Contract to vNFT \n");

  await MuseToken.mint("0x047F606fD5b2BaA5f5C6c4aB8958E45CB6B054B7", (10 * 10 ** 18).toString())
  console.log("🚀 minted token to tester user \n");


  // TEST ERC721 IMPLEMENTATION
  const TestERC721 = await deploy('TestERC721')
  await TestERC721.mint("0xeAD9C93b79Ae7C1591b1FB5323BD777E86e150d4");
  console.log("🚀 minted token to user \n");

  // add support for test 721 contract
  await VNFT.addNft(TestERC721.address, 721);
  console.log("🚀 Added TEST ERC Contract to vNFT \n");



  // test care taker functions
  // await VNFT.addCareTaker(1, MasterChef.address);
  // await VNFT.grantRole("0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929", "0x57245838a670f8de8de3F430157F7e70005203DA")
  // console.log("🚀 Added care taker")



}





async function deploy(name, _args) {
  const args = _args || [];

  console.log(`📄 ${name}`);
  const contractArtifacts = await ethers.getContractFactory(name);
  const contract = await contractArtifacts.deploy(...args);
  console.log(
    chalk.cyan(name),
    "deployed to:",
    chalk.magenta(contract.address)
  );
  fs.writeFileSync(`artifacts/${name}.address`, contract.address);
  console.log("\n");
  return contract;
}

const isSolidity = (fileName) =>
  fileName.indexOf(".sol") >= 0 && fileName.indexOf(".swp.") < 0;

function readArgumentsFile(contractName) {
  let args = [];
  try {
    const argsFile = `./contracts/${contractName}.args`;
    if (fs.existsSync(argsFile)) {
      args = JSON.parse(fs.readFileSync(argsFile));
    }
  } catch (e) {
    console.log(e);
  }

  return args;
}

async function autoDeploy() {
  let contractList = fs.readdirSync(config.paths.sources);
  return contractList
    .filter((fileName) => isSolidity(fileName))
    .reduce((lastDeployment, fileName) => {
      const contractName = fileName.replace(".sol", "");
      const args = readArgumentsFile(contractName);

      // Wait for last deployment to complete before starting the next
      return lastDeployment.then((resultArrSoFar) =>
        deploy(contractName, args).then((result) => [...resultArrSoFar, result])
      );
    }, Promise.resolve([]));
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
