;;;; SPDX-License-Identifier: BSD-2-Clause
;;;; cimatrix/cache — gate bundle cache (~/.cache/cimatrix/gates/)

(in-package #:cimatrix/cache)

(defparameter *gate-base-url* "https://cispec.org/gates/"
  "Canonical gate library URL.")

(defparameter *cache-ttl-seconds* (* 24 60 60)
  "Gate cache TTL: 24 hours.")

(defun cache-dir ()
  "Return the cimatrix cache directory, creating it if necessary."
  (let ((dir (merge-pathnames #p".cache/cimatrix/gates/"
                              (user-homedir-pathname))))
    (ensure-directories-exist dir)
    dir))

(defun cached-gate-path (gate-name)
  "Return the local cache path for GATE-NAME (e.g. \"cispec/attribution.rego\")."
  (merge-pathnames (pathname gate-name) (cache-dir)))

(defun gates-stale-p ()
  "Return T if the gate cache is older than *cache-ttl-seconds* or absent."
  (let ((stamp-file (merge-pathnames #p".last-pull" (cache-dir))))
    (if (probe-file stamp-file)
        (let* ((mtime (file-write-date stamp-file))
               (age   (- (get-universal-time) mtime)))
          (> age *cache-ttl-seconds*))
        t)))

(defun pull-gates (&key force)
  "Pull the gate bundle from *gate-base-url* into the cache directory.
   Skips the pull if the cache is fresh unless FORCE is true."
  (when (or force (gates-stale-p))
    (let ((gates '("cispec/attribution.rego"
                   "slsa/provenance.rego"
                   "c-quality/attribution.rego"
                   "sbom/cyclonedx.rego"
                   "containers/quadlet.rego"
                   "ast/forbidden-calls.rego")))
      (dolist (gate gates)
        (let* ((url    (str:concat *gate-base-url* gate))
               (target (cached-gate-path gate)))
          (ensure-directories-exist target)
          (uiop:run-program
           (list "curl" "-sLf" "-o" (namestring target) url)
           :ignore-error-status t))))
    ;; Touch the stamp file
    (with-open-file (f (merge-pathnames #p".last-pull" (cache-dir))
                       :direction :output
                       :if-exists :supersede)
      (write-string (format nil "~A" (get-universal-time)) f)))
  (cache-dir))
