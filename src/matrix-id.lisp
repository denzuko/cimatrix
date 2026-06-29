;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/matrix-id — org.cispec attribution for the cimatrix binary
;;;; Canonical spec: https://cispec.org/spec/matrix-id.lisp

(in-package #:cimatrix/matrix-id)

;;; cimatrix verifies org.cispec conformance in other artefacts.
;;; It must itself be conformant — verified by:
;;;   cimatrix verify-binary cimatrix

(defun env-or (var default)
  (let ((val (uiop:getenv var)))
    (if (and val (plusp (length val))) val default)))

(defconstant +organization+  (env-or "CISPEC_ORGANIZATION" "daplanet"))
(defconstant +orgunit+       (env-or "CISPEC_ORGUNIT"      "dps"))
(defconstant +application+   (env-or "CISPEC_APPLICATION"  "cimatrix"))
(defconstant +version+       (env-or "CISPEC_VERSION"      "0.1.0"))
(defconstant +oid+           "iso.org.dod.internet.42387")
(defconstant +specversion+   "1.0")

(defun label-set ()
  "Return alist of all org.cispec label pairs for this binary."
  (list (cons "org.cispec.organization" +organization+)
        (cons "org.cispec.orgunit"      +orgunit+)
        (cons "org.cispec.application"  +application+)
        (cons "org.cispec.version"      +version+)
        (cons "org.cispec.oid"          +oid+)
        (cons "org.cispec.specversion"  +specversion+)))
