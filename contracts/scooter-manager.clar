;; ScootFi Scooter Manager Contract
;; Manages electric scooter registration, availability, and operator permissions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SCOOTER_NOT_FOUND (err u101))
(define-constant ERR_SCOOTER_ALREADY_EXISTS (err u102))
(define-constant ERR_SCOOTER_NOT_AVAILABLE (err u103))
(define-constant ERR_INVALID_RATE (err u104))
(define-constant ERR_INVALID_SCOOTER_ID (err u105))
(define-constant ERR_NOT_OPERATOR (err u106))
(define-constant MIN_RATE u1) ;; Minimum 1 microSTX per minute
(define-constant MAX_RATE u1000000) ;; Maximum 1 STX per minute

;; Data Variables
(define-data-var next-scooter-id uint u1001)
(define-data-var total-scooters uint u0)
(define-data-var active-scooters uint u0)

;; Data Maps
(define-map scooters
    { scooter-id: uint }
    {
        operator: principal,
        location: (string-ascii 100),
        rate-per-minute: uint,
        is-available: bool,
        is-active: bool,
        total-rentals: uint,
        total-revenue: uint,
        created-at: uint,
        last-updated: uint
    }
)

(define-map operators
    { operator: principal }
    {
        is-authorized: bool,
        scooter-count: uint,
        total-revenue: uint,
        registration-date: uint
    }
)

(define-map scooter-availability-log
    { scooter-id: uint, block-height: uint }
    {
        status: bool,
        updated-by: principal,
        timestamp: uint
    }
)

;; Authorization and Access Control
(define-read-only (is-contract-owner (caller principal))
    (is-eq caller CONTRACT_OWNER)
)

(define-read-only (is-authorized-operator (operator principal))
    (default-to false (get is-authorized (map-get? operators { operator: operator })))
)

(define-read-only (is-scooter-operator (scooter-id uint) (caller principal))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data (is-eq caller (get operator scooter-data))
        false
    )
)

;; Private Functions
(define-private (validate-rate (rate uint))
    (and (>= rate MIN_RATE) (<= rate MAX_RATE))
)

(define-private (update-operator-stats (operator principal) (revenue-increase uint))
    (match (map-get? operators { operator: operator })
        operator-data
        (map-set operators
            { operator: operator }
            (merge operator-data {
                total-revenue: (+ (get total-revenue operator-data) revenue-increase)
            })
        )
        false
    )
)

;; Read-Only Functions
(define-read-only (get-scooter-info (scooter-id uint))
    (map-get? scooters { scooter-id: scooter-id })
)

(define-read-only (get-operator-info (operator principal))
    (map-get? operators { operator: operator })
)

(define-read-only (get-total-scooters)
    (var-get total-scooters)
)

(define-read-only (get-active-scooters)
    (var-get active-scooters)
)

(define-read-only (get-next-scooter-id)
    (var-get next-scooter-id)
)

(define-read-only (is-scooter-available (scooter-id uint))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data
        (and (get is-available scooter-data) (get is-active scooter-data))
        false
    )
)

(define-read-only (get-scooter-rate (scooter-id uint))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data (some (get rate-per-minute scooter-data))
        none
    )
)

(define-read-only (get-availability-log (scooter-id uint) (height uint))
    (map-get? scooter-availability-log { scooter-id: scooter-id, block-height: height })
)

;; Public Functions - Operator Management
(define-public (register-operator (operator principal))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
        (map-set operators
            { operator: operator }
            {
                is-authorized: true,
                scooter-count: u0,
                total-revenue: u0,
                registration-date: stacks-block-height
            }
        )
        (ok true)
    )
)

(define-public (deauthorize-operator (operator principal))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
        (match (map-get? operators { operator: operator })
            operator-data
            (begin
                (map-set operators
                    { operator: operator }
                    (merge operator-data { is-authorized: false })
                )
                (ok true)
            )
            ERR_NOT_OPERATOR
        )
    )
)

;; Public Functions - Scooter Management
(define-public (register-scooter (location (string-ascii 100)) (rate-per-minute uint))
    (let
        (
            (scooter-id (var-get next-scooter-id))
            (current-time stacks-block-height)
        )
        (asserts! (is-authorized-operator tx-sender) ERR_UNAUTHORIZED)
        (asserts! (validate-rate rate-per-minute) ERR_INVALID_RATE)
        (asserts! (is-none (map-get? scooters { scooter-id: scooter-id })) ERR_SCOOTER_ALREADY_EXISTS)
        
        ;; Create scooter record
        (map-set scooters
            { scooter-id: scooter-id }
            {
                operator: tx-sender,
                location: location,
                rate-per-minute: rate-per-minute,
                is-available: true,
                is-active: true,
                total-rentals: u0,
                total-revenue: u0,
                created-at: current-time,
                last-updated: current-time
            }
        )
        
        ;; Log initial availability
        (map-set scooter-availability-log
            { scooter-id: scooter-id, block-height: current-time }
            {
                status: true,
                updated-by: tx-sender,
                timestamp: current-time
            }
        )
        
        ;; Update operator stats
        (match (map-get? operators { operator: tx-sender })
            operator-data
            (map-set operators
                { operator: tx-sender }
                (merge operator-data {
                    scooter-count: (+ (get scooter-count operator-data) u1)
                })
            )
            false
        )
        
        ;; Update global counters
        (var-set next-scooter-id (+ scooter-id u1))
        (var-set total-scooters (+ (var-get total-scooters) u1))
        (var-set active-scooters (+ (var-get active-scooters) u1))
        
        (ok scooter-id)
    )
)

(define-public (update-scooter-location (scooter-id uint) (new-location (string-ascii 100)))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data
        (begin
            (asserts! (is-scooter-operator scooter-id tx-sender) ERR_UNAUTHORIZED)
            (map-set scooters
                { scooter-id: scooter-id }
                (merge scooter-data {
                    location: new-location,
                    last-updated: stacks-block-height
                })
            )
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

(define-public (update-scooter-rate (scooter-id uint) (new-rate uint))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data
        (begin
            (asserts! (is-scooter-operator scooter-id tx-sender) ERR_UNAUTHORIZED)
            (asserts! (validate-rate new-rate) ERR_INVALID_RATE)
            (asserts! (get is-available scooter-data) ERR_SCOOTER_NOT_AVAILABLE)
            (map-set scooters
                { scooter-id: scooter-id }
                (merge scooter-data {
                    rate-per-minute: new-rate,
                    last-updated: stacks-block-height
                })
            )
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

(define-public (set-scooter-availability (scooter-id uint) (available bool))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data
        (begin
            (asserts! (is-scooter-operator scooter-id tx-sender) ERR_UNAUTHORIZED)
            (map-set scooters
                { scooter-id: scooter-id }
                (merge scooter-data {
                    is-available: available,
                    last-updated: stacks-block-height
                })
            )
            
            ;; Log availability change
            (map-set scooter-availability-log
            { scooter-id: scooter-id, block-height: stacks-block-height }
                {
                    status: available,
                    updated-by: tx-sender,
                    timestamp: stacks-block-height
                }
            )
            
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

(define-public (deactivate-scooter (scooter-id uint))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data
        (begin
            (asserts! (is-scooter-operator scooter-id tx-sender) ERR_UNAUTHORIZED)
            (map-set scooters
                { scooter-id: scooter-id }
                (merge scooter-data {
                    is-active: false,
                    is-available: false,
                    last-updated: stacks-block-height
                })
            )
            
            ;; Update active scooter count
            (if (get is-active scooter-data)
                (var-set active-scooters (- (var-get active-scooters) u1))
                true
            )
            
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)

;; Public Functions - Rental Integration
(define-public (record-rental-completion (scooter-id uint) (revenue uint))
    (match (map-get? scooters { scooter-id: scooter-id })
        scooter-data
        (begin
            ;; Update scooter stats
            (map-set scooters
                { scooter-id: scooter-id }
                (merge scooter-data {
                    total-rentals: (+ (get total-rentals scooter-data) u1),
                    total-revenue: (+ (get total-revenue scooter-data) revenue),
                    is-available: true,
                    last-updated: stacks-block-height
                })
            )
            
            ;; Update operator revenue
            (update-operator-stats (get operator scooter-data) revenue)
            
            (ok true)
        )
        ERR_SCOOTER_NOT_FOUND
    )
)
