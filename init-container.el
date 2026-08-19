;;; init-container.el --- Route project toolchains into a podman dev container -*- lexical-binding: t; -*-

;; Generic, settings-driven layer that transparently runs a project's toolchain
;; (cargo, rust-analyzer, lldb-dap, ...) INSIDE a podman dev container, without
;; requiring the tool to be installed on the host. A project opts in by registering
;; its root (`vexxed-container-register', called from the project's .dir-locals.el);
;; thereafter any matching subprocess Emacs spawns while `default-directory' is under
;; that root is rewritten to `podman exec -w <dir> <container> <tool> ...'.
;;
;; Why: the vexxed repo's Rust toolchain lives in the `vexxed-dev' container
;; (CARGO_TARGET_DIR=/work/target-dev, pinned toolchain, patched deps). Buffers are opened
;; LOCALLY (claude-code-ide path parity via the container's host-path mirror mount), so
;; TRAMP-into-/work is not in effect and the host may not even have rust installed. This
;; layer bridges that gap with zero shell shims and travels with ~/.emacs.d to any host.
;; TRAMP buffers (remote `default-directory') are deliberately left to native TRAMP.

(require 'cl-lib)

(defgroup vexxed-container nil
  "Run project toolchains inside a podman dev container."
  :group 'tools)

(defcustom vexxed-container-name (or (getenv "VEXXED_DEV_CONTAINER") "vexxed-dev")
  "Name of the podman container that hosts the toolchain."
  :type 'string)

(defcustom vexxed-container-podman "podman"
  "Podman executable (must be resolvable on `exec-path')."
  :type 'string)

(defcustom vexxed-container-tools '("cargo" "rust-analyzer" "lldb-dap")
  "Program basenames that should be routed into the container."
  :type '(repeat string))

(defcustom vexxed-container-home "/home/dev"
  "HOME to set inside the container (matches sandbox/dev.sh)."
  :type 'string)

(defvar vexxed-container-roots nil
  "Absolute project roots under which container routing is active.
Populated by `vexxed-container-register' (typically from a project's .dir-locals.el).")

;;;###autoload
(defun vexxed-container-register (root)
  "Register ROOT (an absolute directory) as a container-routed project root."
  (when root
    (add-to-list 'vexxed-container-roots
                 (file-name-as-directory (expand-file-name root)))))

(defun vexxed-container--dir-active-p ()
  "Non-nil when `default-directory' is a LOCAL path under a registered root.
Keyed on `default-directory' (not a buffer-local flag) so it survives the temp
buffers that tools like rustic spawn subprocesses in — those inherit
`default-directory' but not buffer-local variables."
  (and (not (file-remote-p default-directory))
       (cl-some (lambda (root) (file-in-directory-p default-directory root))
                vexxed-container-roots)))

(defun vexxed-container--active-p (program)
  "Non-nil when PROGRAM should be routed into the container from here."
  (and (stringp program)
       (member (file-name-nondirectory program) vexxed-container-tools)
       (vexxed-container--dir-active-p)))

(defun vexxed-container--ensure-running ()
  "Best-effort start of the container. Creation stays sandbox/dev.sh's job."
  (unless (equal "true"
                 (string-trim
                  (shell-command-to-string
                   (format "%s inspect -f '{{.State.Running}}' %s 2>/dev/null"
                           (shell-quote-argument vexxed-container-podman)
                           (shell-quote-argument vexxed-container-name)))))
    (call-process vexxed-container-podman nil nil nil "start" vexxed-container-name)))

(defun vexxed-container--wrap (program args)
  "Return a command list running PROGRAM ARGS inside the container.
Uses `default-directory' as the working dir so cargo/RA/lldb source paths stay
host-parity (the repo is mirror-mounted at its host path in the container)."
  (vexxed-container--ensure-running)
  (append (list vexxed-container-podman "exec" "-i"
                "-w" (directory-file-name (expand-file-name default-directory))
                "-e" (concat "HOME=" vexxed-container-home)
                vexxed-container-name
                (file-name-nondirectory program))
          args))

;; --- cargo + lldb-dap: intercept the generic subprocess seams ----------------
;; process-file  -> rustic's synchronous `cargo locate-project --workspace'
;; make-process  -> rustic-compile, dape's adapter launch + its `compile' step

(defun vexxed-container--process-file (orig program &optional infile buffer display &rest args)
  "Route `process-file' through the container for matching tools."
  (if (vexxed-container--active-p program)
      (let ((cmd (vexxed-container--wrap program args)))
        (apply orig (car cmd) infile buffer display (cdr cmd)))
    (apply orig program infile buffer display args)))

(defun vexxed-container--make-process (orig &rest args)
  "Route `make-process' :command through the container for matching tools.
Wrapped commands begin with podman (not a listed tool), so never double-wrap."
  (let ((command (plist-get args :command)))
    (if (and command (vexxed-container--active-p (car command)))
        (let ((wrapped (vexxed-container--wrap (car command) (cdr command)))
              (args (copy-sequence args)))
          (apply orig (plist-put args :command wrapped)))
      (apply orig args))))

(advice-add 'process-file :around #'vexxed-container--process-file)
(advice-add 'make-process :around #'vexxed-container--make-process)

;; --- rust-analyzer: eglot's documented contact point -------------------------
;; A function contact, so eglot's own `executable-find' check sees `podman' (present)
;; instead of `rust-analyzer' (absent on a bare host). Off-root rust projects fall back
;; to plain host rust-analyzer, so other repos are untouched.

(defun vexxed-container--eglot-rust (&optional _interactive _project)
  "Eglot contact for rust: containerized command under a registered root, else host RA."
  (if (and (member "rust-analyzer" vexxed-container-tools)
           (vexxed-container--dir-active-p))
      (vexxed-container--wrap "rust-analyzer" nil)
    '("rust-analyzer")))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((rust-ts-mode rust-mode) . vexxed-container--eglot-rust)))

(provide 'init-container)
;;; init-container.el ends here
