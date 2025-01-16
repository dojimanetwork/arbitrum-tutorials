// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
    OutboundState Sender interface that will be used by other smart contract developers on dojima chain to call the
    outbound state sender smart contract and send the state to the hermes chain.
*/
interface IOutboundStateSender {
    // Events
    event TransferPayload(
        uint256 indexed depositId,
        bytes32 indexed destinationChain,
        bytes destinationContract,
        address vault,
        address refundAddress,
        uint256 gas,
        bytes payload
    );

    // Events
    event TransferAsset(
        uint256 indexed assetDepositId,
        bytes32 indexed destinationChain,
        bytes destinationAddress,
        address refundAddress,
        uint256 gas,
        bytes destinationAsset,
        uint256 assetAmount
    );

    /**
     * @notice Function to send payload to the hermes chain, value sent by the caller should be used as gas amount.
     * @param destinationChain destination chain name.
     * @param destinationContract destination chain contract address in bytes format.
     * @param payload payload that will be sent to the hermes chain.
     */
    function transferPayload(
        bytes32 destinationChain,
        bytes memory destinationContract,
        address refundAddress,
        bytes memory payload
    ) external payable;

    /**
     * @notice Function to send assets to the hermes chain.
     * @param destinationChain destination chain name.
     * @param destinationAddress destination user address for token transfer.
     * @param destinationAsset is the unique representation of asset on destination chain
     * @param assetAmount is the total amount of asset that the user burnt
     */
    function transferAsset(
        bytes32 destinationChain,
        bytes memory destinationAddress,
        address refundAddress,
        bytes memory destinationAsset,
        uint256 assetAmount
    ) external payable;

    /**
     * @notice Initiates a withdrawal by emitting an event with necessary details for Hermes.
     * @dev Called by the settlement contract after locking the assets.
     * @param rollupId The unique identifier for the rollup initiating the withdrawal.
     * @param amount The amount of the asset to withdraw.
     * @param refundAddress The address that will be refunded for the gas amount.
     * @param destinationChainId The chain ID of the target L1 chain (use a unique ID for non-EVM chains like Bitcoin, Solana).
     * @param destinationAssetId is the unique representation of asset on destination chain.
     * @param recipientAddress The address on the L1 chain where the assets will be sent (could be a custom format for non-EVM chains).
     */
    function initiateWithdrawal(
        uint256 rollupId,
        uint256 amount,
        address refundAddress,
        bytes32 destinationChainId,
        bytes memory destinationAssetId,
        bytes memory recipientAddress
    ) external payable;

    /**
     * @notice Emitted when a withdrawal is initiated.
     * @param initiator The address that initiated the withdrawal (usually the settlement contract).
     * @param rollupId The unique identifier for the rollup initiating the withdrawal.
     * @param amount The amount of the asset to withdraw.
     * @param refundAddress The address that will be refunded for the gas amount.
     * @param gasFee The amount of gas to pay for the withdrawal always in DOJ token.
     * @param destinationAssetId is the unique representation of asset on destination chain.
     * @param destinationChainId The chain ID of the target L1 chain.
     * @param recipientAddress The address on the L1 chain where the assets will be sent (in bytes format for flexibility across different L1s).
     * @param votingContract The address of the voting contract on the L1 chain.
     */
    event InitiateWithdrawal(
        address indexed initiator,
        uint256 indexed rollupId,
        uint256 indexed withdrawId,
        uint256 amount,
        address refundAddress,
        uint256 gasFee,
        bytes32 destinationChainId,
        bytes destinationAssetId,
        bytes recipientAddress,
        address votingContract
    );

    /**
     * @notice Function to handle the voting completed event.
     * @param withdrawEventId The unique identifier for the withdrawal event.
     * @param rollupId The unique identifier for the rollup initiating the withdrawal.
     * @param txHash The hash of the transaction that is being voted on.
     */
    function handleVotingCompleted(
        uint128 withdrawEventId,
        uint128 rollupId,
        bytes32 txHash
    ) external;

    /**
     * @notice Emitted when a voting is completed.
     * @param withdrawEventId The unique identifier for the withdrawal event.
     * @param rollupId The unique identifier for the rollup initiating the withdrawal.
     * @param txHash The hash of the transaction that is being voted on.
     */
    event VotingCompleted(
        uint128 indexed rollupId,
        uint128 indexed withdrawEventId,
        bytes32 indexed txHash
    );
}
