//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//interface
import {ICubedToken} from "./interfaces/ICubedToken.sol";

//contract
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @notice ERC20 Token representing wrapped long power perpetual position
 * @dev value of power perpetual is expected to go down over time through the impact of funding
 */
contract CubedToken is ERC20, Initializable, ICubedToken {
    address public cubedContract;
    address private immutable deployer;

    /**
     * @notice long power perpetual constructor
     * @param _name token name for ERC20
     * @param _symbol token symbol for ERC20
     */
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        deployer = msg.sender;
    }

    modifier onlyCubed() {
        require(msg.sender == cubedContract, "Not controller");
        _;
    }

    /**
     * @notice init wPowerPerp contract
     * @param _cubedContract controller address
     */
    function init(address _cubedContract) external initializer {
        require(msg.sender == deployer, "Invalid caller of init");
        require(_cubedContract != address(0), "Invalid controller address");
        cubedContract = _cubedContract;
    }

    /**
     * @notice mint CUBE token
     * @param _account account to mint to
     * @param _amount amount to mint
     */
    function mint(address _account, uint256 _amount) external override onlyCubed {
        _mint(_account, _amount);
    }

    /**
     * @notice burn CUBE token
     * @param _account account to burn from
     * @param _amount amount to burn
     */
    function burn(address _account, uint256 _amount) external override onlyCubed {
        _burn(_account, _amount);
    }
}
