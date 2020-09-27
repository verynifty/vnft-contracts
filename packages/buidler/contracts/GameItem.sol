pragma solidity ^0.6.0;

// @TODO Add ERC165
// @TODO think of tokenomics and the points based system.
// @TODO think of ways to dynamically change food prices based on supply of tokens
// @TODO Write tests

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
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
interface IBaseToken {
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
}

// ERC721,
contract GameItem is Ownable, ERC721PresetMinterPauserAutoId, TokenRecover {
    IBaseToken public token;

    // for example this should be 10% of total coins
    uint256 public maxDevAllocation = 10000;
    uint256 public devAllocation = 0;

    // External NFTs
    struct NFTInfo {
        IERC721 token; // Address of LP token contract.
        uint256 reward; // this is to divide points that should be given for mining with this erc721, should be less then mining with our pets. example this is 10 to give 10% less rewards for this nft
        bool active;
    }

    NFTInfo[] public supportedNfts;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemIds;

    // how many tokens to burn every time the pet is fed, the remaining goes to the community and devs
    uint256 public burnPercentage = 90;
    uint256 public maxFreePets = 100;

    // mining tokens
    mapping(address => uint256) public timesMinedIn24Hours;
    mapping(address => uint256) public timeStartedMining;

    // pet
    mapping(uint256 => uint256) public timeUntilStarving;
    mapping(uint256 => uint256) public petScore;
    mapping(uint256 => uint256) public timePetBorn;
    mapping(uint256 => bool) public isOutsider;

    // items/benefits for the pet could be anything in the future such as food, glasses, hats, etc.
    mapping(uint256 => uint256) public itemPrice;
    mapping(uint256 => uint256) public itemPoints;
    mapping(uint256 => string) public itemName;
    mapping(uint256 => uint256) public itemTimeExtension;

    event BurnPercentageChanged(uint256 percentage);
    event StartedMining(address who, uint256 timestamp);
    event ClaimedMiningRewards(address who, uint256 amount);
    event PetBurned(uint256 id);
    event PetConsumed(uint256 petId, uint256 itemId);
    event PetMinted(address to);
    event ItemCreated(string name, uint256 price, uint256 points);
    event LifeGiven(uint256 forSupportedNFT, uint256 id);
    event PetSentToValhalla(uint256 forSupportedNFT, uint256 id);

    constructor(address _baseToken)
        public
        ERC721PresetMinterPauserAutoId("GameItem", "ITM", "api.ourapi.com")
    {
        token = IBaseToken(_baseToken);
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Roles: caller does not have the OPERATOR role"
        );
        _;
    }

    modifier isSupportedNFT(uint256 nftId, uint256 _id) {
        require(
            supportedNfts[nftId].token.ownerOf(_id) == msg.sender,
            "You are not the owner of this NFT"
        );
        _;
    }

    // change how much to burn on each buy and how much goes to community.
    function changeBurnPercentage(uint256 percentage) external onlyOperator {
        require(percentage <= 100);
        burnPercentage = burnPercentage;
        emit BurnPercentageChanged(burnPercentage);
    }

    function changeMaxFreePets(uint256 freePetsAmount) external onlyOperator {
        maxFreePets = freePetsAmount;
    }

    function changeMaxDevAllocation(uint256 amount) external onlyOperator {
        maxDevAllocation = amount;
    }

    function itemExists(uint256 itemId) public view returns (bool) {
        if (bytes(itemName[itemId]).length > 0) {
            return true;
        }
    }

    // check that pet didn't starve
    function isPetAlive(uint256 _petId) public view returns (bool) {
        uint256 _timeUntilStarving = timeUntilStarving[_petId];

        if (_timeUntilStarving != 0 && _timeUntilStarving >= block.timestamp) {
            return true;
        }
    }

    function getPetScore(uint256 _petId) public view returns (uint256) {
        return petScore[_petId];
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

    //this is just for test on local blockcahin
    function getCurrentBlock() public view returns (uint256) {
        return block.number;
    }

    // User can start mining up to 5 times per 24 hours
    function startMining() public {
        // must own at least a token to start mining
        require(balanceOf(msg.sender) > 0);

        uint256 _timesMinedIn24Hours = timesMinedIn24Hours[msg.sender];
        uint256 _timeStartedMining = timeStartedMining[msg.sender];

        if (_timeStartedMining.add(1 days) < block.timestamp) {
            timeStartedMining[msg.sender] = block.timestamp;
            timesMinedIn24Hours[msg.sender] = 1;
            emit StartedMining(msg.sender, timeStartedMining[msg.sender]);
        } else if (
            _timeStartedMining != 0 &&
            _timeStartedMining.add(1 days) > block.timestamp &&
            _timesMinedIn24Hours < 5
        ) {
            timeStartedMining[msg.sender] = block.timestamp;
            timesMinedIn24Hours[msg.sender]++;
            emit StartedMining(msg.sender, timeStartedMining[msg.sender]);
        } else if (_timesMinedIn24Hours == 5) {
            revert("You can mine up to 5 times per ~24 hours");
        }
    }

    // check that user waited at least {timeNeededBeforeClaimingTokens} and not more then {timeNeededBeforeClaimingTokens + 2 minutes} to claim tokens to make it as if he mined with "proof of time"
    function claimMiningRewards(uint256 petId) external {
        uint256 _timeStartedMining = timeStartedMining[msg.sender];
        uint256 _timesMinedIn24Hours = timesMinedIn24Hours[msg.sender];
        uint256 timeNeededBeforeClaimingTokens = _timeStartedMining
            .add(10 minutes)
            .mul(_timesMinedIn24Hours);
        require(_timeStartedMining != 0, "You need to start mining first");
        require(_timeStartedMining < block.timestamp);
        require(
            block.timestamp <= timeNeededBeforeClaimingTokens.add(2 minutes),
            "Current timestamp is over the limit to claim the tokens"
        );

        // must be owner of token to claim reward, this is a check to make sure the pet is alive
        require(
            ownerOf(petId) == msg.sender,
            "You must own a pet to claim rewards"
        );
        if (!isPetAlive(petId)) {
            // burn pet cause it's dead
            _burn(petId);
        } else {
            //reset last start mined so can't remine and cheat
            timeStartedMining[msg.sender] = 0;

            // @TODO do calculation based on previous points earned in the game and send amount of tokens deserved "farmed"

            // @TODO send calculated erc20 tokens to user
            token.mint(msg.sender, 1);
            emit ClaimedMiningRewards(msg.sender, 1);
        }
    }

    // feed the pet
    function feedPet(
        uint256 petId,
        uint256 itemId,
        uint256 amount
    ) external {
        require(itemExists(itemId), "This item doesn't exist");
        require(amount >= itemPrice[itemId], "This item costs more tokens");
        require(
            ownerOf(petId) == msg.sender,
            "You must own the pet to feed it"
        );
        if (!isPetAlive(petId)) {
            // burn pet cause it's dead
            _burn(petId);
            emit PetBurned(petId);
        } else {
            uint256 amountToBurn = amount.mul(burnPercentage).div(100);
            uint256 devFee = amount.sub(amountToBurn);
            // calculate how many days the pet is alive, we could add this to the algorithm to calculate points;
            // uint256 daysAlive = block.timestamp.sub(timePetBorn[petId]).div(
            //     86400
            // );
            // // based on item recalculate timeUntilStarving.
            // not sure if this needs to be added or this needs to be replaces for new timeUntilStarving.
            timeUntilStarving[petId] = timeUntilStarving[petId].add(
                itemTimeExtension[itemId]
            );
            //@TODO calculate new points based on an algorithm
            petScore[petId] = petScore[petId].add(itemPoints[itemId]);

            // burn 90% so they go back to community mining and staking, and send 10% to devs
            if (devAllocation <= maxDevAllocation) {
                devAllocation = devAllocation.add(devFee);
                token.transferFrom(msg.sender, address(this), devFee);
                // burn 90% of token, 10% stay for dev and community fund
                token.burn(amount.sub(amountToBurn));
            } else {
                token.burn(amount);
            }
            emit PetConsumed(petId, itemId);
        }
    }

    function setBaseURI(string memory baseURI_) public onlyOperator {
        _setBaseURI(baseURI_);
    }

    // maybe only OPERATOR can mintPet at first and then anyone can mint a pet by helping us burn dead pets.
    function mintPet(address player) external {
        // only 100 pets can be minted for free
        require(totalSupply() <= maxFreePets);

        //pet minted has 7 days until it starves at first
        timeUntilStarving[_tokenIds.current()] = block.timestamp.add(7 days);
        timePetBorn[_tokenIds.current()] = block.timestamp;
        mint(player);
        emit PetMinted(msg.sender);
    }

    // add pet items
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
    function addNft(IERC721 _nftToken, uint256 _reward) public onlyOperator {
        supportedNfts.push(
            NFTInfo({token: _nftToken, reward: _reward, active: true})
        );
    }

    function supportedNftLength() external view returns (uint256) {
        return supportedNfts.length;
    }

    function updateSupportedNFT(
        uint256 _id,
        uint256 _reward,
        bool _active
    ) public onlyOperator {
        supportedNfts[_id].reward = _reward;
        supportedNfts[_id].active = _active;
    }

    // lets give life to your erc721 token and make it fun to mint $pets!
    function giveLife(uint256 nftId, uint256 _id)
        external
        isSupportedNFT(nftId, _id)
    {
        // check that msg.sender is owner of the nft he is giving life to
        require(
            supportedNfts[nftId].token.ownerOf(_id) == msg.sender,
            "You are not the owner of this NFT"
        );

        // we somehow need to add the supported nft to the "db" and keep track of points ,timeUntilStarved,  need help here
        // Jules we can store all mappings (including ours with our address) as maps like timeuntilstarved[NFTaddress][NFTID] instead of timeuntilstarved[nftid]
        emit LifeGiven(nftId, _id);
    }

    // send your current NFT to valhalla and get a $pet NFT
    function valhalla(uint256 nftId, uint256 _id)
        external
        isSupportedNFT(nftId, _id)
    {
        // check that msg.sender is owner the NFT id
        require(
            supportedNfts[nftId].token.ownerOf(_id) == msg.sender,
            "You are not the owner of this NFT"
        );
        // send your NFT to valhalla
        supportedNfts[nftId].token.transferFrom(msg.sender, address(0), _id);
        // get our NFT
        mint(msg.sender);
        emit PetSentToValhalla(nftId, _id);
    }
}
