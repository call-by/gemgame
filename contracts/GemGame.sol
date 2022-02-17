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
  uint256 public whitelistAllocation = 5;
  bool public whitelistUsable = false;

  // Max supply of NFTs
  uint256 public constant MAX_NFT_SUPPLY = 6886;

  // Mint price is 1.5 AVAX
  uint256 public constant MINT_PRICE = 1.5 ether;

  // Owner mint for giveaway
  bool public ownerMinted;

  // Start time for main drop
  uint256 public startTime = 1645808400;

  // Total supply of NFTs
  uint256 private _totalSupply;

  // Pending Ids
  uint256[] private _pendingIds;

  // Admin wallets
  address private _admin;

  modifier mintingStarted() {
    require(block.timestamp >= startTime, "GemGame: Mint not started");
    _;
  }

  modifier beforeMint(uint256 numberOfNfts) {
    require(_pendingIds.length > 0, "GemGame: All minted");
    require(numberOfNfts > 0, "GemGame: numberOfNfts cannot be 0");
    require(numberOfNfts <= 20, "GemGame: You may not buy more than 20 NFTs at once");
    require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "GemGame: not enough remaining");
    require(MINT_PRICE.mul(numberOfNfts) == msg.value, "GemGame: invalid ether value");

    _;
  }

  constructor(string memory baseURI_, address admin_)
    ERC721Metadata("GemGame", "GEMGAME", baseURI_)
  {
    _admin = admin_;
    // For owner mint, diamonds shouldn't be minted for giveaways
    for (uint256 i = 0; i < 6600; i++) {
      _pendingIds.push(i);
    }

    _pause();
  }

  // Ownable functions
  function pauseMint() external onlyOwner {
    _pause();
  }

  function unpauseMint() external onlyOwner {
    _unpause();
  }

  function setAdmin(address admin) external onlyOwner {
    _admin = admin;
  }

  function setWhitelistUsable(bool _whitelistUsable) external onlyOwner {
    whitelistUsable = _whitelistUsable;
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function setStartTime(uint256 _startTime) external onlyOwner {
    require(_startTime > 0, "GemGame: invalid _startTime");
    require(_startTime > block.timestamp, "GemGame: old start time");
    startTime = _startTime;
  }

  // end of ownable functions

  function ownerMint(address to) external onlyOwner {
    require(!ownerMinted, "Already minted");
    require(to != address(0), "Invalid recipient");
    _batchMint(to, 286);

    // After mint, set diamond ids
    for (uint256 i = 0; i < 286; i++) {
      _pendingIds.push(i + 6600);
    }

    ownerMinted = true;
  }

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
    uint256 index = _getRandom() % _pendingIds.length;
    uint256 tokenId = _pendingIds[index];
    _totalSupply++;
    _mint(_to, tokenId);

    _pendingIds[index] = _pendingIds[_pendingIds.length - 1];
    _pendingIds.pop();

    return tokenId;
  }

  function _getRandom() internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _pendingIds)));
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
  function withdraw() external {
    uint256 amount = address(this).balance;
    (bool success, ) = _admin.call{value: amount}("");
    require(success, "Failed to send ether");
  }
}
