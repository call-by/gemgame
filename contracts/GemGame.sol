// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ERC721Metadata.sol";

contract GemGame is ERC721Metadata {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  // Max supply of NFTs
  uint256 public constant MAX_NFT_SUPPLY = 6886;

  // Mint price is 1.5 AVAX
  uint256 public constant MINT_PRICE = 1.5 ether;

  // Pending count
  uint256 public pendingCount = MAX_NFT_SUPPLY;

  // Start time for main drop
  uint256 public startTime = 1645808400;

  // Max number of giveaways
  uint256 public giveawayMax = 300;

  // Minters
  mapping(uint256 => address) public minters;

  // Total supply of NFTs
  uint256 private _totalSupply;

  // Pending Ids
  uint256[10001] private _pendingIds;

  // Giveaway winners
  mapping(uint256 => address) private _giveaways;
  Counters.Counter private _giveawayCounter;

  // Admin wallets
  address private _admin;
  address private _admin2;

  modifier periodStarted() {
    require(block.timestamp >= startTime, "GemGame: Period not started");
    _;
  }

  constructor(
    string memory baseURI_,
    address admin_,
    address admin2_
  ) ERC721Metadata("GemGame", "GEMGAME", baseURI_) {
    _admin = admin_;
    _admin2 = admin2_;
  }

  function setStartTime(uint256 _startTime) external onlyOwner {
    require(_startTime > 0, "GemGame: invalid _startTime");
    require(_startTime > block.timestamp, "GemGame: old start time");
    startTime = _startTime;
  }

  function setGiveawayMax(uint256 _giveawayMax) external onlyOwner {
    require(_giveawayMax >= 0 && _giveawayMax <= MAX_NFT_SUPPLY, "GemGame: invalid max value");
    require(giveawayMax != _giveawayMax, "GemGame: already set");
    giveawayMax = _giveawayMax;
  }

  function randomGiveaway(address to) external onlyOwner {
    require(to != address(0), "GemGame: zero address");
    require(_giveawayCounter.current() < giveawayMax, "GemGame: overflow giveaways");
    uint256 tokenId = _randomMint(to);
    _giveaways[tokenId] = to;
    _giveawayCounter.increment();
  }

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function purchase(uint256 numberOfNfts) external payable {
    require(pendingCount > 0, "GemGame: All minted");
    require(numberOfNfts > 0, "GemGame: numberOfNfts cannot be 0");
    require(numberOfNfts <= 20, "GemGame: You may not buy more than 20 NFTs at once");
    require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "GemGame: sale already ended");
    require(MINT_PRICE.mul(numberOfNfts) == msg.value, "GemGame: invalid ether value");

    for (uint256 i = 0; i < numberOfNfts; i++) {
      _randomMint(msg.sender);
    }
  }

  function getMintedCounts() public view returns (uint256) {
    uint256 count = 0;
    for (uint256 i = 1; i <= MAX_NFT_SUPPLY; i++) {
      if (minters[i] == msg.sender) {
        count += 1;
      }
    }
    return count;
  }

  function _randomMint(address _to) internal returns (uint256) {
    require(totalSupply() < MAX_NFT_SUPPLY, "GemGame: max supply reached");
    uint256 index = (_getRandom() % pendingCount) + 1;
    uint256 tokenId = _popPendingAtIndex(index);
    _totalSupply += 1;
    minters[tokenId] = msg.sender;
    _mint(_to, tokenId);

    return tokenId;
  }

  function getPendingIndexById(
    uint256 tokenId,
    uint256 startIndex,
    uint256 totalCount
  ) external view returns (uint256) {
    for (uint256 i = 0; i < totalCount; i++) {
      uint256 pendingTokenId = _getPendingAtIndex(i + startIndex);
      if (pendingTokenId == tokenId) {
        return i + startIndex;
      }
    }
    revert("NFTInitialSeller: invalid token id(pending index)");
  }

  function _getPendingAtIndex(uint256 _index) internal view returns (uint256) {
    return _pendingIds[_index] + _index;
  }

  function _popPendingAtIndex(uint256 _index) internal returns (uint256) {
    uint256 tokenId = _getPendingAtIndex(_index);
    if (_index != pendingCount) {
      uint256 lastPendingId = _getPendingAtIndex(pendingCount);
      _pendingIds[_index] = lastPendingId - _index;
    }
    pendingCount--;
    return tokenId;
  }

  function _getRandom() internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, pendingCount)));
  }
}
