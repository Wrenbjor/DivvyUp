pragma solidity ^0.4.20;

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
//
// Borrowed from MiniMeToken
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
        require(dividendFee > 0 && myDividends(true) > 0);
        _;
    }
    
    /*==============================
    =            EVENTS            =
    ==============================*/
    event Purchase(
        address indexed customerAddress,
        uint256 incomingEthereum,
        uint256 tokensMinted,
        address indexed referredBy
    );
    
    event Sell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 ethereumEarned
    );
    
    event Reinvestment(
        address indexed customerAddress,
        uint256 ethereumReinvested,
        uint256 tokensMinted
    );
    
    event Withdraw(
        address indexed customerAddress,
        uint256 ethereumWithdrawn
    ); 
    
    /*=====================================
    =            CONFIGURABLES            =
    =====================================*/
    string public name;
    string public symbol;
    uint8  public dividendFee;
    uint8 constant public decimals = 18;
    uint256 constant internal tokenPriceInitial = 0.0000001 ether;
    uint256 constant internal tokenPriceIncremental = 0.00000001 ether;
    uint256 constant internal magnitude = 2**64;

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
    function DivvyUp(string aName, string aSymbol, uint8 aDividendFee) 
    public {
        require(aDividendFee < 100);
        name = aName;
        symbol = aSymbol;
        dividendFee = aDividendFee;
    }
    
    /**
     * The Owner can rebrand
     */
    function changeName(string newName) onlyOwner() public {
        name = newName;
        
    }
    
    /**
     * The Owner can change the symbol
     */
    function changeSymbol(string newSymbol) onlyOwner() public {
        symbol = newSymbol;
    }
    
    /**
     * Converts all incoming ethereum to tokens for the caller
     */
    function purchaseTokens()
        public
        payable 
        returns(uint256)
    {
        return purchaseTokens(msg.value, 0x0);
    }
    
    /**
     * Converts all incoming ethereum to tokens for the caller, and passes on the referral address
     */
    function purchaseTokens(address referredBy)
        public
        payable
        returns(uint256)
    {
        return purchaseTokens(msg.value, referredBy);
    }
    
    /**
     * Fallback function to handle ethereum that was send straight to the contract
    
     */
    function()
        payable
        public
    {
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
        
        customerAddress.transfer(dividends);
        
        // fire event
        emit Withdraw(customerAddress, dividends);
    }
    
    /**
     * Liquifies tokens to ethereum.
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
        uint256 ethereum = tokensToEthereum(tokens);
        uint256 dividends = dividendFee > 0 ? SafeMath.div(ethereum, dividendFee) : 0;
        uint256 taxedEthereum = SafeMath.sub(ethereum, dividends);
        
        // burn the sold tokens
        tokenSupply = SafeMath.sub(tokenSupply, tokens);
        tokenBalanceLedger[customerAddress] = SafeMath.sub(tokenBalanceLedger[customerAddress], tokens);
        
        // update dividends tracker
        int256 updatedPayouts = (int256) (profitPerShare * tokens + (taxedEthereum * magnitude));
        payoutsTo[customerAddress] -= updatedPayouts;       
        
        // dividing by zero is a bad idea
        if (tokenSupply > 0 && dividendFee > 0) {
            // update the amount of dividends per token
            profitPerShare = SafeMath.add(profitPerShare, (dividends * magnitude) / tokenSupply);
        }
        
        // fire event
        emit Sell(customerAddress, tokens, taxedEthereum);
    }
    
    /**
     * Transfer tokens from the caller to a new holder.
     */
    function transfer(address toAddress, uint256 amountOfTokens)
        onlyTokenHolders()
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
            emit Transfer(0x0, customerAddress, amountOfTokens);

            return true;
        }
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
    * Implementation taken from ERC20 reference
    * 
    */
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
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
    
    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current Ethereum stored in the contract
     * Example: totalEthereumBalance()
     */
    function totalEthereumBalance()
        public
        view
        returns(uint256)
    {
        return address(this).balance;
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
            uint256 ethereum = tokensToEthereum(1e18);
            uint256 dividends = SafeMath.div(ethereum, dividendFee);
            uint256 taxedEthereum = SafeMath.sub(ethereum, dividends);
            return taxedEthereum;
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
            uint256 ethereum = tokensToEthereum(1e18);
            uint256 dividends = SafeMath.div(ethereum, dividendFee);
            uint256 taxedEthereum = SafeMath.add(ethereum, dividends);
            return taxedEthereum;
        }
    }
    
    /**
     * Function for the frontend to dynamically retrieve the price scaling of buy orders.
     */
    function calculateTokensReceived(uint256 ethereumToSpend) 
        public 
        view 
        returns(uint256)
    {
        uint256 dividends = SafeMath.div(ethereumToSpend, dividendFee);
        uint256 taxedEthereum = SafeMath.sub(ethereumToSpend, dividends);
        uint256 amountOfTokens = ethereumToTokens(taxedEthereum);
        
        return amountOfTokens;
    }
    
    /**
     * Function for the frontend to dynamically retrieve the price scaling of sell orders.
     */
    function calculateEthereumReceived(uint256 tokensToSell) 
        public 
        view 
        returns(uint256)
    {
        require(tokensToSell <= tokenSupply);
        uint256 ethereum = tokensToEthereum(tokensToSell);
        uint256 dividends = SafeMath.div(ethereum, dividendFee);
        uint256 taxedEthereum = SafeMath.sub(ethereum, dividends);
        return taxedEthereum;
    }
    
    /*==========================================
    =            INTERNAL FUNCTIONS            =
    ==========================================*/
    function purchaseTokens(uint256 incomingEthereum, address referredBy)
        internal
        returns(uint256)
    {
        if(incomingEthereum == 0){
            return reinvestDividends();
        }
        
        // data setup
        address customerAddress = msg.sender;
        uint256 undividedDividends = dividendFee > 0 ? SafeMath.div(incomingEthereum, dividendFee) : 0;
        uint256 referralBonus = SafeMath.div(undividedDividends, 3);
        uint256 dividends = SafeMath.sub(undividedDividends, referralBonus);
        uint256 taxedEthereum = SafeMath.sub(incomingEthereum, undividedDividends);
        uint256 amountOfTokens = ethereumToTokens(taxedEthereum);
        uint256 fee = dividends * magnitude;
 
        // no point in continuing execution if OP is a poorfag russian hacker
        // prevents overflow in the case that the pyramid somehow magically starts being used by everyone in the world
        // (or hackers)
        // and yes we know that the safemath function automatically rules out the "greater then" equasion.
        require(amountOfTokens > 0 && (SafeMath.add(amountOfTokens,tokenSupply) > tokenSupply));
        
        // is the user referred by a masternode?
        if(referredBy != 0x0 && referredBy != customerAddress && dividendFee > 0x0){
            // wealth redistribution
            referralBalance[referredBy] = SafeMath.add(referralBalance[referredBy], referralBonus);
        } else {
            // no ref purchase
            // add the referral bonus back to the global dividends cake
            dividends = SafeMath.add(dividends, referralBonus);
            fee = dividends * magnitude;
        }
        
        // we can't give people infinite ethereum
        if(tokenSupply > 0){
            
            // add tokens to the pool
            tokenSupply = SafeMath.add(tokenSupply, amountOfTokens);
 
            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare += (dividends * magnitude / (tokenSupply));
            
            // calculate the amount of tokens the customer receives over his purchase 
            fee = dividendFee > 0 ? fee - (fee-(amountOfTokens * (dividends * magnitude / (tokenSupply)))) : 0x0;
        
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
        emit Purchase(customerAddress, incomingEthereum, amountOfTokens, referredBy);
        emit Transfer(0x0, customerAddress, amountOfTokens);
        return amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming ethereum
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function ethereumToTokens(uint256 ethereum)
        internal
        view
        returns(uint256)
    {
        uint256 tokenPrice = tokenPriceInitial * 1e18;
        // underflow attempts BTFO
        uint256 tokensReceived = ((SafeMath.sub((sqrt((tokenPrice**2)+(2*(tokenPriceIncremental * 1e18)*(ethereum * 1e18))+(((tokenPriceIncremental)**2)*(tokenSupply**2))+(2*(tokenPriceIncremental)*tokenPrice*tokenSupply))), tokenPrice))/(tokenPriceIncremental))-(tokenSupply);  
        return tokensReceived;
    }
    
    /**
     * Calculate token sell value.
     * It's an algorithm, hopefully we gave you the whitepaper with it in scientific notation;
     * Some conversions occurred to prevent decimal errors or underflows / overflows in solidity code.
     */
    function tokensToEthereum(uint256 tokens)
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
}