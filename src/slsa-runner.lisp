;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/slsa-runner — slsa-verifier wrapper with org.cispec-aware output

(in-package #:cimatrix/slsa-runner)

(defparameter *slsa-verifier-binary* "slsa-verifier"
  "slsa-verifier binary name; resolved via PATH at runtime.")

(defun slsa-verifier-available-p ()
  (zerop (nth-value 2 (uiop:run-program
                       (list "which" *slsa-verifier-binary*)
                       :ignore-error-status t
                       :output nil
                       :error-output nil))))

(defun run-slsa-verifier (artefact-path provenance-path source-uri
                          &key builder-id)
  "Run slsa-verifier verify-artifact on ARTEFACT-PATH.
   Returns (values exit-code output)."
  (unless (slsa-verifier-available-p)
    (error "slsa-verifier not found on PATH"))
  (let ((args (list *slsa-verifier-binary*
                    "verify-artifact"
                    (namestring artefact-path)
                    "--provenance-path" (namestring provenance-path)
                    "--source-uri"      source-uri)))
    (when builder-id
      (setf args (append args (list "--builder-id" builder-id))))
    (multiple-value-bind (output error-output exit-code)
        (uiop:run-program args
                          :output '(:string :stripped t)
                          :error-output '(:string :stripped t)
                          :ignore-error-status t)
      (values exit-code (str:concat output error-output)))))

(defun verify-slsa (artefact-path provenance-path source-uri
                    &key builder-id)
  "Verify SLSA provenance for ARTEFACT-PATH.
   Returns a report plist: (:pass BOOL :violations LIST :warnings LIST :artefact PATH)."
  (multiple-value-bind (exit-code output)
      (run-slsa-verifier artefact-path provenance-path source-uri
                         :builder-id builder-id)
    (let ((pass (zerop exit-code)))
      (list :pass       pass
            :violations (if pass
                            nil
                            (list (format nil "slsa-verifier: ~A" output)))
            :warnings   nil
            :artefact   artefact-path
            :source-uri source-uri))))
