pragma solidity ^0.6.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./interfaces/IMuseToken.sol";
import "./interfaces/IVNFT.sol";

contract V1 is Ownable, ERC1155Holder {
    using SafeMath for uint256;

    bool paused = false;
    //for upgradability
    address public delegateContract;
    address[] public previousDelegates;
    uint256 public total = 1;

    IVNFT public vnft;
    IMuseToken public muse;
    IERC1155 public addons;

    uint256 public artistPct = 5;

    struct Addon {
        string _type;
        uint256 price;
        uint256 hp;
        uint256 rarity;
        string artistName;
        address artistAddr;
        uint256 quantity;
        uint256 used;
    }

    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 => Addon) public addon;

    mapping(uint256 => EnumerableSet.UintSet) private addonsConsumed;

    //nftid to rarity points
    mapping(uint256 => uint256) public rarity;

    using Counters for Counters.Counter;
    Counters.Counter private _addonId;

    uint256 public maxIds = 20;

    // uint256 public MAX_INT = 2**256 - 1;

    constructor(IVNFT _vnft, IMuseToken _muse) public {
        vnft = _vnft;
        muse = _muse;
    }

    modifier notPaused() {
        require(!paused, "PAUSED");
        _;
    }

    function challenge1(uint256 _nftId) public {
        rarity[_nftId] = rarity[_nftId] + 888;
    }

    /** Wafflemkr NIFTY TOOLS  
         github.com/verynifty/verynifty-tools/blob/master/contracts/NiftyTools.sol 
    /**
    
    /**
       @notice claim MUSE tokens from multiple vNFTs
        @dev contract should be whitelisted as caretaker beforehand
     */
    function claimMultiple(uint256[] calldata ids) external notPaused {
        require(ids.length <= maxIds, "LENGTH");

        for (uint256 i = 0; i < ids.length; i++) {
            require(vnft.ownerOf(ids[i]) == msg.sender);
            vnft.claimMiningRewards(ids[i]);
        }
        // Send muse to user
        require(muse.transfer(msg.sender, muse.balanceOf(address(this))));
    }

    function _checkAmount(uint256[] memory _itemIds)
        public
        view
        returns (uint256 totalAmt)
    {
        for (uint256 i = 0; i < _itemIds.length; i++) {
            totalAmt = totalAmt.add(vnft.itemPrice(_itemIds[i]));
        }
    }

    /**
        @notice feed multiple vNFTs with items/gems
        @dev contract should be whitelisted as caretaker beforehand   
        @dev contract should have MUSE allowance  
     */
    function feedMultiple(uint256[] calldata ids, uint256[] calldata itemIds)
        external
        notPaused
    {
        require(ids.length <= maxIds, "Too many ids");
        uint256 museCost = _checkAmount(itemIds);
        require(
            muse.transferFrom(msg.sender, address(this), museCost),
            "MUSE:Items"
        );

        require(muse.approve(address(vnft), museCost), "MUSE:approve");

        for (uint256 i = 0; i < ids.length; i++) {
            require(vnft.ownerOf(ids[i]) == msg.sender);
            vnft.buyAccesory(ids[i], itemIds[i]);
        }
    }

    /** NIFTY TOOLS  */

    function setMaxIds(uint256 _maxIds) public onlyOwner {
        maxIds = _maxIds;
    }

    function pause(bool _paused) public onlyOwner {
        paused = _paused;
    }
}
