;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/gate-runner — OPA/Rego gate runner

(in-package #:cimatrix/gate-runner)

(defparameter *opa-binary* "opa"
  "OPA binary name; resolved via PATH at runtime.")

(defparameter *deny-query* "data.%s.deny"
  "OPA query template. Package name is derived from the gate file's package declaration.")

;;; ----------------------------------------------------------------
;;; OPA presence check
;;; ----------------------------------------------------------------

(defun opa-available-p ()
  "Return T if opa(1) is on PATH."
  (zerop (nth-value 2 (uiop:run-program
                       (list "which" *opa-binary*)
                       :ignore-error-status t
                       :output nil
                       :error-output nil))))

;;; ----------------------------------------------------------------
;;; Package name extraction
;;; ----------------------------------------------------------------

(defun extract-package-name (gate-path)
  "Read the first 'package <name>' declaration from GATE-PATH."
  (with-open-file (f gate-path :direction :input)
    (loop for line = (read-line f nil nil)
          while line
          when (cl-ppcre:register-groups-bind (pkg)
                   ("^package\\s+(\\S+)" line)
                 pkg)
          return it)))

;;; ----------------------------------------------------------------
;;; opa check — syntax and import validation
;;; ----------------------------------------------------------------

(defun run-opa-check (gate-path)
  "Run 'opa check <gate-path>'. Returns (values exit-code output)."
  (multiple-value-bind (output error-output exit-code)
      (uiop:run-program (list *opa-binary* "check" (namestring gate-path))
                        :output '(:string :stripped t)
                        :error-output :output
                        :ignore-error-status t)
    (declare (ignore error-output))
    (values exit-code output)))

;;; ----------------------------------------------------------------
;;; opa eval — run the deny query against input
;;; ----------------------------------------------------------------

(defun run-opa (gate-path input-path)
  "Run the deny query for GATE-PATH against INPUT-PATH using OPA.
   Returns (values violations-list raw-output exit-code)."
  (unless (opa-available-p)
    (error "opa(1) not found on PATH; install OPA to use verify-gate"))
  (let* ((pkg   (extract-package-name gate-path))
         (query (format nil "data.~A.deny" pkg)))
    (multiple-value-bind (output error-output exit-code)
        (uiop:run-program
         (list *opa-binary* "eval"
               "--data"   (namestring gate-path)
               "--input"  (namestring input-path)
               "--format" "raw"
               query)
         :output '(:string :stripped t)
         :error-output '(:string :stripped t)
         :ignore-error-status t)
      (declare (ignore error-output))
      ;; OPA eval exits 0 even on deny; parse the output JSON array
      (let ((violations
              (handler-case
                  (let ((parsed (jonathan:parse output)))
                    ;; OPA returns: [[result]] or []
                    (if (and parsed (listp parsed) (listp (car parsed)))
                        (car parsed)
                        nil))
                (error () nil))))
        (values violations output exit-code)))))

;;; ----------------------------------------------------------------
;;; verify-gate — high-level entry point
;;; ----------------------------------------------------------------

(defun verify-gate (gate-path &key input-path offline)
  "Verify GATE-PATH against optional INPUT-PATH.
   Returns a report plist: (:pass BOOL :violations LIST :warnings LIST :gate PATH).
   OFFLINE skips the cache pull."
  (unless offline
    (cimatrix/cache:pull-gates))

  ;; opa check first
  (multiple-value-bind (check-exit check-output)
      (run-opa-check gate-path)
    (when (/= check-exit 0)
      (return-from verify-gate
        (list :pass nil
              :violations (list (format nil "opa check failed: ~A" check-output))
              :warnings   nil
              :gate       gate-path))))

  (if input-path
      ;; eval mode
      (multiple-value-bind (violations raw exit-code)
          (run-opa gate-path input-path)
        (declare (ignore raw exit-code))
        (list :pass       (null violations)
              :violations violations
              :warnings   nil
              :gate       gate-path))
      ;; syntax-only mode (no input)
      (list :pass       t
            :violations nil
            :warnings   (list "no --input provided; only syntax was verified")
            :gate       gate-path)))
