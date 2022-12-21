// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from "openzeppelin-contracts/interfaces/IERC20.sol";


contract TestERC20 is IERC20 {
    error AlreadyClaimed();
    error NullAddress();
    error InsufficientAllowance(uint256 allowance, uint256 balance);
    error InsufficientBalance(uint256 balance, uint256 transferAmount);

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private constant _totalSupply = 1_000_000_000 * 1e6 wei;
    uint256 constant CLAIM_AMOUNT = 100 * 1e6 wei;

    string private _name;
    string private _symbol;

    uint256 private immutable _decimals;

    address private _owner;

    mapping(address => bool) claimed;

    constructor(string memory name_, string memory symbol_, uint256 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _owner = msg.sender;
        _decimals = decimals_;
        _balances[msg.sender] = _totalSupply / 2;
        _balances[address(this)] = _totalSupply / 2;
        emit Transfer(address(0), msg.sender, _totalSupply / 2);
        emit Transfer(address(0), address(this), _totalSupply / 2);
    }

    function getOwner() external view returns (address) {
        return _owner;
    }

    function decimals() external view returns (uint256) {
        return _decimals;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external pure returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(currentAllowance, amount);
        }
        _transfer(sender, recipient, amount);
        unchecked {
            _allowances[sender][msg.sender] = currentAllowance - amount;
        }
        return true;
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        if (sender == address(0) || recipient == address(0)) {
            revert NullAddress();
        }

        uint256 balance = _balances[sender];
        if (balance < amount) {
            revert InsufficientBalance(balance, amount);
        }

        unchecked {
            _balances[sender] = balance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == _owner);
        _transfer(address(this), _owner, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        if (owner == address(0) || spender == address(0)) {
            revert NullAddress();
        }
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function sendToMutiUsers(address[] memory input, uint256 amount) external {
        if (_balances[msg.sender] < input.length * amount) {
            revert InsufficientBalance(_balances[msg.sender], input.length * amount);
        }
        
        for (uint256 i = 0; i < input.length; i++) {
            _transfer(msg.sender, input[i], amount);
        }
    }

    function claim() external {
        if (claimed[msg.sender]) revert AlreadyClaimed();
        claimed[msg.sender] = true;
        _transfer(address(this), msg .sender, CLAIM_AMOUNT);
    }

    function isClaimedAlready(address user) external view returns (bool){
        return claimed[user] ? true : false;
    }
}
