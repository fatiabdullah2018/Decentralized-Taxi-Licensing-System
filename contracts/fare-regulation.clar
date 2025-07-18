;; Fare Regulation Contract
;; Enforces municipal pricing guidelines and manages fare calculations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-INPUT (err u301))
(define-constant ERR-FARE-DISPUTE-EXISTS (err u302))
(define-constant ERR-DISPUTE-NOT-FOUND (err u303))
(define-constant ERR-INVALID-ZONE (err u304))

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var admin principal CONTRACT-OWNER)
(define-data-var base-fare uint u250) ;; $2.50 in cents
(define-data-var per-mile-rate uint u180) ;; $1.80 per mile in cents
(define-data-var per-minute-rate uint u35) ;; $0.35 per minute in cents
(define-data-var surge-multiplier uint u100) ;; 1.0x (100 = 1.0)
(define-data-var max-surge-multiplier uint u300) ;; 3.0x maximum

;; Data Maps
(define-map fare-zones
  { zone-id: uint }
  {
    name: (string-ascii 50),
    base-multiplier: uint, ;; 100 = 1.0x
    active: bool
  }
)

(define-map fare-disputes
  { dispute-id: uint }
  {
    passenger: principal,
    driver: principal,
    trip-id: (string-ascii 50),
    disputed-amount: uint,
    claimed-amount: uint,
    reason: (string-ascii 200),
    status: (string-ascii 20),
    created-date: uint,
    resolved-date: uint
  }
)

(define-map trip-fares
  { trip-id: (string-ascii 50) }
  {
    driver: principal,
    passenger: principal,
    base-fare: uint,
    distance-fare: uint,
    time-fare: uint,
    surge-multiplier: uint,
    zone-multiplier: uint,
    total-fare: uint,
    timestamp: uint
  }
)

(define-data-var dispute-counter uint u0)

;; Public Functions

;; Calculate fare for a trip
(define-public (calculate-fare (distance-miles uint) (time-minutes uint) (zone-id uint))
  (let (
    (zone-data (unwrap! (map-get? fare-zones { zone-id: zone-id }) ERR-INVALID-ZONE))
    (current-base-fare (var-get base-fare))
    (current-per-mile (var-get per-mile-rate))
    (current-per-minute (var-get per-minute-rate))
    (current-surge (var-get surge-multiplier))
    (zone-multiplier (get base-multiplier zone-data))
  )
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (get active zone-data) ERR-INVALID-ZONE)

    (let (
      (distance-fare (* distance-miles current-per-mile))
      (time-fare (* time-minutes current-per-minute))
      (subtotal (+ current-base-fare (+ distance-fare time-fare)))
      (surge-adjusted (* subtotal current-surge))
      (zone-adjusted (* surge-adjusted zone-multiplier))
      (final-fare (/ (/ zone-adjusted u100) u100)) ;; Adjust for multipliers
    )
      (ok {
        base-fare: current-base-fare,
        distance-fare: distance-fare,
        time-fare: time-fare,
        surge-multiplier: current-surge,
        zone-multiplier: zone-multiplier,
        total-fare: final-fare
      })
    )
  )
)

;; Record completed trip fare
(define-public (record-trip-fare
  (trip-id (string-ascii 50))
  (passenger principal)
  (distance-miles uint)
  (time-minutes uint)
  (zone-id uint))
  (let ((fare-calculation (unwrap! (calculate-fare distance-miles time-minutes zone-id) ERR-INVALID-INPUT)))
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)

    (map-set trip-fares
      { trip-id: trip-id }
      {
        driver: tx-sender,
        passenger: passenger,
        base-fare: (get base-fare fare-calculation),
        distance-fare: (get distance-fare fare-calculation),
        time-fare: (get time-fare fare-calculation),
        surge-multiplier: (get surge-multiplier fare-calculation),
        zone-multiplier: (get zone-multiplier fare-calculation),
        total-fare: (get total-fare fare-calculation),
        timestamp: block-height
      }
    )

    (ok (get total-fare fare-calculation))
  )
)

;; Create fare dispute
(define-public (create-fare-dispute
  (trip-id (string-ascii 50))
  (driver principal)
  (disputed-amount uint)
  (claimed-amount uint)
  (reason (string-ascii 200)))
  (let ((current-dispute-id (var-get dispute-counter)))
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? trip-fares { trip-id: trip-id })) ERR-INVALID-INPUT)

    (map-set fare-disputes
      { dispute-id: current-dispute-id }
      {
        passenger: tx-sender,
        driver: driver,
        trip-id: trip-id,
        disputed-amount: disputed-amount,
        claimed-amount: claimed-amount,
        reason: reason,
        status: "pending",
        created-date: block-height,
        resolved-date: u0
      }
    )

    (var-set dispute-counter (+ current-dispute-id u1))
    (ok current-dispute-id)
  )
)

;; Resolve fare dispute (admin only)
(define-public (resolve-dispute (dispute-id uint) (resolution (string-ascii 20)) (final-amount uint))
  (let ((dispute-data (unwrap! (map-get? fare-disputes { dispute-id: dispute-id }) ERR-DISPUTE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status dispute-data) "pending") ERR-INVALID-INPUT)

    (map-set fare-disputes
      { dispute-id: dispute-id }
      (merge dispute-data {
        status: resolution,
        resolved-date: block-height
      })
    )

    (ok true)
  )
)

;; Set base fare (admin only)
(define-public (set-base-fare (new-base-fare uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-base-fare u100) (<= new-base-fare u1000)) ERR-INVALID-INPUT) ;; $1.00 - $10.00

    (var-set base-fare new-base-fare)
    (ok true)
  )
)

;; Set per-mile rate (admin only)
(define-public (set-per-mile-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-rate u50) (<= new-rate u500)) ERR-INVALID-INPUT) ;; $0.50 - $5.00

    (var-set per-mile-rate new-rate)
    (ok true)
  )
)

;; Set surge multiplier (admin only)
(define-public (set-surge-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-multiplier u100) (<= new-multiplier (var-get max-surge-multiplier))) ERR-INVALID-INPUT)

    (var-set surge-multiplier new-multiplier)
    (ok true)
  )
)

;; Create fare zone (admin only)
(define-public (create-fare-zone (zone-id uint) (name (string-ascii 50)) (base-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= base-multiplier u50) (<= base-multiplier u200)) ERR-INVALID-INPUT) ;; 0.5x - 2.0x

    (map-set fare-zones
      { zone-id: zone-id }
      {
        name: name,
        base-multiplier: base-multiplier,
        active: true
      }
    )

    (ok true)
  )
)

;; Toggle fare zone status (admin only)
(define-public (toggle-fare-zone (zone-id uint))
  (let ((zone-data (unwrap! (map-get? fare-zones { zone-id: zone-id }) ERR-INVALID-ZONE)))
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)

    (map-set fare-zones
      { zone-id: zone-id }
      (merge zone-data { active: (not (get active zone-data)) })
    )

    (ok true)
  )
)

;; Emergency pause (admin only)
(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; Read-only Functions

;; Get current fare rates
(define-read-only (get-fare-rates)
  {
    base-fare: (var-get base-fare),
    per-mile-rate: (var-get per-mile-rate),
    per-minute-rate: (var-get per-minute-rate),
    surge-multiplier: (var-get surge-multiplier),
    max-surge-multiplier: (var-get max-surge-multiplier)
  }
)

;; Get fare zone information
(define-read-only (get-fare-zone (zone-id uint))
  (map-get? fare-zones { zone-id: zone-id })
)

;; Get trip fare details
(define-read-only (get-trip-fare (trip-id (string-ascii 50)))
  (map-get? trip-fares { trip-id: trip-id })
)

;; Get dispute information
(define-read-only (get-dispute (dispute-id uint))
  (map-get? fare-disputes { dispute-id: dispute-id })
)

;; Estimate fare for planning
(define-read-only (estimate-fare (distance-miles uint) (time-minutes uint) (zone-id uint))
  (match (map-get? fare-zones { zone-id: zone-id })
    zone-data (if (get active zone-data)
      (let (
        (current-base-fare (var-get base-fare))
        (current-per-mile (var-get per-mile-rate))
        (current-per-minute (var-get per-minute-rate))
        (current-surge (var-get surge-multiplier))
        (zone-multiplier (get base-multiplier zone-data))
        (distance-fare (* distance-miles current-per-mile))
        (time-fare (* time-minutes current-per-minute))
        (subtotal (+ current-base-fare (+ distance-fare time-fare)))
        (surge-adjusted (* subtotal current-surge))
        (zone-adjusted (* surge-adjusted zone-multiplier))
        (final-fare (/ (/ zone-adjusted u100) u100))
      )
        (some final-fare)
      )
      none
    )
    none
  )
)

;; Get contract info
(define-read-only (get-contract-info)
  {
    paused: (var-get contract-paused),
    admin: (var-get admin),
    dispute-counter: (var-get dispute-counter)
  }
)
