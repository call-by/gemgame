import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";

const whitelists = [
  "0xe86AeBc40Bd023f8e1da04fB5A069fF823f8C62D",
  "0x7fDE1a599FCEd3139C7e8F2FCCE92526FF65A649",
  "0xFe035df35C6fE5578EdE6267883638DB7634DE82",
];

async function main() {
  let leafnodes: Buffer[], merkleTree: MerkleTree, merkleRoot: string;
  leafnodes = whitelists.map((addr) => keccak256(addr));
  merkleTree = new MerkleTree(leafnodes, keccak256, { sortPairs: true });
  merkleRoot = merkleTree.getHexRoot();

  console.log("merkleRoot", String(merkleRoot));
  const merkleData: { [key: string]: { leaf: string; proof: string[] } } = {};
  for (let i = 0; i < whitelists.length; i++) {
    const minter1Leaf = leafnodes[i].toString("hex");
    const minter1Proof = merkleTree.getHexProof(minter1Leaf);
    merkleData[whitelists[i]] = {
      leaf: "0x" + minter1Leaf,
      proof: minter1Proof,
    };
  }
  console.log(merkleData);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
