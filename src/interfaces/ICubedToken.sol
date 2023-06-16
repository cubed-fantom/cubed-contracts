//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICubedToken {
    function init(address _cubedContract) external;

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;
}
