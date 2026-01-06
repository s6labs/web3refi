const hre = require("hardhat");

async function main() {
  console.log("Deploying Invoice System contracts...");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Get network
  const network = await hre.ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  // Deploy InvoiceRegistry
  console.log("\n1. Deploying InvoiceRegistry...");
  const InvoiceRegistry = await hre.ethers.getContractFactory("InvoiceRegistry");
  const registry = await InvoiceRegistry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("InvoiceRegistry deployed to:", registryAddress);

  // Deploy InvoiceFactory
  console.log("\n2. Deploying InvoiceFactory...");
  const InvoiceFactory = await hre.ethers.getContractFactory("InvoiceFactory");
  const factory = await InvoiceFactory.deploy(
    deployer.address, // Default arbiter
    deployer.address  // Fee collector
  );
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("InvoiceFactory deployed to:", factoryAddress);

  // Grant roles to factory
  console.log("\n3. Granting roles to factory...");
  const REGISTRAR_ROLE = await registry.REGISTRAR_ROLE();
  await registry.grantRole(REGISTRAR_ROLE, factoryAddress);
  console.log("Granted REGISTRAR_ROLE to factory");

  // Verify deployment
  console.log("\n4. Verifying deployment...");
  const defaultArbiter = await factory.defaultArbiter();
  const feeCollector = await factory.feeCollector();
  const platformFee = await factory.platformFee();

  console.log("Factory configuration:");
  console.log("  - Default Arbiter:", defaultArbiter);
  console.log("  - Fee Collector:", feeCollector);
  console.log("  - Platform Fee:", platformFee.toString(), "basis points");

  // Summary
  console.log("\n✅ Invoice System Deployment Complete!");
  console.log("=====================================");
  console.log("InvoiceRegistry:", registryAddress);
  console.log("InvoiceFactory:", factoryAddress);
  console.log("=====================================");

  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: network.name,
    chainId: Number(network.chainId),
    deployer: deployer.address,
    contracts: {
      InvoiceRegistry: registryAddress,
      InvoiceFactory: factoryAddress,
    },
    timestamp: new Date().toISOString(),
  };

  const filename = `deployments/invoice-system-${network.chainId}.json`;
  fs.mkdirSync("deployments", { recursive: true });
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
  console.log("\nDeployment info saved to:", filename);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
