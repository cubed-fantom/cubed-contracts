//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//interface
import {ICubed} from "./interfaces/ICubed.sol";

//contract
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @notice ERC721 NFT representing ownership of a vault (short position)
 */
contract VaultNFT is ERC721, Initializable {
    /// @dev tokenId for the next vault opened
    uint256 public nextId = 1;

    address public cubedContract;
    address private immutable deployer;

    modifier onlyCubed() {
        require(msg.sender == cubedContract, "Not Cubed contract");
        _;
    }

    /**
     * @notice short power perpetual constructor
     * @param _name token name for ERC721
     * @param _symbol token symbol for ERC721
     */
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        deployer = msg.sender;
    }

    /**
     * @notice initialize cubed contract
     * @param _cubedContract Cubed address
     */
    function init(address _cubedContract) public initializer {
        require(msg.sender == deployer, "Invalid caller of init");
        require(_cubedContract != address(0), "Invalid controller address");
        cubedContract = _cubedContract;
    }

    /**
     * @notice mint new NFT
     * @dev autoincrement tokenId starts at 1
     * @param _recipient recipient address for NFT
     */
    function mintNFT(address _recipient) external onlyCubed returns (uint256 tokenId) {
        // mint NFT
        _safeMint(_recipient, (tokenId = nextId++));
    }

    function _beforeTokenTransfer(
        address, /* from */
        address, /* to */
        uint256 tokenId
    ) internal {
        ICubed(cubedContract).updateOperator(tokenId, address(0));
    }
}
