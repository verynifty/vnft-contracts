pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "./interfaces/IMuseToken.sol";
import "./interfaces/IVNFT.sol";

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

contract TokenizeNFT is Ownable, ERC20PresetMinterPauser {
    using SafeMath for uint256;

    IVNFT public vnft;
    IMuseToken public muse;
    uint256 public premint;
    address public creator;
    uint256 public vestingPeriod;
    uint256 public MAXTOKENS = 20;
    uint256 public defaultGem;

    uint256 public currentNft; // maybe put it as an array to tokenize buckets?

    constructor(
        IVNFT _vnft,
        IMuseToken _muse,
        string memory _tokenName,
        string memory _tokenSymbol,
        address _creator,
        uint256 _premint,
        uint256 _vestingPeriod,
        uint256 _defaultGem
    ) public ERC20PresetMinterPauser(_tokenName, _tokenSymbol) {
        vnft = _vnft;
        muse = _muse;
        creator = _creator;
        premint = _premint;
        vestingPeriod = _vestingPeriod;
        defaultGem = _defaultGem;
        if (premint > 0) {
            mint(_creator, premint);
        }
        /* Need to have the transfer of vnft function here */
    }

    function join(address _to, uint256 _times) public {
        require(_times < MAXTOKENS, "Can't whale in");
        muse.transferFrom(
            msg.sender,
            address(this),
            vnft.itemPrice(defaultGem) * _times
        );
        uint256 index = 0;
        while (index < _times) {
            vnft.buyAccesory(currentNft, defaultGem);
            _times = _times + 1;
        }
        // Need to calculate the reward
        mint(_to, getJoinReturn(_times));
    }

    function getMuseValue(uint256 _quantity) public view returns (uint256) {
        uint256 reward = totalSupply().div(_quantity); // Need to put in percent and send make it to muse balance of this
        return reward;
    }

    function getJoinReturn(uint256 _times) public pure returns (uint256) {
        return _times; //need to calculate how much reward depending on time fed?
    }

    function remove(address _to, uint256 _quantity) public {
        _burn(msg.sender, _quantity);
        muse.transfer(_to, getMuseValue(_quantity));
    }
}
