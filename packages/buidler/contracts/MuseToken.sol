// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract MuseToken is ERC20PresetMinterPauser {
    constructor(uint256 initialSupply)
        public
        ERC20PresetMinterPauser("Muse", "MUSE")
    {
        _mint(msg.sender, initialSupply);
    }
}
