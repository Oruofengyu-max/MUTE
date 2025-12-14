pragma solidity ^0.5.12;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract PowX {
    using SafeMath for uint256;

    /* MODIFIERS */
    modifier onlyBagholders() {
        require(myTokens() > 0);
        _;
    }
    
    modifier onlyStronghands() {
        require(myDividends(true) > 0);
        _;
    }
    
    modifier onlyAdministrator(){
        address _customerAddress = msg.sender;
        require(administrators[keccak256(abi.encodePacked(_customerAddress))]);
        _;
    }
    
    modifier antiEarlyWhale(uint256 _amountOfEthereum){
        address _customerAddress = msg.sender;
        if( onlyAmbassadors && ((totalEthereumBalance() - _amountOfEthereum) <= ambassadorQuota_ )){
            require(
                ambassadors_[_customerAddress] == true &&
                (ambassadorAccumulatedQuota_[_customerAddress] + _amountOfEthereum) <= ambassadorMaxPurchase_
            );
            ambassadorAccumulatedQuota_[_customerAddress] = SafeMath.add(ambassadorAccumulatedQuota_[_customerAddress], _amountOfEthereum);
            _;
        } else {
            onlyAmbassadors = false;
            _;    
        }
    }

    /* EVENTS */
    event onTokenPurchase(address indexed customerAddress, uint256 incomingEthereum, uint256 tokensMinted, address indexed referredBy);
    event onTokenSell(address indexed customerAddress, uint256 tokensBurned, uint256 ethereumEarned);
    event onReinvestment(address indexed customerAddress, uint256 ethereumReinvested, uint256 tokensMinted);
    event onWithdraw(address indexed customerAddress, uint256 ethereumWithdrawn);
    event Transfer(address indexed from, address indexed to, uint256 tokens);

    /* CONFIGURABLES */
    string public name = "PowX";
    string public symbol = "PWX";
    uint8 constant public decimals = 18;
    uint8 constant internal dividendFee_ = 15;
    uint256 constant internal tokenPriceInitial_ = 0.0000001 ether;
    uint256 constant internal tokenPriceIncremental_ = 0.00000001 ether;
    uint256 constant internal magnitude = 2**64;
    uint256 public stakingRequirement = 100e18;
    address public forcedRecipient;


    mapping(address => bool) internal ambassadors_;
    uint256 constant internal ambassadorMaxPurchase_ = 1 ether;
    uint256 constant internal ambassadorQuota_ = 20 ether;

    /* DATASETS */
    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => uint256) internal referralBalance_;
    mapping(address => int256) internal payoutsTo_;
    mapping(address => uint256) internal ambassadorAccumulatedQuota_;
    uint256 internal tokenSupply_ = 0;
    uint256 internal profitPerShare_;
    mapping(bytes32 => bool) public administrators;
    bool public onlyAmbassadors = true;

    /* CONSTRUCTOR */
    constructor() public {
        administrators[keccak256(abi.encodePacked(msg.sender))] = true;
        ambassadors_[msg.sender] = true;
    }

    /* PUBLIC FUNCTIONS */
    function buy(address _referredBy) public payable returns(uint256) {
        return purchaseTokens(msg.value, _referredBy);
    }

    function() external payable {
        purchaseTokens(msg.value, address(0));
    }

    function reinvest() onlyStronghands() public {
        uint256 _dividends = myDividends(false);
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] += int256(_dividends * magnitude);
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        uint256 _tokens = purchaseTokens(_dividends, address(0));
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function exit() public {
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if(_tokens > 0) sell(_tokens);
        withdraw();
    }

    function withdraw() onlyStronghands() public {
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(false);
        payoutsTo_[_customerAddress] += int256(_dividends * magnitude);
        _dividends += referralBalance_[_customerAddress];
        referralBalance_[_customerAddress] = 0;
        emit onWithdraw(_customerAddress, _dividends);
    }

    function sell(uint256 _amountOfTokens) onlyBagholders() public {
        address _customerAddress = msg.sender;
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress]);
        uint256 _tokens = _amountOfTokens;
        uint256 _ethereum = tokensToEthereum_(_tokens);
        uint256 _dividends = _ethereum.div(dividendFee_);
        uint256 _taxedEthereum = _ethereum.sub(_dividends);
        tokenSupply_ = tokenSupply_.sub(_tokens);
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].sub(_tokens);
        int256 _updatedPayouts = int256(profitPerShare_ * _tokens + (_taxedEthereum * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;
        if(tokenSupply_ > 0){
            profitPerShare_ = profitPerShare_.add((_dividends * magnitude) / tokenSupply_);
        }
        emit onTokenSell(_customerAddress, _tokens, _taxedEthereum);
    }

    function transfer(address _toAddress, uint256 _amountOfTokens) onlyBagholders() public returns(bool){
        address _customerAddress = msg.sender;
        if(myDividends(true) > 0) withdraw();
        uint256 _tokenFee = _amountOfTokens.div(dividendFee_);
        uint256 _taxedTokens = _amountOfTokens.sub(_tokenFee);
        uint256 _dividends = tokensToEthereum_(_tokenFee);
        tokenSupply_ = tokenSupply_.sub(_tokenFee);
        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].sub(_amountOfTokens);
        tokenBalanceLedger_[_toAddress] = tokenBalanceLedger_[_toAddress].add(_taxedTokens);
        payoutsTo_[_customerAddress] -= int256(profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += int256(profitPerShare_ * _taxedTokens);
        profitPerShare_ = profitPerShare_.add((_dividends * magnitude) / tokenSupply_);
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);
        return true;
    }

    /* ADMIN FUNCTIONS */
    function disableInitialStage() onlyAdministrator() public {
        onlyAmbassadors = false;
    }
    function setAdministrator(bytes32 _identifier, bool _status) onlyAdministrator() public {
        administrators[_identifier] = _status;
    }
    function setAmbassadors(address ambassador, bool _status) onlyAdministrator() public {
        ambassadors_[ambassador] = _status;
    }
    function setStakingRequirement(uint256 _amountOfTokens) onlyAdministrator() public {
        stakingRequirement = _amountOfTokens;
    }
    function setName(string memory _name) onlyAdministrator() public { name = _name; }
    function setSymbol(string memory _symbol) onlyAdministrator() public { symbol = _symbol; }

    /* HELPERS */
    function totalEthereumBalance() public view returns(uint) { return address(this).balance; }
    function totalSupply() public view returns(uint256) { return tokenSupply_; }
    function myTokens() public view returns(uint256) { return balanceOf(msg.sender); }
    function myDividends(bool _includeReferralBonus) public view returns(uint256){
        address _customerAddress = msg.sender;
        return _includeReferralBonus ? dividendsOf(_customerAddress) + referralBalance_[_customerAddress] : dividendsOf(_customerAddress);
    }
    function balanceOf(address _customerAddress) public view returns(uint256){ return tokenBalanceLedger_[_customerAddress]; }
    function dividendsOf(address _customerAddress) public view returns(uint256){
        return uint256(int256(profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }
    function sellPrice() public view returns(uint256){
        if(tokenSupply_ == 0){ return tokenPriceInitial_ - tokenPriceIncremental_; }
        uint256 _ethereum = tokensToEthereum_(1e18);
        uint256 _dividends = _ethereum.div(dividendFee_);
        return _ethereum.sub(_dividends);
    }
    function buyPrice() public view returns(uint256){
        if(tokenSupply_ == 0){ return tokenPriceInitial_ + tokenPriceIncremental_; }
        uint256 _ethereum = tokensToEthereum_(1e18);
        uint256 _dividends = _ethereum.div(dividendFee_);
        return _ethereum.add(_dividends);
    }
    function calculateTokensReceived(uint256 _ethereumToSpend) public view returns(uint256){
        uint256 _dividends = _ethereumToSpend.div(dividendFee_);
        uint256 _taxedEthereum = _ethereumToSpend.sub(_dividends);
        return ethereumToTokens_(_taxedEthereum);
    }
    function calculateEthereumReceived(uint256 _tokensToSell) public view returns(uint256){
        uint256 _ethereum = tokensToEthereum_(_tokensToSell);
        uint256 _dividends = _ethereum.div(dividendFee_);
        return _ethereum.sub(_dividends);
    }

    /* INTERNAL FUNCTIONS */
    function purchaseTokens(uint256 _incomingEthereum, address _referredBy) antiEarlyWhale(_incomingEthereum) internal returns(uint256){
        address _customerAddress = msg.sender;
        uint256 _undividedDividends = _incomingEthereum.div(dividendFee_);
        uint256 _referralBonus = _undividedDividends.div(3);
        uint256 _dividends = _undividedDividends.sub(_referralBonus);
        uint256 _taxedEthereum = _incomingEthereum.sub(_undividedDividends);
        uint256 _amountOfTokens = ethereumToTokens_(_taxedEthereum);
        uint256 _fee = _dividends * magnitude;
        require(_amountOfTokens > 0 && (_amountOfTokens.add(tokenSupply_) > tokenSupply_));

        if(_referredBy != address(0) && _referredBy != _customerAddress && tokenBalanceLedger_[_referredBy] >= stakingRequirement){
            referralBalance_[_referredBy] = referralBalance_[_referredBy].add(_referralBonus);
        } else {
            _dividends = _dividends.add(_referralBonus);
            _fee = _dividends * magnitude;
        }

        if(tokenSupply_ > 0){
            tokenSupply_ = tokenSupply_.add(_amountOfTokens);
            profitPerShare_ += (_dividends * magnitude / (tokenSupply_));
            _fee = _fee - (_fee-(_amountOfTokens * (_dividends * magnitude / (tokenSupply_))));
        } else {
            tokenSupply_ = _amountOfTokens;
        }

        tokenBalanceLedger_[_customerAddress] = tokenBalanceLedger_[_customerAddress].add(_amountOfTokens);
        payoutsTo_[_customerAddress] += int256((profitPerShare_ * _amountOfTokens) - _fee);

        emit onTokenPurchase(_customerAddress, _incomingEthereum, _amountOfTokens, _referredBy);
        return _amountOfTokens;
    }

    function ethereumToTokens_(uint256 _ethereum) internal view returns(uint256){
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived = (
            (SafeMath.sub(
                sqrt(
                    (_tokenPriceInitial**2) +
                    (2*(tokenPriceIncremental_ * 1e18)*(_ethereum * 1e18)) +
                    ((tokenPriceIncremental_**2)*(tokenSupply_**2)) +
                    (2*(tokenPriceIncremental_)*_tokenPriceInitial*tokenSupply_)
                ), _tokenPriceInitial
            )) / tokenPriceIncremental_
        ) - tokenSupply_;
        return _tokensReceived;
    }

    function tokensToEthereum_(uint256 _tokens) internal view returns(uint256){
        uint256 tokens_ = _tokens + 1e18;
        uint256 _tokenSupply = tokenSupply_ + 1e18;
        uint256 _etherReceived = SafeMath.sub(
            ((tokenPriceInitial_ + (tokenPriceIncremental_ * (_tokenSupply/1e18)) - tokenPriceIncremental_) * (tokens_ - 1e18)),
            (tokenPriceIncremental_*((tokens_**2-tokens_)/1e18))/2
        ) / 1e18;
        return _etherReceived;
    }

    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
