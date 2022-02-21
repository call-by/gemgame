/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { expect } from "chai";
import { ethers } from "hardhat";
import { GemGame } from "../types";
import { parseEther } from "@ethersproject/units";
import { BigNumber } from "ethers";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";

chai.use(solidity);

const ADMIN_WALLET = process.env.ADMIN_WALLET || "";
const TOKEN_URI = "TokenURI/";

describe("GemGame", function () {
  let gemGame: GemGame;
  let deployer: SignerWithAddress;
  let minter1: SignerWithAddress;
  let minter2: SignerWithAddress;
  let minter3: SignerWithAddress;

  // merkle tree variables
  let whitelists: string[], leafnodes: Buffer[], merkleTree: MerkleTree, merkleRoot: string;

  before(async function () {
    [deployer, minter1, minter2, minter3] = await ethers.getSigners();
    const GemGame = await ethers.getContractFactory("GemGame");
    gemGame = (await GemGame.connect(deployer).deploy(TOKEN_URI, deployer.address)) as GemGame;
    await gemGame.deployed();

    whitelists = [minter1.address, minter2.address];
    leafnodes = whitelists.map((addr) => keccak256(addr));
    merkleTree = new MerkleTree(leafnodes, keccak256, { sortPairs: true });
    merkleRoot = merkleTree.getHexRoot();
  });

  describe("#ownable", () => {
    it("setAdmin", async function () {
      await gemGame.setAdmin(ADMIN_WALLET);
      expect(await gemGame.admin()).to.eq(ADMIN_WALLET);
      await expect(gemGame.connect(minter1).setAdmin(minter1.address)).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setStartTimestamp", async function () {
      await gemGame.setStartTime(BigNumber.from(9942529782));
      expect(await gemGame.startTime()).to.eq(BigNumber.from(9942529782));
      await expect(gemGame.connect(minter1).setStartTime(BigNumber.from(100))).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setMerkleRoot", async function () {
      await gemGame.setMerkleRoot(String(merkleRoot));
      expect(await gemGame.merkleRoot()).to.eq(merkleRoot);
    });
  });

  describe("#mint", () => {
    it("ownerMint", async function () {
      let i;
      for (i = 1; i <= 15; i++) {
        const tx = await gemGame.ownerMint(ADMIN_WALLET);
        const re = await tx.wait();
        // console.log("gas used:", re.gasUsed.toNumber());
        expect(await gemGame.totalSupply()).to.eq(20 * i);
        expect(await gemGame.balanceOf(ADMIN_WALLET)).to.eq(20 * i);
      }
      await gemGame.addDiamonds();
      await gemGame.unpauseMint();

      const mintedIds = (await gemGame.getMintedIds())
        .map((mintedId) => mintedId.toNumber())
        .sort(function (a, b) {
          return a - b;
        });
      const pendingIds = (await gemGame.getPendingIds()).map((pendingId) => pendingId.toNumber());
      const pendingCount = (await gemGame.pendingCount()).toNumber();
      expect(pendingCount).to.eq(6300 + 286);

      const flags: { [key: number]: boolean | undefined } = {};
      for (i = 0; i < mintedIds.length; i++) {
        expect(flags[mintedIds[i]]).to.eq(undefined);
        flags[mintedIds[i]] = true;
      }

      for (i = 0; i < pendingCount; i++) {
        const tokenId = (pendingIds[i] === 0 ? i + 1 : pendingIds[i]) - 1;
        expect(flags[tokenId]).to.eq(undefined);
        flags[tokenId] = true;
      }
    });

    it("whitelistMint", async function () {
      const minter1Idx = whitelists.indexOf(minter1.address);
      const minter1Leaf = leafnodes[minter1Idx].toString("hex");
      const minter1Proof = merkleTree.getHexProof(minter1Leaf);

      await expect(
        gemGame
          .connect(minter1)
          .whitelistMint(3, "0x" + minter1Leaf, minter1Proof, { value: parseEther("4.5") })
      ).to.revertedWith("Whitelist is not allowed");

      const tx = await gemGame.setWhitelistUsable(true);
      await tx.wait();

      await expect(
        gemGame
          .connect(deployer)
          .whitelistMint(1, "0x" + minter1Leaf, minter1Proof, { value: parseEther("1.5") })
      ).to.revertedWith("Sender don't match Merkle leaf");

      await expect(
        gemGame
          .connect(minter1)
          .whitelistMint(
            1,
            "0x" + minter1Leaf,
            merkleTree.getHexProof(leafnodes[1].toString("hex")),
            { value: parseEther("1.5") }
          )
      ).to.revertedWith("Not a valid leaf in the Merkle tree");

      await expect(
        gemGame.connect(minter1).whitelistMint(0, "0x" + minter1Leaf, minter1Proof)
      ).to.revertedWith("GemGame: numberOfNfts cannot be 0");
      await expect(
        gemGame
          .connect(minter1)
          .whitelistMint(1, "0x" + minter1Leaf, minter1Proof, { value: parseEther("1") })
      ).to.revertedWith("GemGame: invalid ether value");
      await expect(
        gemGame
          .connect(minter1)
          .whitelistMint(6, "0x" + minter1Leaf, minter1Proof, { value: parseEther("9") })
      ).to.revertedWith("Can't mint more than remaining allocation");

      const beforeGemMine = await ethers.provider.getBalance(gemGame.address);
      await gemGame
        .connect(minter1)
        .whitelistMint(3, "0x" + minter1Leaf, minter1Proof, { value: parseEther("4.5") });

      const afterGemMine = await ethers.provider.getBalance(gemGame.address);
      expect(afterGemMine.sub(beforeGemMine)).to.eq(parseEther("4.5"));
      expect(await gemGame.totalSupply()).to.eq(303);
      expect(await gemGame.balanceOf(minter1.address)).to.eq(3);
    });

    it("publicMint", async function () {
      await expect(
        gemGame.connect(minter3).publicMint(3, { value: parseEther("4.5") })
      ).to.revertedWith("GemGame: Mint not started");
      await gemGame.setStartTime(0);
      await expect(
        gemGame.connect(minter3).publicMint(3, { value: parseEther("4.5") })
      ).to.revertedWith("Start time not set");
      await gemGame.setStartTime(Math.floor(new Date().getTime() / 1000));
      await expect(gemGame.publicMint(0)).to.revertedWith("GemGame: numberOfNfts cannot be 0");
      await expect(
        gemGame.connect(minter3).publicMint(3, {
          value: parseEther("4"),
        })
      ).to.revertedWith("GemGame: invalid ether value");
      const beforeGemMine = await ethers.provider.getBalance(gemGame.address);
      await gemGame.connect(minter3).publicMint(10, { value: parseEther("15") });
      const afterGemMine = await ethers.provider.getBalance(gemGame.address);
      expect(afterGemMine.sub(beforeGemMine)).to.eq(parseEther("15"));
      expect(await gemGame.totalSupply()).to.eq(313);
    });

    it("pauseMint", async function () {
      const minter2Idx = whitelists.indexOf(minter2.address);
      const minter2Leaf = leafnodes[minter2Idx].toString("hex");
      const minter2Proof = merkleTree.getHexProof(minter2Leaf);
      await gemGame.pauseMint();
      await expect(
        gemGame.connect(minter2).publicMint(10, { value: parseEther("15") })
      ).to.revertedWith("Pausable: paused");
      await expect(
        gemGame
          .connect(minter2)
          .whitelistMint(3, "0x" + minter2Leaf, minter2Proof, { value: parseEther("4.5") })
      ).to.revertedWith("Pausable: paused");
      await gemGame.unpauseMint();
      await expect(
        gemGame.connect(minter2).publicMint(10, { value: parseEther("15") })
      ).not.to.revertedWith("Pausable: paused");
      await expect(
        gemGame
          .connect(minter2)
          .whitelistMint(3, "0x" + minter2Leaf, minter2Proof, { value: parseEther("4.5") })
      ).not.to.revertedWith("Pausable: paused");
    });
  });

  describe("#withdraw", () => {
    it("withdraw", async function () {
      const beforeAdmin = await ethers.provider.getBalance(ADMIN_WALLET);
      await gemGame.withdraw();
      const afterAdmin = await ethers.provider.getBalance(ADMIN_WALLET);
      expect(afterAdmin.sub(beforeAdmin)).to.eq(parseEther("39"));
      const pendingCount = (await gemGame.pendingCount()).toNumber();
      expect(pendingCount).to.eq(6560);
    });
  });
});
