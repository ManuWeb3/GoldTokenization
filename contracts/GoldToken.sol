// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./GoldReserveAndPrices.sol";

/// @title Tokenize Gold on Ethereum (1 gram pure Gold = 1 TGOLD ERC-20 token)
/// @author Manu Kapoor
/// @notice You can use this contract to tokenize your Gold holdings on use tokens in DeFi like Yield Farming
/// @custom:applying following learnings- 
/// how to use Chainlink price feeds, Proof of Reserve feeds, forking mainnet, using Git on Remix, 
/// clean code practices, some gas optimizations, NatSpec, etc. 

/// @custom:inspiration tried to mimic CacheGold project's workflow in this MVP, coded from scratch

contract GoldToken is ERC20, GoldReserveAndPrices, Ownable {

    error InsufficientFunding(uint256 amountFunded, uint256 amountMinimumRequired);
    error TestAlreadyDone();
    error NonStandardPurity();
    error UserGoldTestNotPassed();
    error TGOLDAlreadyMinted();
    error ExceededReserves();
    error SendFailed();

    /// emitted whenever the owner enters new user's data
    event NewUserData(address indexed account, string userName, uint256 userIDNumber, uint256 qtyGold, uint8 purityGold, uint8 turn);
    /// emitted when the new user's Gold bar passes Standard purity + weight tests
    event GoldTestPassed(address indexed account, uint256 qtyGold, uint8 purityGold);
    /// emitted when owner mints the TGOLD ERC-20 tokens to the user after test is passed
    event TGOLDMinted(address indexed account, uint256 amount);
    /// emitted when owner redeems the entire contract's Ether balance to its account    
    event ContractBalanceRedeemedToOwner(uint256 contractBalance);
    /// emitted when user redeems its balance of TGOLD tokens as Ether/Wei to its wallet
    event TGOLDRedeemedAsWeiToUser(address indexed account, uint256 tGOLDAmountRedeemed, uint256 weiSent);

    struct UserData {
        string s_userName;
        uint256 s_userIDNumber;
        uint256 s_qtyGold;          // can only be either 10g, 100g or 1000g Gold bars, 24K purity only (99.9%)
        uint8 s_purityGold;         // an integer value representing Karat (must be 24 only)
        uint8 s_flag;               // set to 1 when Gold-tests passed else default 0
        bool s_goldTestingDone;     // whether test conducted irrespective of the pass/fail outcome
        uint8 s_turn;               // to record the times the user brought new Gold holding(s) / bar(s) to get those tokenized
        bool s_goldTokensMinted;    // default false, true when minted by the Owner to avoid repeat / infinite mints      
    }

    /// mapping user's account to a unique turn-number for a user's recurring deposits (default turn = 1 for an account, 1st turn)
    mapping(address => mapping(uint8 => UserData)) private s_userData;

    uint8 public constant GOLDPURITY = 24;
    uint256 private totalSupplyTGOLD;
     
    constructor () ERC20 ("GoldToken", "TGOLD") Ownable(msg.sender) payable { 
        /// Fund at least 10 Ether to enable redeeming of TGOLD tokens to Ether by any user
        if(msg.value < 10*1e18) {
            revert InsufficientFunding(msg.value, 10*1e18);
        }
        /// Below, assigned all the TGOLD tokens/units equal to CacheGold's PoR reserve value to the contract owner, it's an MVP
        totalSupplyTGOLD = uint256(getLatestReserve());
        _mint(owner(), totalSupplyTGOLD);       // _totalSupply private state var. of ERC20 can only be written in mint()/burn()
    }

    /// @notice Owner will input new user's data
    /// @dev only owner should have access to enter legit user data. Event emitted. Data verified
    /// @param account: user's address, turn: count of turn, userIDNumber: any validID for KYC, rest self-explanatory
    function inputUserData(address account, uint8 turn, string memory userName, uint256 userIDNumber, uint256 qtyGold, uint8 purityGold) public onlyOwner() {
        // populate user data in the struct
        s_userData[account][turn].s_userName = userName;
        s_userData[account][turn].s_qtyGold = qtyGold;
        s_userData[account][turn].s_userIDNumber = userIDNumber;
        s_userData[account][turn].s_purityGold = purityGold;
        s_userData[account][turn].s_turn = turn;
        
        emit NewUserData(account, userName, userIDNumber, qtyGold, purityGold, turn);
    }

    /// @notice Owner tests for standard weight and purity of Gold Bar
    /// @dev only owner should have access to enter legit user data. Event emitted. Data verified
    /// @param account: user's address, turn: count of turn
    /// @return bool: true if passed else false
    /// Owner should immediately perform test() and mint() post entering user data
    function testGoldBarPassed(address account, uint8 turn) public onlyOwner() returns (bool) {
        /// avoid repetitive tests on the same user + turn   
        if(s_userData[account][turn].s_goldTestingDone) {
            revert TestAlreadyDone();
        }
        s_userData[account][turn].s_goldTestingDone = true;         // test done irrespective of the result
        /// only 3 standard weights of the Gold bars expected: 10g, 100g, 1000g
        require(s_userData[account][turn].s_qtyGold == 10 || 
                s_userData[account][turn].s_qtyGold == 100 || 
                s_userData[account][turn].s_qtyGold == 1000, "Non-standard weight");
        /// only 1 standrad purity of Gold bar accepted: 24K (99.9% pure)
        if(s_userData[account][turn].s_purityGold != GOLDPURITY) {
            revert NonStandardPurity();
        }
        /// set flag to 1 when passed
        s_userData[account][turn].s_flag = 1;
        emit GoldTestPassed(account, s_userData[account][turn].s_qtyGold, s_userData[account][turn].s_purityGold);
        return true;
    }
    
    /// @notice Owner mints TGOLD ERC-20 tokens to the user after test is passed
    /// @param account: user's address, turn: count of turn
    function mint(address account, uint8 turn) public onlyOwner() {
        /// first check whether test is already done or not
        if(s_userData[account][turn].s_flag != 1) {
            revert UserGoldTestNotPassed();
        }
        // mint TGOLD only if NOT already minted
        if(s_userData[account][turn].s_goldTokensMinted) {
            revert TGOLDAlreadyMinted();
        }
        
        uint256 totalSupply = totalSupply();
        /// e.g. 99.9% of 24K 1000 gram Bar = 999 gram of pure Gold
        /// TGOLD has 8 decimals, hence converting 999 gram of Gold to 10**8 decimal units
        uint256 amountToMint = ((s_userData[account][turn].s_qtyGold * 999) * 10**8) / 1000;
        uint256 supplyAfterMint = totalSupply + amountToMint;
        /// (total supply of TGOLD token units after new mint must be) <= (total of token-units corresponding to PoR Gold + new user Gold)
        if(supplyAfterMint > (uint256(getLatestReserve()) + amountToMint)) {
            revert ExceededReserves();
        }
        // Checks-Effects-Implementations
        s_userData[account][turn].s_goldTokensMinted = true; 
        _mint(account, amountToMint);                           

        emit TGOLDMinted(account, amountToMint);
    }

    /// @notice Any user can redeem its TGOLD for equivalent Ether/Wei whenever it wants to
    /// @param amountTGOLD: amount of TGOLD token units user wishes to redeem
    /// Can redeem custom balance, rest with the Vault to use at a later point in time.
    function redeemToWei(uint256 amountTGOLD) public {
        _burn(msg.sender, amountTGOLD);
        uint256 amountOfWei = tGOLDToWei(amountTGOLD);                  // get equivalent wei for TGOLD held
        (bool success, ) = msg.sender.call{value: amountOfWei}("");     // contract must be sufficiently funded
        if(!success) {
            revert SendFailed();
        }
        emit TGOLDRedeemedAsWeiToUser(msg.sender, amountTGOLD, amountOfWei);
    }

    /// @notice Overriding TGOLD decimals to 8, not 18, on the lines of real CGT token by CacheGold project
    function decimals() public pure override returns(uint8) {
        return 8;       
    }
    
    /// @notice get the actual real-world price of Gold amount tokenized by the user
    /// @dev Price Feed XAU/USD is 8 decimals, hence, our Gold Price is also 8 decimals
    /// @param account: user's address, turn: count of turn
    /// @return value (price) of user's Gold
    function getUserGoldPrice(address account, uint8 turn) public view returns (uint256) {
        uint256 priceGold = uint256(getLatestPriceGold());    
        // 10**8 introduced @ getLatestPriceGold of XAU/USD
        // hence, while displaying to the user, divide by 10**8
        // => e.g. 1000 gram Bar => 999 gm pure Gold @24K purity, 1 Troy Ounce is 31.103 gram
        // Price of 1 Troy Ounce returned by the XAU/USD Price Feed on mainnet
        return ((uint256(s_userData[account][turn].s_qtyGold) * 999) * (priceGold / 31103) * 1000) / 1000;
        // 31103 because $1962.403 (Gold Price Feed) pertains to 1 Troy Oz (= 31.103 gram) of Gold
    }

    /// @notice fetch user data
    /// @param account: user's address, turn: count of turn
    /// @return UserData struct type value returned in memory
    function getUserData(address account, uint8 turn) public view returns (UserData memory) {
        return (s_userData[account][turn]);
    }

    /// @notice Convert TGOLD token units to an equivalent amount of Ether/Wei
    /// @dev uses 2 of Chainlink's Price Feeds: XAU/USD and ETH/USD
    /**
    *TGOLD to Wei calculation:
    * 1 gram of Gold = 1 TGOLD token
    * TGOLD has 8 decimals => 1 TGOLD = 1e8 units
    * 1e8 units = price of 1 gram of pure Gold
    * price of 1 gram of pure Gold = (price returned by the XAU/USD price feed in 8 decimal) / 31.103
    * Why? Because XAU/USD returns the price of 1 Troy Ounce of Gold = 31.103 gram
    * Hence, 1e8 units = (price returned by the XAU/USD price feed in 8 decimal) / 31.103
    * any value of user's actual balance of amountTGOLD (is in 8 decimal) = (((price returned by the XAU/USD price feed in 8 decimal) / 31.103) / 1e8) * amountTGOLD
    * Name the above expression as "Y" for ease of use ahead
    * 1 Ether = 10e18 wei = $(priceFeed ETH/USD in 8 decimal) returned
    * It means, Wei-equivalent (18 decimal) user's amountTGOLD (in 8 decimal) = (10e18 / $(priceFeed ETH/USD in 8 decimal)) * amountTGOLD -- Final formulae
    */
    /// @param amountTGOLD amount user wants to redeem
    /// @return equivalent value in wei
    function tGOLDToWei(uint256 amountTGOLD) public view returns(uint256) {
        uint256 priceGold = uint256(getLatestPriceGold());
        uint256 priceEth = uint256(getLatestPriceEth());
        /// I did my own calculation as explaiend above
        uint256 numerator = 1e18 * priceGold * 10**3 * amountTGOLD;
        uint256 denominator = 31103 * priceEth * 10**8;
        return numerator / denominator;         // detailed calculation / logic in Notebook # 12 @ page # 46
    }

    /// @notice owner can redeem the Ether balance in the contract anytime
    function redeemContractBalance() public payable onlyOwner() {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if(!success) {
            revert SendFailed();
        }
        emit ContractBalanceRedeemedToOwner(address(this).balance);
    }

    /// @notice a getter to get the contract's Ether balance
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /// @notice receive ether function to enable the contract receive funds from the owner...
    /// post deployment that enables users to redeem TGOLD to Ether anytime
    receive() external payable {}

    fallback() external payable {}
}

