// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
// OZ-ownable.sol: ADD - VS Code
import "docs.chain.link/samples/DataFeeds/ReserveConsumerV3.sol";

contract GoldToken is ERC20 {

    event TGOLDMinted(address indexed account, uint256 amount);
    event GoldTestPassed(address indexed account, uint16 qtyGold, uint8 purityGold);

    modifier onlyOwner() {
        require(owner == msg.sender, "Unauthorized Account");
        _;
    }

    address private owner;

    struct UserData {
        string s_userName;
        uint256 s_userIDNumber;
        uint16 s_qtyGold;       // can only be either 10g, 100g or 1000g Gold bars, 24K purity only (99.9%)
        uint8 s_purityGold;     // an integer value reresenting Karat
        uint8 s_flag;           // set to 1 when Gold-tests passed else default 0
    }

    mapping(address => UserData) private s_userData;

    uint8 public constant GOLDPURITY = 24;
     
    // ADD- use this while calculating number of TGOLD tokens for user's Gold bar: ((s_qtyGold * 999) * 10**8) / 1000;

    GoldReserveAndPrice internal immutable s_goldReserveAndPrice;

    constructor () ERC20 ("GoldToken", "TGOLD") { 
        owner = msg.sender;
        s_goldReserveAndPrice = GoldReserveAndPrice(0xEc29164D68c4992cEdd1D386118A47143fdcF142);
        // VS CODE - dynamically store the above deployment-address in VS Code via a script
    }

    function decimals() public pure override returns(uint8) {
        return 8;
    }

    function testGoldBarPassed(address account) public returns (bool) {
        require(s_userData[account].s_qtyGold == 10 || 
                s_userData[account].s_qtyGold == 100 || 
                s_userData[account].s_qtyGold == 1000, "Non-standard weight");

        require(s_userData[account].s_purityGold == GOLDPURITY, "Non-standard purity");
        
        // set flag to 1
        s_userData[account].s_flag = 1;
        emit GoldTestPassed(account, s_userData[account].s_qtyGold, s_userData[account].s_purityGold);
        return true;
    }
    
    // Only Contract-Owner can mint all the TGOLD tokens to the user
    function mint(address account) public onlyOwner() {
        require(s_userData[account].s_flag == 1, "User's Gold-test not passed");

        uint256 totalSupply = totalSupply();
        uint256 amountToMint = ((s_userData[account].s_qtyGold * 999) * 10**8) / 1000;  // decimal of TGOLD is 8, purity 24K = 99.9%
        uint256 supplyAfterMint = totalSupply + amountToMint;

        require(supplyAfterMint <= uint256(s_goldReserveAndPrice.getLatestReserve()), "Exceeded reserves");

        _mint(account, amountToMint);
        emit TGOLDMinted(account, amountToMint);  // can add account.name instead of account.address in the event
    }

    function getUserGoldPrice(address account) public view returns (uint256) {
        uint256 priceGold = uint256(s_goldReserveAndPrice.getLatestPrice());
        return ((uint256(s_userData[account].s_qtyGold) * 999) * priceGold) / 1000;
}

    function getUserData(address account) public view returns (string memory, uint256, uint16) {
        return (s_userData[account].s_userName, s_userData[account].s_userIDNumber, s_userData[account].s_qtyGold);
    }

    function getContractOwner() public view returns(address) {
        return owner;
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

