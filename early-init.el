;; Treat startup like `emacs --debug-init': drop into a *Backtrace* buffer on
;; any error while loading the init files (daemon, standalone, or fallback).
(setq init-file-debug t)
(setq debug-on-error t)

(setq package-enable-at-startup nil)

(push '(undecorated . t) default-frame-alist)

;; Set the font on the initial frame *before* it is created, otherwise the
;; first GUI frame is mapped with the tiny built-in default font/size and the
;; window manager keeps that small geometry even after the decorator runs.
(push '(font . "JetBrainsMono Nerd Font 12") default-frame-alist)

;; Don't let the early font/size change trigger a frame resize race.
(setq frame-inhibit-implied-resize t)
