// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
// OZ-ownable.sol: ADD - VS Code
import "docs.chain.link/samples/DataFeeds/ReserveConsumerV3.sol";
import "hardhat/console.sol";

contract GoldToken is ERC20, GoldReserveAndPrice {

    mapping(address=>uint256) public s_testMappingBalance;

    event TGOLDMinted(address indexed account, uint256 amount);
    event GoldTestPassed(address indexed account, uint256 qtyGold, uint8 purityGold);
    event NewUserData(address indexed account, string userName, uint256 userIDNumber, uint256 qtyGold, uint8 purityGold, uint8 turn);

    modifier onlyOwner() {
        require(owner == msg.sender, "Unauthorized Account");
        _;
    }

    address private owner;

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
     
    // GoldReserveAndPrice internal immutable i_goldReserveAndPrice; - not needed as it's already inherited

    constructor () ERC20 ("GoldToken", "TGOLD") { 
        owner = msg.sender;
        // s_goldReserveAndPrice = GoldReserveAndPrice(0xE5f2A565Ee0Aa9836B4c80a07C8b32aAd7978e22); -  not needed as it's already inherited
        // VS CODE - dynamically store the above deployment-address in VS Code via a script - not needed as it's already inherited
    }

    // only Contract-owner should have access to enter legit user data, event emit, data verified
    // IMMEDIATELY PERFORM TEST() AND MINT() POST ENTRING USER DATA
    function inputUserData(address account, uint8 turn, string memory userName, uint256 userIDNumber, uint256 qtyGold, uint8 purityGold) public onlyOwner() {
        // populate user data in the struct
        // uint16 ids = s_userData[account][index];
        s_userData[account][turn].s_userName = userName;
        s_userData[account][turn].s_qtyGold = qtyGold;
        s_userData[account][turn].s_userIDNumber = userIDNumber;
        s_userData[account][turn].s_purityGold = purityGold;
        s_userData[account][turn].s_turn = turn;
        
        emit NewUserData(account, userName, userIDNumber, qtyGold, purityGold, turn);
    }

    function testGoldBarPassed(address account, uint8 turn) public onlyOwner() returns (bool) {
        require(!s_userData[account][turn].s_goldTestingDone, "Test already done");   // avoid repetitive tests
        s_userData[account][turn].s_goldTestingDone = true;                           // test done irrespective of the result

        require(s_userData[account][turn].s_qtyGold == 10 || 
                s_userData[account][turn].s_qtyGold == 100 || 
                s_userData[account][turn].s_qtyGold == 1000, "Non-standard weight");

        require(s_userData[account][turn].s_purityGold == GOLDPURITY, "Non-standard purity");
        
        // set flag to 1 when passed
        s_userData[account][turn].s_flag = 1;
        emit GoldTestPassed(account, s_userData[account][turn].s_qtyGold, s_userData[account][turn].s_purityGold);
        return true;
    }
    
    // Only Contract-Owner can mint all the TGOLD tokens to the user
    function mint(address account, uint8 turn) public onlyOwner() {
        // first check whether test is done or not
        require(s_userData[account][turn].s_flag == 1, "User's Gold-test not passed");
        // require(!testGoldBarPassed(account, turn), "User's Gold-test not passed");       
        // above version reverts, onlyOnwer can call the test, not mint() fn.

        // mint TGOLD only if not already minted
        require(!s_userData[account][turn].s_goldTokensMinted, "TGOLD already minted");     // !false = true
        
        
        uint256 totalSupply = totalSupply();
        uint256 amountToMint = ((s_userData[account][turn].s_qtyGold * 999) * 10**8) / 1000;
        // decimal of TGOLD is 8, purity 24K = 99.9%
        uint256 supplyAfterMint = totalSupply + amountToMint;
        
        require(supplyAfterMint <= uint256(getLatestReserve()), "Exceeded reserves");
        
        // Checks-Effects-Implementations
        s_userData[account][turn].s_goldTokensMinted = true; 
        // State change
        _mint(account, amountToMint);                           // actual token transfer from address(0)

        emit TGOLDMinted(account, amountToMint);  // can add account.name / other parameters instead of account.address
    }

    // ADD BURN => reduce totalSupply----------------------------------------------

    // Redeem custom balance, rest with Vault for future trading
    // can add an event Redeemed but already have Transfer event in _burn()
    function redeemToWei(uint256 amountTGOLD) public {
        uint256 balanceTGOLD = balanceOf(msg.sender);
        require(amountTGOLD <= balanceTGOLD, "Insufficient balance");
        // Checks-Effects-Interactions
        balanceTGOLD -= amountTGOLD;
        uint256 amountOfWei = tGOLDToWei(amountTGOLD);
        (bool success, ) = msg.sender.call{value: amountOfWei}("");
        require(success, "Send Failed");
    }

    function decimals() public pure override returns(uint8) {
        return 8;       
        // not 18, on the lines of real CGT token by CacheGold => actual qty. held by an a/c = 8 (whereas Eth is 18 wei)
    }

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

    function getContractOwner() public view returns(address) {
        return owner;
    }

    function tGOLDToWei(uint256 amountTGOLD) public view returns(uint256) {
        // uint256 balanceTGOLD = balanceOf(msg.sender);       // replace balance with actual_amount in redeem(). This is for testing.
        uint256 priceGold = uint256(getLatestPriceGold());
        uint256 priceEth = uint256(getLatestPriceEth());
        uint256 numerator = 1e18 * priceGold * 10**3 * amountTGOLD;
        uint256 denominator = 31103 * priceEth * 10**8;
        return numerator / denominator;
        // detailed calculation / logic in Notebook # 12 @ page # 46
    }

    function redeem() public payable {
        (bool success, ) = msg.sender.call{value: 1e18}("");
        require(success, "Send Failed");
    }

    function redeemContractBalance() public payable {
        //s_testMappingBalance[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: 1e18}("");
        require(success, "Send Failed");
    }

    function fund() public payable {
        //s_testMappingBalance[msg.sender] += msg.value;
    }
}

