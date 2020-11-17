pragma solidity ^0.6.0;

import "./interfaces/IVNFT.sol";
import "./interfaces/IMuseToken.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract MyContract {
    function calculate() public pure returns (bytes memory) {
        address accessory = 0x47F42e4d4dE7EBF20d582e57ecd88ff64B2d7910;

        address muse = 0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81;

        address VNFT = 0x57f0B53926dd62f2E26bc40B30140AbEA474DA94;

        bytes memory payload = abi.encodeWithSignature(
            "initialize(address,address,address)",
            VNFT,
            muse,
            accessory
        );

        return payload;
    }
}
