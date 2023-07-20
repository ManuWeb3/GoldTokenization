// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "docs.chain.link/samples/DataFeeds/ReserveConsumerV3.sol";

contract GoldToken is ERC20 {

    event TGOLDMinted(address indexed account, uint256 amount);

    struct OwnerData {
        string s_ownerName;
        uint256 s_ownerIDNumber;
        uint16 s_qtyGold;    // can only be either 10g, 100g or 1000g Gold bars, 24K purity only (99.9%)
    }

    mapping(address => OwnerData) private s_userData;

    string private constant GOLDPURITY = "24K";
     
    // ADD- 2*REQUIRES to check these 2 qty. and purity  
    // ADD- use this while calculating number of TGOLD tokens for user's Gold bar: ((s_qtyGold * 999) * 10**8) / 1000;

    GoldReserveAndPrice internal immutable s_goldReserveAndPrice;

    constructor () ERC20 ("GoldToken", "TGOLD") { 
        s_goldReserveAndPrice = GoldReserveAndPrice(0x0813d4a158d06784FDB48323344896B2B1aa0F85);
        // VS CODE - dynamically store the above deployment-address in VS Code via a script
    }

    function decimals() public pure override returns(uint8) {
        return 8;
    }

    function mint(address account, uint256 amount) public {
        uint256 totalSupply = totalSupply();
        uint256 supplyAfterMint = totalSupply + amount;
        require(supplyAfterMint <= uint256(s_goldReserveAndPrice.getLatestReserve()), "Exceeded reserves, reverted");
        _mint(account, amount);
        emit TGOLDMinted(account, amount);
    }

    function testGoldBarPassed(uint16 goldQty, string memory goldPurity) public view returns (bool) {
        require(
            
        )
    }

    function getOwnerGoldPrice(address account) public view returns (uint256) {
        uint256 priceGold = uint256(s_goldReserveAndPrice.getLatestPrice());
        return ((uint256(s_userData[account].s_qtyGold) * 999) * priceGold) / 1000;
}

    function getOwnerData(address account) public view returns (string memory, uint256, uint16) {
        return (s_userData[account].s_ownerName, s_userData[account].s_ownerIDNumber, s_userData[account].s_qtyGold);
    }
    
    // function getOwnerName(address account) public view returns (string memory) {
    //     return s_userData[account].s_ownerName;
    // }

    // function getOwnerIDNumber(address account) public view returns (uint256) {
    //     return s_userData[account].s_ownerIDNumber;
    // }

    // function getOwnerGoldQty(address account) public view returns (uint8) {
    //     return s_userData[account].s_qtyGold;
    // }

}

