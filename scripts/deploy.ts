import { ethers, run } from "hardhat";
import { GemGame, GemGame__factory } from "../types";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer: ", deployer.address);

  // const gemGameFactory: GemGame__factory = await ethers.getContractFactory("GemGame");
  // let gemGame = await gemGameFactory.deploy("REVEAL", deployer.address);
  // await gemGame.deployed();

  // console.log("Deployed: ", gemGame.address);

  const gemGame: GemGame = await ethers.getContractAt(
    "GemGame",
    "0x9e8217DEDe230Ff3845C3E54Ca1Ff6e3233956bA"
  );

  // Verification
  // try {
  //   await run("verify:verify", {
  //     address: gemGame.address,
  //     constructorArguments: ["REVEAL", deployer.address],
  //   });
  // } catch (e) {
  //   console.log(e);
  // }

  for (let i = 0; i < 3; i++) {
    console.log("Mint started: ", i);
    const tx = await gemGame.ownerMint("0x6D4f8DFF04ba62BC76281c5fA320B9793EA5b973", {
      gasLimit: 5e6,
    });
    await tx.wait();
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
