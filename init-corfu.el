(use-package corfu
  :ensure t :demand t
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.3)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-quit-no-match 'separator)
  (corfu-scroll-margin 3)
  ;; Only use corfu in the minibuffer when vertico/mct isn't already handling
  ;; completion (e.g. M-:), and never in password prompts
  (global-corfu-minibuffer
   (lambda ()
     (not (or (bound-and-true-p mct--active)
              (bound-and-true-p vertico--input)
              (eq (current-local-map) read-passwd-map)))))
  :init
  (global-corfu-mode)
  (corfu-popupinfo-mode 1))

;; `nerd-icons' defaults `nerd-icons-font-family' to "Symbols Nerd Font Mono",
;; a separate download that is not installed here; on Windows it would also be
;; registered under its truncated legacy name "Symbols NFM".  Point it at a
;; patched font that IS installed so glyphs render instead of tofu -- the
;; JetBrainsMono Nerd Font carries the same glyph set.
(use-package nerd-icons
  :ensure t :demand t
  :config
  (when-let* ((family (my/first-available-font
                       (append (when (eq system-type 'windows-nt)
                                 '("Symbols NFM" "Symbols NF"))
                               '("Symbols Nerd Font Mono" "Symbols Nerd Font")
                               my/font-families))))
    (setq nerd-icons-font-family family)))

;; Icons in the corfu popup — requires a Nerd Font in your terminal/GUI font
(use-package nerd-icons-corfu
  :ensure t :after corfu
  :config (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

;; Corfu works in terminal frames too
(use-package corfu-terminal
  :ensure (:host codeberg :repo "akib/emacs-corfu-terminal")
  :unless (display-graphic-p)
  :config (corfu-terminal-mode 1))
