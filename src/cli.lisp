;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/cli — command-line interface (adopt)

(in-package #:cimatrix/cli)

;;; ----------------------------------------------------------------
;;; Option definitions
;;; ----------------------------------------------------------------

(adopt:define-string *help-text*
  "cimatrix — org.cispec Change Item attribution validator~2%~
   Usage:~%~
     cimatrix verify-binary <binary>~%~
     cimatrix verify-gate   <gate.rego> [--input <file>] [--offline]~%~
     cimatrix verify-slsa   <artefact> <provenance.jsonl> --source-uri <uri>~2%~
   Exit codes:~%~
     0  Verified conformance~%~
     1  Violations found~%~
     2  Tool error~2%~
   Canonical spec: https://cispec.org/~%~
   IANA PEN: 42387  SPDX: BSD-2-Clause")

(defparameter *opt-input*
  (adopt:make-option 'input
    :long "input"
    :parameter "FILE"
    :help "JSON input file for gate evaluation"
    :initial-value nil))

(defparameter *opt-offline*
  (adopt:make-option 'offline
    :long "offline"
    :help "Use cached gate bundle; skip remote pull"
    :reduce #'adopt:last))

(defparameter *opt-source-uri*
  (adopt:make-option 'source-uri
    :long "source-uri"
    :parameter "URI"
    :help "Source repository URI for SLSA verification (e.g. github.com/org/repo)"
    :initial-value nil))

(defparameter *opt-builder-id*
  (adopt:make-option 'builder-id
    :long "builder-id"
    :parameter "URI"
    :help "SLSA builder ID URI (optional)"
    :initial-value nil))

(defparameter *opt-sarif*
  (adopt:make-option 'sarif
    :long "sarif"
    :parameter "FILE"
    :help "Write SARIF 2.1.0 output to FILE"
    :initial-value nil))

(defparameter *opt-help*
  (adopt:make-option 'help
    :short #\h
    :long "help"
    :help "Show this help and exit"
    :reduce #'adopt:last))

;;; ----------------------------------------------------------------
;;; UI / top-level interface
;;; ----------------------------------------------------------------

(defparameter *ui*
  (adopt:make-interface
    :name        "cimatrix"
    :summary     "org.cispec Change Item attribution validator"
    :usage       "<subcommand> [options]"
    :help        *help-text*
    :contents    (list *opt-help* *opt-sarif*)))

;;; ----------------------------------------------------------------
;;; SARIF write helper
;;; ----------------------------------------------------------------

(defun maybe-write-sarif (report sarif-path)
  (when sarif-path
    (with-open-file (f sarif-path
                       :direction :output
                       :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string
       (cimatrix/report:report->sarif report "cimatrix" "0.1.0")
       f))
    (format t "SARIF report written to ~A~%" sarif-path)))

;;; ----------------------------------------------------------------
;;; Subcommand dispatch
;;; ----------------------------------------------------------------

(defun cmd-verify-binary (args opts)
  (unless args
    (format *error-output* "Usage: cimatrix verify-binary <binary>~%")
    (uiop:quit 2))
  (let* ((path   (car args))
         (result (cimatrix/strings-extract:verify-binary path))
         (report (cimatrix/report:make-report
                   :pass       (getf result :pass)
                   :violations (getf result :violations)
                   :warnings   (getf result :warnings)
                   :labels     (getf result :labels)
                   :artefact   path)))
    (cimatrix/report:print-report report)
    (maybe-write-sarif report (gethash 'sarif opts))
    (uiop:quit (cimatrix/report:exit-code report))))

(defun cmd-verify-gate (args opts)
  (unless args
    (format *error-output* "Usage: cimatrix verify-gate <gate.rego> [--input FILE]~%")
    (uiop:quit 2))
  (let* ((gate-path  (car args))
         (input-path (gethash 'input opts))
         (offline    (gethash 'offline opts))
         (result     (cimatrix/gate-runner:verify-gate
                       gate-path
                       :input-path input-path
                       :offline    offline))
         (report     (cimatrix/report:make-report
                       :pass       (getf result :pass)
                       :violations (getf result :violations)
                       :warnings   (getf result :warnings)
                       :gate       gate-path)))
    (cimatrix/report:print-report report)
    (maybe-write-sarif report (gethash 'sarif opts))
    (uiop:quit (cimatrix/report:exit-code report))))

(defun cmd-verify-slsa (args opts)
  (unless (>= (length args) 2)
    (format *error-output*
            "Usage: cimatrix verify-slsa <artefact> <provenance.jsonl> --source-uri <uri>~%")
    (uiop:quit 2))
  (let* ((artefact-path   (first args))
         (provenance-path (second args))
         (source-uri      (gethash 'source-uri opts))
         (builder-id      (gethash 'builder-id opts)))
    (unless source-uri
      (format *error-output* "error: --source-uri is required for verify-slsa~%")
      (uiop:quit 2))
    (let* ((result (cimatrix/slsa-runner:verify-slsa
                     artefact-path
                     provenance-path
                     source-uri
                     :builder-id builder-id))
           (report (cimatrix/report:make-report
                     :pass       (getf result :pass)
                     :violations (getf result :violations)
                     :warnings   (getf result :warnings)
                     :artefact   artefact-path
                     :source-uri source-uri)))
      (cimatrix/report:print-report report)
      (maybe-write-sarif report (gethash 'sarif opts))
      (uiop:quit (cimatrix/report:exit-code report)))))

;;; ----------------------------------------------------------------
;;; main
;;; ----------------------------------------------------------------

(defun main ()
  ;; Print our own attribution to stderr for traceability
  (format *error-output*
          "cimatrix ~A (org.cispec/~A) https://cispec.org/~%"
          cimatrix/matrix-id:+version+
          cimatrix/matrix-id:+specversion+)

  (multiple-value-bind (args opts)
      (handler-case (adopt:parse-options *ui*)
        (adopt:unrecognized-option (c)
          (format *error-output* "error: ~A~%" c)
          (uiop:quit 2)))

    (when (gethash 'help opts)
      (adopt:print-help-and-exit *ui*))

    (let ((subcommand (car args))
          (rest-args  (cdr args)))
      (cond
        ((string= subcommand "verify-binary") (cmd-verify-binary rest-args opts))
        ((string= subcommand "verify-gate")   (cmd-verify-gate   rest-args opts))
        ((string= subcommand "verify-slsa")   (cmd-verify-slsa   rest-args opts))
        (t
         (format *error-output*
                 "error: unknown subcommand ~S~%~%~A~%"
                 subcommand
                 "Subcommands: verify-binary  verify-gate  verify-slsa")
         (uiop:quit 2))))))
