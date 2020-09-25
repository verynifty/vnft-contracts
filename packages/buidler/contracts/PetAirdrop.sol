pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@nomiclabs/buidler/console.sol";
import "./GameItem.sol";

contract PetAirdrop {

    event Claimed(bytes32, address);

    GameItem public immutable  petMinter;
    bytes32 public immutable  merkleRoot;

    // This is a packed array of booleans.
    mapping(bytes32 => uint256) private claimedBitMap;

    constructor(GameItem pet_minter_, bytes32 merkleRoot_) public {
        petMinter = pet_minter_;
        merkleRoot = merkleRoot_;
    }

    function isClaimed(bytes32 index) public view  returns (bool) {
        return claimedBitMap[index] == 1;
    }

    function _setClaimed(bytes32 index) private {
        claimedBitMap[index] = 1;
    }

    function claim(bytes32 index, bytes32[] calldata merkleProof) external  {
        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');
        console.logBytes(abi.encodePacked(index));
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index));
        console.logBytes32(node);
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);
       
       // petMinter.mintPet(msg.sender);

        emit Claimed(index, msg.sender);
    }
}