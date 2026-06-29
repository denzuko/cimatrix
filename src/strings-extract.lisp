;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/strings-extract — extract org.cispec.* strings from binaries

(in-package #:cimatrix/strings-extract)

(defparameter *required-keys*
  '("org.cispec.organization"
    "org.cispec.orgunit"
    "org.cispec.application"
    "org.cispec.version")
  "Label keys required for Declared conformance.")

(defparameter *slug-re*
  "^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$"
  "Slug pattern: lower-case alphanumeric and hyphens.")

(defparameter *semver-re*
  "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
  "Semver 2.0 pattern.")

(defparameter *slug-keys*
  '("org.cispec.organization"
    "org.cispec.orgunit"
    "org.cispec.role"
    "org.cispec.environment")
  "Keys whose values must match *slug-re*.")

;;; ----------------------------------------------------------------
;;; strings(1) invocation
;;; ----------------------------------------------------------------

(defun strings-binary (path &key (min-length 8))
  "Run strings(1) on PATH and return a list of string lines.
   MIN-LENGTH filters out short strings (default 8, matching strings(1) default)."
  (let ((args (list "strings" (format nil "-n~D" min-length) path)))
    (multiple-value-bind (output error-output exit-code)
        (uiop:run-program args
                          :output '(:string :stripped t)
                          :error-output '(:string :stripped t)
                          :ignore-error-status t)
      (declare (ignore error-output))
      (when (/= exit-code 0)
        (error "strings(1) failed on ~A (exit ~D)" path exit-code))
      (str:split #\newline output :omit-nulls t))))

;;; ----------------------------------------------------------------
;;; Label pair extraction
;;; ----------------------------------------------------------------

(defun parse-label-pair (line)
  "If LINE matches 'org.cispec.<key>=<value>', return (key . value). Else NIL."
  (cl-ppcre:register-groups-bind (key value)
      ("^(org\\.cispec\\.[a-z.]+)=(.+)$" line)
    (cons key value)))

(defun extract-cispec-strings (path)
  "Return an alist of (key . value) pairs extracted from the binary at PATH."
  (let ((lines (strings-binary path)))
    (remove nil (mapcar #'parse-label-pair lines))))

;;; ----------------------------------------------------------------
;;; Verification
;;; ----------------------------------------------------------------

(defun verify-binary (path)
  "Verify org.cispec Declared conformance of the binary at PATH.
   Returns a REPORT plist: (:pass BOOL :violations LIST :warnings LIST :labels ALIST)."
  (let* ((labels    (extract-cispec-strings path))
         (label-map (alexandria:alist-hash-table labels :test #'equal))
         (violations '())
         (warnings   '()))

    ;; Required key presence
    (dolist (key *required-keys*)
      (let ((val (gethash key label-map)))
        (cond
          ((null val)
           (push (format nil "missing required label: ~A" key) violations))
          ((string= val "")
           (push (format nil "required label is empty: ~A" key) violations)))))

    ;; Slug validation
    (dolist (key *slug-keys*)
      (let ((val (gethash key label-map)))
        (when (and val (plusp (length val))
                   (not (cl-ppcre:scan *slug-re* val)))
          (push (format nil "~A value ~S is not a valid slug" key val)
                violations))))

    ;; Semver validation
    (let ((ver (gethash "org.cispec.version" label-map)))
      (when (and ver (plusp (length ver))
                 (not (cl-ppcre:scan *semver-re* ver)))
        (push (format nil "org.cispec.version value ~S is not valid semver 2.0" ver)
              violations)))

    ;; OID root check
    (let ((oid (gethash "org.cispec.oid" label-map)))
      (cond
        ((null oid)
         (push "recommended label org.cispec.oid is absent" warnings))
        ((not (str:starts-with? "iso.org.dod.internet.42387" oid))
         (push (format nil "org.cispec.oid ~S must be rooted at iso.org.dod.internet.42387" oid)
               violations))))

    ;; specversion advisory
    (unless (gethash "org.cispec.specversion" label-map)
      (push "org.cispec.specversion is absent; add to record the spec version validated against"
            warnings))

    (list :pass (null violations)
          :violations (nreverse violations)
          :warnings   (nreverse warnings)
          :labels     labels)))
