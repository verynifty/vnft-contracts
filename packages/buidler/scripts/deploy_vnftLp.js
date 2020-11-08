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

  const LP1 = await deploy("LP1");

  const VNFT = await deploy("VNFT", [MuseToken.address]);

  const VnftLp = await deploy("VnftLp", [43, VNFT.address]);

  //   create accessory so can fee pet to test more lp days
  const threeDays = 60 * 60 * 24 * 3;
  await VNFT.createItem("diamond", 5, 100, threeDays);

  //   create pool with LP1 token
  await VnftLp.add(100, LP1.address, true);
  console.log("🚀 added LP1 token pool \n");

  // grant minter role to VnftLp
  await VNFT.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    VnftLp.address
  );
  console.log("🚀 Granted VNFT Minter Role to VnftLp \n");

  // grant miner role to VNFT
  await MuseToken.grantRole(
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
    VNFT.address
  );
  console.log("🚀 Granted MuseToken Minter Role to VNFT \n");

  // mint muse to users
  await MuseToken.mint(
    "0xc783df8a850f42e7F7e57013759C285caa701eB6",
    "1000000000000000000000"
  );

  // mint a vnft to user so he can stake
  await VNFT.mint("0xc783df8a850f42e7F7e57013759C285caa701eB6");
  // Mint lp tokens
  await LP1.mint(
    "0xc783df8a850f42e7F7e57013759C285caa701eB6",
    "1000000000000000000000"
  );

  await MuseToken.approve(VNFT.address, "100000000000000000000000000000000000");

  //  Approve Vnftlp address for spending
  await LP1.approve(VnftLp.address, "100000000000000000000000000000000000");

  //   deposit lps
  await VnftLp.deposit(0, "1000000000000000000");
  console.log("🚀 Depsoited 1Lp into pool \n");

  const userDeposit = await VnftLp.userInfo(
    0,
    "0xc783df8a850f42e7F7e57013759C285caa701eB6"
  );
  console.log("user lp deposit: ", userDeposit.toString());

  // start 9 days of mining and claiming
  await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 + 2]); // add 1day
  //   buy accessory so can stay alive
  await VNFT.buyAccesory(0, 1);

  let pending = await VnftLp.pendingPoints(
    0,
    "0xc783df8a850f42e7F7e57013759C285caa701eB6"
  );
  console.log("1 day passed, got points: ", pending.toString());
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
