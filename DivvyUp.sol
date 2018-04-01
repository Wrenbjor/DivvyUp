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
*                                  ''      /  <>            ''''    
* =====================================================================*
*
* A wealth redistribution smart contract cleverly disguised as a ERC20 token.
* Complete with a factory for making new verticals, and a fair launch contract
* to ensure a fair launch.
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


contract DivvyUpFactory is Owned {

    modifier onlyZeroSpend(){
        require(msg.value == 0);
        _;
    }

    event Create(
        bytes32 name,
        bytes32 symbol,
        uint8 dividendDivisor,
        uint8 decimals,
        uint256 initialPrice,
        uint256 incrementPrice,
        uint256 magnitude,
        address creator
    );

    event ICOCreate(bytes32 name,
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

    mapping(address => DivvyUp[]) public registry;
    mapping(address => DivvyUpICO[]) public icoRegistry;

    function() public payable onlyZeroSpend {
        create("DivvyUp", "DUP", uint8(msg.data[0]));
    }

    // The Gentlemen's Agreement
    function createICO(bytes32 name, bytes32 symbol, uint8 dividendDivisor, uint8 decimals, uint256 initialPrice, uint256 incrementPrice, uint256 magnitude, uint256 launchBalanceCap) public returns (DivvyUpICO){
        return createBalanceAndBlockHeightICO(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, 0, 0, launchBalanceCap);
    }

    // Fundraiser
    function createBalanceICO(bytes32 name, bytes32 symbol, uint8 dividendDivisor, uint8 decimals, uint256 initialPrice, uint256 incrementPrice, uint256 magnitude, uint256 launchBalanceTarget, uint256 launchBalanceCap) public returns (DivvyUpICO){
        return createBalanceAndBlockHeightICO(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, 0, launchBalanceTarget, launchBalanceCap);
    }

    // Timed
    function createBlockICO(bytes32 name, bytes32 symbol, uint8 dividendDivisor, uint8 decimals, uint256 initialPrice, uint256 incrementPrice, uint256 magnitude, uint256 launchBlockHeight, uint256 launchBalanceCap) public returns (DivvyUpICO){
        return createBalanceAndBlockHeightICO(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, launchBlockHeight, 0, launchBalanceCap);
    }

    // Timed And Fundraiser
    function createBalanceAndBlockHeightICO(bytes32 name, bytes32 symbol, uint8 dividendDivisor, uint8 decimals, uint256 initialPrice, uint256 incrementPrice, uint256 magnitude, uint256 launchBlockHeight, uint256 launchBalanceTarget, uint256 launchBalanceCap) public returns (DivvyUpICO){
        DivvyUpICO ico = new DivvyUpICO(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, launchBlockHeight, launchBalanceTarget, launchBalanceCap, this);
        ico.changeOwner(msg.sender);
        icoRegistry[msg.sender].push(ico);
        emit ICOCreate(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, 0, 0, launchBalanceCap, msg.sender);        
        return ico;   
    }

    function create(bytes32 name, bytes32 symbol)
        public 
        returns(DivvyUp)
    {
        return create(name, symbol, 10, 18, 0.0000001 ether, 0.00000001 ether, 2**64);
    }

    function create(bytes32 name, bytes32 symbol, uint8 dividendDivisor)
        public 
        returns(DivvyUp)
    {
        return create(name, symbol, dividendDivisor, 18, 0.0000001 ether, 0.00000001 ether, 2**64);
    }

    function create(bytes32 name, bytes32 symbol, uint8 dividendDivisor, uint8 decimals)
        public 
        returns(DivvyUp)
    {
        return create(name, symbol, dividendDivisor, decimals, 0.0000001 ether, 0.00000001 ether, 2**64);
    }

    function create(bytes32 name, bytes32 symbol, uint8 dividendDivisor, uint8 decimals, uint256 initialPrice, uint256 incrementPrice, uint256 magnitude)
        public 
        returns(DivvyUp)
    {
        DivvyUp divvyUp = new DivvyUp(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, 1, 0x0);
        divvyUp.changeOwner(msg.sender);
        registry[msg.sender].push(divvyUp);
        emit Create(name, symbol, dividendDivisor, decimals, initialPrice, incrementPrice, magnitude, msg.sender);
        return divvyUp;
    }

    function die() onlyOwner() public {
        selfdestruct(msg.sender);
    }

    /**
    * Owner can transfer out any accidentally sent ERC20 tokens
    * 
    * Implementation taken from ERC20 reference
    * 
    */
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
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
    DivvyUp public destination;
    DivvyUpFactory public factory;
    

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
    function DivvyUpICO(bytes32 aName, bytes32 aSymbol, uint8 aDividendDivisor, uint8 aDecimals, uint256 anInitialPrice, uint256 anIncrementPrice, uint256 aMagnitude, uint256 aLaunchBlockHeight, uint256 aLaunchBalanceTarget, uint256 aLaunchBalanceCap, address aCounter, DivvyUpFactory aFactory) public {
        _name = aName;
        iconame = stringToBytes32(concat(bytes32ToString(aName), "ICO"));
        _symbol = aSymbol;
        icosymbol = stringToBytes32(concat(bytes32ToString(aSymbol), "ICO"));
        dividendDivisor = aDividendDivisor;
        finalDecimals = aDecimals;
        initialPrice = anInitialPrice;
        incrementPrice = anIncrementPrice;
        magnitude = aMagnitude;
        launchBlockHeight = aLaunchBlockHeight;
        launchBalanceTarget = aLaunchBalanceTarget;
        launchBalanceCap = aLaunchBalanceCap;
        counter = aCounter;
        factory = aFactory;
    }


    function() public payable {
        if(msg.value == 0 && hasLaunched){
            withdraw(msg.sender, balanceOf(msg.sender));
            return;
        }
        require(launchBalanceCap == 0 || totalDeposits.add(msg.value) <= launchBalanceCap);
        require(counter == 0x0);
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
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
        destination = factory.create(_name, _symbol, dividendDivisor, finalDecimals, initialPrice, incrementPrice, magnitude);
        destination.changeOwner(owner);
        if(totalDeposits > 0){}
        if(counter == 0x0){
            destination.purchaseTokens.value(address(this).balance)();
        } else {
            destination.purchaseTokensERC20.value(totalDeposits);
        }
    }

    function myBalance() public view returns (uint256) {
        return balanceOf(msg.sender);
    }

    function balanceOf(address anAddress) public view returns (uint256){
        if(!hasLaunched){
            return deposits[anAddress];
        }else{
            return destination.balanceOf(this).div(totalDeposits.div(deposits[anAddress]));
        }
    }

    function totalSupply() public view returns (uint256){
        if(!hasLaunched){
            return address(this).balance;
        }else{
            return destination.balanceOf(this);
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
        uint256 actualAmount = !hasLaunched ? tokens : destination.balanceOf(this).div(tokens); 
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
            uint256 ethEqulivent = destination.balanceOf(this).div(amount);
            uint256 withdrawAmount = totalDeposits.div(ethEqulivent);
            totalDeposits -= withdrawAmount;
            deposits[msg.sender] -= amount;
            if(deposits[msg.sender] == 0){
                delete deposits[msg.sender];
            }
            require(destination.transfer(anAddress, destination.balanceOf(this).div(amount)));
        }else{
            totalDeposits -= amount;
            deposits[msg.sender] -= amount;
            if(deposits[msg.sender] == 0){
                delete deposits[msg.sender];
            }
            anAddress.transfer(amount);
        }
        return true;
    }

    function die() onlyOwner public {
        if(!hasLaunched){
            require(owner == msg.sender && address(this).balance == 0);
        }else{
            require(totalDeposits == 0);
            destination.withdraw();
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
        require(tokenAddress != address(destination));
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

}

contract DivvyUp is ERC20Interface, Owned {
    using SafeMath for uint256;
    /*=================================
    =            MODIFIERS            =
    =================================*/
    // only people with tokens
    modifier onlyTokenHolders() {
        require(myTokens() > 0);
        _;
    }
    
    // only people with profits
    modifier onlyDividendHolders() {
        require(dividendDivisor > 0 && myDividends(true) > 0);
        _;
    }

    modifier erc20Destination(){
        require(counter != 0x0);
        _;
    }
    
    /*==============================
    =            EVENTS            =
    ==============================*/
    event Purchase(
        address indexed customerAddress,
        uint256 incomingCounter,
        uint256 tokensMinted,
        address indexed referredBy
    );
    
    event Sell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 counterEarned
    );
    
    event Reinvestment(
        address indexed customerAddress,
        uint256 counterReinvested,
        uint256 tokensMinted
    );
    
    event Withdraw(
        address indexed customerAddress,
        uint256 counterWithdrawn
    ); 
    
    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    bytes32 public name;
    bytes32 public symbol;
    uint8  public dividendDivisor;
    uint8 public decimals;// = 18;
    uint256 public tokenPriceInitial;// = 0.0000001 ether;
    uint256 public tokenPriceIncremental;// = 0.00000001 ether;
    uint256 public magnitude;// = 2**64;
    //0 = ignored, 1 = allowed, 2 = mandatory
    uint8 public referrals;
    address counter;

   /*================================
    =            DATASETS            =
    ================================*/
    // amount of tokens for each address
    mapping(address => uint256) internal tokenBalanceLedger;
    // amount of referral bonus for each address
    mapping(address => uint256) internal referralBalance;
    // amount of eth withdrawn
    mapping(address => int256) internal payoutsTo;
    // amount of tokens allowed to someone else 
    mapping(address => mapping(address => uint)) allowed;
    // the actual amount of tokens
    uint256 internal tokenSupply = 0;
    // the amount of dividends per token
    uint256 internal profitPerShare;
    
    /*=======================================
    =            PUBLIC FUNCTIONS            =
    =======================================*/
    /**
    * -- APPLICATION ENTRY POINTS --  
    */
    function DivvyUp(bytes32 aName, bytes32 aSymbol, uint8 aDividendDivisor, uint8 aDecimals, uint256 aTokenPriceInitial, uint256 aTokenPriceIncremental, uint256 aMagnitude, uint8 aReferrals, address aDestination) 
    public {
        require(aDividendDivisor < 100);
        name = aName;
        symbol = aSymbol;
        dividendDivisor = aDividendDivisor;
        decimals = aDecimals;
        tokenPriceInitial = aTokenPriceInitial;
        tokenPriceIncremental = aTokenPriceIncremental;
        magnitude = aMagnitude;
        referrals = aReferrals;
        counter = aDestination;    
        require(referrals <= 2);
    }
    
    /**
     * Allows the owner to change the name of the contract
     */
    function changeName(bytes32 newName) onlyOwner() public {
        name = newName;
        
    }
    
    /**
     * Allows the owner to change the symbol of the contract
     */
    function changeSymbol(bytes32 newSymbol) onlyOwner() public {
        symbol = newSymbol;
    }
    
    /**
     * Converts all incoming counter to tokens for the caller
     */
    function purchaseTokens()
        public
        payable
        returns(uint256)
    {
        if(msg.value > 0){
            require(counter == 0x0);
        }
        return purchaseTokens(msg.value, 0x0);
    }
    

    /**
     * Converts all incoming counter to tokens for the caller
     */
    function purchaseTokensERC20(uint256 amount)
        public
        erc20Destination
        returns(uint256)
    {
        return purchaseTokensERC20WithReferrer(amount, 0x0);
    }

    /**
     * Converts all incoming counter to tokens for the caller
     */
    function purchaseTokensERC20WithReferrer(uint256 amount, address referrer)
        public
        erc20Destination
        returns(uint256)
    {
        require(ERC20Interface(counter).transferFrom(msg.sender, this, amount));
        return purchaseTokens(amount, referrer);
    }

    /**
     * Converts all incoming counter to tokens for the caller, and passes on the referral address
     */
    function purchaseTokensWithReferrer(address referredBy)
        public
        payable
        returns(uint256)
    {
        if(msg.value > 0){
            require(counter == 0x0);
        }
        return purchaseTokens(msg.value, referredBy);
    }
    
    /**
     * Fallback function to handle counter that was send straight to the contract.
     * Causes tokens to be purchased.
     */
    function()
        payable
        public
    {
        if(msg.value > 0){
            require(counter == 0x0);
        }
        purchaseTokens(msg.value, 0x0);
    }
    
    /**
     * Converts all of caller's dividends to tokens.
     */
    function reinvestDividends()
        onlyDividendHolders()
        public
        returns (uint256)
    {
        // fetch dividends
        uint256 dividends = myDividends(false); // retrieve ref. bonus later in the code
        
        // pay out the dividends virtually
        address customerAddress = msg.sender;
        payoutsTo[customerAddress] += (int256) (dividends * magnitude);
        
        // retrieve ref. bonus
        dividends += referralBalance[customerAddress];
        referralBalance[customerAddress] = 0;
        
        // dispatch a buy order with the virtualized "withdrawn dividends" if we have dividends
        uint256 tokens = purchaseTokens(dividends, 0);
        
        // fire event
        emit Reinvestment(customerAddress, dividends, tokens);
        
        return tokens;
    }
    
    /**
     * Alias of sell() and withdraw().
     */
    function exit()
        public
    {
        // get token count for caller & sell them all
        address customerAddress = msg.sender;
        uint256 tokens = tokenBalanceLedger[customerAddress];
        if(tokens > 0) {
            sell(tokens);
        }
        // lambo delivery service
        withdraw();
    }

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw()
        onlyDividendHolders()
        public
    {
        // setup data
        address customerAddress = msg.sender;
        uint256 dividends = myDividends(false); // get ref. bonus later in the code
        
        // update dividend tracker
        payoutsTo[customerAddress] += (int256) (dividends * magnitude);
        
        // add ref. bonus
        dividends += referralBalance[customerAddress];
        referralBalance[customerAddress] = 0;
        if(counter == 0x0){
            customerAddress.transfer(dividends);
        }else{
            ERC20Interface(counter).transfer(customerAddress, dividends);
        }
        
        // fire event
        emit Withdraw(customerAddress, dividends);
    }
    
    /**
     * Liquifies tokens to counter.
     */
    function sell(uint256 amountOfTokens)
        onlyTokenHolders()
        public
    {
        require(amountOfTokens > 0);
        // setup data
        address customerAddress = msg.sender;
        // russian hackers BTFO
        require(amountOfTokens <= tokenBalanceLedger[customerAddress]);
        uint256 tokens = amountOfTokens;
        uint256 counter = tokensToDestination(tokens);
        uint256 dividends = dividendDivisor > 0 ? SafeMath.div(counter, dividendDivisor) : 0;
        uint256 taxedCounter = SafeMath.sub(counter, dividends);
        
        // burn the sold tokens
        tokenSupply = SafeMath.sub(tokenSupply, tokens);
        tokenBalanceLedger[customerAddress] = SafeMath.sub(tokenBalanceLedger[customerAddress], tokens);
        
        // update dividends tracker
        int256 updatedPayouts = (int256) (profitPerShare * tokens + (taxedCounter * magnitude));
        payoutsTo[customerAddress] -= updatedPayouts;       
        
        // dividing by zero is a bad idea
        if (tokenSupply > 0 && dividendDivisor > 0) {
            // update the amount of dividends per token
            profitPerShare = SafeMath.add(profitPerShare, (dividends * magnitude) / tokenSupply);
        }
        
        // fire event
        emit Sell(customerAddress, tokens, taxedCounter);
    }
    
    /**
     * Transfer tokens from the caller to a new holder.
     * Transfering ownership of tokens requires settling ououtstanding dividends
     * and transfering them back. You can therefore send 0 tokens to this contract to
     * trigger your withdraw.
     */
    function transfer(address toAddress, uint256 amountOfTokens)
        onlyTokenHolders
        public
        returns(bool)
    {

       // Sell on transfer in instad of transfering to
        if(toAddress == address(this)){
            // If we sent in tokens, destroy them and credit their account with ETH
            if(amountOfTokens > 0){
                sell(amountOfTokens);
            }
            // Send them their ETH
            withdraw();
            // fire event
            emit Transfer(0x0, msg.sender, amountOfTokens);

            return true;
        }
        
        // Deal with outstanding dividends first
        if(myDividends(true) > 0) {
            withdraw();
        }
        
        return _transfer(toAddress, amountOfTokens);
    }

    function transferWithDividends(address toAddress, uint256 amountOfTokens) public onlyTokenHolders returns (bool) {
        return _transfer(toAddress, amountOfTokens);
    }

    function _transfer(address toAddress, uint256 amountOfTokens)
        internal
        onlyTokenHolders
        returns(bool)
    {
        // setup
        address customerAddress = msg.sender;
        
        // make sure we have the requested tokens
        require(amountOfTokens <= tokenBalanceLedger[customerAddress]);
       
        // exchange tokens
        tokenBalanceLedger[customerAddress] = SafeMath.sub(tokenBalanceLedger[customerAddress], amountOfTokens);
        tokenBalanceLedger[toAddress] = SafeMath.add(tokenBalanceLedger[toAddress], amountOfTokens);
        
        // fire event
        emit Transfer(customerAddress, toAddress, amountOfTokens);

        // ERC20
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
        tokenBalanceLedger[from] = tokenBalanceLedger[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        tokenBalanceLedger[to] = tokenBalanceLedger[to].add(tokens);
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

    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current Counter stored in the contract
     * Example: totalDestinationBalance()
     */
    function totalDestinationBalance()
        public
        view
        returns(uint256)
    {
        if(counter == 0x0){
            return address(this).balance;
        } else {
            return ERC20Interface(counter).balanceOf(this);
        }
    }
    
    /**
     * Retrieve the name of the token.
     */
    function name() 
        public 
        view 
        returns(bytes32)
    {
        return name;
    }
     

    /**
     * Retrieve the symbol of the token.
     */
    function symbol() 
        public
        view
        returns(bytes32)
    {
        return symbol;
    }
     
    /**
     * Retrieve the total token supply.
     */
    function totalSupply()
        public
        view
        returns(uint256)
    {
        return tokenSupply;
    }
    
    /**
     * Retrieve the tokens owned by the caller.
     */
    function myTokens()
        public
        view
        returns(uint256)
    {
        address customerAddress = msg.sender;
        return balanceOf(customerAddress);
    }
    
    /**
     * Retrieve the dividends owned by the caller.
     * If `includeReferralBonus` is to to 1/true, the referral bonus will be included in the calculations.
     * The reason for this, is that in the frontend, we will want to get the total divs (global + ref)
     * But in the internal calculations, we want them separate. 
     */ 
    function myDividends(bool includeReferralBonus) 
        public 
        view 
        returns(uint256)
    {
        address customerAddress = msg.sender;
        return includeReferralBonus ? dividendsOf(customerAddress) + referralBalance[customerAddress] : dividendsOf(customerAddress) ;
    }
    
    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(address customerAddress)
        view
        public
        returns(uint256)
    {
        return tokenBalanceLedger[customerAddress];
    }
    
    /**
     * Retrieve the dividend balance of any single address.
     */
    function dividendsOf(address customerAddress)
        view
        public
        returns(uint256)
    {
        return (uint256) ((int256)(profitPerShare * tokenBalanceLedger[customerAddress]) - payoutsTo[customerAddress]) / magnitude;
    }
    
    /**
     * Return the buy price of 1 individual token.
     */
    function sellPrice() 
        public 
        view 
        returns(uint256)
    {
        // our calculation relies on the token supply, so we need supply. Doh.
        if(tokenSupply == 0){
            return tokenPriceInitial - tokenPriceIncremental;
        } else {
            uint256 counter = tokensToDestination(1e18);
            uint256 dividends = SafeMath.div(counter, dividendDivisor);
            uint256 taxedCounter = SafeMath.sub(counter, dividends);
            return taxedCounter;
        }
    }
    
    /**
     * Return the sell price of 1 individual token.
     */
    function buyPrice() 
        public 
        view 
        returns(uint256)
    {
        // our calculation relies on the token supply, so we need supply. Doh.
        if(tokenSupply == 0){
            return tokenPriceInitial + tokenPriceIncremental;
        } else {
            uint256 counter = tokensToDestination(1e18);
            uint256 dividends = SafeMath.div(counter, dividendDivisor);
            uint256 taxedCounter = SafeMath.add(counter, dividends);
            return taxedCounter;
        }
    }
    
    /**
     * Function for the frontend to dynamically retrieve the price scaling of buy orders.
     */
    function calculateTokensReceived(uint256 counterToSpend) 
        public 
        view 
        returns(uint256)
    {
        uint256 dividends = SafeMath.div(counterToSpend, dividendDivisor);
        uint256 taxedCounter = SafeMath.sub(counterToSpend, dividends);
        uint256 amountOfTokens = counterToTokens(taxedCounter);
        
        return amountOfTokens;
    }
    
    /**
     * Function for the frontend to dynamically retrieve the price scaling of sell orders.
     */
    function calculateCounterReceived(uint256 tokensToSell) 
        public 
        view 
        returns(uint256)
    {
        require(tokensToSell <= tokenSupply);
        uint256 counter = tokensToDestination(tokensToSell);
        uint256 dividends = SafeMath.div(counter, dividendDivisor);
        uint256 taxedCounter = SafeMath.sub(counter, dividends);
        return taxedCounter;
    }
    
    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 incomingCounter, address referredBy)
        internal
        returns(uint256)
    {
        if(incomingCounter == 0){
            return reinvestDividends();
        }
        
        // data setup
        address customerAddress = msg.sender;
        uint256 undividedDividends = dividendDivisor > 0 ? SafeMath.div(incomingCounter, dividendDivisor) : 0;
        uint256 referralBonus = SafeMath.div(undividedDividends, 3);
        uint256 dividends = SafeMath.sub(undividedDividends, referralBonus);
        uint256 taxedCounter = SafeMath.sub(incomingCounter, undividedDividends);
        uint256 amountOfTokens = counterToTokens(taxedCounter);
        uint256 fee = dividends * magnitude;
 
        // no point in continuing execution if OP is a poorfag russian hacker
        // prevents overflow in the case that the pyramid somehow magically starts being used by everyone in the world
        // (or hackers)
        // and yes we know that the safemath function automatically rules out the "greater then" equasion.
        require(amountOfTokens > 0 && (SafeMath.add(amountOfTokens,tokenSupply) > tokenSupply));
        
        // is the user referred by a masternode?
        if(referredBy != 0x0 && referredBy != customerAddress && dividendDivisor > 0x0){
            // wealth redistribution
            referralBalance[referredBy] = SafeMath.add(referralBalance[referredBy], referralBonus);
        } else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
            dividends = SafeMath.add(dividends, referralBonus);
            fee = dividends * magnitude;
        }
        
        // we can't give people infinite counter
        if(tokenSupply > 0){
            
            // add tokens to the pool
            tokenSupply = SafeMath.add(tokenSupply, amountOfTokens);
 
            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare += (dividends * magnitude / (tokenSupply));
            
            // calculate the amount of tokens the customer receives over his purchase 
            fee = dividendDivisor > 0 ? fee - (fee-(amountOfTokens * (dividends * magnitude / (tokenSupply)))) : 0x0;
        
        } else {
            // add tokens to the pool
            tokenSupply = amountOfTokens;
        }
        
        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger[customerAddress] = SafeMath.add(tokenBalanceLedger[customerAddress], amountOfTokens);
        
        // Tells the contract that the buyer doesn't deserve dividends for the tokens before they owned them;
        //really i know you think you do but you don't
        int256 updatedPayouts = (int256) ((profitPerShare * amountOfTokens) - fee);
        payoutsTo[customerAddress] += updatedPayouts;
        
        // fire event
        emit Purchase(customerAddress, incomingCounter, amountOfTokens, referredBy);
        emit Transfer(0x0, customerAddress, amountOfTokens);
        return amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming counter
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function counterToTokens(uint256 counter)
        internal
        view
        returns(uint256)
    {
        uint256 tokenPrice = tokenPriceInitial * 1e18;
        // underflow attempts BTFO
        uint256 tokensReceived = ((SafeMath.sub((sqrt((tokenPrice**2)+(2*(tokenPriceIncremental * 1e18)*(counter * 1e18))+(((tokenPriceIncremental)**2)*(tokenSupply**2))+(2*(tokenPriceIncremental)*tokenPrice*tokenSupply))), tokenPrice))/(tokenPriceIncremental))-(tokenSupply);  
        return tokensReceived;
    }
    
    /**
     * Calculate token sell value.
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tokensToDestination(uint256 tokens)
        internal
        view
        returns(uint256)
    {

        uint256 theTokens = (tokens + 1e18);
        uint256 theTokenSupply = (tokenSupply + 1e18);
        // underflow attempts BTFO
        uint256 etherReceived = (SafeMath.sub((((tokenPriceInitial + (tokenPriceIncremental * (theTokenSupply/1e18)))-tokenPriceIncremental)*(theTokens - 1e18)),(tokenPriceIncremental*((theTokens**2-theTokens)/1e18))/2)/1e18);
        return etherReceived;
    }
    
    //This is where all your gas goes, sorry
    //Not sorry, you probably only paid 1 gwei
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /**
    * Owner can transfer out any accidentally sent ERC20 tokens
    * 
    * Implementation taken from ERC20 reference
    * 
    */
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        require(tokenAddress != counter);
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}