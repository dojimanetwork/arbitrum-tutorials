// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import { IOutboundStateSender } from './IOutboundStateSender.sol';
import '@dojimanetwork/dojima-contracts/contracts/interfaces/IStateReceiver.sol';
import '@dojimanetwork/dojima-contracts/contracts/dojimachain/StateSyncerVerifier.sol';

contract WrappedCrossERC20Token is ERC20, AccessControl, ReentrancyGuard, IStateReceiver {
    // Define roles using keccak256 hash identifiers
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    // Interface for state synchronization
    IOutboundStateSender public outboundStateSender;
    StateSyncerVerifier private _stateVerifier;
    error InvalidAmount();
    error InvalidMsgValue(uint256 expected, uint256 actual);
    error WithdrawEthFail(address vault);

    // Mapping for destination chain contracts
    mapping(bytes32 => bytes) public chainContractMappings;

    // Events
    event WrappedTokensMinted(address indexed user, uint256 amount, uint256 depositId);
    event WrappedTokensBurned(address indexed user, uint256 amount, uint256 transferId);
    event OutboundStateSenderUpdated(address indexed newOutboundStateSender);
    event EthereumERC20TokenUpdated(address indexed newEthereumERC20Token);
    event ChainContractMappingUpdated(bytes32 chainName, bytes contractAddress);

    modifier onlyStateSyncer() {
        require(
            msg.sender == address(_stateVerifier.stateSyncer()),
            'WrappedCrossERC20: Caller is not the state syncer'
        );
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address stateSender_,
        address stateSyncerVerifier_
    ) ERC20(name_, symbol_) {
        require(stateSender_ != address(0), 'WrappedCrossERC20: StateSender address cannot be zero');
        require(stateSyncerVerifier_ != address(0), 'WrappedCrossERC20: Invalid state syncer verifier address');

        // Assign roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);

        outboundStateSender = IOutboundStateSender(stateSender_);
        _stateVerifier = StateSyncerVerifier(stateSyncerVerifier_);

        _mint(msg.sender, 1000 * 10 ** decimals());
    }
    /**
     * @notice Update the outboundStateSender contract address
     * @param newStateSender The new StateSender contract address
     */
    function updateStateSender(address newStateSender) external onlyRole(ADMIN_ROLE) {
        require(newStateSender != address(0), 'WrappedCrossERC20: New StateSender address cannot be zero');
        outboundStateSender = IOutboundStateSender(newStateSender);
        emit OutboundStateSenderUpdated(newStateSender);
    }

    /**
     * @notice Function to handle incoming state from Ethereum and mint wrapped tokens
     * @param id The deposit ID associated with the minting
     * @param data The encoded data containing user address, amount, and identifier
     */
    function onStateReceive(uint256 id, bytes calldata data) external {
        (bytes memory userBytes, uint256 amount, uint256 depositId) = abi.decode(data, (bytes, uint256, uint256));

        // Ensure the bytes array for the address is of the correct length
        require(userBytes.length > 0, 'WrappedCrossERC20: Invalid address length');

        address userAddress;
        assembly {
            userAddress := mload(add(userBytes, 20))
        }

        require(userAddress != address(0), 'WrappedCrossERC20: Invalid user address');
        require(amount > 0, 'WrappedCrossERC20: Amount must be greater than zero');

        // Mint wrapped tokens to the user
        _mint(userAddress, amount);

        emit WrappedTokensMinted(userAddress, amount, depositId);
    }

    /**
     * @notice Transfer wrapped tokens back to Ethereum chain
     * @param destinationChain The bytes32 identifier of the destination chain
     * @param user The encoded user address on the destination chain
     * @param amount The amount of wrapped tokens to transfer
     * @param destinationContractAddress The encoded contract address on the destination chain
     */
    function transferToChain(
        bytes32 destinationChain,
        bytes memory user,
        uint256 amount,
        uint256 gasFee,
        bytes memory destinationContractAddress
    ) external payable nonReentrant {
        require(
            keccak256(destinationContractAddress) == keccak256(chainContractMappings[destinationChain]),
            'WrappedCrossERC20: Destination contract address does not match'
        );

        // Gas fee will be in doj token
        if (msg.value != gasFee) revert InvalidMsgValue(gasFee, msg.value);

        require(balanceOf(msg.sender) >= amount, 'WrappedCrossERC20: Insufficient wrapped token balance');

        // Burn wrapped tokens from the sender
        _burn(msg.sender, amount);

        // msg.value will be used as gas amount for the outbound transfer
        outboundStateSender.transferPayload{ value: gasFee }(
            destinationChain,
            destinationContractAddress,
            msg.sender,
            abi.encode(user, amount, 0) // Using timestamp as transferId
        );

        emit WrappedTokensBurned(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Set the mapping for destination chain to contract address
     * @param chainName The bytes32 identifier of the destination chain
     * @param contractAddress The encoded contract address on the destination chain
     */
    function updateChainContractMapping(bytes32 chainName, bytes memory contractAddress) external onlyRole(ADMIN_ROLE) {
        chainContractMappings[chainName] = contractAddress;
        emit ChainContractMappingUpdated(chainName, contractAddress);
    }

    /**
     * @notice Get the mapped contract address for a destination chain
     * @param destinationChain The bytes32 identifier of the destination chain
     * @return The encoded contract address on the destination chain
     */
    function getChainContractMapping(bytes32 destinationChain) external view returns (bytes memory) {
        return chainContractMappings[destinationChain];
    }
}
