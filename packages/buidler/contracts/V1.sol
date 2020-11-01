pragma solidity ^0.6.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IMuseToken.sol";
import "./interfaces/IVNFT.sol";

contract V1 is Ownable {
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

    constructor() public {}

    function challenge1(uint256 _nftId) public {
        rarity[_nftId] = rarity[_nftId] + 100;
    }
}
