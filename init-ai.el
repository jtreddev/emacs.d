;; --- Claude Code IDE: Claude drives Emacs via MCP -------------------
;; Must run before any file is opened so dir-locals can override cli-path
;; without Emacs prompting or silently dropping the variable.
(put 'claude-code-ide-cli-path 'safe-local-variable #'stringp)
;; Same for ai-code-interface's kimi backend: per-project container wrappers
;; (e.g. vexxed's sandbox/kimi-vexxed) override the global kimi-toolbox default.
(put 'ai-code-kimi-cli-program 'safe-local-variable #'stringp)
(put 'ai-code-kimi-cli-program-switches 'safe-local-variable
     (lambda (v) (and (listp v) (seq-every-p #'stringp v))))

(use-package vterm :ensure t :demand t)

(use-package eat :ensure t :demand t)

;; libghostty-based terminal; native module auto-downloads on first use.
(use-package ghostel :ensure t :demand t)

(use-package claude-code-ide
  :ensure (:host github :repo "manzaltu/claude-code-ide.el")
  :bind ("C-c '" . claude-code-ide-menu)
  :config
  ;; ghostel renders the Claude TUI most faithfully (synchronized output, C-v
  ;; image paste); switch back to 'eat or 'vterm here if it misbehaves.
  (setq claude-code-ide-terminal-backend 'ghostel)
  ;; Bigger PTY reads / no adaptive buffering so fewer partial frames reach the
  ;; renderer (helps eat too; global, also benefits LSP/comint).
  (setq read-process-output-max (* 4 1024 1024)
        process-adaptive-read-buffering nil)
  ;; Default: run claude inside the 'claude' fedora-toolbox container (claude-toolbox wrapper).
  ;; The vexxed project overrides this to claude-container (the vexxed-dev podman container) via
  ;; its .dir-locals.el — so ONLY vexxed uses podman; every other project uses the toolbox.
  (setq-default claude-code-ide-cli-path "/home/jtreddev/.local/bin/claude-toolbox")
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
    (require 'ai-code-embark)))

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
