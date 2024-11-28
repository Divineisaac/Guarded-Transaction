# Real-time Payment Smart Contract

## About
A robust smart contract system built on the Stacks blockchain for handling secure real-time payments with multi-signature support, escrow functionality, and comprehensive transaction management.

## Features
- **Secure Payment Processing**: Real-time transaction execution with balance verification
- **Multi-signature Support**: Additional security for large transactions
- **Escrow System**: Built-in holding period for transaction security
- **Emergency Controls**: Contract pause/unpause functionality for risk management
- **Balance Management**: Automated account balance tracking and updates
- **Transaction History**: Comprehensive transaction record keeping

## Security Features
- Transaction amount thresholds
- Multi-signature requirements for large transactions
- Emergency stop mechanism
- Balance verification
- Transaction sequence tracking
- Authorization checks

## Contract Constants
```clarity
LARGE_TRANSACTION_THRESHOLD: u1000000    // Threshold for multi-sig requirement
ESCROW_HOLDING_PERIOD: u144              // ~24 hours in blocks
```

## Data Structures

### TransactionRecords
Stores detailed information about each transaction:
```clarity
{
    transaction-initiator: principal,
    transaction-recipient: principal,
    transaction-amount: uint,
    transaction-status: string-ascii,
    transaction-creation-time: uint,
    transaction-completion-time: optional uint,
    requires-multiple-signatures: bool
}
```

### MultiSignatureRequests
Tracks approval status for large transactions:
```clarity
{
    authorized-signers: (list 10 principal),
    required-signature-count: uint
}
```

## Public Functions

### deposit-funds
Deposits STX into the contract.
```clarity
(define-public (deposit-funds) ...)
```

### create-payment-transaction
Initiates a new payment transaction.
```clarity
(define-public (create-payment-transaction (payment-recipient principal) (payment-amount uint)) ...)
```

### approve-transaction
Approves a pending multi-signature transaction.
```clarity
(define-public (approve-transaction (transaction-identifier uint)) ...)
```

### execute-transaction
Processes and completes a payment transaction.
```clarity
(define-public (execute-transaction (transaction-identifier uint)) ...)
```

## Administrative Functions

### activate-emergency-stop
Pauses the contract operations (admin only).
```clarity
(define-public (activate-emergency-stop) ...)
```

### deactivate-emergency-stop
Resumes contract operations (admin only).
```clarity
(define-public (deactivate-emergency-stop) ...)
```

## Read-Only Functions

### get-transaction-details
Retrieves details of a specific transaction.
```clarity
(define-read-only (get-transaction-details (transaction-identifier uint)) ...)
```

### get-account-balance-view
Checks the balance of a specified account.
```clarity
(define-read-only (get-account-balance-view (account-holder principal)) ...)
```

### get-contract-operational-status
Checks if the contract is currently operational.
```clarity
(define-read-only (get-contract-operational-status) ...)
```

## Error Codes
- `ERROR_NOT_AUTHORIZED (u100)`: Unauthorized access attempt
- `ERROR_INSUFFICIENT_BALANCE (u101)`: Insufficient funds for transaction
- `ERROR_INVALID_TRANSACTION_AMOUNT (u102)`: Invalid transaction amount
- `ERROR_TRANSACTION_IN_PROGRESS (u103)`: Transaction already in progress
- `ERROR_TRANSACTION_NOT_FOUND (u104)`: Transaction identifier not found
- `ERROR_TRANSACTION_ALREADY_COMPLETED (u105)`: Transaction already completed

## Usage Examples

### Creating a Payment Transaction
```clarity
(contract-call? .secure-payment-processor create-payment-transaction 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
    u1000)
```

### Approving a Large Transaction
```clarity
(contract-call? .secure-payment-processor approve-transaction u1)
```

### Checking Account Balance
```clarity
(contract-call? .secure-payment-processor get-account-balance-view 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Security Considerations
- Ensure proper access control for administrative functions
- Verify transaction amounts against thresholds
- Monitor multi-signature approval process
- Regular balance reconciliation
- Emergency stop functionality testing

## Contributing
1. Fork the repository
2. Create a feature branch
3. Submit a pull request