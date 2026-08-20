(add-to-list 'load-path (expand-file-name "site-lisp/cm" user-emacs-directory))

;; Configura's cm layer -- p4.el in particular, pulled in by cm.el when the
;; tree is not a git workspace -- still uses the pre-24.3 cl.el names
;; (`defun*', `loop', ...).  Those only exist once `cl' is loaded; cl.el moved
;; to lisp/obsolete/ in Emacs 30 but is still shipped and still works.  Without
;; this, cm.el dies with "Symbol's function definition is void: defun*".
(unless (fboundp 'defun*)
  (with-no-warnings (require 'cl)))

(load-library "cm")
(load-library "cm-hide")

(global-unset-key (kbd "C-,"))
(global-set-key (kbd "M-o") 'cm-move-to-previous-window)
(global-set-key (kbd "C-M-o") 'cm-move-to-next-window)

;; Kill these dudes on compilation start
(setq cm-pskill-arglist
      (concat "/name \"_cm.exe\""
                      " /beginsWith \"msdev\""
                      " /beginsWith \"link\""
                      " /name \"sh.exe\""
                      " /name \"make.exe\""
                      ))




