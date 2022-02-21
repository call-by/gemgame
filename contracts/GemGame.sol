// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./ERC721Metadata.sol";

contract GemGame is ERC721Metadata, ReentrancyGuard, Pausable {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  bytes32 public merkleRoot = "";
  mapping(address => uint256) public whitelistRemaining;
  mapping(address => bool) public whitelistUsed;
  uint256 public whitelistAllocation = 10;
  bool public whitelistUsable = false;

  // Max supply of NFTs
  uint256 public constant MAX_NFT_SUPPLY = 6886;

  // Mint price is 1.5 AVAX
  uint256 public mintPrice = 1.5 ether;

  // Owner mint for giveaway
  bool public ownerMinted;

  // Start time for main drop
  uint256 public startTime = 1645808400;

  // Pending count for
  uint256 public pendingCount;

  // Total supply of NFTs
  uint256 private _totalSupply;

  // Pending Ids
  uint256[6600] private _pendingIds;
  uint256[] private mintedIds;

  // Admin wallets
  address public admin;

  modifier mintingStarted() {
    require(startTime != 0, "Start time not set");
    require(block.timestamp >= startTime, "GemGame: Mint not started");
    _;
  }

  modifier beforeMint(uint256 numberOfNfts) {
    require(ownerMinted, "Owner mint not done");
    require(pendingCount > 0, "GemGame: All minted");
    require(numberOfNfts > 0, "GemGame: numberOfNfts cannot be 0");
    require(numberOfNfts <= 20, "GemGame: You may not buy more than 20 NFTs at once");
    require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "GemGame: not enough remaining");
    require(mintPrice.mul(numberOfNfts) == msg.value, "GemGame: invalid ether value");

    _;
  }

  constructor(string memory baseURI_, address _admin)
    ERC721Metadata("GemGame", "GEMGAME", baseURI_)
  {
    admin = _admin;
    pendingCount = 6600; // Without diamonds for giveaway ownerMint
    _pause();
  }

  // Ownable functions
  function pauseMint() external onlyOwner {
    _pause();
  }

  function unpauseMint() external onlyOwner {
    _unpause();
  }

  function setAdmin(address _admin) external onlyOwner {
    admin = _admin;
  }

  function setWhitelistUsable(bool _whitelistUsable) external onlyOwner {
    whitelistUsable = _whitelistUsable;
  }

  function setWhitelistAllocation(uint256 _whitelistAllocation) external onlyOwner {
    whitelistAllocation = _whitelistAllocation;
  }

  function setMintPrice(uint256 _mintPrice) external onlyOwner {
    require(_mintPrice > 0, "Price can't be zero");
    mintPrice = _mintPrice;
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function setStartTime(uint256 _startTime) external onlyOwner {
    startTime = _startTime;
  }

  function ownerMint(address to) external onlyOwner {
    require(!ownerMinted, "Already minted");
    require(to != address(0), "Invalid recipient");
    _batchMint(to, 20);
  }

  function addDiamonds() external onlyOwner {
    require(pendingCount == 6300, "300 should be minted for giveaway");
    // After mint, set diamond ids
    for (uint256 i = 0; i < 286; i++) {
      _pendingIds[6300 + i] = 6601 + i;
    }

    pendingCount += 286;
    ownerMinted = true;
  }

  function getPendingIds() external view onlyOwner returns (uint256[6600] memory) {
    return _pendingIds;
  }

  function getMintedIds() external view onlyOwner returns (uint256[] memory) {
    return mintedIds;
  }

  // end of ownable functions

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function whitelistMint(
    uint256 amount,
    bytes32 leaf,
    bytes32[] memory proof
  ) external payable beforeMint(amount) whenNotPaused nonReentrant {
    require(whitelistUsable, "Whitelist is not allowed");

    // Create storage element tracking user mints if this is the first mint for them
    if (!whitelistUsed[msg.sender]) {
      // Verify that (msg.sender, amount) correspond to Merkle leaf
      require(keccak256(abi.encodePacked(msg.sender)) == leaf, "Sender don't match Merkle leaf");

      // Verify that (leaf, proof) matches the Merkle root
      require(verify(merkleRoot, leaf, proof), "Not a valid leaf in the Merkle tree");

      whitelistUsed[msg.sender] = true;
      whitelistRemaining[msg.sender] = whitelistAllocation;
    }

    require(whitelistRemaining[msg.sender] >= amount, "Can't mint more than remaining allocation");

    whitelistRemaining[msg.sender] -= amount;
    _batchMint(msg.sender, amount);
  }

  function publicMint(uint256 numberOfNfts)
    external
    payable
    mintingStarted
    beforeMint(numberOfNfts)
    whenNotPaused
    nonReentrant
  {
    _batchMint(msg.sender, numberOfNfts);
  }

  function _batchMint(address to, uint256 numberOfNfts) internal {
    for (uint256 i = 0; i < numberOfNfts; i++) {
      _randomMint(to);
    }
  }

  function _randomMint(address _to) internal returns (uint256) {
    require(totalSupply() < MAX_NFT_SUPPLY, "GemGame: max supply reached");
    uint256 index = _getRandom() % pendingCount;
    uint256 tokenId = _getTokenIdByIndex(index);
    _mint(_to, tokenId - 1); // actual tokenId should start from 0
    mintedIds.push(tokenId - 1);

    _pendingIds[index] = _getTokenIdByIndex(pendingCount - 1);
    pendingCount--;
    _totalSupply++;

    return tokenId - 1;
  }

  function _getTokenIdByIndex(uint256 index) internal view returns (uint256) {
    return _pendingIds[index] == 0 ? index + 1 : _pendingIds[index];
  }

  function _getRandom() internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, pendingCount)));
  }

  function verify(
    bytes32 root,
    bytes32 leaf,
    bytes32[] memory proof
  ) public pure returns (bool) {
    return MerkleProof.verify(proof, root, leaf);
  }

  /**
   * @dev Withdraw the contract balance to the administrator address
   */
  function withdraw() external onlyOwner {
    uint256 amount = address(this).balance;
    (bool success, ) = admin.call{value: amount}("");
    require(success, "Failed to send ether");
  }
}
