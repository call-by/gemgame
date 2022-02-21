import { ethers, run } from "hardhat";
import { GemGiveaway__factory } from "../types";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer: ", deployer.address);

  const gemGiveawayFactory: GemGiveaway__factory = await ethers.getContractFactory("GemGiveaway");
  const gemGiveaway = await gemGiveawayFactory.deploy(
    "0x2c023ae57513c8af66F5707314bC2cC5237AD713",
    1646002904
  );
  await gemGiveaway.deployed();

  console.log("Deployed: ", gemGiveaway.address);

  // Verification
  try {
    await run("verify:verify", {
      address: gemGiveaway.address,
      constructorArguments: ["0x2c023ae57513c8af66F5707314bC2cC5237AD713", 1646002904],
    });
  } catch (e) {
    console.log(e);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
