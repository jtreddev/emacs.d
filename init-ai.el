;; --- Claude Code IDE: Claude drives Emacs via MCP -------------------
;; Must run before any file is opened so dir-locals can override cli-path
;; without Emacs prompting or silently dropping the variable.
(put 'claude-code-ide-cli-path 'safe-local-variable #'stringp)
;; Same for ai-code-interface's kimi backend: per-project container wrappers
;; (e.g. vexxed's sandbox/kimi-vexxed) override the global kimi-toolbox default.
(put 'ai-code-kimi-cli-program 'safe-local-variable #'stringp)
(put 'ai-code-kimi-cli-program-switches 'safe-local-variable
     (lambda (v) (and (listp v) (seq-every-p #'stringp v))))

;; Native-module terminals.  Both are wrapped in a plain `when' rather than
;; use-package's `:if': use-package processes `:ensure' BEFORE `:if', so `:if'
;; alone would still have Elpaca clone and build the order on a host that can
;; never use it.
;;
;; vterm needs cmake + a C toolchain to build libvterm, and does not build
;; against stock Windows Emacs at all.
(when (and (not (eq system-type 'windows-nt)) (executable-find "cmake"))
  (use-package vterm :ensure t :demand t))

;; eat is pure elisp, so it is the terminal that is always available.
(use-package eat :ensure t :demand t)

;; libghostty-based terminal; native module auto-downloads on first use.
;; No Windows build is published, so skip it there.
(unless (eq system-type 'windows-nt)
  (use-package ghostel :ensure t :demand t))

(use-package claude-code-ide
  :ensure (:host github :repo "manzaltu/claude-code-ide.el")
  :bind ("C-c '" . claude-code-ide-menu)
  :config
  ;; ghostel renders the Claude TUI most faithfully (synchronized output, C-v
  ;; image paste); switch back to 'eat or 'vterm here if it misbehaves.
  ;; ghostel/vterm are unavailable on Windows (see the gated `use-package'
  ;; forms above), so fall back to eat, which is pure elisp.
  (setq claude-code-ide-terminal-backend
        (cond ((featurep 'ghostel) 'ghostel)
              ((featurep 'vterm)   'vterm)
              (t                   'eat)))
  ;; Bigger PTY reads / no adaptive buffering so fewer partial frames reach the
  ;; renderer (helps eat too; global, also benefits LSP/comint).
  (setq read-process-output-max (* 4 1024 1024)
        process-adaptive-read-buffering nil)
  ;; Default: run claude inside the 'claude' fedora-toolbox container (claude-toolbox wrapper).
  ;; The vexxed project overrides this to claude-container (the vexxed-dev podman container) via
  ;; its .dir-locals.el — so ONLY vexxed uses podman; every other project uses the toolbox.
  ;; Resolve from `exec-path' first so this works on hosts without the toolbox
  ;; wrapper (e.g. Windows, where claude.exe lives in ~/.local/bin); the
  ;; .dir-locals.el overrides described above still win, this is only the
  ;; default.
  ;; The last fallback is the bare name, NOT a hardcoded absolute path: an
  ;; absolute Linux path can only ever fail on this host, and it fails with
  ;; claude-code-ide's misleading "CLI not available, please install it and
  ;; ensure it is on PATH" rather than pointing at the real problem.  A bare
  ;; name at least lets `call-process' re-search `exec-path' at call time.
  (setq-default claude-code-ide-cli-path
                (or (executable-find "claude-toolbox")
                    (executable-find "claude")
                    "claude"))
  ;; eat-exec is not Tramp-aware: strip the /podman:vexxed: prefix so the
  ;; working directory is a plain local path that eat can cd into.
  (advice-add 'claude-code-ide--get-working-directory :filter-return
              (lambda (dir)
                (if (and (fboundp 'tramp-tramp-file-p) (tramp-tramp-file-p dir))
                    (tramp-file-local-name dir)
                  dir)))
  (claude-code-ide-emacs-tools-setup)
  ;; eat fixes: keep the Claude terminal scrollable and sized correctly after a
  ;; window resize / minibuffer transient (SIGWINCH nudge + blink redraw override).
  (load (expand-file-name "init-eat-blink-ab.el" user-emacs-directory)))

;; --- agent-shell: native Emacs buffers over ACP ---------------------
(use-package agent-shell
  :ensure t :demand t
  :config
  ;; Uses your Claude subscription login (no API key billing)
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)))

;; --- ai-code-interface: unified AI CLI menu (local fork with Kimi) --
;; Local fork, so this only exists on a host with the checkout.  Guarded with a
;; plain `when' rather than use-package's `:if' because use-package processes
;; `:ensure' before `:if', so `:if' would not stop Elpaca from queueing (and
;; failing) the order on a host where the repo is absent.
(defvar my/ai-code-repo (expand-file-name "~/src/ai-code-interface.el")
  "Local checkout of the ai-code-interface fork; skipped when absent.")

(when (file-directory-p my/ai-code-repo)
  (use-package ai-code
    :ensure (:repo "~/src/ai-code-interface.el" :files ("*.el" "snippets"))
    ;; C-c a is org-agenda; use C-c A for the AI menu instead.
    :bind ("C-c A" . ai-code-menu)
    :config
    ;; GUI Emacs has a minimal PATH; the kimi binary lives in ~/.kimi-code/bin.
    (add-to-list 'exec-path (expand-file-name "~/.kimi-code/bin"))
    (setenv "PATH" (concat (expand-file-name "~/.kimi-code/bin")
                           path-separator (getenv "PATH")))
    ;; Default: run agent CLIs inside the shared fedora-toolbox container via the
    ;; generic agent-toolbox entry point; the agent binary is the first switch.
    ;; Projects override both via .dir-locals.el (e.g. vexxed uses agent-vexxed
    ;; with the vexxed-dev podman container and /home/dev/.kimi-code/bin/kimi).
    (setq-default ai-code-kimi-cli-program "/home/jtreddev/.local/bin/agent-toolbox")
    (setq-default ai-code-kimi-cli-program-switches '("/home/jtreddev/.kimi-code/bin/kimi"))
    (ai-code-set-backend 'kimi)
    ;; Buffer-interaction commands (code change, ask, explain, ...) live in
    ;; Embark, not the transient: embark-act then "@" for the AI actions.
    (with-eval-after-load 'embark
      (require 'ai-code-embark))))

;; --- gptel: in-buffer LLM (rewrite region, quick asks, org chat) ----
(use-package gptel
  :ensure t :demand t
  :bind (("C-c RET" . gptel-send)
         ("C-c g"   . gptel-menu))
  :config
  (setq gptel-backend (gptel-make-anthropic "Claude"
                        :stream t :key (getenv "ANTHROPIC_API_KEY"))
        gptel-model 'claude-opus-4-8))

(use-package gptel-agent
  :ensure (:host github :repo "karthink/gptel-agent")
  :after gptel)
