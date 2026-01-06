const hre = require("hardhat");

// Namehash implementation
function namehash(name) {
  let node = '0x0000000000000000000000000000000000000000000000000000000000000000';

  if (name) {
    const labels = name.split('.');
    for (let i = labels.length - 1; i >= 0; i--) {
      const labelHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(labels[i]));
      node = hre.ethers.keccak256(hre.ethers.concat([node, labelHash]));
    }
  }

  return node;
}

async function main() {
  console.log("Deploying UNS (Universal Name Service) contracts...");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Get network
  const network = await hre.ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  // TLD configuration (change based on network)
  const TLD_CONFIGS = {
    1: "web3refi",      // Ethereum
    137: "web3refi",    // Polygon
    56: "web3refi",     // BNB Chain
    42161: "web3refi",  // Arbitrum
    10: "web3refi",     // Optimism
    8453: "web3refi",   // Base
    43114: "web3refi",  // Avalanche
    31337: "web3refi",  // Localhost/Hardhat
  };

  const tld = TLD_CONFIGS[Number(network.chainId)] || "web3refi";
  const tldNode = namehash(tld);

  console.log("\nTLD Configuration:");
  console.log("  - TLD:", tld);
  console.log("  - TLD Node:", tldNode);

  // Deploy UniversalRegistry
  console.log("\n1. Deploying UniversalRegistry...");
  const UniversalRegistry = await hre.ethers.getContractFactory("UniversalRegistry");
  const registry = await UniversalRegistry.deploy(tld, tldNode);
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("UniversalRegistry deployed to:", registryAddress);

  // Deploy UniversalResolver
  console.log("\n2. Deploying UniversalResolver...");
  const UniversalResolver = await hre.ethers.getContractFactory("UniversalResolver");
  const resolver = await UniversalResolver.deploy(registryAddress);
  await resolver.waitForDeployment();
  const resolverAddress = await resolver.getAddress();
  console.log("UniversalResolver deployed to:", resolverAddress);

  // Verify deployment
  console.log("\n3. Verifying deployment...");
  const registryTld = await registry.tld();
  const registryTldNode = await registry.tldNode();
  const registryOwner = await registry.registryOwner();
  const resolverRegistry = await resolver.registry();

  console.log("Registry configuration:");
  console.log("  - TLD:", registryTld);
  console.log("  - TLD Node:", registryTldNode);
  console.log("  - Owner:", registryOwner);
  console.log("  - Controller (deployer):", deployer.address);

  console.log("\nResolver configuration:");
  console.log("  - Registry:", resolverRegistry);
  console.log("  - Match:", resolverRegistry === registryAddress ? "✓" : "✗");

  // Example: Register a test name
  console.log("\n4. Registering test domain...");
  const testName = "alice";
  const testNode = namehash(`${testName}.${tld}`);
  const testDuration = 365 * 24 * 60 * 60; // 1 year

  try {
    const tx = await registry.register(
      testNode,
      testName,
      deployer.address,
      testDuration
    );
    await tx.wait();
    console.log(`  - Registered: ${testName}.${tld}`);

    // Set resolver
    const tx2 = await registry.setResolver(testNode, resolverAddress);
    await tx2.wait();
    console.log(`  - Resolver set for: ${testName}.${tld}`);

    // Set address
    const tx3 = await resolver.setAddr(testNode, deployer.address);
    await tx3.wait();
    console.log(`  - Address set: ${deployer.address}`);

    // Verify resolution
    const resolvedAddress = await resolver.addr(testNode);
    console.log(`  - Resolved: ${testName}.${tld} → ${resolvedAddress}`);
    console.log(`  - Match: ${resolvedAddress === deployer.address ? "✓" : "✗"}`);
  } catch (error) {
    console.log("  - Test registration skipped (may already exist)");
  }

  // Summary
  console.log("\n✅ UNS Deployment Complete!");
  console.log("=====================================");
  console.log("UniversalRegistry:", registryAddress);
  console.log("UniversalResolver:", resolverAddress);
  console.log("TLD:", tld);
  console.log("=====================================");

  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: network.name,
    chainId: Number(network.chainId),
    deployer: deployer.address,
    tld: tld,
    tldNode: tldNode,
    contracts: {
      UniversalRegistry: registryAddress,
      UniversalResolver: resolverAddress,
    },
    testDomain: {
      name: `${testName}.${tld}`,
      node: testNode,
      owner: deployer.address,
    },
    timestamp: new Date().toISOString(),
  };

  const filename = `deployments/uns-${network.chainId}.json`;
  fs.mkdirSync("deployments", { recursive: true });
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
  console.log("\nDeployment info saved to:", filename);

  // Instructions
  console.log("\n📝 Next Steps:");
  console.log("1. Add more controllers to registry for name registration");
  console.log("2. Deploy registration controller contracts");
  console.log("3. Integrate with frontend");
  console.log("4. Set up indexer for name resolution");
  console.log("\nTo verify contracts on block explorer:");
  console.log(`npx hardhat verify --network ${network.name} ${registryAddress} "${tld}" "${tldNode}"`);
  console.log(`npx hardhat verify --network ${network.name} ${resolverAddress} "${registryAddress}"`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
