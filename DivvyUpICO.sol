pragma solidity 0.4.21;

/*
* Sensei Kevlar presents...
*
* ====================================================================*
*'||''|.    ||                                    '||'  '|'         
* ||   ||  ...  .... ... .... ... .... ...      ,  ||    |  ... ... 
* ||    ||  ||   '|.  |   '|.  |   '|.  |  <>  /   ||    |   ||'  ||
* ||    ||  ||    '|.|     '|.|     '|.|      /    ||    |   ||    |
*.||...|'  .||.    '|       '|       '|      /      '|..'    ||...' 
*                                 .. |      /                ||     
*                                  ''      /  <>            ''''     ICO
* =====================================================================*
* A fair launch protocol for creating and launcing ICOs.
* 
*
*/


// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint256);
    function balanceOf(address tokenOwner) public constant returns (uint256 balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint256 remaining);
    function transfer(address to, uint256 tokens) public returns (bool success);
    function approve(address spender, uint256 tokens) public returns (bool success);
    function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ----------------------------------------------------------------------------
// Contract function to receive approval and execute function in one call
// ----------------------------------------------------------------------------
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public ownerCandidate;

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    function changeOwner(address _newOwner) public onlyOwner {
        ownerCandidate = _newOwner;
    }
    
    function acceptOwnership() public {
        require(msg.sender == ownerCandidate);  
        owner = ownerCandidate;
    }
    
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
    * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract DivvyUpInterface{
    function purchaseTokens()
        public
        payable
        returns(uint256);

    function purchaseTokensERC20(uint256 amount)
        public
        returns(uint256);

    function withdraw()
        public;
}

contract DivvyUpFactoryInterface {
    function create(
        bytes32 name, // Name of the DivvyUp
        bytes32 symbol,  // ERC20 Symbol fo the DivvyUp
        uint8 dividendDivisor, // Amount to divide incoming counter by as fees for dividens. Example: 3 for 33%, 10 for 10%, 100 for 1%
        uint8 decimals, // Number of decimals the token has. Example: 18
        uint256 initialPrice, // Starting price per token. Example: 0.0000001 ether
        uint256 incrementPrice, // How much to increment the price by. Example: 0.00000001 ether
        uint256 magnitude, //magnitude to multiply the fees by before distribution. Example: 2**64
        address counter // The counter currency to accept. Example: 0x0 for ETH, otherwise the ERC20 token address.
     )  public 
        returns(address);
}

contract DivvyUpICOFactory is Owned {

    event Create(bytes32 name,
        bytes32 symbol,
        uint8 dividendDivisor,
        uint8 decimals,
        uint256 initialPrice,
        uint256 incrementPrice,
        uint256 magnitude,
        uint256 launchBlockHeight,
        uint256 launchBalanceTarget,
        uint256 launchBalanceCap,
        address creator
    );


    DivvyUpICO[] public registry;

    function create(        
        bytes32 name, // Name of the DivvyUp
        bytes32 symbol,  // ERC20 Symbol fo the DivvyUp
        uint8 dividendDivisor, // Amount to divide incoming counter by as fees for dividens. Example: 3 for 33%, 10 for 10%, 100 for 1%
        uint8 decimals, // Number of decimals the token has. Example: 18
        uint256 initialPrice, // Starting price per token. Example: 0.0000001 ether
        uint256 incrementPrice, // How much to increment the price by. Example: 0.00000001 ether
        uint256 magnitude, //magnitude to multiply the fees by before distribution. Example: 2**64
        uint256 launchBlockHeight, // Block this won't launch before, or 0 for any block.
        uint256 launchBalanceTarget, // Balance this wont launch before, or 0 for any balance. (soft cap)
        uint256 launchBalanceCap, // Balance this will not exceed, or 0 for no cap. (hard cap)
        address counter // The counter currency to accept. Example: 0x0 for ETH, otherwise the ERC20 token address.
        )
        public 
        returns (DivvyUpICO)
    {
        DivvyUpICO ico = new DivvyUpICO(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, launchBlockHeight, launchBalanceTarget, launchBalanceCap, counter, this);
        ico.changeOwner(msg.sender);
        registry.push(ico);
        
        emit Create(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, 0, 0, launchBalanceCap, msg.sender);        
        return ico;   
    }

}

contract DivvyUpICO is Owned, ERC20Interface {
    using SafeMath for uint256;
   
    modifier hasNotLaunched(){
        require(!hasLaunched);
        _;
    }

    modifier hasAlreadyLaunched(){
        require(hasLaunched);
        _;
    }

    modifier isReadyToLaunch(){
        require((block.number > launchBlockHeight || launchBlockHeight == 0) && (address(this).balance >= launchBalanceTarget));
        _;
    }

    modifier balanceHolder(){
        require(deposits[msg.sender] > 0);
        _;
    }

    bytes32 internal _name;
    bytes32 internal _symbol;
    bytes32 internal iconame;
    bytes32 internal icosymbol;
    uint8 public finalDecimals;
    uint8 public dividendDivisor;
    uint256 public initialPrice;
    uint256 public incrementPrice;
    uint256 public magnitude;
    uint256 public launchBlockHeight = 0;
    uint256 public launchBalanceTarget = 0;
    uint256 public launchBalanceCap = 0;
    bool public hasLaunched = false;
    address counter;
    address public destination;
    DivvyUpFactoryInterface public factory;
    

    mapping(address => uint256) public deposits;
    mapping(address => mapping(address => uint)) allowed;
    uint256 public totalDeposits;

    function concat(string _base, string _value) internal pure returns (string) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        string memory _tmpValue = new string(_baseBytes.length + _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for(i = 0; i < _baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for(i = 0; i < _valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i++];
        }

        return string(_newValue);
    }

    function bytes32ToString(bytes32 x) internal pure returns (string) {
        bytes memory bytesString = new bytes(32);
        uint256 charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
    function DivvyUpICO(bytes32 aName, bytes32 aSymbol, uint8 aDividendDivisor, uint8 aDecimals, uint256 anInitialPrice, uint256 anIncrementPrice, uint256 aMagnitude, uint256 aLaunchBlockHeight, uint256 aLaunchBalanceTarget, uint256 aLaunchBalanceCap, address aCounter, address aFactory) public {
        _name = aName;
        _symbol = aSymbol;
        dividendDivisor = aDividendDivisor;
        finalDecimals = aDecimals;
        initialPrice = anInitialPrice;
        incrementPrice = anIncrementPrice;
        magnitude = aMagnitude;
        launchBlockHeight = aLaunchBlockHeight;
        launchBalanceTarget = aLaunchBalanceTarget;
        launchBalanceCap = aLaunchBalanceCap;
        counter = aCounter;
        factory = DivvyUpFactoryInterface(aFactory);
    }


    function() public payable {
        if(msg.value == 0 && hasLaunched){
            withdraw(msg.sender, balanceOf(msg.sender));
            return;
        }
        require(!hasLaunched);
        require(launchBalanceCap == 0 || totalDeposits.add(msg.value) <= launchBalanceCap);
        require(counter == 0x0);
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    function depositERC20(uint256 amount) public {
        if(amount == 0 && hasLaunched){
            withdraw(msg.sender, balanceOf(msg.sender));
            return;
        }
        require(!hasLaunched);
        require(launchBalanceCap == 0 || totalDeposits.add(amount) <= launchBalanceCap);
        require(counter != 0x0);
        require(ERC20Interface(counter).transferFrom(msg.sender, this, amount));
        deposits[msg.sender] += amount;
        totalDeposits += amount;
    }


    function name() public view returns(bytes32){
        return iconame;
    }

    function symbol() public view returns(bytes32){
        return icosymbol;
    }

    function decimals() public view returns(uint8){
        if(!hasLaunched){
            return 18;
        }else{
            return finalDecimals;
        }
    }

    function launch() public hasNotLaunched isReadyToLaunch returns (address) {
        hasLaunched = true;
        destination = factory.create(_name, _symbol, dividendDivisor, finalDecimals, initialPrice, incrementPrice, magnitude, counter);
        Owned(destination).changeOwner(owner);
        if(totalDeposits > 0){
            if(counter == 0x0){
                DivvyUpInterface(destination).purchaseTokens.value(totalDeposits)();
            } else {
                DivvyUpInterface(destination).purchaseTokensERC20(totalDeposits);
            }
        }
    }

    function myBalance() public view returns (uint256) {
        return balanceOf(msg.sender);
    }

    function balanceOf(address anAddress) public view returns (uint256){
        if(!hasLaunched){
            return deposits[anAddress];
        }else{
            return ERC20Interface(destination).balanceOf(this).div(totalDeposits.div(deposits[anAddress]));
        }
    }

    function totalSupply() public view returns (uint256){
        if(!hasLaunched){
            return totalDeposits;
        }else{
            return ERC20Interface(destination).balanceOf(this);
        }
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        if(address(this) == to){
            withdraw(to, tokens);
        }
        deposits[msg.sender] = deposits[msg.sender].sub(tokens);
        deposits[to] = deposits[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }
  
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }


    /**
    * Transfer `tokens` from the `from` account to the `to` account
    * 
    * The calling account must already have sufficient tokens approve(...)-d
    * for spending from the `from` account and
    * - From account must have sufficient balance to transfer
    * - Spender must have sufficient allowance to transfer
    * - 0 value transfers are allowed
    * 
    * Implementation taken from ERC20 reference
    * 
    */
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        uint256 actualAmount = !hasLaunched ? tokens : ERC20Interface(destination).balanceOf(this).div(tokens); 
        deposits[from] = deposits[from].sub(actualAmount);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        deposits[to] = deposits[to].add(actualAmount);
        emit Transfer(from, to, tokens);
        return true;
    }

    /**
    * Returns the amount of tokens approved by the owner that can be
    * transferred to the spender's account
    * 
    * Implementation taken from ERC20 reference
    * 
    */
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    /**
    * Token owner can approve for `spender` to transferFrom(...) `tokens`
    * from the token owner's account. The `spender` contract function
    * `receiveApproval(...)` is then executed
    * 
    */
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }

    function withdraw(address anAddress, uint256 amount) public returns (bool) {
        require(balanceOf(msg.sender) <= amount);
        if(hasLaunched){
            uint256 ethEqulivent = ERC20Interface(destination).balanceOf(this).div(amount);
            uint256 withdrawAmount = totalDeposits.div(ethEqulivent);
            totalDeposits -= withdrawAmount;
            deposits[msg.sender] -= amount;
            if(deposits[msg.sender] == 0){
                delete deposits[msg.sender];
            }
            require(ERC20Interface(destination).transfer(anAddress, ERC20Interface(destination).balanceOf(this).div(amount)));
        }else{
            totalDeposits -= amount;
            deposits[msg.sender] -= amount;
            if(deposits[msg.sender] == 0){
                delete deposits[msg.sender];
            }
            if(counter == 0x0){
                anAddress.transfer(amount);
            } else{
                require(ERC20Interface(counter).transfer(anAddress, amount));
            }
        }
        return true;
    }

    function die() onlyOwner public {
        if(!hasLaunched){
            require(owner == msg.sender && address(this).balance == 0);
        }else{
            require(totalDeposits == 0);
            DivvyUpInterface(destination).withdraw();
        }
        if(counter != 0x0){
            uint256 balance = ERC20Interface(counter).balanceOf(this);
            if(balance > 0){
                require(ERC20Interface(counter).transfer(msg.sender, balance));
            }
        }
        selfdestruct(owner);
    }

    /**
    * Owner can transfer out any accidentally sent ERC20 tokens
    * 
    * Implementation taken from ERC20 reference
    * 
    */
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        // Do not allow the owner to prematurely steal tokens that do not belong to them
        if(!hasLaunched){
            require(tokenAddress != counter);
        }else{
            require(tokenAddress != address(destination));
        }
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

}
