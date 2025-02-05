const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying CollateralToken with the account:", deployer.address);

  const CollateralTokenFactory = await hre.ethers.getContractFactory("CollateralToken");
  const collateral = await CollateralTokenFactory.deploy(
    "Collateral USDC",    // name
    "cUSDC",              // symbol
    deployer.address      // owner
  );

  // ב-Ethers v6 אין "deployed()", אלא:
  await collateral.waitForDeployment();

  // כדי לקבל את הכתובת:
  const contractAddress = await collateral.getAddress();
  console.log("CollateralToken deployed at:", contractAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

