;;;; SPDX-License-Identifier: BSD-2-Clause
;;;;
;;;; cimatrix.asd — ASDF system definition
;;;; org.cispec validation toolkit
;;;; Canonical spec: https://cispec.org/
;;;; IANA PEN: 42387

(asdf:defsystem "cimatrix"
  :description "org.cispec Change Item attribution validation toolkit"
  :version "0.1.0"
  :author "Dwight Spencer <FC13F74B@cispec.org>"
  :licence "BSD-2-Clause"
  :homepage "https://cispec.org/tools/"
  :source-control (:git "https://github.com/denzuko/cimatrix")

  :depends-on ("uiop"
               "adopt"
               "str"
               "cl-ppcre"
               "jonathan"
               "org.shirakumo.verbose")

  :components ((:module "src"
                :serial t
                :components
                ((:file "package")
                 (:file "matrix-id")
                 (:file "strings-extract")
                 (:file "gate-runner")
                 (:file "slsa-runner")
                 (:file "cache")
                 (:file "report")
                 (:file "cli"))))

  :build-operation "program-op"
  :build-pathname "cimatrix"
  :entry-point "cimatrix/cli:main")
