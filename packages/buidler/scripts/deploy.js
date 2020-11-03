const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("@nomiclabs/buidler");

async function main() {
  console.log("📡 Deploy \n");
  // auto deploy to read contract directory and deploy them all (add ".args" files for arguments)
  // await autoDeploy();
  // OR
  // custom deploy (to use deployed addresses)

  const MuseToken = await deploy("MuseToken");
  const VNFT = await deploy("VNFT", [MuseToken.address]);

  const MasterChef = await deploy("MasterChef", [
    MuseToken.address,
    "7523148148148000",
    VNFT.address,
  ]);

  const StakeForVnfts = await deploy("StakeForVnfts", [
    VNFT.address,
    MuseToken.address,
  ]);
  const PetAirdrop = await deploy("PetAirdrop", [
    VNFT.address,
    "0x331d49138d6f29e1a3e96b1179a95f6551f5c10daedea65c3230eb8ba4658556",
  ]);

  // grant minter role to PetAirdrop
  await VNFT.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    PetAirdrop.address
  );
  console.log("🚀 Granted VNFT Minter Role to PetAirdrop \n");

  // Grant Miner role to StakeForVnfts
  await VNFT.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    StakeForVnfts.address
  );
  console.log("🚀 Granted VNFT Minter Role to StakeForVnfts \n");

  // grant miner role to VNFT
  await MuseToken.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    VNFT.address
  );
  console.log("🚀 Granted MuseToken Minter Role to VNFT \n");

  // mint to other user to test erc1155 works

  await MuseToken.mint("0xc783df8a850f42e7F7e57013759C285caa701eB6", 1000);

  // grant miner role to Master Chef
  await MuseToken.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    MasterChef.address
  );

  console.log("🚀 Granted MuseToken Minter Role to MasterChef \n");

  // reate an item with 5 points
  const threeDays = 60 * 60 * 24 * 3;
  await VNFT.createItem("diamond", 5, 100, threeDays);
  await VNFT.createItem("cheat", 1, 10000, 60 * 60 * 24);
  await VNFT.createItem("cheat", 1, 10000, threeDays);
  console.log("🚀 added item diamond \n");

  await VNFT.mint("0xc783df8a850f42e7F7e57013759C285caa701eB6");
  console.log("🚀 Minted one vNFT to for test \n");

  // deploy VNFTx.sol

  const NiftyAddons = await deploy("NiftyAddons", [
    "https://gallery.verynifty.io/api/addon/",
  ]);

  console.log("🚀 Deployed Addons \n");

  const V1 = await deploy("V1", []);
  const VNFTx = await deploy("VNFTx", [
    VNFT.address,
    MuseToken.address,
    V1.address,
    NiftyAddons.address,
  ]);

  await MuseToken.approve(VNFTx.address, "1000000000000000000000");

  console.log("🚀 Deployed VNFTx \n");

  await NiftyAddons.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    VNFTx.address
  );
  console.log("🚀 Granted VNFT Minter Role to PetAirdrop \n");

  const createAddonShield = await VNFTx.createAddon(
    "shield",
    10,
    150,
    "RektMeRev",
    VNFTx.address,
    100
  );

  const createAddonHat = await VNFTx.createAddon(
    "hat",
    10,
    150,
    "RektMeRev",
    VNFTx.address,
    100
  );

  console.log("🚀 Created addon shield and hat \n");

  // run action function to test delegate contract
  const challenge = await VNFTx.action("challenge1(uint256)", 0);
  console.log("action on delegate contract", challenge);

  await VNFTx.buyAddon(0, 1);
  await VNFTx.buyAddon(0, 2);

  // return balance of
  const listSize = await VNFTx.addonsBalanceOf(0);
  const tokens = [];

  for (let index = 0; index < listSize; index++) {
    let id = await VNFTx.addonsOfNftByIndex(0, index);
    tokens.push(id.toString());
  }

  console.log("Addons Pet #0 owns", tokens);
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
