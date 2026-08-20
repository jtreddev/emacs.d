;; CRITICAL: prevents silent connection failure when container HOME has no
;; .tramp_history (known rootless Podman footgun).
(setq tramp-histfile-override nil)
;; Minimal overhead for local containers (no network hop).
(setq remote-file-name-inhibit-cache 0)
(setq tramp-verbose 1)

;; Primary, claude-aligned workflow: open the vexxed project LOCALLY. claude-code-ide runs claude
;; inside the vexxed-dev container at the mirrored /home/jtreddev/vexxed path, so claude's file
;; paths match these buffers exactly (its MCP open-file/diff/diagnostics resolve correctly). eglot
;; uses the host rust-analyzer (~/.cargo/bin).
(defcustom my/vexxed-root
  (or (getenv "VEXXED_ROOT")
      (if (eq system-type 'windows-nt)
          (my/home-file "vexxed/")
        "/home/jtreddev/vexxed/"))
  "Local checkout of the vexxed project.
Override with the VEXXED_ROOT environment variable or via Customize;
the hardcoded default only exists on the Linux host."
  :type 'directory
  :group 'tools)

(defun my/vexxed ()
  (interactive)
  (if (file-directory-p my/vexxed-root)
      (project-switch-project my/vexxed-root)
    (user-error "my/vexxed: %s does not exist; set `my/vexxed-root'"
                my/vexxed-root)))
(global-set-key (kbd "C-c v") #'my/vexxed)

;; In-container LSP/build: open the project via Tramp Podman against vexxed-dev (repo at /work).
;; Once default-directory is the Tramp path, eglot, M-x compile, and M-x shell route into the
;; container. NOTE: claude-code-ide's MCP file ops do not translate /work back to a Tramp path, so
;; use `my/vexxed' (local) for the Claude workflow and this one for in-container tooling.
(defun my/vexxed-tramp ()
  (interactive)
  (unless (executable-find "podman")
    (user-error "my/vexxed-tramp: podman is not installed on this host"))
  (project-switch-project "/podman:vexxed-dev:/work/"))
(global-set-key (kbd "C-c V") #'my/vexxed-tramp)
