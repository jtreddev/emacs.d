(defvar my/deco nil
  "Symbol naming the frame-decorator function to apply to new frames.")

(defvar my/fonts
  '("JetBrainsMono Nerd Font 12"
    "JetBrainsMono Nerd Font 14"
    "FiraCode Nerd Font 12"
    "FiraCode Nerd Font 14"
    "Hack Nerd Font 12"
    "CaskaydiaCove Nerd Font 12"
    "Meslo LG M Nerd Font 12"
    "UbuntuMono Nerd Font 12"))

(defun my/toggle-font (font)
  (interactive (list (completing-read "Font: " my/fonts nil t)))
  (set-frame-font font nil t)
  (message "Font: %s" font))


(defun init-my/decorator ()
  ;; For the built-in themes which cannot use `require'.
  (require-theme 'modus-themes) ; `require-theme' is ONLY for the built-in Modus themes
  (define-key global-map (kbd "<f5>") #'modus-themes-toggle)
  (setq my/deco 'my/default-decorator)

  (if (daemonp)
      (add-hook 'after-make-frame-functions my/deco)
    (funcall my/deco (selected-frame))))


(defun my/default-decorator (frame)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq visible-bell t)

  (line-number-mode -1)
  (display-line-numbers-mode -1)

  (when (display-graphic-p frame)
    (set-frame-font "JetBrainsMono Nerd Font 12" nil t))

  ;; FiraCode in vterm terminal buffers — tighter spacing suits terminal output
  (add-hook 'vterm-mode-hook
            (lambda () (face-remap-add-relative 'default :family "FiraCode Nerd Font")))

  (unless (memq 'modus-operandi-tinted custom-enabled-themes)
    (load-theme 'modus-operandi-tinted t)))


(defun my/presentation-decorator (frame)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (display-line-numbers-mode -1)
  (setq visible-bell nil)
  (load-theme 'modus-vivendi t))


(init-my/decorator)
