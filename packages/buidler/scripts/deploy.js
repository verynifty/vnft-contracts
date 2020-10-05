const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("@nomiclabs/buidler");



async function main() {
  console.log("📡 Deploy \n");
  // auto deploy to read contract directory and deploy them all (add ".args" files for arguments)
  // await autoDeploy();
  // OR
  // custom deploy (to use deployed addresses)
  const MuseToken = await deploy("MuseToken", [1000])
  const VNFT = await deploy("VNFT", [MuseToken.address])
  const MasterChef = await deploy("MasterChef", [MuseToken.address, 1, 1, 1])
  const StakeForVnfts = await deploy("StakeForVnfts", [VNFT.address, MuseToken.address])
  const PetAirdrop = await deploy("PetAirdrop", [VNFT.address, "0x2a3eb5e4fd7ca38eebd660d4b9879fd3e235cd240772bccdfadfa6c1529b4711"])

  // grant minter role to PetAirdrop
  await VNFT.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", PetAirdrop.address);
  console.log("🚀 Granted VNFT Minter Role to PetAirdrop \n")

  // Grant Miner role to StakeForVnfts
  await VNFT.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", StakeForVnfts.address);
  console.log("🚀 Granted VNFT Minter Role to StakeForVnfts \n")

  // grant miner role to Master Chef
  await MuseToken.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", MasterChef.address)
  console.log("🚀 Granted MuseToken Minter Role to MasterChef \n")


  // reate an item with 5 points
  const threeDays = 60 * 60 * 24 * 3
  await VNFT.createItem("diamond", 5, 1, threeDays)
  console.log("🚀 added item diamond \n");


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
