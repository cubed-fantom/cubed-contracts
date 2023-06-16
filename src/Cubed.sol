//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// interface
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {ICubedToken} from "./interfaces/ICubedToken.sol";

//contract
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//library
import {Uint256Casting} from "./libs/Uint256Casting.sol";
import {VaultLib} from "./libs/VaultLib.sol";

contract Cubed is Ownable, ReentrancyGuard, IERC721Receiver {
    using Uint256Casting for uint256;
    using VaultLib for VaultLib.Vault;

    address public vaultNFT;
    address public cubedToken;

    // these 2 parameters are always updated together. Use uint128 to batch read and write.
    uint128 public normalizationFactor;
    uint128 public lastFundingUpdateTimestamp;

    mapping(address => uint256) public vaultAssigned;
    mapping(uint256 => VaultLib.Vault) public vaults;

    event OpenVault(address sender, uint256 vaultId);
    event DepositCollateral(address sender, uint256 vaultId, uint256 amount);
    event MintShort(address sender, uint256 amount, uint256 vaultId);
    event UpdateOperator(address sender, uint256 vaultId, address operator);

    constructor(address _vaultNFT, address _cubedToken) {
        vaultNFT = _vaultNFT;
        cubedToken = _cubedToken;
    }

    /**
     * @notice deposit collateral and mint CUBE
     * @param _amount amount of powerPerp to mint
     * @param _uniTokenId uniswap v3 position token id (additional collateral)
     * @return vaultId
     * @return amount of CUBE minted
     */
    function depositAndMint(
        uint256 _amount,
        uint256 _uniTokenId
    ) external payable nonReentrant returns (uint256, uint256) {
        return _openDepositMint(msg.sender, _amount, msg.value, _uniTokenId);
    }

    /**
     * @notice wrapper function which opens a vault, adds collateral and mints CUBE
     * @param _account account to receive CUBE
     * @param _mintAmount amount to mint
     * @param _depositAmount amount of eth as collateral
     * _uniTokenId id of uniswap v3 position token
     * _isWAmount if the input amount is a CUBE amount (as opposed to rebasing powerPerp)
     * @return the vaultId that was acted on or for a new vault the newly created vaultId
     * @return the minted CUBE amount
     */
    function _openDepositMint(
        address _account,
        uint256 _mintAmount,
        uint256 _depositAmount,
        uint256 //_uniTokenId
        // bool _isWAmount
    ) internal returns (uint256, uint256) {
        // uint256 cachedNormFactor = _applyFunding();
        // uint256 depositAmountWithFee = _depositAmount;
        // uint256 wPowerPerpAmount = _isWAmount ? _mintAmount : _mintAmount.mul(ONE).div(cachedNormFactor);
        // uint256 feeAmount;
        VaultLib.Vault memory cachedVault;
        uint256 _vaultId;

        // load vault or create new a new one
        if (vaultAssigned[_account] == 0) {
            (_vaultId, cachedVault) = _openVault(_account);
            vaultAssigned[_account] = _vaultId;
        }

        if (_mintAmount > 0) {
            // (feeAmount, depositAmountWithFee) = _getFee(cachedVault, wPowerPerpAmount, _depositAmount);
            _mintCUBE(cachedVault, _account, _vaultId, _mintAmount);
        }
        if (_depositAmount > 0) _addEthCollateral(cachedVault, _vaultId, _depositAmount);
        // if (_uniTokenId != 0) _depositUniPositionToken(cachedVault, _account, _vaultId, _uniTokenId);

        // _checkVault(cachedVault, cachedNormFactor);
        _writeVault(_vaultId, cachedVault);

        // pay insurance fee
        // if (feeAmount > 0) payable(feeRecipient).sendValue(feeAmount);

        return (_vaultId, _mintAmount);
    }

    /**
     * @notice open a new vault
     * @dev create a new vault and bind it with a new short vault id
     * @param _recipient owner of new vault
     * @return id of the new vault
     * @return new in-memory vault
     */
    function _openVault(address _recipient) internal returns (uint256, VaultLib.Vault memory) {
        uint256 vaultId = IVaultNFT(vaultNFT).mintNFT(_recipient);

        VaultLib.Vault memory vault = VaultLib.Vault({
            NftCollateralId: 0,
            collateralAmount: 0,
            shortAmount: 0,
            operator: address(0)
        });
        emit OpenVault(msg.sender, vaultId);
        return (vaultId, vault);
    }

    /**
     * @notice authorize an address to modify the vault
     * @dev can be revoke by setting address to 0
     * @param _vaultId id of the vault
     * @param _operator new operator address
     */
    function updateOperator(uint256 _vaultId, address _operator) external {
        require(
            (vaultNFT == msg.sender) || (IVaultNFT(vaultNFT).ownerOf(_vaultId) == msg.sender),
            "Not authorised"
        );
        vaults[_vaultId].operator = _operator;
        emit UpdateOperator(msg.sender, _vaultId, _operator);
    }

    /**
     * @notice mint wPowerPerp (ERC20) to an account
     * @dev this function will update the vault memory in-place
     * @param _vault the Vault memory to update
     * @param _account account to receive wPowerPerp
     * @param _vaultId id of the vault
     * _wPowerPerpAmount wPowerPerp amount to mint
     */
    function _mintCUBE(
        VaultLib.Vault memory _vault,
        address _account,
        uint256 _vaultId,
        uint256 _amount
    ) internal {
        _vault.addShort(_amount);
        ICubedToken(cubedToken).mint(_account, _amount);

        emit MintShort(msg.sender, _amount, _vaultId);
    }

    /**
     * @notice add eth collateral into a vault
     * @dev this function will update the vault memory in-place
     * @param _vault the Vault memory to update.
     * @param _vaultId id of the vault
     * @param _amount amount of eth adding to the vault
     */
    function _addEthCollateral(
        VaultLib.Vault memory _vault,
        uint256 _vaultId,
        uint256 _amount
    ) internal {
        _vault.addEthCollateral(_amount);
        emit DepositCollateral(msg.sender, _vaultId, _amount);
    }

    function _writeVault(uint256 _vaultId, VaultLib.Vault memory _vault) private {
        vaults[_vaultId] = _vault;
    }

    /**
     * @dev accept erc721 from safeTransferFrom and safeMint after callback
     * @return returns received selector
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}