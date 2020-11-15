pragma solidity ^0.6.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./interfaces/IMuseToken.sol";
import "./interfaces/IVNFT.sol";
import "./interfaces/IVNFTx.sol";

// import "@nomiclabs/buidler/console.sol";

// @TODO create interface for VNFTx
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
        uint256 requiredhp;
        uint256 rarity;
        string artistName;
        address artistAddr;
        uint256 quantity;
        uint256 used;
    }

    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 => Addon) public addon;

    mapping(uint256 => EnumerableSet.UintSet) private addonsConsumed;
    EnumerableSet.UintSet lockedAddons;

    //nftid to rarity points
    mapping(uint256 => uint256) public rarity;
    mapping(uint256 => uint256) public challengesUsed;

    //!important, decides which gem score hp is based of
    uint256 public healthGemScore = 100;
    uint256 public healthGemId = 1;
    uint256 public healthGemPrice = 13 * 10**18;
    uint256 public healthGemDays = 1;

    // premium hp is the min requirement for premium features.
    uint256 public premiumHp = 90;
    uint256 public hpMultiplier = 70;
    uint256 public rarityMultiplier = 15;
    uint256 public addonsMultiplier = 15;
    //expected addons to be used for max hp
    uint256 public expectedAddons = 10;
    //Expected rarity, this should be changed according to new addons introduced.
    uint256 expectedRarity = 300;

    using Counters for Counters.Counter;
    Counters.Counter private _addonId;

    IVNFTx public vnftx;

    constructor(IVNFT _vnft, IMuseToken _muse) public {
        vnft = _vnft;
        muse = _muse;
    }

    function setVNFTX(IVNFTx _vnftx) public onlyOwner {
        vnftx = _vnftx;
    }

    modifier notPaused() {
        require(!paused, "PAUSED");
        _;
    }

    modifier notLocked(uint256 _id) {
        require(!lockedAddons.contains(_id), "This addon is locked");
        _;
    }

    modifier tokenOwner(uint256 _id) {
        require(
            vnft.ownerOf(_id) == msg.sender ||
                vnft.careTaker(_id, vnft.ownerOf(_id)) == msg.sender,
            "You must own the vNFT or be a care taker to buy addons"
        );
        _;
    }

    // func to test store update with delegatecall
    function challenge1(bytes memory data) public {
        uint256 _nftId;
        uint256 _add;
        // decode params
        (_nftId, _add) = abi.decode(data, (uint256, uint256));

        rarity[_nftId] = rarity[_nftId] + 888 + _add;
    }

    // simple battle for muse
    function battle(uint256 _nftId, uint256 _opponent)
        public
        tokenOwner(_nftId)
    {
        // require x challenges and x hp or xx rarity for battles
        require(
            vnftx.getChallenges(_nftId) >= 1 &&
                rarity[_nftId] >= 100 &&
                vnftx.getHp(_nftId) >= premiumHp &&
                vnft.level(_nftId) >= vnft.level(_opponent),
            "can't challenge"
        );

        // require opponent to be of certain threshold
        require(
            vnftx.getHp(_opponent) <= vnftx.getHp(_nftId),
            "You can't attack this pet"
        );

        // challenge used.
        challengesUsed[_nftId] = challengesUsed[_nftId].sub(1);

        // decrease something, maybe rarity or something that will lower the opponents hp;
        rarity[_opponent] = rarity[_opponent].sub(100);

        // send muse to attacker based on condition, maybe level of opponent
        muse.mint(msg.sender, 1 ether);
    }

    function cash(uint256 _nftId) external tokenOwner(_nftId) {
        //require to own the accessory and maintain x level of hp
        require(
            addonsConsumed[_nftId].contains(1) &&
                vnftx.getHp(_nftId) >= premiumHp,
            "You are not qualified"
        );

        uint256 currentScore = vnft.vnftScore(_nftId);
        uint256 timeBorn = vnft.timeVnftBorn(_nftId);
        uint256 daysLived = (now.sub(timeBorn)).div(1 days);

        // multiply by healthy gem divided by 2 (every 2 days)
        uint256 expectedScore = daysLived.mul(
            healthGemScore.div(healthGemDays)
        );

        uint256 scoreHealth = currentScore.mul(100).div(expectedScore);

        //hp will make sure they have good health from score, rarity and buy addons mix
        // scoreHealth makes sure they also extra leveled up so it can't be gamed (Basically get 90% from expected score)
        if (scoreHealth > premiumHp) {
            //check min burn required to get the cashback and send 40 percentage back on that.
            uint256 amount = (healthGemPrice.mul(uint256(7).div(healthGemDays)))
                .mul(40)
                .div(100);

            muse.mint(msg.sender, amount);
        }
    }
}
