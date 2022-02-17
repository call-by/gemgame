// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interface/IERC721Burnable.sol";

contract GemGiveaway is Ownable, ReentrancyGuard {
  /// @notice Gem collection address
  IERC721Burnable public collection;
  /// @notice Weekly reward amount for each winner
  uint256 rewardAmount;
  /// @notice Id for each type/color pair starting from 0. 0 ~ 329 for 6600 gems in 55 types/6 colors
  uint256[] private uniqueIds;
  /// @notice Unix timestamp for the start of current week
  uint256 giveawayStartTimestamp;
  /// @notice Reserved amount for fees
  uint256 constant FEE = 3 ether;

  /// @notice Pairs chosen so far
  uint256[] public pairs;
  /// @notice Winner list for current week
  address[40] public winners;
  /// @notice Indicates wheater or not the winners claimed for current week
  bool[40] public claimed;

  constructor(address _collection, uint256 firstWeeklyGiveawayStart) {
    collection = IERC721Burnable(_collection);
    for (uint256 i = 0; i < 330; i++) {
      uniqueIds.push(i);
    }
    giveawayStartTimestamp = firstWeeklyGiveawayStart;
  }

  function chooseRandomPairs() external onlyOwner {
    require(
      giveawayStartTimestamp < block.timestamp && uniqueIds.length >= 2,
      "Weekly giveaway not started yet"
    );
    giveawayStartTimestamp += 7 days; // next week
    rewardAmount = (address(this).balance - FEE) / 40; // 25% of the current treasury will be used as reward. Treasury will fund this contract every week. And it will be distributed equally among 40 winners

    // choose 2 random pairs
    getRandomNumber();
    getRandomNumber();
  }

  function claim() external nonReentrant {
    uint256 i;
    for (i = 0; i < 40; i++) {
      if (winners[i] == msg.sender && !claimed[i]) {
        break;
      }
    }
    require(i < 40, "Not winner for this week");

    uint256 tokenId = pairs[i / 20] * 20 + (i % 20);
    require(collection.ownerOf(tokenId) == msg.sender, "Ownership issue");

    // burn NFT
    claimed[i] = true;
    collection.burn(tokenId);
    (bool sent, ) = msg.sender.call{value: rewardAmount}("");
    require(sent, "Failed to send AVAX");
  }

  function withdraw(address to, uint256 value) external onlyOwner {
    (bool sent, ) = to.call{value: value}("");
    require(sent, "Failed to send AVAX");
  }

  function getRandomNumber() private {
    uint256 id = uint256(
      keccak256(abi.encodePacked(block.difficulty, block.timestamp, rewardAmount, uniqueIds))
    ) % uniqueIds.length;
    // remove element from the array
    uint256 newRandomNumber = uniqueIds[id];
    uniqueIds[id] = uniqueIds[uniqueIds.length - 1];
    uniqueIds.pop();

    pairs.push(newRandomNumber);

    if (pairs.length % 2 == 0) {
      // chose 2 winners
      for (uint256 i = 0; i < 20; i++) {
        winners[i] = collection.ownerOf(20 * pairs[pairs.length - 1] + i);
        winners[i + 20] = collection.ownerOf(20 * pairs[pairs.length - 2] + i);
        claimed[i] = claimed[i + 20] = false;
      }
    }
  }
}
