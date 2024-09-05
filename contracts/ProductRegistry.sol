// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ProductRegistry is OApp {
    using Counters for Counters.Counter;

    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 timestamp;
        bool isVerified;
    }

    mapping(uint256 => Product) public products;
    Counters.Counter private _productIds;

    event ProductRegistered(
        uint256 indexed id,
        string name,
        address manufacturer
    );
    event ProductVerified(uint256 indexed id, uint32 sourceChain);

    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) {}


    /**
    * @dev Register product on source chain
    * @param _name Name of product.
    */
    function registerProduct(string memory _name) external {
        _productIds.increment();
        uint256 newProductId = _productIds.current();
        products[newProductId] = Product(
            newProductId,
            _name,
            msg.sender,
            block.timestamp,
            false
        );
        emit ProductRegistered(newProductId, _name, msg.sender);
    }


    /**
     * @dev Verify a Product Cross-chain.
     * @param _productId Product identifier to be verified.
     * @param _dstChainId Destination chain's endpoint ID.
     * @param _options Message execution options (e.g., for sending gas to destination).
     */
    function verifyProduct(
        uint256 _productId,
        uint32 _dstChainId,
        bytes calldata _options
    ) external payable {
        require(
            products[_productId].manufacturer == msg.sender,
            "Not the manufacturer"
        );

        bytes memory payload = abi.encode(_productId);

        // Send cross-chain message
        _lzSend(
            _dstChainId,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
    }


    /**
     * @dev Called when data is received from the protocol. It overrides the equivalent function in the parent contract.
     * Protocol messages are defined as packets, comprised of the following parameters.
     * @param _origin A struct containing information about where the packet came from.
     * @param _guid A global unique identifier for tracking the packet.
     * @param _message Encoded message.
     * @param _executor the address of the executor.
     * @param _extraData arbitrary data.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        uint256 productId = abi.decode(_message, (uint256));
        products[productId].isVerified = true;
        emit ProductVerified(productId, _origin.srcEid);
    }


    /**
    * @dev Quotes the gas needed to pay for the full omnichain transaction.
    * @return nativeFee Estimated gas fee in native gas.
    * @return lzTokenFee Estimated gas fee in ZRO token.
    */
    function quote(
        uint32 _dstChainId,
        uint256 _productId,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        bytes memory _payload = abi.encode(_productId);
        MessagingFee memory fee = _quote(
            _dstChainId,
            _payload,
            _options,
            _payInLzToken
        );
        return (fee.nativeFee, fee.lzTokenFee);
    }
}
