/* eslint-disable no-console */
/* eslint-disable @typescript-eslint/no-extra-semi */
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { GemMine } from "../typechain";
import { parseEther } from "@ethersproject/units";
import { BigNumber } from "ethers";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";

chai.use(solidity);

const ADMIN_WALLET = process.env.ADMIN_WALLET || "";
const TOKEN_URI = "TokenURI/";

describe("GemMine", function () {
  let gemMine: GemMine;
  let deployer: SignerWithAddress;
  let minter1: SignerWithAddress;
  let minter2: SignerWithAddress;
  let minter3: SignerWithAddress;

  // merkle tree variables
  let whitelists: string[], leafnodes: Buffer[], merkleTree: MerkleTree, merkleRoot: string;

  before(async function () {
    [deployer, minter1, minter2, minter3] = await ethers.getSigners();

    const GemMine = await ethers.getContractFactory("GemMine");
    gemMine = (await GemMine.connect(deployer).deploy(deployer.address)) as GemMine;
    await gemMine.deployed();

    whitelists = [minter1.address, minter2.address];
    leafnodes = whitelists.map((addr) => keccak256(addr));
    merkleTree = new MerkleTree(leafnodes, keccak256, { sortPairs: true });
    merkleRoot = merkleTree.getHexRoot();
  });

  describe("#ownable", () => {
    it("setMintPrice", async function () {
      await gemMine.setMintPrice(parseEther("1"));
      expect(await gemMine.mintPrice()).to.eq(parseEther("1"));
      await expect(gemMine.connect(minter1).setMintPrice(parseEther("2"))).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setMaxItems", async function () {
      await gemMine.setMaxItems(BigNumber.from(50));
      expect(await gemMine.maxItems()).to.eq(BigNumber.from(50));
      await expect(gemMine.connect(minter1).setMaxItems(BigNumber.from(200))).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setAdmin", async function () {
      await gemMine.setAdmin(ADMIN_WALLET);
      expect(await gemMine.admin()).to.eq(ADMIN_WALLET);
      await expect(gemMine.connect(minter1).setAdmin(minter1.address)).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setStartTimestamp", async function () {
      await gemMine.setStartTimestamp(BigNumber.from(9942529782));
      expect(await gemMine.startTimestamp()).to.eq(BigNumber.from(9942529782));
      await expect(gemMine.connect(minter1).setStartTimestamp(BigNumber.from(100))).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setBaseTokenURI", async function () {
      await gemMine.setBaseTokenURI(TOKEN_URI);
      expect(await gemMine._baseTokenURI()).to.eq(TOKEN_URI);
      await expect(gemMine.connect(minter1).setBaseTokenURI("Changed")).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("setMerkleRoot", async function () {
      await gemMine.setMerkleRoot(String(merkleRoot));
      expect(await gemMine.merkleRoot()).to.eq(merkleRoot);
      await expect(gemMine.connect(minter1).setBaseTokenURI("Changed")).to.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
  });

  describe("#metadata", () => {
    it("tokenURI", async function () {
      expect(await gemMine.tokenURI(BigNumber.from(1))).to.eq(TOKEN_URI + "1.json");
    });
  });

  describe("#mint", () => {
    it("ownerMint", async function () {
      await expect(gemMine.ownerMint(20, ADMIN_WALLET)).to.revertedWith(
        "mintWithoutValidation: Surpasses maxItemsPerTx"
      );
      await gemMine.ownerMint(10, ADMIN_WALLET);
      expect(await gemMine.totalSupply()).to.eq(10);
      expect(await gemMine.balanceOf(ADMIN_WALLET)).to.eq(10);
    });

    it("whitelistMint", async function () {
      const minter1Idx = whitelists.indexOf(minter1.address);
      const minter1Leaf = leafnodes[minter1Idx].toString("hex");
      const minter1Proof = merkleTree.getHexProof(minter1Leaf);

      await expect(
        gemMine
          .connect(minter1)
          .whitelistMint(3, "0x" + minter1Leaf, minter1Proof, { value: parseEther("3") })
      ).to.revertedWith("Whitelist is not allowed");

      const tx = await gemMine.setWhitelistUsable(true);
      await tx.wait();

      await expect(
        gemMine.connect(deployer).whitelistMint(1, "0x" + minter1Leaf, minter1Proof)
      ).to.revertedWith("Sender don't match Merkle leaf");

      await expect(
        gemMine
          .connect(minter1)
          .whitelistMint(
            1,
            "0x" + minter1Leaf,
            merkleTree.getHexProof(leafnodes[1].toString("hex"))
          )
      ).to.revertedWith("Not a valid leaf in the Merkle tree");

      await expect(
        gemMine.connect(minter1).whitelistMint(0, "0x" + minter1Leaf, minter1Proof)
      ).to.revertedWith("Can't mint zero");

      await expect(
        gemMine.connect(minter1).whitelistMint(1, "0x" + minter1Leaf, minter1Proof)
      ).to.revertedWith("Send proper ETH amount");

      await expect(
        gemMine
          .connect(minter1)
          .whitelistMint(4, "0x" + minter1Leaf, minter1Proof, { value: parseEther("4") })
      ).to.revertedWith("Can't mint more than remaining allocation");

      const beforeGemMine = await ethers.provider.getBalance(gemMine.address);
      await gemMine
        .connect(minter1)
        .whitelistMint(3, "0x" + minter1Leaf, minter1Proof, { value: parseEther("3") });

      const afterGemMine = await ethers.provider.getBalance(gemMine.address);
      expect(afterGemMine.sub(beforeGemMine)).to.eq(parseEther("3"));
      expect(await gemMine.totalSupply()).to.eq(13);
    });

    it("publicMint", async function () {
      await expect(
        gemMine.connect(minter3).publicMint(3, { value: parseEther("3") })
      ).to.revertedWith("Not open yet");
      await gemMine.setStartTimestamp(0);
      await expect(
        gemMine.connect(minter3).publicMint(3, { value: parseEther("3") })
      ).to.revertedWith("Start timestamp not set");
      await gemMine.setStartTimestamp(Math.floor(new Date().getTime() / 1000));
      await expect(gemMine.publicMint(0)).to.revertedWith("Can't mint zero");
      await expect(gemMine.connect(minter3).publicMint(3)).to.revertedWith(
        "Send proper ETH amount"
      );
      const beforeGemMine = await ethers.provider.getBalance(gemMine.address);
      await gemMine.connect(minter3).publicMint(10, { value: parseEther("10") });
      const afterGemMine = await ethers.provider.getBalance(gemMine.address);
      expect(afterGemMine.sub(beforeGemMine)).to.eq(parseEther("10"));
      expect(await gemMine.totalSupply()).to.eq(23);
    });

    it("pauseMint", async function () {
      const minter2Idx = whitelists.indexOf(minter2.address);
      const minter2Leaf = leafnodes[minter2Idx].toString("hex");
      const minter2Proof = merkleTree.getHexProof(minter2Leaf);
      await gemMine.pauseMint();
      await expect(
        gemMine.connect(minter2).publicMint(10, { value: parseEther("10") })
      ).to.revertedWith("Pausable: paused");
      await expect(
        gemMine
          .connect(minter2)
          .whitelistMint(3, "0x" + minter2Leaf, minter2Proof, { value: parseEther("3") })
      ).to.revertedWith("Pausable: paused");
      await gemMine.unpauseMint();
      await expect(
        gemMine.connect(minter2).publicMint(10, { value: parseEther("10") })
      ).not.to.revertedWith("Pausable: paused");
      await expect(
        gemMine
          .connect(minter2)
          .whitelistMint(3, "0x" + minter2Leaf, minter2Proof, { value: parseEther("3") })
      ).not.to.revertedWith("Pausable: paused");
    });
  });

  describe("#withdraw", () => {
    it("withdraw", async function () {
      const beforeAdmin = await ethers.provider.getBalance(ADMIN_WALLET);
      await gemMine.withdraw();
      const afterAdmin = await ethers.provider.getBalance(ADMIN_WALLET);
      expect(afterAdmin.sub(beforeAdmin)).to.eq(parseEther("26"));
    });
  });
});
