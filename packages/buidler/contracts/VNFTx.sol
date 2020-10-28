pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IStakeForVnfts.sol";
import "./interfaces/IMuseToken.sol";
import "./interfaces/IVNFT.sol";

contract VNFTx is Ownable {
    using SafeMath for uint256;

    IVNFT public vnft;
    IMuseToken public muse;

    mapping(uint256 => string) public addonName;
    mapping(uint256 => uint256) public addonPrice;
    mapping(uint256 => uint256) public addonRarity;

    mapping(uint256 => uint256) public rarity;

    using Counters for Counters.Counter;
    Counters.Counter private _addonId;

    constructor(IVNFT _vnft, IMuseToken _muse) public {
        vnft = _vnft;
        muse = _muse;
    }

    event BuyAddon(uint256 nftId, uint256 addon, address player);
    event CreateAddon(uint256 addonId, string name, uint256 rarity);
    event EditAddon(uint256 addonId, string name, uint256 price);

    /*Addons */

    function getAddon(uint256 _id)
        public
        view
        returns (
            string memory _addonName,
            uint256 _addonPrice,
            uint256 _addonRarity
        )
    {
        _addonName = addonName[_id];
        _addonPrice = addonPrice[_id];
        _addonRarity = addonRarity[_id];
    }

    function buyAddon(uint256 _nftId, uint256 addonId) external {
        require(
            vnft.ownerOf(_nftId) == msg.sender ||
                vnft.careTaker(_nftId, vnft.ownerOf(_nftId)) == msg.sender,
            "You must own the vNFT or be a care taker to buy items"
        );

        rarity[_nftId] = rarity[_nftId].add(addonRarity[addonId]);
        muse.burnFrom(msg.sender, addonPrice[_addonId.current()]);
        emit BuyAddon(_nftId, addonId, msg.sender);
    }

    function createAddon(
        string calldata name,
        uint256 price,
        uint256 _rarity
    ) external onlyOwner {
        _addonId.increment();
        uint256 newAddonId = _addonId.current();
        addonName[newAddonId] = name;
        addonPrice[newAddonId] = price * 10**18;
        addonRarity[newAddonId] = _rarity;
        emit CreateAddon(newAddonId, name, _rarity);
    }

    function editAddon(
        uint256 _id,
        string calldata name,
        uint256 price,
        uint256 _rarity
    ) external onlyOwner {
        addonName[_id] = name;
        addonPrice[_id] = price * 10**18;
        addonRarity[_id] = _rarity;
        emit EditAddon(_id, name, price);
    }

    /* end Addons */

    /* start Challenge */

    // @TODO challenge someone or kill someoen based on conditions
    function challenge() external {}

    /* end Challenge */
}
