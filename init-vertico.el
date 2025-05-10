;; Enable vertico
(use-package vertico
  :demand t
  :ensure t
  :init
  (vertico-mode)
  (vertico-multiform-mode 1)

  ;; Different scroll margin
  (setq vertico-scroll-margin 10)

  ;; Show more candidates
  (setq vertico-count 20)

  ;; Grow and shrink the Vertico minibuffer
  (setq vertico-resize t)
  (setq vertico-grid-mode t)
  ;; Optionally enable cycling for `vertico-next' and `vertico-previous'.
  (setq vertico-cycle  t))
