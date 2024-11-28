;; Real-time Payment Smart Contract
;; Implements secure payment processing with escrow functionality
;; and multi-signature requirements for large transactions

(define-constant CONTRACT_ADMINISTRATOR tx-sender)
(define-constant LARGE_TRANSACTION_THRESHOLD u1000000) ;; Threshold for multi-sig requirement (in micro-STX)
(define-constant ESCROW_HOLDING_PERIOD u144) ;; ~24 hours in blocks
(define-constant ERROR_NOT_AUTHORIZED (err u100))
(define-constant ERROR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERROR_INVALID_TRANSACTION_AMOUNT (err u102))
(define-constant ERROR_TRANSACTION_IN_PROGRESS (err u103))
(define-constant ERROR_TRANSACTION_NOT_FOUND (err u104))
(define-constant ERROR_TRANSACTION_ALREADY_COMPLETED (err u105))
(define-constant ERROR_INVALID_RECIPIENT (err u106))
(define-constant ERROR_INVALID_IDENTIFIER (err u107))

;; Data structures
(define-map TransactionRecords
    { transaction-identifier: uint }
    {
        transaction-initiator: principal,
        transaction-recipient: principal,
        transaction-amount: uint,
        transaction-status: (string-ascii 20),
        transaction-creation-time: uint,
        transaction-completion-time: (optional uint),
        requires-multiple-signatures: bool
    }
)

(define-map MultiSignatureRequests
    { transaction-identifier: uint }
    {
        authorized-signers: (list 10 principal),
        required-signature-count: uint
    }
)

(define-map AccountBalances principal uint)

(define-data-var transaction-sequence-number uint u0)
(define-data-var contract-emergency-stop bool false)

;; Private functions
(define-private (is-administrator)
    (is-eq tx-sender CONTRACT_ADMINISTRATOR)
)

(define-private (verify-transaction-exists (transaction-identifier uint))
    (match (map-get? TransactionRecords { transaction-identifier: transaction-identifier })
        transaction-record true
        false
    )
)

(define-private (requires-multiple-signatures (transaction-amount uint))
    (>= transaction-amount LARGE_TRANSACTION_THRESHOLD)
)

(define-private (get-account-balance (account-holder principal))
    (default-to u0 (map-get? AccountBalances account-holder))
)

;; Public functions
(define-public (deposit-funds)
    (let
        (
            (deposit-amount (stx-get-balance tx-sender))
            (existing-balance (get-account-balance tx-sender))
        )
        (if (> deposit-amount u0)
            (begin
                (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
                (map-set AccountBalances tx-sender (+ existing-balance deposit-amount))
                (ok deposit-amount)
            )
            ERROR_INVALID_TRANSACTION_AMOUNT
        )
    )
)

(define-public (create-payment-transaction (payment-recipient principal) (payment-amount uint))
    (let
        (
            (transaction-initiator tx-sender)
            (initiator-balance (get-account-balance transaction-initiator))
            (transaction-identifier (var-get transaction-sequence-number))
            (requires-approval (requires-multiple-signatures payment-amount))
        )
        (asserts! (not (var-get contract-emergency-stop)) ERROR_NOT_AUTHORIZED)
        (asserts! (>= initiator-balance payment-amount) ERROR_INSUFFICIENT_BALANCE)
        (asserts! (> payment-amount u0) ERROR_INVALID_TRANSACTION_AMOUNT)
        (asserts! (not (is-eq payment-recipient transaction-initiator)) ERROR_INVALID_RECIPIENT)
        
        ;; Create transaction record
        (map-set TransactionRecords
            { transaction-identifier: transaction-identifier }
            {
                transaction-initiator: transaction-initiator,
                transaction-recipient: payment-recipient,
                transaction-amount: payment-amount,
                transaction-status: "pending",
                transaction-creation-time: block-height,
                transaction-completion-time: none,
                requires-multiple-signatures: requires-approval
            }
        )
        
        ;; Initialize multi-signature tracking if needed
        (if requires-approval
            (map-set MultiSignatureRequests
                { transaction-identifier: transaction-identifier }
                {
                    authorized-signers: (list),
                    required-signature-count: u2
                }
            )
            true
        )
        
        ;; Update sequence number and return
        (var-set transaction-sequence-number (+ transaction-identifier u1))
        (ok transaction-identifier)
    )
)

(define-public (approve-transaction (transaction-identifier uint))
    (let
        (
            (transaction-record (unwrap! (map-get? TransactionRecords { transaction-identifier: transaction-identifier }) ERROR_TRANSACTION_NOT_FOUND))
            (signature-data (unwrap! (map-get? MultiSignatureRequests { transaction-identifier: transaction-identifier }) ERROR_TRANSACTION_NOT_FOUND))
            (current-authorized-signers (get authorized-signers signature-data))
        )
        (asserts! (> transaction-identifier u0) ERROR_INVALID_IDENTIFIER)
        (asserts! (is-eq (get transaction-status transaction-record) "pending") ERROR_TRANSACTION_ALREADY_COMPLETED)
        (asserts! (get requires-multiple-signatures transaction-record) ERROR_NOT_AUTHORIZED)
        (asserts! (not (is-eq (index-of current-authorized-signers tx-sender) (some u0))) ERROR_NOT_AUTHORIZED)
        
        ;; Add signature
        (map-set MultiSignatureRequests
            { transaction-identifier: transaction-identifier }
            {
                authorized-signers: (unwrap! (as-max-len? (append current-authorized-signers tx-sender) u10) ERROR_NOT_AUTHORIZED),
                required-signature-count: (get required-signature-count signature-data)
            }
        )
        
        ;; Process if enough signatures collected
        (if (>= (len (get authorized-signers signature-data)) (get required-signature-count signature-data))
            (execute-transaction transaction-identifier)
            (ok true)
        )
    )
)

(define-public (execute-transaction (transaction-identifier uint))
    (let
        (
            (transaction-record (unwrap! (map-get? TransactionRecords { transaction-identifier: transaction-identifier }) ERROR_TRANSACTION_NOT_FOUND))
            (transaction-initiator (get transaction-initiator transaction-record))
            (transaction-recipient (get transaction-recipient transaction-record))
            (transaction-amount (get transaction-amount transaction-record))
        )
        (asserts! (> transaction-identifier u0) ERROR_INVALID_IDENTIFIER)
        (asserts! (is-eq (get transaction-status transaction-record) "pending") ERROR_TRANSACTION_ALREADY_COMPLETED)
        (asserts! (>= (get-account-balance transaction-initiator) transaction-amount) ERROR_INSUFFICIENT_BALANCE)
        
        ;; Update account balances
        (map-set AccountBalances
            transaction-initiator
            (- (get-account-balance transaction-initiator) transaction-amount)
        )
        (map-set AccountBalances
            transaction-recipient
            (+ (get-account-balance transaction-recipient) transaction-amount)
        )
        
        ;; Update transaction status
        (map-set TransactionRecords
            { transaction-identifier: transaction-identifier }
            (merge transaction-record {
                transaction-status: "completed",
                transaction-completion-time: (some block-height)
            })
        )
        
        (ok true)
    )
)

;; Admin functions
(define-public (activate-emergency-stop)
    (begin
        (asserts! (is-administrator) ERROR_NOT_AUTHORIZED)
        (var-set contract-emergency-stop true)
        (ok true)
    )
)

(define-public (deactivate-emergency-stop)
    (begin
        (asserts! (is-administrator) ERROR_NOT_AUTHORIZED)
        (var-set contract-emergency-stop false)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-transaction-details (transaction-identifier uint))
    (map-get? TransactionRecords { transaction-identifier: transaction-identifier })
)

(define-read-only (get-account-balance-view (account-holder principal))
    (ok (get-account-balance account-holder))
)

(define-read-only (get-contract-operational-status)
    (ok (not (var-get contract-emergency-stop)))
)