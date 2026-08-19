(use-package treesit-auto
  :ensure t :demand t
  :config
  (setq treesit-auto-install 'prompt)
  (global-treesit-auto-mode))

;; Maintained fork -- NOT brotzeit/rustic
(use-package rustic
  :ensure (:host github :repo "emacs-rustic/rustic")
  :init
  (setq rustic-lsp-client 'eglot)
  :config
  (setq rustic-format-on-save nil) ;; apheleia owns formatting
  ;; clippy instead of plain check on save
  (setq-default eglot-workspace-configuration
                '(:rust-analyzer (:check (:command "clippy")))))

(use-package consult-eglot
  :ensure t :after consult
  :bind (("M-g s" . consult-eglot-symbols)))

(use-package apheleia
  :ensure t :demand t
  :config (apheleia-global-mode 1))

(use-package dape
  :ensure t
  :config
  (setq dape-buffer-window-arrangement 'right))
  ;; NOTE: the vexxed fleet dape configs live in the project's .dape-vexxed.el (loaded via
  ;; .dir-locals.el). init-container.el routes their `lldb-dap' + `cargo build' steps into the
  ;; vexxed-dev container from local buffers, so no host-path lldb config is needed here.
