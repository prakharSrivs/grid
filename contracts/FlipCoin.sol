// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol"; 

contract FlipCoin is ERC20Burnable {

    address public owner;
    uint256 public _userId;
    uint256 public constant EXPIRY_DURATION = 180 days;
    uint256 public constant DECAY_PERCENTAGE = 10;

    struct User {
        string name;
        string email;
        uint256 balance;
    }
    struct Seller {
        string storeName;
        string storeAddress;
        uint256 balance;
    }
    struct Transaction {
        string transactionType;
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
    }
    struct TokenHolderInfo{
        uint256 _tokenId;
        address _from;
        address _to;
        uint256 _totalToken; 
        bool _tokenHolder;
    }
    mapping(address => User) public users;
    mapping(address => Seller) public sellers;
    mapping(address => uint256) public lastActiveTime;
    mapping(address => Transaction[]) public userTransactions;
    mapping(address => TokenHolderInfo) public tokenHolderInfos;
    mapping(address => uint256) public balance;

    enum TransactionType { Mint, Burn, Transfer }
    event NewTransaction(string indexed transactionType, address indexed from, address indexed to, uint256 amount, uint256 timestamp);
    constructor(uint256 initialAmount) ERC20("FlipCoin", "FLC"){
        owner=msg.sender;
        balance[msg.sender]=initialAmount;
        _mint(owner,initialAmount);
        userTransactions[msg.sender].push(Transaction({
            transactionType: "credit",
            from: address(0),
            to: msg.sender,
            amount: initialAmount,
            timestamp: block.timestamp
        }));
    }

    function _returnOwner() public view returns(address){
        return owner;
    }
    
    function _getBalance(address _address) public view returns(uint){ 
        return balanceOf(_address);
    }

    function transferFromSellerToUser(address seller, address user, uint256 amount) public {
        // Ensure the function caller is the seller
        require(msg.sender == seller, "Only the seller can initiate the transfer");
        // Ensure the seller exists
        require(_sellerExists(seller), "Seller does not exist");
        // Ensure the user exists
        require(_userExists(user), "User does not exist");
        // Use the ERC20 transfer function to transfer tokens from the seller to the user
        require(transferFrom(seller, user, amount*(10**decimals())), "Transfer failed");

        // Log the transaction for the seller
        userTransactions[seller].push(Transaction({
            transactionType: "debit",
            from: seller,
            to: user,
            amount: amount,
            timestamp: block.timestamp
        }));

        // Log the transaction for the user
        userTransactions[user].push(Transaction({
            transactionType: "credit",
            from: seller,
            to: user,
            amount: amount,
            timestamp: block.timestamp
        }));
        emit NewTransaction("debit", seller, user, amount, block.timestamp);
        emit NewTransaction("credit", user, seller, amount, block.timestamp);
    }
    function getTransactionCount(address user) public view returns (uint256) {
        return userTransactions[user].length;
    }
    function getAllTransactions(address user) 
        public view 
        returns (
            string[] memory transactionTypes, 
            address[] memory fromAddresses, 
            address[] memory toAddresses, 
            uint256[] memory amounts, 
            uint256[] memory timestamps
        ) 
    {
        uint256 length = userTransactions[user].length;

        transactionTypes = new string[](length);
        fromAddresses = new address[](length);
        toAddresses = new address[](length);
        amounts = new uint256[](length);
        timestamps = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            Transaction memory txn = userTransactions[user][i];
            transactionTypes[i] = txn.transactionType;
            fromAddresses[i] = txn.from;
            toAddresses[i] = txn.to;
            amounts[i] = txn.amount;
            timestamps[i] = txn.timestamp;
        }
    }

    function _userExists(address _userAddress) public view returns (bool) {
        return bytes(users[_userAddress].name).length > 0;
    }

    function setUserData(string memory _name, string memory _email) public returns(address) {
        require(!_userExists(msg.sender), "User already exists!");
        User memory newUser = User({
            name: _name,
            email: _email,
            balance: 0
        });
        users[msg.sender] = newUser;
        return msg.sender;
    }

    function setSellerData(string memory _storeName, string memory _storeAddress) public returns(address){
        require(!_sellerExists(msg.sender), "Seller already exists!");

        Seller memory newSeller = Seller({
            storeName: _storeName,
            storeAddress: _storeAddress,
            balance: 0 
        });

        sellers[msg.sender] = newSeller;
        return msg.sender;
    }

    function _sellerExists(address _sellerAddress) public view returns (bool) {
        return bytes(sellers[_sellerAddress].storeName).length > 0;
    }
    function _mintTo(address _address, uint256 amount) public {
        _mint(_address, amount);
        emit NewTransaction("credit", msg.sender, _address, amount, block.timestamp);
        userTransactions[_address].push(Transaction({
            transactionType: "credit",
            from: address(0),
            to: _address,
            amount: amount,
            timestamp: block.timestamp
        }));
    }
    function _mint(address account, uint256 amount) internal override {
        super._mint(account, amount);
        lastActiveTime[account]=block.timestamp;

    }

    function _customerReward(uint256 _amount, address _customerAddress) public{
        _mint(_customerAddress, _amount);
        emit NewTransaction("credit", msg.sender, _customerAddress, _amount, block.timestamp);
    }

    function _sellerReward(uint256 _amount, address _sellerAddress) public{
        _mint(_sellerAddress, _amount);
        emit NewTransaction("credit", msg.sender, _sellerAddress, _amount, block.timestamp);
    }

   function _burnToken(address _address, uint256 amount) public{
       _burn(_address, amount);

       userTransactions[_address].push(Transaction({
        transactionType: "debit", 
        from: _address, 
        to: address(0), 
        amount: amount, 
        timestamp: block.timestamp
       }));
   }

    function decay(address user) external {
        uint256 elapsedTime = block.timestamp - lastActiveTime[user];
        require(elapsedTime > EXPIRY_DURATION, "Coins have not yet expired");
        uint256 decayAmount = (balanceOf(user) * DECAY_PERCENTAGE) / 100;
        _burn(user, decayAmount);
        lastActiveTime[user] = block.timestamp;
    }

}