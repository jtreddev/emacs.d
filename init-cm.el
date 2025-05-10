(add-to-list 'load-path (expand-file-name "site-lisp/emacs" user-emacs-directory))
(load-library "cm")
(load-library "cm-hide")

(setq cm-current-compilation-window-style 2) ;; current window layout split left/right

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




