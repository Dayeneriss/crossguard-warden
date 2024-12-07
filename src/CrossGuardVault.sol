// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol";

contract CrossGuardVault is Ownable, IAxelarExecutable {
    // Événements
    event AssetDeposited(address indexed user, address token, uint256 amount);
    event AssetWithdrawn(address indexed user, address token, uint256 amount);
    event CrossChainTransferInitiated(string destinationChain, address token, uint256 amount);

    // Structure pour les stratégies d'Intent
    struct IntentStrategy {
        uint256 minBalance;
        uint256 maxBalance;
        address targetToken;
        bool autoConvert;
    }

    // Configuration Axelar
    IAxelarGateway public immutable gateway;
    
    // Mapping pour les soldes des utilisateurs
    mapping(address => mapping(address => uint256)) public userBalances;
    
    // Mapping pour les stratégies d'Intent
    mapping(address => IntentStrategy) public userIntents;

    constructor(address _gateway) IAxelarExecutable(_gateway) {
        gateway = IAxelarGateway(_gateway);
    }

    // Dépôt d'actifs
    function deposit(address token, uint256 amount) external {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        userBalances[msg.sender][token] += amount;
        emit AssetDeposited(msg.sender, token, amount);
    }

    // Retrait d'actifs
    function withdraw(address token, uint256 amount) external {
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");
        userBalances[msg.sender][token] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
        emit AssetWithdrawn(msg.sender, token, amount);
    }

    // Transfert cross-chain via Axelar
    function transferCrossChain(
        string memory destinationChain, 
        address destinationContract,
        address token, 
        uint256 amount
    ) external payable {
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");
        userBalances[msg.sender][token] -= amount;

        bytes memory payload = abi.encode(msg.sender, token, amount);
        gateway.callContract(destinationChain, destinationContract, payload);
        
        emit CrossChainTransferInitiated(destinationChain, token, amount);
    }

    // Gestion des Intents
    function setIntentStrategy(
        address token,
        uint256 minBalance,
        uint256 maxBalance,
        address targetToken,
        bool autoConvert
    ) external {
        userIntents[msg.sender] = IntentStrategy({
            minBalance: minBalance,
            maxBalance: maxBalance,
            targetToken: targetToken,
            autoConvert: autoConvert
        });
    }

    // Exécution automatique des Intents
    function executeIntent(address user, address token) external {
        IntentStrategy memory strategy = userIntents[user];
        uint256 balance = userBalances[user][token];

        if (strategy.autoConvert && 
            (balance < strategy.minBalance || balance > strategy.maxBalance)) {
            // Logique de conversion/rééquilibrage à implémenter
            // Nécessiterait une intégration avec un DEX ou un service d'échange
        }
    }

    // Fonction de réception cross-chain
    function _execute(
        string memory sourceChain, 
        string memory sourceAddress, 
        bytes calldata payload
    ) internal override {
        (address sender, address token, uint256 amount) = abi.decode(payload, (address, address, uint256));
        userBalances[sender][token] += amount;
    }
}