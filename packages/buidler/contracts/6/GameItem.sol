pragma solidity ^0.6.0;

// @TODO Add ERC165
// @TODO check how to implement correct BASE URI from Meme LTD for the API
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

    IBaseToken public token = IBaseToken(
        0x18b9306737eaf6E8FC8e737F488a1AE077b18053
    );

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _foodIds;

    // how much tokens to burn every time the pet is fed, the remaining goes to the community and devs
    uint256 public burnPercentage = 90;
    uint256 public maxFreePets = 100;
    // mining tokens
    mapping(address => uint256) public blockStartedMining;
    mapping(address => uint256) public timesMinedIn24Hours;
    mapping(address => uint256) public timeStartedMining;

    // pet
    mapping(uint256 => uint256) public blockLastFed;
    mapping(uint256 => uint256) public petScore;
    mapping(uint256 => uint256) public blockPetBorn;

    // food
    mapping(uint256 => uint256) public foodPrice;
    mapping(uint256 => uint256) public foodPoints;
    mapping(uint256 => string) public foodName;

    // returns the food id that is available to the user.
    // mapping(address => uint256) public foodAvailable;

    // constructor() public ERC721("GameItem", "ITM") {}
    constructor()
        public
        ERC721PresetMinterPauserAutoId("GameItem", "ITM", "google.com")
    {}

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
            "ERC721PresetMinterPauserAutoId: Must be operator to allow to claim more free pets"
        );
        maxFreePets = freePetsAmount;
    }

    function foodExists(uint256 foodId) public view returns (bool) {
        if (bytes(foodName[foodId]).length > 0) {
            return true;
        }
    }

    function isPetAlive(uint256 _petId) public view returns (bool) {
        uint256 _blockLastFed = blockLastFed[_petId];

        // check that was fed less then 24 hours ago otherwise dead af
        if (_blockLastFed != 0 && block.number.sub(_blockLastFed) < 10) {
            return true;
        }
    }

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
            blockStartedMining[msg.sender] = block.number;
            timesMinedIn24Hours[msg.sender] = 1;
        } else if (
            _timeStartedMining != 0 &&
            _timeStartedMining.add(1 days) > block.timestamp &&
            _timesMinedIn24Hours < 5
        ) {
            blockStartedMining[msg.sender] = block.number;
            timesMinedIn24Hours[msg.sender]++;
        } else if (_timesMinedIn24Hours == 5) {
            revert("You can mine up to 5 times per ~24 hours");
        }
    }

    // check that user waited at least {blocksNeededBeforeClaimingTokens} blocks and not more then {blocksNeededBeforeClaimingTokens + 4} blocks to claim tokens to make it as if he mined with "proof of time"
    function claimMiningRewards(uint256 petId) external {
        uint256 _blockStartedMining = blockStartedMining[msg.sender];
        uint256 _timesMinedIn24Hours = timesMinedIn24Hours[msg.sender];
        uint256 blocksNeededBeforeClaimingTokens = _timesMinedIn24Hours * 20;
        require(_blockStartedMining != 0, "You need to start mining first");
        require(_blockStartedMining < block.number);

        require(
            block.number.sub(_blockStartedMining) >
                blocksNeededBeforeClaimingTokens &&
                block.number.sub(_blockStartedMining) <
                (blocksNeededBeforeClaimingTokens.add(4)),
            "Current block number must be higher then start mining block"
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
            blockStartedMining[msg.sender] = 0;

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
            // erc20 _transfer pet tokens to admin, burn 90% and 10% send to gov contract
            token.transferFrom(msg.sender, address(this), amount);
            // burn 90% of token, 10% stay for dev and community fund
            token.burn(amount.sub(amountToBurn));
            blockLastFed[petId] = block.number;
            // calculate new points based on algorithm
            petScore[petId] += foodPoints[foodId];
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
        mint(player);
        // on creation add block it was "fed" in this case made alive to be able to calculate if 24 hours pass without further feeding to burn this pet
        blockLastFed[_tokenIds.current()] = block.number;
        blockPetBorn[_tokenIds.current()] = block.number;
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
