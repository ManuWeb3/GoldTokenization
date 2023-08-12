// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./GoldReserveAndPrices.sol";

contract GoldToken is ERC20, GoldReserveAndPrices, Ownable {

    error InsufficientFunding(uint256 amountFunded, uint256 amountMinimumRequired);
    error TestAlreadyDone();
    error NonStandardPurity();
    error UserGoldTestNotPassed();
    error TGOLDAlreadyMinted();
    error ExceededReserves();
    error SendFailed();

    event TGOLDMinted(address indexed account, uint256 amount);
    event GoldTestPassed(address indexed account, uint256 qtyGold, uint8 purityGold);
    event NewUserData(address indexed account, string userName, uint256 userIDNumber, uint256 qtyGold, uint8 purityGold, uint8 turn);
    event ContractBalanceRedeemedToOwner(uint256 contractBalance);
    event TGOLDRedeemedAsWeiToUser(address indexed account, uint256 tGOLDAmountRedeemed, uint256 weiSent);

    struct UserData {
        string s_userName;
        uint256 s_userIDNumber;
        uint256 s_qtyGold;      // can only be either 10g, 100g or 1000g Gold bars, 24K purity only (99.9%)
        uint8 s_purityGold;     // an integer value representing Karat
        uint8 s_flag;           // set to 1 when Gold-tests passed else default 0
        bool s_goldTestingDone; // whether test conducted irrespective of the pass/fail outcome
        uint8 s_turn;   
        bool s_goldTokensMinted;  // default false, true when minted by the Owner to avoid repeat / infinite mint      
    }

    // mapping account to a unique turn-number for a user's recurring deposits (default turn = 1 for an account)
    mapping(address => mapping(uint8 => UserData)) private s_userData;

    uint8 public constant GOLDPURITY = 24;
    uint256 private totalSupplyTGOLD;
     
    constructor () ERC20 ("GoldToken", "TGOLD") Ownable(msg.sender) payable { 
        if(msg.value < 10*1e18) {
            revert InsufficientFunding(msg.value, 10*1e18);
        }
        // Below, assigned all the TGOLD tokens/units equal to CacheGold's PoR reserve value to the contract owner
        // _totalSupply private state var. of ERC20 can only be written in mint()/burn()
        totalSupplyTGOLD = uint256(getLatestReserve());
        _mint(owner(), totalSupplyTGOLD);
    }

    // only Contract-owner should have access to enter legit user data, event emit, data verified
    // IMMEDIATELY PERFORM TEST() AND MINT() POST ENTRING USER DATA
    function inputUserData(address account, uint8 turn, string memory userName, uint256 userIDNumber, uint256 qtyGold, uint8 purityGold) public onlyOwner() {
        // populate user data in the struct
        s_userData[account][turn].s_userName = userName;
        s_userData[account][turn].s_qtyGold = qtyGold;
        s_userData[account][turn].s_userIDNumber = userIDNumber;
        s_userData[account][turn].s_purityGold = purityGold;
        s_userData[account][turn].s_turn = turn;
        
        emit NewUserData(account, userName, userIDNumber, qtyGold, purityGold, turn);
    }

    function testGoldBarPassed(address account, uint8 turn) public onlyOwner() returns (bool) {
        // avoid repetitive tests   
        if(s_userData[account][turn].s_goldTestingDone) {
            revert TestAlreadyDone();
        }
        s_userData[account][turn].s_goldTestingDone = true;                           // test done irrespective of the result

        require(s_userData[account][turn].s_qtyGold == 10 || 
                s_userData[account][turn].s_qtyGold == 100 || 
                s_userData[account][turn].s_qtyGold == 1000, "Non-standard weight");

        if(s_userData[account][turn].s_purityGold != GOLDPURITY) {
            revert NonStandardPurity();
        }
        
        // set flag to 1 when passed
        s_userData[account][turn].s_flag = 1;
        emit GoldTestPassed(account, s_userData[account][turn].s_qtyGold, s_userData[account][turn].s_purityGold);
        return true;
    }
    
    // Only Contract-Owner can mint all the TGOLD tokens to the user
    function mint(address account, uint8 turn) public onlyOwner() {
        // first check whether test is done or not
        if(s_userData[account][turn].s_flag != 1) {
            revert UserGoldTestNotPassed();
        }

        // mint TGOLD only if NOT already minted
        if(s_userData[account][turn].s_goldTokensMinted) {
            revert TGOLDAlreadyMinted();
        }
        
        uint256 totalSupply = totalSupply(); // ==================================
        uint256 amountToMint = ((s_userData[account][turn].s_qtyGold * 999) * 10**8) / 1000;
        // decimal of TGOLD is 8, purity 24K = 99.9%
        uint256 supplyAfterMint = totalSupply + amountToMint;
        // total supply of token units after new mint <= total of token-units corresponding to PoR Gold + new user Gold        
        if(supplyAfterMint > (uint256(getLatestReserve()) + amountToMint)) {
            revert ExceededReserves();
        }
        
        // Checks-Effects-Implementations
        s_userData[account][turn].s_goldTokensMinted = true; 
        // State change
        _mint(account, amountToMint);                           // actual token transfer from address(0)

        emit TGOLDMinted(account, amountToMint);  // can add account.name / other parameters instead of account.address
    }

    // Redeem custom balance, rest with Vault for future trading
    // can add an event Redeemed but already have Transfer event in _burn()
    function redeemToWei(uint256 amountTGOLD) public {
        _burn(msg.sender, amountTGOLD);
        uint256 amountOfWei = tGOLDToWei(amountTGOLD);      // equivalent wei for TGOLD held
        (bool success, ) = msg.sender.call{value: amountOfWei}("");     // contract sufficiently funded
        if(!success) {
            revert SendFailed();
        }
        emit TGOLDRedeemedAsWeiToUser(msg.sender, amountTGOLD, amountOfWei);
    }

    function decimals() public pure override returns(uint8) {
        return 8;       
        // not 18, on the lines of real CGT token by CacheGold => actual qty. held by an a/c = 8 (whereas Eth is 18 wei)
    }
    
    // Price Feed XAU/USD is 8 decimals, hence, our GOld Price is also 8 decimals
    function getUserGoldPrice(address account, uint8 turn) public view returns (uint256) {
        uint256 priceGold = uint256(getLatestPriceGold());    // 10**8 introduced @ getLatestPriceGold of XAU/USD
        // hence, while displaying to the user, divide by 10**8
        // => 1000 gram total => 999 gm old @24K => $63,030.---- value => inside Smart Contract, the value = 6303058632000
        return ((uint256(s_userData[account][turn].s_qtyGold) * 999) * (priceGold / 31103) * 1000) / 1000;
        // 31103 because $1962.403 (Gold Price Feed) pertains to 1 Troy Oz (= 31.103 gram) of Gold
    }


    function getUserData(address account, uint8 turn) public view returns (UserData memory) {
        return (s_userData[account][turn]);
    }

    function tGOLDToWei(uint256 amountTGOLD) public view returns(uint256) {
        uint256 priceGold = uint256(getLatestPriceGold());
        uint256 priceEth = uint256(getLatestPriceEth());
        uint256 numerator = 1e18 * priceGold * 10**3 * amountTGOLD;
        uint256 denominator = 31103 * priceEth * 10**8;
        return numerator / denominator;
        // detailed calculation / logic in Notebook # 12 @ page # 46
    }

    function redeemContractBalance() public payable onlyOwner() {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if(!success) {
            revert SendFailed();
        }
        emit ContractBalanceRedeemedToOwner(address(this).balance);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}

    fallback() external payable {}
}