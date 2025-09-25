;; ScootFi Rental System Contract
;; Manages rental transactions, payments, and user interactions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SCOOTER_NOT_FOUND (err u201))
(define-constant ERR_SCOOTER_NOT_AVAILABLE (err u202))
(define-constant ERR_RENTAL_NOT_FOUND (err u203))
(define-constant ERR_RENTAL_ALREADY_ACTIVE (err u204))
(define-constant ERR_INSUFFICIENT_BALANCE (err u205))
(define-constant ERR_PAYMENT_FAILED (err u206))
(define-constant ERR_INVALID_DURATION (err u207))
(define-constant ERR_RENTAL_EXPIRED (err u208))
(define-constant ERR_NOT_RENTER (err u209))
(define-constant ERR_INVALID_AMOUNT (err u210))
(define-constant MIN_RENTAL_DURATION u5) ;; Minimum 5 minutes
(define-constant MAX_RENTAL_DURATION u1440) ;; Maximum 24 hours (1440 minutes)
(define-constant SECURITY_DEPOSIT u1000000) ;; 1 STX security deposit in microSTX
(define-constant PLATFORM_FEE_RATE u50) ;; 5% platform fee (50/1000)

;; Data Variables
(define-data-var next-rental-id uint u1)
(define-data-var total-rentals uint u0)
(define-data-var active-rentals uint u0)
(define-data-var platform-revenue uint u0)
(define-data-var total-revenue uint u0)

;; Data Maps
(define-map rentals
    { rental-id: uint }
    {
        scooter-id: uint,
        renter: principal,
        start-time: uint,
        planned-duration: uint,
        actual-duration: (optional uint),
        rate-per-minute: uint,
        security-deposit: uint,
        total-cost: (optional uint),
        platform-fee: (optional uint),
        is-active: bool,
        end-time: (optional uint),
        payment-status: (string-ascii 20)
    }
)

(define-map user-rentals
    { user: principal }
    {
        total-rentals: uint,
        active-rental-id: (optional uint),
        total-spent: uint,
        last-rental: (optional uint)
    }
)

(define-map scooter-rental-status
    { scooter-id: uint }
    {
        is-rented: bool,
        current-rental-id: (optional uint),
        renter: (optional principal),
        rental-start: (optional uint)
    }
)

(define-map rental-payments
    { rental-id: uint }
    {
        deposit-paid: uint,
        rental-fee: uint,
        platform-fee: uint,
        refund-amount: uint,
        payment-block: uint
    }
)

;; Private Functions
(define-private (calculate-rental-cost (duration uint) (rate-per-minute uint))
    (* duration rate-per-minute)
)

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount PLATFORM_FEE_RATE) u1000)
)

(define-private (validate-rental-duration (duration uint))
    (and (>= duration MIN_RENTAL_DURATION) (<= duration MAX_RENTAL_DURATION))
)

;; Scooter data within rental system (independent implementation)
(define-map scooter-rates
    { scooter-id: uint }
    {
        rate-per-minute: uint,
        is-available: bool,
        operator: principal
    }
)

(define-private (get-scooter-availability (scooter-id uint))
    (match (map-get? scooter-rates { scooter-id: scooter-id })
        scooter-data (get is-available scooter-data)
        false
    )
)

(define-private (get-scooter-rate (scooter-id uint))
    (match (map-get? scooter-rates { scooter-id: scooter-id })
        scooter-data (some (get rate-per-minute scooter-data))
        none
    )
)

(define-private (set-scooter-availability (scooter-id uint) (available bool))
    (match (map-get? scooter-rates { scooter-id: scooter-id })
        scooter-data
        (begin
            (map-set scooter-rates
                { scooter-id: scooter-id }
                (merge scooter-data { is-available: available })
            )
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

(define-private (record-completed-rental (scooter-id uint) (revenue uint))
    (ok true) ;; Simplified - just return ok
)

(define-private (update-user-stats (user principal) (rental-id uint) (amount uint))
    (match (map-get? user-rentals { user: user })
        user-data
        (map-set user-rentals
            { user: user }
            (merge user-data {
                total-rentals: (+ (get total-rentals user-data) u1),
                total-spent: (+ (get total-spent user-data) amount),
                last-rental: (some rental-id),
                active-rental-id: none
            })
        )
        (map-set user-rentals
            { user: user }
            {
                total-rentals: u1,
                active-rental-id: none,
                total-spent: amount,
                last-rental: (some rental-id)
            }
        )
    )
)

;; Read-Only Functions
(define-read-only (get-rental-info (rental-id uint))
    (map-get? rentals { rental-id: rental-id })
)

(define-read-only (get-user-rental-info (user principal))
    (map-get? user-rentals { user: user })
)

(define-read-only (get-scooter-rental-status (scooter-id uint))
    (map-get? scooter-rental-status { scooter-id: scooter-id })
)

(define-read-only (get-rental-payment-info (rental-id uint))
    (map-get? rental-payments { rental-id: rental-id })
)

(define-read-only (get-total-rentals)
    (var-get total-rentals)
)

(define-read-only (get-active-rentals)
    (var-get active-rentals)
)

(define-read-only (get-platform-revenue)
    (var-get platform-revenue)
)

(define-read-only (get-total-revenue)
    (var-get total-revenue)
)

(define-read-only (calculate-rental-quote (scooter-id uint) (duration uint))
    (match (get-scooter-rate scooter-id)
        rate
        (let
            (
                (rental-cost (calculate-rental-cost duration rate))
                (platform-fee (calculate-platform-fee rental-cost))
                (total-cost (+ rental-cost platform-fee SECURITY_DEPOSIT))
            )
            (ok {
                rental-cost: rental-cost,
                platform-fee: platform-fee,
                security-deposit: SECURITY_DEPOSIT,
                total-upfront: total-cost,
                refund-amount: SECURITY_DEPOSIT
            })
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

(define-read-only (is-user-renting (user principal))
    (match (map-get? user-rentals { user: user })
        user-data (is-some (get active-rental-id user-data))
        false
    )
)

(define-read-only (get-user-active-rental (user principal))
    (match (map-get? user-rentals { user: user })
        user-data (get active-rental-id user-data)
        none
    )
)

;; Public Functions - Scooter Management
(define-public (register-scooter-for-rental (scooter-id uint) (rate-per-minute uint) (operator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set scooter-rates
            { scooter-id: scooter-id }
            {
                rate-per-minute: rate-per-minute,
                is-available: true,
                operator: operator
            }
        )
        (ok true)
    )
)

(define-public (update-scooter-rate-rental (scooter-id uint) (new-rate uint))
    (match (map-get? scooter-rates { scooter-id: scooter-id })
        scooter-data
        (begin
            (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get operator scooter-data))) ERR_UNAUTHORIZED)
            (map-set scooter-rates
                { scooter-id: scooter-id }
                (merge scooter-data { rate-per-minute: new-rate })
            )
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

;; Public Functions - Rental Management
(define-public (start-rental (scooter-id uint) (duration uint))
    (let
        (
            (rental-id (var-get next-rental-id))
            (current-time stacks-block-height)
        )
        ;; Validations
        (asserts! (validate-rental-duration duration) ERR_INVALID_DURATION)
        (asserts! (get-scooter-availability scooter-id) ERR_SCOOTER_NOT_AVAILABLE)
        (asserts! (not (is-user-renting tx-sender)) ERR_RENTAL_ALREADY_ACTIVE)
        
        ;; Get scooter rate
        (match (get-scooter-rate scooter-id)
            rate
            (let
                (
                    (rental-cost (calculate-rental-cost duration rate))
                    (platform-fee (calculate-platform-fee rental-cost))
                    (total-payment (+ rental-cost platform-fee SECURITY_DEPOSIT))
                )
                ;; Check user balance
                (asserts! (>= (stx-get-balance tx-sender) total-payment) ERR_INSUFFICIENT_BALANCE)
                
                ;; Transfer payment to contract
                (match (stx-transfer? total-payment tx-sender (as-contract tx-sender))
                    success-value (begin
                        ;; Create rental record
                        (map-set rentals
                            { rental-id: rental-id }
                            {
                                scooter-id: scooter-id,
                                renter: tx-sender,
                                start-time: current-time,
                                planned-duration: duration,
                                actual-duration: none,
                                rate-per-minute: rate,
                                security-deposit: SECURITY_DEPOSIT,
                                total-cost: none,
                                platform-fee: (some platform-fee),
                                is-active: true,
                                end-time: none,
                                payment-status: "paid"
                            }
                        )
                        
                        ;; Update scooter rental status
                        (map-set scooter-rental-status
                            { scooter-id: scooter-id }
                            {
                                is-rented: true,
                                current-rental-id: (some rental-id),
                                renter: (some tx-sender),
                                rental-start: (some current-time)
                            }
                        )
                        
                        ;; Update user rental status
                        (match (map-get? user-rentals { user: tx-sender })
                            user-data
                            (map-set user-rentals
                                { user: tx-sender }
                                (merge user-data {
                                    active-rental-id: (some rental-id)
                                })
                            )
                            (map-set user-rentals
                                { user: tx-sender }
                                {
                                    total-rentals: u0,
                                    active-rental-id: (some rental-id),
                                    total-spent: u0,
                                    last-rental: none
                                }
                            )
                        )
                        
                        ;; Record payment details
                        (map-set rental-payments
                            { rental-id: rental-id }
                            {
                                deposit-paid: SECURITY_DEPOSIT,
                                rental-fee: rental-cost,
                                platform-fee: platform-fee,
                                refund-amount: u0,
                                payment-block: current-time
                            }
                        )
                        
                        ;; Set scooter as unavailable
                        (try! (set-scooter-availability scooter-id false))
                        
                        ;; Update counters
                        (var-set next-rental-id (+ rental-id u1))
                        (var-set total-rentals (+ (var-get total-rentals) u1))
                        (var-set active-rentals (+ (var-get active-rentals) u1))
                        
                        (ok rental-id)
                    )
                    error-value ERR_PAYMENT_FAILED
                )
            )
            ERR_SCOOTER_NOT_FOUND
        )
    )
)

(define-public (end-rental (rental-id uint))
    (match (map-get? rentals { rental-id: rental-id })
        rental-data
        (begin
            ;; Validations
            (asserts! (is-eq tx-sender (get renter rental-data)) ERR_NOT_RENTER)
            (asserts! (get is-active rental-data) ERR_RENTAL_NOT_FOUND)
            
            (let
                (
                    (current-time stacks-block-height)
                    (start-time (get start-time rental-data))
                    (actual-duration (- current-time start-time))
                    (rate (get rate-per-minute rental-data))
                    (actual-cost (calculate-rental-cost actual-duration rate))
                    (platform-fee (calculate-platform-fee actual-cost))
                    (total-cost (+ actual-cost platform-fee))
                    (refund-amount (- SECURITY_DEPOSIT 
                                     (if (> total-cost (get security-deposit rental-data))
                                         u0
                                         (- (get security-deposit rental-data) total-cost))))
                    (scooter-id (get scooter-id rental-data))
                )
                
                ;; Update rental record
                (map-set rentals
                    { rental-id: rental-id }
                    (merge rental-data {
                        actual-duration: (some actual-duration),
                        total-cost: (some total-cost),
                        end-time: (some current-time),
                        is-active: false,
                        payment-status: "completed"
                    })
                )
                
                ;; Update scooter rental status
                (map-set scooter-rental-status
                    { scooter-id: scooter-id }
                    {
                        is-rented: false,
                        current-rental-id: none,
                        renter: none,
                        rental-start: none
                    }
                )
                
                ;; Update payment record
                (match (map-get? rental-payments { rental-id: rental-id })
                    payment-data
                    (map-set rental-payments
                        { rental-id: rental-id }
                        (merge payment-data {
                            refund-amount: refund-amount
                        })
                    )
                    false
                )
                
                ;; Process refund if applicable
                (if (> refund-amount u0)
                    (match (as-contract (stx-transfer? refund-amount tx-sender (get renter rental-data)))
                        success-value true
                        error-value false
                    )
                    true
                )
                
                ;; Update user stats
                (update-user-stats tx-sender rental-id total-cost)
                
                ;; Set scooter as available
                (try! (set-scooter-availability scooter-id true))
                
                ;; Update global stats
                (var-set active-rentals (- (var-get active-rentals) u1))
                (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
                (var-set total-revenue (+ (var-get total-revenue) total-cost))
                
                (ok {
                    actual-duration: actual-duration,
                    total-cost: total-cost,
                    refund-amount: refund-amount
                })
            )
        )
        ERR_RENTAL_NOT_FOUND
    )
)

;; Emergency function to force end rental (contract owner only)
(define-public (force-end-rental (rental-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (match (map-get? rentals { rental-id: rental-id })
            rental-data
            (if (get is-active rental-data)
                (end-rental rental-id)
                ERR_RENTAL_NOT_FOUND
            )
            ERR_RENTAL_NOT_FOUND
        )
    )
)

;; Platform revenue withdrawal (contract owner only)
(define-public (withdraw-platform-revenue (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= amount (var-get platform-revenue)) ERR_INVALID_AMOUNT)
        (match (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))
            success-value (begin
                (var-set platform-revenue (- (var-get platform-revenue) amount))
                (ok amount)
            )
            error-value ERR_PAYMENT_FAILED
        )
    )
)
