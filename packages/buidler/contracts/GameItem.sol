pragma solidity ^0.6.0;

// @TODO Add ERC165
// @TODO think of tokenomics and the points based system.
// @TODO think of ways to dynamically change food prices based on supply of tokens
// @TODO Create base staking contract, the rewards for staking should be minimmal compared to actual game playing so people just don't mine the token without playing
//@TODO Create minting contract, the only way to get new pets after initial airdrop should be by staking $pets, note that staked pets can also die

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    // using SafeMath for uint256;

    IBaseToken public token;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _foodIds;

    // how much tokens to burn every time the pet is fed, the remaining goes to the community and devs
    uint256 public burnPercentage = 90;
    uint256 public maxFreePets = 100;

    // mining tokens
    mapping(address => uint256) public timesMinedIn24Hours;
    mapping(address => uint256) public timeStartedMining;

    // pet
    mapping(uint256 => uint256) public timeUntilStarving;
    mapping(uint256 => uint256) public petScore;
    mapping(uint256 => uint256) public timePetBorn;

    // food
    mapping(uint256 => uint256) public foodPrice;
    mapping(uint256 => uint256) public foodPoints;
    mapping(uint256 => string) public foodName;

    // returns the food id that is available to the user.
    // mapping(address => uint256) public foodAvailable;

    constructor(address _baseToken)
        public
        ERC721PresetMinterPauserAutoId("GameItem", "ITM", "api.ourapi.com")
    {
        token = IBaseToken(_baseToken);
    }

    // maybe useful in futurer functiosn, not used for now
    // modifier checkPetAlive(uint256 petId) {
    //     require(isPetAlive(petId));
    //     _;
    // }

    // change how much to burn on each buy and how much goes to community.
    function changeBurnPercentage(uint256 percentage) external {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "ERC721PresetMinterPauserAutoId: Must be operator to set new BaseURI"
        );
        require(percentage <= 100);
        burnPercentage = burnPercentage;
    }

    function changeMaxFreePets(uint256 freePetsAmount) external {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "ERC721PresetMinterPauserAutoId: Must be operator to allow to allow more free pets"
        );
        maxFreePets = freePetsAmount;
    }

    function foodExists(uint256 foodId) public view returns (bool) {
        if (bytes(foodName[foodId]).length > 0) {
            return true;
        }
    }

    function isPetAlive(uint256 _petId) public view returns (bool) {
        uint256 _timeUntilStarving = timeUntilStarving[_petId];

        // check that pet didn't starve
        if (_timeUntilStarving != 0 && _timeUntilStarving >= block.timestamp) {
            return true;
        }
    }

    //this is just for text on local blockcahin
    function getCurrentBlock() public view returns (uint256) {
        return block.number;
    }

    // end erc20 example

    // User can start mining up to 5 times per 24 hours
    function startMining() public {
        // must own at least a token to start mining
        require(balanceOf(msg.sender) > 0);

        uint256 _timesMinedIn24Hours = timesMinedIn24Hours[msg.sender];
        uint256 _timeStartedMining = timeStartedMining[msg.sender];

        if (_timeStartedMining.add(1 days) < block.timestamp) {
            timeStartedMining[msg.sender] = block.timestamp;
            timesMinedIn24Hours[msg.sender] = 1;
        } else if (
            _timeStartedMining != 0 &&
            _timeStartedMining.add(1 days) > block.timestamp &&
            _timesMinedIn24Hours < 5
        ) {
            timeStartedMining[msg.sender] = block.timestamp;
            timesMinedIn24Hours[msg.sender]++;
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
        }
    }

    // feed the pet
    function feedPet(
        uint256 petId,
        uint256 foodId,
        uint256 amount
    ) external {
        require(foodExists(foodId), "This food doesn't exist");
        require(amount >= foodPrice[foodId], "This food costs more tokens");
        require(
            ownerOf(petId) == msg.sender,
            "You must own the pet to feed it"
        );
        if (!isPetAlive(petId)) {
            // burn pet cause it's dead
            _burn(petId);
        } else {
            // burn 90% of tokens paid
            uint256 amountToBurn = amount.mul(burnPercentage).div(100);
            //@TODO calculate based on food value how much more time it gives the pet.
            timeUntilStarving[petId] = timeUntilStarving[petId].add(1);
            //@TODO calculate new points based on algorithm
            petScore[petId] += foodPoints[foodId];
            // erc20 _transfer pet tokens to admin, burn 90% and 10% send to gov contract
            token.transferFrom(msg.sender, address(this), amount);
            // burn 90% of token, 10% stay for dev and community fund
            token.burn(amount.sub(amountToBurn));
        }
    }

    function setBaseURI(string memory baseURI_) public {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "ERC721PresetMinterPauserAutoId: Must be operator to set new BaseURI"
        );
        _setBaseURI(baseURI_);
    }

    // maybe only OPERATOR can mintPet at first and then anywone can mint a pet by helping us burn dead pets.
    function mintPet(address player) external {
        // only 100 pets can be minted for free
        require(totalSupply() <= maxFreePets);

        //pet minted has 24 hours until it starves at first
        timeUntilStarving[_tokenIds.current()] = block.timestamp.add(1 days);
        timePetBorn[_tokenIds.current()] = block.timestamp;
        mint(player);
    }

    // create foods only admin and set private in BaseToken
    function createFood(
        string calldata name,
        uint256 price,
        uint256 points
    ) external returns (bool) {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "ERC721PresetMinterPauserAutoId: must have operator role to create food"
        );
        _foodIds.increment();
        uint256 newFoodId = _foodIds.current();
        foodName[newFoodId] = name;
        foodPrice[newFoodId] = price * 10**18;
        foodPoints[newFoodId] = points;
    }

    // // buy food
    // function buyFood(uint256 foodId, uint256 amount) external returns (bool) {
    //     require(foodExists(foodId), "This food doesn't exist");
    //     require(amount >= foodPrice[foodId], "This food costs more tokens");
    //     require(
    //         foodAvailbale[msg.sender] == 0,
    //         "You can't buy extra food while you have one available"
    //     );
    //     // transfer erc20 $pet

    //     foodAvailable[msg.sender] = foodId;
    //     // only buy one food at a time for simplicity, you can always buy more after you use the food.
    // }
}
