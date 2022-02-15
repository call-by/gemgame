// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IERC721Burnable {
  function ownerOf(uint256 tokenId) external view returns (address owner);

  function burn(uint256 tokenId) external;
}
