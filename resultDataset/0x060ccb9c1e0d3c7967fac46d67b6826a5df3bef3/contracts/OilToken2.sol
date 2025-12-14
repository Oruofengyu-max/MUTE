pragma solidity ^0.5.12;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address _who) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
        if (_a == 0) return 0;
        uint256 c = _a * _b;
        require(c / _a == _b, "Mul overflow");
        return c;
    }

    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b > 0, "Div by zero");
        return _a / _b;
    }

    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b <= _a, "Sub underflow");
        return _a - _b;
    }

    function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
        uint256 c = _a + _b;
        require(c >= _a, "Add overflow");
        return c;
    }
}

contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) private balances_;
    mapping(address => mapping(address => uint256)) private allowed_;
    uint256 private totalSupply_;

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances_[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed_[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances_[msg.sender] = balances_[msg.sender].sub(_value);
        balances_[_to] = balances_[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed_[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_value <= balances_[_from], "Insufficient balance");
        require(_value <= allowed_[_from][msg.sender], "Allowance exceeded");
        require(_to != address(0), "Invalid address");

        balances_[_from] = balances_[_from].sub(_value);
        balances_[_to] = balances_[_to].add(_value);
        allowed_[_from][msg.sender] = allowed_[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function increaseApproval(address _spender, uint256 _addedValue) public returns (bool) {
        allowed_[msg.sender][_spender] = allowed_[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed_[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint256 _subtractedValue) public returns (bool) {
        uint256 oldValue = allowed_[msg.sender][_spender];
        if (_subtractedValue >= oldValue) {
            allowed_[msg.sender][_spender] = 0;
        } else {
            allowed_[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed_[msg.sender][_spender]);
        return true;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "Zero address");
        totalSupply_ = totalSupply_.add(_amount);
        balances_[_account] = balances_[_account].add(_amount);
        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "Zero address");
        require(_amount <= balances_[_account], "Insufficient balance");
        totalSupply_ = totalSupply_.sub(_amount);
        balances_[_account] = balances_[_account].sub(_amount);
        emit Transfer(_account, address(0), _amount);
    }

    function _burnFrom(address _account, uint256 _amount) internal {
        require(_amount <= allowed_[_account][msg.sender], "Allowance exceeded");
        allowed_[_account][msg.sender] = allowed_[_account][msg.sender].sub(_amount);
        _burn(_account, _amount);
    }
}

contract OilToken is ERC20 {
    string public constant name = "OilToken";
    string public constant symbol = "OLT";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 15 * (10 ** 7) * (10 ** uint256(decimals));

    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
