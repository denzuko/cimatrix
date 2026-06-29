;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix — package declarations

(defpackage #:cimatrix/matrix-id
  (:use #:cl)
  (:export #:+organization+
           #:+orgunit+
           #:+application+
           #:+version+
           #:+oid+
           #:+specversion+
           #:label-set))

(defpackage #:cimatrix/strings-extract
  (:use #:cl)
  (:export #:extract-cispec-strings
           #:strings-binary
           #:parse-label-pair
           #:verify-binary))

(defpackage #:cimatrix/gate-runner
  (:use #:cl)
  (:export #:verify-gate
           #:run-opa
           #:pull-gate-bundle
           #:gate-bundle-path))

(defpackage #:cimatrix/slsa-runner
  (:use #:cl)
  (:export #:verify-slsa
           #:run-slsa-verifier))

(defpackage #:cimatrix/cache
  (:use #:cl)
  (:export #:cache-dir
           #:cached-gate-path
           #:pull-gates
           #:gates-stale-p))

(defpackage #:cimatrix/report
  (:use #:cl)
  (:export #:make-report
           #:report-pass
           #:report-fail
           #:report-warn
           #:print-report
           #:report->sarif
           #:exit-code))

(defpackage #:cimatrix/cli
  (:use #:cl
        #:cimatrix/strings-extract
        #:cimatrix/gate-runner
        #:cimatrix/slsa-runner
        #:cimatrix/report)
  (:export #:main))
