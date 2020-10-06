pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

contract TokenRecover is Ownable {
    /**
     * @dev Remember that only owner can call so be careful when use on contracts generated from other contracts.
     * @param tokenAddress The token contract address
     * @param tokenAmount Number of tokens to be sent
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        public
        onlyOwner
    {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}

// Interface for our erc20 token
interface IMuseToken {
    function totalSupply() external view returns (uint256);

    function balanceOf(address tokenOwner)
        external
        view
        returns (uint256 balance);

    function allowance(address tokenOwner, address spender)
        external
        view
        returns (uint256 remaining);

    function transfer(address to, uint256 tokens)
        external
        returns (bool success);

    function approve(address spender, uint256 tokens)
        external
        returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) external returns (bool success);

    function mintingFinished() external view returns (bool);

    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

/*
 * Deployment checklist::
 *  1. Deploy all contracts
 *  2. Give minter role to the claiming contract
 *  3. Add objects (most basic cost 5 and give 1 day and 1 score)
 *  4.
 */

// ERC721,
contract VNFT is
    Ownable,
    ERC721PresetMinterPauserAutoId,
    TokenRecover,
    ERC1155Holder
{
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    IMuseToken public muse;

    struct VNFTObj {
        address token;
        uint256 id;
    }

    // Mapping from token ID to NFT struct details
    mapping(uint256 => VNFTObj) public vnftDetails;

    // max dev allocation is 10% of total supply
    uint256 public maxDevAllocation = 100000 * 10**18;
    uint256 public devAllocation = 0;

    // External NFTs
    struct NFTInfo {
        address token; // Address of LP token contract.
        bool active;
        uint256 standard; //the nft standard ERC721 || ERC1155
    }

    NFTInfo[] public supportedNfts;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemIds;

    // how many tokens to burn every time the VNFT is given an accessory, the remaining goes to the community and devs
    uint256 public burnPercentage = 90;
    uint256 public giveLifePrice = 5 * 10**18;

    bool public gameStopped = false;

    // mining tokens
    mapping(uint256 => uint256) public lastTimeMined;

    // VNFT properties
    mapping(uint256 => uint256) public timeUntilStarving;
    mapping(uint256 => uint256) public vnftScore;
    mapping(uint256 => uint256) public timeVnftBorn;

    // items/benefits for the VNFT could be anything in the future.
    mapping(uint256 => uint256) public itemPrice;
    mapping(uint256 => uint256) public itemPoints;
    mapping(uint256 => string) public itemName;
    mapping(uint256 => uint256) public itemTimeExtension;

    // mapping(uint256 => address) public careTaker;
    mapping(uint256 => mapping(address => address)) public careTaker;

    event BurnPercentageChanged(uint256 percentage);
    event ClaimedMiningRewards(uint256 who, uint256 amount);
    event VnftConsumed(uint256 nftId, uint256 itemId);
    event VnftMinted(address to);
    event ItemCreated(string name, uint256 price, uint256 points);
    event LifeGiven(uint256 forSupportedNFT, uint256 id);
    event CareTakerAdded(uint256 nftId, address _to);
    event CareTakerRemoved(uint256 nftId);

    constructor(address _museToken)
        public
        ERC721PresetMinterPauserAutoId("VNFT", "VNFT", "api.ourapi.com")
    {
        _setupRole(OPERATOR_ROLE, _msgSender());
        muse = IMuseToken(_museToken);
    }

    modifier notPaused() {
        require(!gameStopped, "Contract is paused");
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Roles: caller does not have the OPERATOR role"
        );
        _;
    }

    modifier onlyMinter() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Roles: caller does not have the MINTER role"
        );
        _;
    }

    // in case a bug happens or we upgrade to another smart contract
    function pauseGame(bool _pause) external onlyOperator {
        gameStopped = _pause;
    }

    // change how much to burn on each buy and how much goes to community.
    function changeBurnPercentage(uint256 percentage) external onlyOperator {
        require(percentage <= 100);
        burnPercentage = burnPercentage;
        emit BurnPercentageChanged(burnPercentage);
    }

    function changeGiveLifePrice(uint256 _newPrice) external onlyOperator {
        giveLifePrice = _newPrice * 10**18;
    }

    function changeMaxDevAllocation(uint256 amount) external onlyOperator {
        maxDevAllocation = amount;
    }

    function itemExists(uint256 itemId) public view returns (bool) {
        if (bytes(itemName[itemId]).length > 0) {
            return true;
        }
    }

    // check that VNFT didn't starve
    function isVnftAlive(uint256 _nftId) public view returns (bool) {
        uint256 _timeUntilStarving = timeUntilStarving[_nftId];
        if (_timeUntilStarving != 0 && _timeUntilStarving >= block.timestamp) {
            return true;
        }
    }

    function getVnftScore(uint256 _nftId) public view returns (uint256) {
        return vnftScore[_nftId];
    }

    function getVnftInfo(uint256 _nftId)
        public
        view
        returns (
            uint256 _vNFT,
            bool _isAlive,
            uint256 _score,
            uint256 _level,
            uint256 _expectedReward,
            uint256 _timeUntilStarving,
            uint256 _lastTimeMined,
            uint256 _timeVnftBorn,
            address _owner,
            address _token,
            uint256 _tokenId,
            address _careTaker
        )
    {
        _vNFT = _nftId;
        _isAlive = this.isVnftAlive(_nftId);
        _score = this.getVnftScore(_nftId);
        _level = this.level(_nftId);
        _expectedReward = this.getRewards(_nftId);
        _timeUntilStarving = timeUntilStarving[_nftId];
        _lastTimeMined = lastTimeMined[_nftId];
        _timeVnftBorn = timeVnftBorn[_nftId];
        _owner = this.ownerOf(_nftId);
        _token = vnftDetails[_nftId].token;
        _tokenId = vnftDetails[_nftId].id;
        _careTaker = careTaker[_nftId][ownerOf(_nftId)];
    }

    // get the level the vNFT is on to calculate points
    function level(uint256 tokenId) external view returns (uint256) {
        // This is the formula curve L(score)=(score)/(1+0.14 score)+1
        uint256 _score = vnftScore[tokenId].mul(100000);
        uint256 _level = _score.div(100000 + _score.mul(1400000).div(10000000));
        return (_level.add(1));
    }

    // get the level the vNFT is on to calculate the token reward
    function getRewards(uint256 tokenId) external view returns (uint256) {
        // This is the formula to get token rewards R(level)=5 + (level)/(4+0.1 level)+1
        uint256 _level = this.level(tokenId);
        if (_level == 1) {
            return (6 ether);
        }
        _level = _level.sub(1).mul(1 ether);
        uint256 _reward = uint256(6 ether).add(
            _level.mul(1 ether).div(
                uint256(4 ether).add(
                    uint256(1 ether).div(uint256(10).mul(_level))
                )
            )
        );
        return (_reward);
    }

    // edit specific item in case token goes up in value and the price for items gets to expensive for normal users.
    function editItem(
        uint256 _id,
        uint256 _price,
        uint256 _points,
        string calldata _name,
        uint256 _timeExtension
    ) external onlyOperator {
        itemPrice[_id] = _price;
        itemPoints[_id] = _points;
        itemName[_id] = _name;
        itemTimeExtension[_id] = _timeExtension;
    }

    //can mine once every 24 hours per token.
    function claimMiningRewards(uint256 nftId) external notPaused {
        require(isVnftAlive(nftId), "Your vNFT is dead, you can't mine");
        require(
            block.timestamp >= lastTimeMined[nftId].add(1 minutes) ||
                lastTimeMined[nftId] == 0,
            "Current timestamp is over the limit to claim the tokens"
        );
        require(
            ownerOf(nftId) == msg.sender ||
                careTaker[nftId][ownerOf(nftId)] == msg.sender,
            "You must own the vNFT to claim rewards"
        );

        //reset last start mined so can't remine and cheat
        lastTimeMined[nftId] = block.timestamp;
        uint256 _reward = this.getRewards(nftId);
        muse.mint(msg.sender, _reward);
        emit ClaimedMiningRewards(nftId, _reward);
    }

    // Buy accesory to the VNFT
    function buyAccesory(
        uint256 nftId,
        uint256 itemId,
        uint256 amount
    ) external notPaused {
        require(itemExists(itemId), "This item doesn't exist");
        require(amount >= itemPrice[itemId], "This item costs more tokens");
        require(
            ownerOf(nftId) == msg.sender ||
                careTaker[nftId][ownerOf(nftId)] == msg.sender,
            "You must own the vNFT or be a care taker to buy items"
        );
        require(isVnftAlive(nftId), "Your vNFT is dead");

        uint256 amountToBurn = amount.mul(burnPercentage).div(100);

        //recalculate timeUntilStarving.
        timeUntilStarving[nftId] = block.timestamp.add(
            itemTimeExtension[itemId]
        );
        vnftScore[nftId] = vnftScore[nftId].add(itemPoints[itemId]);

        // burn 90% so they go back to community mining and staking, and send 10% to devs
        if (devAllocation <= maxDevAllocation) {
            devAllocation = devAllocation.add(amount.sub(amountToBurn));
            muse.transferFrom(msg.sender, address(this), amount);
            // burn 90% of token, 10% stay for dev and community fund
            muse.burn(amountToBurn);
        } else {
            muse.burnFrom(msg.sender, amount);
        }
        emit VnftConsumed(nftId, itemId);
    }

    function setBaseURI(string memory baseURI_) public onlyOperator {
        _setBaseURI(baseURI_);
    }

    function mint(address player) public override onlyMinter {
        //pet minted has 3 days until it starves at first
        timeUntilStarving[_tokenIds.current()] = block.timestamp.add(3 days);
        timeVnftBorn[_tokenIds.current()] = block.timestamp;

        vnftDetails[_tokenIds.current()] = VNFTObj(
            address(this),
            _tokenIds.current()
        );
        super.mint(player);
        _tokenIds.increment();
        emit VnftMinted(msg.sender);
    }

    function burn(uint256 tokenId) public override notPaused {
        delete vnftDetails[tokenId];
        super.burn(tokenId);
    }

    // kill starverd NFT and get 10% of his points.
    function fatality(uint256 _deadId, uint256 _tokenId) external notPaused {
        require(
            !isVnftAlive(_deadId),
            "The vNFT has to be starved to claim his points"
        );
        vnftScore[_tokenId] = vnftScore[_tokenId].add(
            (vnftScore[_deadId].mul(10).div(100))
        );
        delete vnftDetails[_deadId];
        _burn(_deadId);
    }

    // Check how much score you'll get by fatality someone.
    function getFatalityReward(uint256 _deadId) public view returns (uint256) {
        if (!isVnftAlive(_deadId)) {
            return 0;
        } else {
            return (vnftScore[_deadId].mul(10).div(100));
        }
    }

    // add items/accessories
    function createItem(
        string calldata name,
        uint256 price,
        uint256 points,
        uint256 timeExtension
    ) external onlyOperator returns (bool) {
        _itemIds.increment();
        uint256 newItemId = _itemIds.current();
        itemName[newItemId] = name;
        itemPrice[newItemId] = price * 10**18;
        itemPoints[newItemId] = points;
        itemTimeExtension[newItemId] = timeExtension;
        emit ItemCreated(name, price, points);
    }

    //  *****************************
    //  LOGIC FOR EXTERNAL NFTS
    //  ****************************
    // support an external nft to mine rewards and play
    function addNft(address _nftToken, uint256 _type) public onlyOperator {
        supportedNfts.push(
            NFTInfo({token: _nftToken, active: true, standard: _type})
        );
    }

    function supportedNftLength() external view returns (uint256) {
        return supportedNfts.length;
    }

    function updateSupportedNFT(
        uint256 index,
        bool _active,
        address _address
    ) public onlyOperator {
        supportedNfts[index].active = _active;
        supportedNfts[index].token = _address;
    }

    // lets give life to your erc721 token and make it fun to mint $muse!
    function giveLife(
        uint256 index,
        uint256 _id,
        uint256 nftType
    ) external notPaused {
        uint256 amountToBurn = giveLifePrice.mul(burnPercentage).div(100);

        if (devAllocation <= maxDevAllocation) {
            devAllocation = devAllocation.add(giveLifePrice.sub(amountToBurn));
            muse.transferFrom(msg.sender, address(this), giveLifePrice);
            // burn 90% of token, 10% stay for dev and community fund
            muse.burn(amountToBurn);
        } else {
            muse.burnFrom(msg.sender, giveLifePrice);
        }

        if (nftType == 721) {
            IERC721(supportedNfts[index].token).transferFrom(
                msg.sender,
                address(this),
                _id
            );
        } else if (nftType == 1155) {
            IERC1155(supportedNfts[index].token).safeTransferFrom(
                msg.sender,
                address(this),
                _id,
                1, //the amount of tokens to transfer which always be 1
                "0x0"
            );
        }

        // mint a vNFT
        vnftDetails[_tokenIds.current()] = VNFTObj(
            supportedNfts[index].token,
            _id
        );
        super.mint(msg.sender);
        _tokenIds.increment();
        emit LifeGiven(index, _id);
    }

    // withdraw dead wrapped NFTs or send them to the burn address.
    function withdraw(
        uint256 _id,
        address _contractAddr,
        address _to,
        uint256 _type
    ) external onlyOperator {
        if (_type == 1155) {
            IERC1155(_contractAddr).safeTransferFrom(
                address(this),
                _to,
                _id,
                1,
                ""
            );
        } else if (_type == 721) {
            IERC721(_contractAddr).safeTransferFrom(
                address(this),
                _to,
                _id,
                ""
            );
        }
    }

    // add care taker so in the future if vNFTs are sent to tokenizing platforms like niftex we can whitelist and the previous owner could still mine and do interesting stuff.
    function addCareTaker(uint256 _tokenId, address _careTaker) external {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()) ||
                ownerOf(_tokenId) == msg.sender,
            "Roles: caller does not have the OPERATOR role"
        );
        careTaker[_tokenId][msg.sender] = _careTaker;
        emit CareTakerAdded(_tokenId, _careTaker);
    }

    function clearCareTaker(uint256 _tokenId) external {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()) ||
                ownerOf(_tokenId) == msg.sender,
            "Roles: caller does not have the OPERATOR role"
        );
        delete careTaker[_tokenId][msg.sender];
        emit CareTakerRemoved(_tokenId);
    }
}
