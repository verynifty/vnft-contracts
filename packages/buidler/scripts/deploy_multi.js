const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("@nomiclabs/buidler");
MUSE_TOKEN = "0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81";
VNFT_CONTRACT = "0x57f0B53926dd62f2E26bc40B30140AbEA474DA94";
async function main() {
  console.log("📡 Deploy \n");

  const MultiVnft = await deploy("MultiVnft", [VNFT_CONTRACT, MUSE_TOKEN]);
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
