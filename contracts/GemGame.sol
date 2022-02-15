// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ERC721Metadata.sol";

contract AvaPepes is ERC721Metadata {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  // Max supply of NFTs
  uint256 public constant MAX_NFT_SUPPLY = 10000;

  // Mint price is 2.5 AVAX
  uint256 public constant MINT_PRICE = 2.5 ether;

  // Pending count
  uint256 public pendingCount = MAX_NFT_SUPPLY;

  // Start time for main drop
  uint256 public startTime = 1633449600;

  // Max number of giveaways
  uint256 public giveawayMax = 400;

  // Total reflection balance
  uint256 public reflectionBalance;
  uint256 public totalDividend;
  mapping(uint256 => uint256) public lastDividendAt;

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
    require(block.timestamp >= startTime, "AvaPepes: Period not started");
    _;
  }

  constructor(
    string memory baseURI_,
    address admin_,
    address admin2_
  ) ERC721Metadata("AvaPepes", "AVAPEPE", baseURI_) {
    _admin = admin_;
    _admin2 = admin2_;
  }

  function setStartTime(uint256 _startTime) external onlyOwner {
    require(_startTime > 0, "AvaPepes: invalid _startTime");
    require(_startTime > block.timestamp, "AvaPepes: old start time");
    startTime = _startTime;
  }

  function setGiveawayMax(uint256 _giveawayMax) external onlyOwner {
    require(_giveawayMax >= 0 && _giveawayMax <= MAX_NFT_SUPPLY, "AvaPepes: invalid max value");
    require(giveawayMax != _giveawayMax, "AvaPepes: already set");
    giveawayMax = _giveawayMax;
  }

  function randomGiveaway(address to) external onlyOwner {
    require(to != address(0), "AvaPepes: zero address");
    require(_giveawayCounter.current() < giveawayMax, "AvaPepes: overflow giveaways");
    uint256 tokenId = _randomMint(to);
    _giveaways[tokenId] = to;
    _giveawayCounter.increment();
  }

  function presaleReward(
    address to,
    uint256 startIndex,
    uint256 count
  ) external onlyOwner {
    require(to != address(0), "AvaPepes: zero address");
    uint256 index = (_getRandom() % count) + startIndex;
    uint256 tokenId = _popPendingAtIndex(index);
    _totalSupply += 1;
    minters[tokenId] = to;
    _mint(to, tokenId);
  }

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function purchase(uint256 numberOfNfts) external payable {
    require(pendingCount > 0, "AvaPepes: All minted");
    require(numberOfNfts > 0, "AvaPepes: numberOfNfts cannot be 0");
    require(numberOfNfts <= 20, "AvaPepes: You may not buy more than 20 NFTs at once");
    require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "AvaPepes: sale already ended");
    require(MINT_PRICE.mul(numberOfNfts) == msg.value, "AvaPepes: invalid ether value");

    for (uint256 i = 0; i < numberOfNfts; i++) {
      _randomMint(msg.sender);
      _splitBalance(msg.value / numberOfNfts);
    }
  }

  function claimRewards() public {
    uint256 count = balanceOf(msg.sender);
    uint256 balance = 0;
    for (uint256 i = 0; i < count; i++) {
      uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
      if (_giveaways[tokenId] != address(0)) continue;
      balance += getReflectionBalance(tokenId);
      lastDividendAt[tokenId] = totalDividend;
    }
    payable(msg.sender).transfer(balance);
  }

  function getReflectionBalances() public view returns (uint256) {
    uint256 count = balanceOf(msg.sender);
    uint256 total = 0;
    for (uint256 i = 0; i < count; i++) {
      uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
      if (_giveaways[tokenId] != address(0)) continue;
      total += getReflectionBalance(tokenId);
    }
    return total;
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

  function claimReward(uint256 tokenId) public {
    require(
      ownerOf(tokenId) == _msgSender() || getApproved(tokenId) == _msgSender(),
      "AvaxApes: Only owner or approved can claim rewards"
    );
    require(_giveaways[tokenId] == address(0), "AvaxApes: can't claim for giveaways");
    uint256 balance = getReflectionBalance(tokenId);
    payable(ownerOf(tokenId)).transfer(balance);
    lastDividendAt[tokenId] = totalDividend;
  }

  function getReflectionBalance(uint256 tokenId) public view returns (uint256) {
    return totalDividend - lastDividendAt[tokenId];
  }

  function _splitBalance(uint256 amount) internal {
    uint256 reflectionShare = (amount * 20) / 100;
    uint256 mintingShare1 = ((amount - reflectionShare) * 60) / 100;
    uint256 mintingShare2 = ((amount - reflectionShare) * 40) / 100;
    _reflectDividend(reflectionShare);
    payable(_admin).transfer(mintingShare1);
    payable(_admin2).transfer(mintingShare2);
  }

  function _reflectDividend(uint256 amount) internal {
    reflectionBalance = reflectionBalance + amount;
    totalDividend = totalDividend + (amount / totalSupply());
  }

  function _randomMint(address _to) internal returns (uint256) {
    require(totalSupply() < MAX_NFT_SUPPLY, "AvaPepes: max supply reached");
    uint256 index = (_getRandom() % pendingCount) + 1;
    uint256 tokenId = _popPendingAtIndex(index);
    _totalSupply += 1;
    minters[tokenId] = msg.sender;
    lastDividendAt[tokenId] = totalDividend;
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
