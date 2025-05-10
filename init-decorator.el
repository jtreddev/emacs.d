(defvar my/deco nil)
(defun my/deco (decorator)
  (setq my/deco decorator)
   (funcall my/deco 'selected-frame))


(defun init-my/decorator ()
  ;; For the built-in themes which cannot use `require'.
  (require-theme 'modus-themes) ; `require-theme' is ONLY for the built-in Modus themes
  (define-key global-map (kbd "<f5>") #'modus-themes-toggle)
  (message (format "%s" my/deco))
  (setq my/deco 'my/default-decorator)
  (message (format "%s" my/deco))

   (if (daemonp)
       (add-hook 'after-make-frame-functions my/deco)
     (funcall my/deco 'selected-frame)))


(defun my/default-decorator (frame)
  (message "YEYSIUODJF")
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq visible-bell -1)

  (line-number-mode -1)

  (display-line-numbers-mode -1)

  (load-theme 'modus-operandi-tinted)

  (set-frame-font "Iosevka 14" nil t)

  ;; (vertico-posframe-mode 1)
  ;; (setq vertico-posframe-poshandler 'posframe-poshandler-frame-top-center)

  ;; (which-key-mode 1)
  ;; (which-key-posframe-mode 1)
  ;; (setq which-key-posframe-poshandler 'posframe-poshandler-frame-bottom-center)
  )


(defun my/presentation-decorator (frame)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (display-line-numbers-mode -1)
  (setq visible-bell -1)
  (load-theme 'modus-vivendi)
  (set-frame-font "Iosevka 16" nil t))
