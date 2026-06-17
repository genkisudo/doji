// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title DojiTradeNFT
/// @notice Mints a trade proof NFT for DojiFunded trades with on-chain metadata.
/// @dev v2 scaling: prices 1e8 (Chainlink), USD 1e6 (USDC), quantity 1e18 (ERC20), leverage 1e2, fundingRate 1e8.
contract DojiTradeNFT is ERC721, AccessControl {
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Per-field decimals so off-chain consumers know how to interpret each value
    // without having to re-read the source. Exposed as constants in the ABI.
    uint8  public constant PRICE_DECIMALS    = 8;   // entry/exit/mark/TP/SL/funding rate
    uint8  public constant USD_DECIMALS      = 6;   // sizeUsd, realizedPnl, feesPaid, fundingPayment
    uint8  public constant QTY_DECIMALS      = 18;  // quantity (base asset)
    uint8  public constant LEVERAGE_DECIMALS = 2;   // 1x = 100, 50x = 5000

    uint256 public nextTokenId;

    struct TradeMetadata {
        string symbol;
        string accountId;
        string tradeId;
        string positionId;
        bool isLong;
        uint64 openedAt;
        uint64 closedAt;
        int128  realizedPnl;            // 1e6 USD
        uint128 positionSizeUsd;        // 1e6 USD
        uint256 quantity;               // 1e18 base asset
        uint32  leverage;               // 1e2 (1x = 100)
        uint128 entryPrice;             // 1e8
        uint128 exitPrice;              // 1e8
        uint128 requestedPrice;         // 1e8
        uint128 markPrice;              // 1e8
        uint128 feesPaid;               // 1e6 USD
        int128  fundingPayment;         // 1e6 USD
        int128  fundingRate;            // 1e8
        uint128 takeProfitTrigger;      // 1e8
        uint128 takeProfitLimit;        // 1e8
        uint8   takeProfitTriggerType;  // 0=NONE, 1=MARK, 2=LAST
        uint128 stopLossTrigger;        // 1e8
        uint128 stopLossLimit;          // 1e8
        uint8   stopLossTriggerType;    // 0=NONE, 1=MARK, 2=LAST
        string  breachedRule;
    }

    mapping(uint256 => TradeMetadata) private tradeData;

    event TradeMinted(
        uint256 indexed tokenId,
        address indexed trader,
        string symbol,
        bool isLong,
        uint128 positionSizeUsd,
        uint32  leverage,
        uint128 exitPrice,
        int128  realizedPnl,
        uint128 feesPaid,
        string accountId,
        string tradeId
    );
    event TradeBurned(uint256 indexed tokenId, address indexed owner);

    constructor(address admin) ERC721("DojiFunded Trade Proof", "DOJI-TRADE") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mintTrade(address to, TradeMetadata calldata data)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        tokenId = ++nextTokenId;
        _safeMint(to, tokenId);
        tradeData[tokenId] = data;
        emit TradeMinted(
            tokenId,
            to,
            data.symbol,
            data.isLong,
            data.positionSizeUsd,
            data.leverage,
            data.exitPrice,
            data.realizedPnl,
            data.feesPaid,
            data.accountId,
            data.tradeId
        );
    }

    function tradeMetadata(uint256 tokenId) external view returns (TradeMetadata memory) {
        _requireMinted(tokenId);
        return tradeData[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        TradeMetadata memory data = tradeData[tokenId];
        string memory attributes = _buildAttributes(data);

        string memory json = string(
            abi.encodePacked(
                '{"name":"DojiFunded Trade #',
                tokenId.toString(),
                '","description":"On-chain proof of a DojiFunded trade.",',
                '"attributes":',
                attributes,
                "}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Admin-only burn for emergency remediation.
    function burn(uint256 tokenId) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert("Admin only");
        }
        _burn(tokenId);
        delete tradeData[tokenId];
        emit TradeBurned(tokenId, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _attr(string memory key, string memory value) private pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', key, '","value":"', value, '"}'));
    }

    function _buildAttributes(TradeMetadata memory data) private pure returns (string memory) {
        return string(abi.encodePacked("[", _buildBaseAttributes(data), ",", _buildExtraAttributes(data), "]"));
    }

    /// @dev Generic fixed-point formatter — divides `value` by 10**decimals,
    ///      pads the fractional part to `decimals` digits, then trims trailing
    ///      zeros (and the trailing dot) so e.g. 62.49447800 reads as "62.494478".
    function _formatFixed(uint256 value, uint8 decimals) private pure returns (string memory) {
        uint256 unit = 10 ** uint256(decimals);
        uint256 whole = value / unit;
        uint256 frac = value % unit;
        string memory fracStr = _padLeft(frac.toString(), decimals);
        bytes memory fracBytes = bytes(fracStr);
        // Trim trailing zeros so display is human-friendly.
        uint256 end = fracBytes.length;
        while (end > 0 && fracBytes[end - 1] == "0") {
            end--;
        }
        if (end == 0) {
            return whole.toString();
        }
        bytes memory trimmed = new bytes(end);
        for (uint256 i = 0; i < end; i++) {
            trimmed[i] = fracBytes[i];
        }
        return string(abi.encodePacked(whole.toString(), ".", trimmed));
    }

    function _padLeft(string memory s, uint8 width) private pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length >= width) return s;
        bytes memory pad = new bytes(uint256(width) - b.length);
        for (uint256 i = 0; i < pad.length; i++) pad[i] = "0";
        return string(abi.encodePacked(pad, b));
    }

    function _formatSigned(int256 value, uint8 decimals) private pure returns (string memory) {
        if (value >= 0) {
            return _formatFixed(uint256(value), decimals);
        }
        return string(abi.encodePacked("-", _formatFixed(uint256(-value), decimals)));
    }

    function _formatOptional(uint256 value, uint8 decimals) private pure returns (string memory) {
        if (value == 0) return "N/A";
        return _formatFixed(value, decimals);
    }

    function _triggerType(uint8 value) private pure returns (string memory) {
        if (value == 1) return "MARK";
        if (value == 2) return "LAST";
        return "NONE";
    }

    function _buildBaseAttributes(TradeMetadata memory data) private pure returns (string memory) {
        string memory side = data.isLong ? "LONG" : "SHORT";
        return string(
            abi.encodePacked(
                _attr("Symbol", data.symbol),
                ",",
                _attr("Side", side),
                ",",
                _attr("Position Size (USD)", _formatFixed(data.positionSizeUsd, USD_DECIMALS)),
                ",",
                _attr("Quantity", _formatFixed(data.quantity, QTY_DECIMALS)),
                ",",
                _attr("Leverage", _formatFixed(data.leverage, LEVERAGE_DECIMALS)),
                ",",
                _attr("Entry Price", _formatFixed(data.entryPrice, PRICE_DECIMALS)),
                ",",
                _attr("Exit Price", _formatFixed(data.exitPrice, PRICE_DECIMALS)),
                ",",
                _attr("Requested Price", _formatOptional(data.requestedPrice, PRICE_DECIMALS)),
                ",",
                _attr("Mark Price", _formatOptional(data.markPrice, PRICE_DECIMALS)),
                ",",
                _attr("Profit (USD)", _formatFixed(_profitAmount(data.realizedPnl), USD_DECIMALS)),
                ",",
                _attr("Loss (USD)", _formatFixed(_lossAmount(data.realizedPnl), USD_DECIMALS)),
                ",",
                _attr("Realized PnL", _formatSigned(data.realizedPnl, USD_DECIMALS)),
                ",",
                _attr("Fees Paid", _formatFixed(data.feesPaid, USD_DECIMALS)),
                ",",
                _attr("Funding Payment", _formatSigned(data.fundingPayment, USD_DECIMALS)),
                ",",
                _attr("Funding Rate", _formatSigned(data.fundingRate, PRICE_DECIMALS))
            )
        );
    }

    function _buildExtraAttributes(TradeMetadata memory data) private pure returns (string memory) {
        string memory tpType = _triggerType(data.takeProfitTriggerType);
        string memory slType = _triggerType(data.stopLossTriggerType);
        return string(
            abi.encodePacked(
                _attr("Opened At", uint256(data.openedAt).toString()),
                ",",
                _attr("Closed At", uint256(data.closedAt).toString()),
                ",",
                _attr("Account", data.accountId),
                ",",
                _attr("Position Id", data.positionId),
                ",",
                _attr("Trade Id", data.tradeId),
                ",",
                _attr("TP Trigger", _formatOptional(data.takeProfitTrigger, PRICE_DECIMALS)),
                ",",
                _attr("TP Limit", _formatOptional(data.takeProfitLimit, PRICE_DECIMALS)),
                ",",
                _attr("TP Trigger Type", tpType),
                ",",
                _attr("SL Trigger", _formatOptional(data.stopLossTrigger, PRICE_DECIMALS)),
                ",",
                _attr("SL Limit", _formatOptional(data.stopLossLimit, PRICE_DECIMALS)),
                ",",
                _attr("SL Trigger Type", slType),
                ",",
                _attr("Breached Rule", data.breachedRule)
            )
        );
    }

    function _profitAmount(int256 value) private pure returns (uint256) {
        if (value <= 0) return 0;
        return uint256(value);
    }

    function _lossAmount(int256 value) private pure returns (uint256) {
        if (value >= 0) return 0;
        return uint256(-value);
    }
}
