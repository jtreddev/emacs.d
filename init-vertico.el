;; Enable vertico
(use-package vertico
  :demand t
  :ensure t
  :init
  (vertico-mode)
  (vertico-multiform-mode 1)

  (setq vertico-scroll-margin 3)
  (setq vertico-count 20)
  (setq vertico-resize t)
  (setq vertico-cycle t)

  (setq vertico-multiform-commands
        '((consult-line buffer)
          (consult-imenu buffer)
          (consult-ripgrep buffer))))
