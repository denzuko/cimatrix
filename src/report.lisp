;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/report — report formatting and SARIF output

(in-package #:cimatrix/report)

;;; ANSI codes — omitted when not a TTY
(defun tty-p () (uiop:getenv "TERM"))
(defun green  (s) (if (tty-p) (format nil "~C[32m~A~C[0m" #\Escape s #\Escape) s))
(defun red    (s) (if (tty-p) (format nil "~C[31m~A~C[0m" #\Escape s #\Escape) s))
(defun yellow (s) (if (tty-p) (format nil "~C[33m~A~C[0m" #\Escape s #\Escape) s))

(defun make-report (&key pass violations warnings labels gate artefact source-uri)
  "Construct a normalised report plist."
  (list :pass       pass
        :violations (or violations '())
        :warnings   (or warnings   '())
        :labels     (or labels     '())
        :gate       gate
        :artefact   artefact
        :source-uri source-uri))

;;; ----------------------------------------------------------------
;;; Terminal output
;;; ----------------------------------------------------------------

(defun print-labels (labels)
  (dolist (pair labels)
    (format t "  ~A ~A=~A~%"
            (green "✓")
            (car pair)
            (cdr pair))))

(defun print-violations (violations)
  (dolist (v violations)
    (format t "  ~A ~A~%" (red "✗") v)))

(defun print-warnings (warnings)
  (dolist (w warnings)
    (format t "  ~A ~A~%" (yellow "⚠") w)))

(defun print-report (report &key (stream *standard-output*))
  "Print a human-readable conformance report to STREAM."
  (let ((*standard-output* stream))
    (when (getf report :labels)
      (print-labels (getf report :labels)))
    (when (getf report :violations)
      (print-violations (getf report :violations)))
    (when (getf report :warnings)
      (print-warnings (getf report :warnings)))
    (let ((vcount (length (getf report :violations)))
          (wcount (length (getf report :warnings))))
      (if (getf report :pass)
          (format t "~%~A: Verified conformance (~D label~:P found, ~D warning~:P)~%"
                  (green "PASS")
                  (length (getf report :labels))
                  wcount)
          (format t "~%~A: ~D violation~:P~%"
                  (red "FAIL")
                  vcount)))))

;;; ----------------------------------------------------------------
;;; SARIF 2.1.0 output
;;; ----------------------------------------------------------------

(defun report->sarif (report tool-name tool-version)
  "Convert REPORT to a SARIF 2.1.0 JSON string."
  (let* ((results
           (append
            (mapcar (lambda (v)
                      `(("ruleId" . "CISPEC001")
                        ("level"  . "error")
                        ("message" . (("text" . ,v)))))
                    (getf report :violations))
            (mapcar (lambda (w)
                      `(("ruleId" . "CISPEC002")
                        ("level"  . "warning")
                        ("message" . (("text" . ,w)))))
                    (getf report :warnings))))
         (sarif
           `(("version" . "2.1.0")
             ("$schema" . "https://json.schemastore.org/sarif-2.1.0.json")
             ("runs" .
              #((("tool" .
                  (("driver" .
                    (("name"            . ,tool-name)
                     ("version"         . ,tool-version)
                     ("informationUri"  . "https://cispec.org/tools/")
                     ("rules" .
                      #((("id" . "CISPEC001")
                         ("name" . "AttributionViolation")
                         ("shortDescription" .
                          (("text" . "org.cispec required label missing or invalid"))))
                        (("id" . "CISPEC002")
                         ("name" . "AttributionAdvisory")
                         ("shortDescription" .
                          (("text" . "org.cispec recommended label absent"))))))))))
                 ("results" . ,(coerce results 'vector))))))))
    (jonathan:to-json sarif)))

(defun exit-code (report)
  "Return process exit code: 0 = pass, 1 = violations, 2 = tool error."
  (if (getf report :pass) 0 1))
