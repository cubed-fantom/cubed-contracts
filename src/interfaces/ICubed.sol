//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VaultLib} from "../libs/VaultLib.sol";

interface ICubed {
    function depositAndMint(
        uint256 _amount,
        uint256 _uniTokenId
    ) external payable returns (uint256, uint256);
	
    function updateOperator(uint256 _vaultId, address _operator) external;
}