pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/presets/ERC1155PresetMinterPauser.sol";

import "./interfaces/IMuseToken.sol";
import "./interfaces/IVNFT.sol";

contract VNFTx is Ownable {
    using SafeMath for uint256;

    //for upgradability
    address public delegateContract;
    address[] public previousDelegates;
    uint256 public total = 1;

    IVNFT public vnft;
    IMuseToken public muse;

    uint256 public artistPct = 5;

    struct Addon {
        string name;
        uint256 price;
        uint256 rarity;
        string artistName;
        address artist;
    }

    mapping(uint256 => Addon) public addon;
    mapping(uint256 => uint256[]) public addonsConsumed;

    //nftid to rarity points
    mapping(uint256 => uint256) public rarity;

    using Counters for Counters.Counter;
    Counters.Counter private _addonId;

    event DelegateChanged(address oldAddress, address newAddress);
    event BuyAddon(uint256 nftId, uint256 addon, address player);
    event CreateAddon(uint256 addonId, string name, uint256 rarity);
    event EditAddon(uint256 addonId, string name, uint256 price);

    constructor(
        IVNFT _vnft,
        IMuseToken _muse,
        address _mainContract
    ) public {
        vnft = _vnft;
        muse = _muse;
        delegateContract = _mainContract;
        previousDelegates.push(delegateContract);
    }

    /*Addons */
    function buyAddon(uint256 _nftId, uint256 addonId) external {
        require(
            vnft.ownerOf(_nftId) == msg.sender ||
                vnft.careTaker(_nftId, vnft.ownerOf(_nftId)) == msg.sender,
            "You must own the vNFT or be a care taker to buy addons"
        );

        Addon storage _addon = addon[addonId];

        addonsConsumed[_nftId].push(addonId);

        rarity[_nftId] = rarity[_nftId].add(_addon.rarity);

        uint256 artistCut = _addon.price.mul(artistPct).div(100);
        muse.transferFrom(msg.sender, _addon.artist, artistCut);
        muse.burnFrom(msg.sender, _addon.price.sub(artistCut));
        emit BuyAddon(_nftId, addonId, msg.sender);
    }

    /* end Addons */

    // perform an action on delegate contract
    function action(string memory _signature, uint256 nftId) public {
        (bool success, ) = delegateContract.delegatecall(
            abi.encodeWithSignature(_signature, nftId)
        );

        require(success, "Action error");
    }

    /* ADMIN FUNCTIONS */

    function changeDelegate(address _newDelegate) external onlyOwner {
        require(
            _newDelegate != delegateContract,
            "New delegate should be diff"
        );
        previousDelegates.push(delegateContract);
        address oldDelegate = delegateContract;
        delegateContract = _newDelegate;
        total = total++;
        DelegateChanged(oldDelegate, _newDelegate);
    }

    function createAddon(
        string calldata name,
        uint256 price,
        uint256 _rarity,
        string calldata _artistName,
        address _artist
    ) external onlyOwner {
        _addonId.increment();
        uint256 newAddonId = _addonId.current();

        addon[newAddonId] = Addon(name, price, _rarity, _artistName, _artist);

        emit CreateAddon(newAddonId, name, _rarity);
    }

    function editAddon(
        uint256 _id,
        string calldata name,
        uint256 price,
        uint256 _rarity,
        string calldata _artistName,
        address _artist
    ) external onlyOwner {
        Addon storage _addon = addon[_id];

        _addon.name = name;
        _addon.price = price * 10**18;
        _addon.rarity = _rarity;
        _addon.artistName = _artistName;
        _addon.artist = _artist;
        emit EditAddon(_id, name, price);
    }

    function setArtistPct(uint256 _newPct) external onlyOwner {
        artistPct = _newPct;
    }
}
