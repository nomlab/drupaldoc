;;
;; emacs -Q -batch -l org-publish-all.el -f make-all
;;

;; setup load-path if you need to add some extra load-path
;; (setq load-path (cons "~/sys/lib/elisp/org-mode/lisp" load-path))

(require 'org)
(require 'ox-html)
(require 'font-lock)
(global-font-lock-mode 1)

(setq debug-on-error t)
(setq backup-inhibited t) ;; don't make *~
(setq make-backup-files nil)

(set-foreground-color "black")
(set-background-color "white")
(setq org-html-htmlize-output-type 'css)

;;;;;;;;;;;;;;;;
;;; babel

(setq org-link-search-must-match-exact-headline nil) ;; for #+INCLUDE:

(setq org-ditaa-jar-path (expand-file-name "./scripts/jditaa.jar"))
(setq org-babel-default-header-args:ditaa
      '(
        (:results . "file")
        (:exports . "results")
        (:java . "-Dfile.encoding=UTF-8 -Djava.awt.headless=true")))

(setq org-confirm-babel-evaluate nil)
(org-babel-do-load-languages
 'org-babel-load-languages
 '((R . t)
   (ditaa . t)
   (dot . t)
   (emacs-lisp . t)
   (gnuplot . t)
   (C . t)
   (haskell . t)
   (ocaml . nil)
   (python . t)
   (ruby . t)
   (screen . nil)
   (shell . t)
   (sql . nil)
   (sqlite . t)))

;;;;;;;;;;;;;;;;
;; exporter

(setq org-publish-timestamp-directory ".org-timestamps/")
(setq org-html-validation-link nil)
(setq org-export-coding-system 'utf-8)
(setq org-export-default-language "ja")
(setq org-export-dictionary
      '(("Author")
        ("Date")
        ("Equation")
        ("Figure")
        ("Footnotes")
        ("List of Listings")
        ("List of Tables")
        ("Listing %d:")
        ("Listing %d: %s")
        ("See section %s")
        ("Table %d:")
        ("Table %d: %s")
        ("Table of Contents")
        ("Unknown reference")))

(eval-after-load 'org
  '(progn
     (setq org-emphasis-regexp-components
           (list
            ;; pre-match
            (concat (nth 0 org-emphasis-regexp-components) "　，（")
            ;; post-match
            (concat (nth 1 org-emphasis-regexp-components) "　．，）")
            ;; border
            (nth 2 org-emphasis-regexp-components)
            ;; body-regexp
            (nth 3 org-emphasis-regexp-components)
            ;; newline
            (nth 4 org-emphasis-regexp-components)))
     (org-set-emph-re 'org-emphasis-regexp-components org-emphasis-regexp-components)))

(setq sh-make-vars-local nil)

(defun orglue-update-publish-project-alist (project-alist-var projects)
  (let ((project-names (mapcar 'car projects))
        (project-alist (symbol-value project-alist-var)))
    ;; remove old projects from project-alist
    (mapc
     (lambda (prj)
       (setq project-alist
             (delete (assoc prj project-alist) project-alist)))
     project-names)
    ;; add new projects to project-alist
    (set project-alist-var (append projects project-alist))))

(defun orglue-publish-setup-current-project (&optional top-directory html-directory)
  "+ Set standard directory layout for a project ::
  + org/       ... project top
    + *.org    ... org files
    + dat/     ... static attachments linked from *.org
    + dyn/     ... dinamically generated files from *.org
    + pub/     ... files only needed on publish
      + css/   ... style sheets
      + top/   ... top-level dot files such as .htaccess
    + options/ ... org-mode options (not copied on publishing)
  + html/      ... destination to publish

+ oprations to publish ::
  1) find-file TOP/org/index.org
  2) M-x orglue-publish-setup-current-project to register the TOP.
  3) C-c C-e P p to publish files to TOP/html/

+ Note ::
  All org/*.org files will be converted into html/*.html files.
  this is a non-recursive operation due to the css linking problem.
  http://orgmode.org/worg/org-tutorials/org-publish-html-tutorial.html

  All other files in org/ will be copied into html/ preserving
  their relaive positons in the directory tree.

  Directories named ``attic'' will be ignored.

  You must make the necessary directories beforehand.

+ Clean up your published files ::

  Since every file in html/ can be reproduced from the other files,
  you can clean up html/ like:
  : rm -rf html ; mkdir html

  In addition, in case their cache files seem to be harmful:
  : rm -f  ~/.org-timestamps
"
  (interactive)
  (let* ((src (directory-file-name (or top-directory default-directory)))
         (top (directory-file-name (file-name-directory src)))
         (dst (or (expand-file-name html-directory) (expand-file-name "html" top))))
    ;; current-file: /foo/project/org/index.org
    ;;   top => /foo/project
    ;;   src => /foo/project/org
    ;;   dst => /foo/project/html
    (orglue-update-publish-project-alist
     'org-publish-project-alist
     `(
       ("current" :components
        ("current-org" "current-static" "current-static-top")
        )
       ("current-org" ;; SRC/*.org -> DST/
        :base-directory ,src
        :base-extension "org"
        :publishing-directory ,dst
        :recursive t
        :publishing-function org-html-publish-to-html
        :html-html5-fancy t
        :html-doctype "html5"
        )
       ("current-static" ;; SRC/**/* -> DST/html/
        :base-directory ,src
        :base-extension ".*"
        :exclude "^\\(attic\\|top\\|options\\|.*\\.org\\)$"
        :publishing-directory ,dst
        :recursive t
        :publishing-function org-publish-attachment
        )
       ("current-static-top" ;; SRC/pub/top -> DST/html/
        :base-directory ,(concat src "/pub/top")
        :base-extension ".*"
        :include (".htaccess")
        :publishing-directory ,dst
        :recursive nil
        :publishing-function org-publish-attachment
        )
       ))
    (message "PUBLISH %s => %s" src dst)))

(defun make-all (src dst)
  (mapcar (lambda (file)
            (find-file file)
            (org-babel-tangle)
            (kill-buffer))
          (directory-files (expand-file-name "./org") t "\\.org$"))
  ;; (find-file project-top-file)
  (orglue-publish-setup-current-project
   (expand-file-name src)
   (expand-file-name dst))
  (org-publish "current")
  )
