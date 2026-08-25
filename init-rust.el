;; Scoped deliberately narrowly.  `global-treesit-auto-mode' otherwise remaps
;; every prog mode it has a recipe for, and two things go wrong here:
;;
;;   1. Nothing can be installed.  `treesit-install-language-grammar' clones the
;;      grammar and then *compiles* it, which needs a C and a C++ compiler on
;;      `exec-path'.  This box has none (no gcc/cc/clang/cl), and under the
;;      CetDev launcher cm-tools.exe composes PATH itself, so a toolchain
;;      installed later would not be visible either.  With `treesit-auto-install'
;;      set to `prompt' that meant a failing yes/no prompt on every visit.
;;
;;   2. Succeeding would be worse than failing.  Configura's cm-bindings.el maps
;;      .cm (and .m/.ih/.cmdoc/...) to `c-mode', and the whole CM layer hangs off
;;      `c-mode-hook': the CM keybindings, `cm-auto-hide-copyright-notice',
;;      `cm-c-mode/fix-nestable-comment-syntax' and
;;      `c-mode-install-special-indent-hook'.  `c-ts-mode' derives from
;;      `prog-mode' and never runs `c-mode-hook', so a working c grammar would
;;      silently strip CM indentation, comment syntax and bindings -- and
;;      font-lock CM as if it were C.
;;
;; `treesit-auto-langs' therefore whitelists only what this file actually wants
;; tree-sitter for; `c' and `cpp' must stay out of it.  (The c recipe also
;; declares :requires 'cpp, which is why one .cm visit used to prompt twice.)
;; `treesit-auto-install' stays nil so any future gap falls back silently
;; instead of asking.
(use-package treesit-auto
  :ensure t :demand t
  :config
  (setq treesit-auto-install nil)
  (setq treesit-auto-langs '(rust toml))
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
