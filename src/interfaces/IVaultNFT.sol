//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultNFT is IERC721 {

    function init(address _cubedContract) external;

    function mintNFT(address _recipient) external returns (uint256 tokenId);
}
