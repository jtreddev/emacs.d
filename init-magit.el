(use-package transient
  :ensure t :demand t)

(use-package magit
  :ensure t :demand t)

(use-package diff-hl
  :ensure t :demand t
  :hook ((prog-mode . diff-hl-mode)
         (magit-pre-refresh  . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh)))
