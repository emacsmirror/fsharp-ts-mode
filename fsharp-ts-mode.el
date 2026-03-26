;;; fsharp-ts-mode.el --- Major mode for F# code -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>
;; Maintainer: Bozhidar Batsov <bozhidar@batsov.dev>
;; URL: https://github.com/bbatsov/fsharp-ts-mode
;; Keywords: languages fsharp
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides font-lock, indentation, and navigation for the
;; F# programming language (https://fsharp.org).

;; For the tree-sitter grammar this mode is based on,
;; see https://github.com/ionide/tree-sitter-fsharp.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'treesit)

(defgroup fsharp-ts nil
  "Major mode for editing F# code with tree-sitter."
  :prefix "fsharp-ts-"
  :group 'languages
  :link '(url-link :tag "GitHub" "https://github.com/bbatsov/fsharp-ts-mode")
  :link '(emacs-commentary-link :tag "Commentary" "fsharp-ts-mode"))

(defcustom fsharp-ts-indent-offset 4
  "Number of spaces for each indentation step in the major modes."
  :type 'natnum
  :safe 'natnump
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-other-file-alist
  '(("\\.fsi\\'" (".fs"))
    ("\\.fs\\'" (".fsi")))
  "Associative list of alternate extensions to find.
See `ff-other-file-alist' and `ff-find-other-file'."
  :type '(repeat (list regexp (choice (repeat string) function)))
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defvar fsharp-ts--debug nil
  "Enable debugging messages and show the current node in the mode-line.
When set to t, show indentation debug info.
When set to `font-lock', show fontification info as well.

Only intended for use at development time.")

(defconst fsharp-ts-mode-version "0.1.0")

(defun fsharp-ts-mode-version ()
  "Display the current package version in the minibuffer."
  (interactive)
  (let ((pkg-version (package-get-version)))
    (if (called-interactively-p 'interactively)
        (if pkg-version
            (message "fsharp-ts-mode %s (package: %s)" fsharp-ts-mode-version pkg-version)
          (message "fsharp-ts-mode %s" fsharp-ts-mode-version))
      (or pkg-version fsharp-ts-mode-version))))

;;;; Grammar management

(defconst fsharp-ts-mode-grammar-recipes
  '((fsharp "https://github.com/ionide/tree-sitter-fsharp"
            "v0.2.2"
            "fsharp/src")
    (fsharp-signature "https://github.com/ionide/tree-sitter-fsharp"
                      "v0.2.2"
                      "fsharp_signature/src"))
  "Tree-sitter grammar recipes for F# and F# Signature.
Each entry is a list of (LANGUAGE URL REV SOURCE-DIR).
Suitable for use as the value of `treesit-language-source-alist'.")

(defun fsharp-ts-mode-install-grammars (&optional force)
  "Install required language grammars if not already available.
With prefix argument FORCE, reinstall grammars even if they are
already installed.  This is useful after upgrading fsharp-ts-mode to a
version that requires a newer grammar."
  (interactive "P")
  (dolist (recipe fsharp-ts-mode-grammar-recipes)
    (let ((grammar (car recipe)))
      (when (or force (not (treesit-language-available-p grammar nil)))
        (message "Installing %s tree-sitter grammar..." grammar)
        (let ((treesit-language-source-alist fsharp-ts-mode-grammar-recipes))
          (treesit-install-language-grammar grammar))))))

;;;; Syntax table

(defvar fsharp-ts-base-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "_" st)
    (modify-syntax-entry ?' "_" st)      ; type parameters like 'a
    ;; Operator characters
    (dolist (c '(?! ?$ ?% ?& ?+ ?- ?< ?= ?> ?@ ?^ ?| ?~ ??))
      (modify-syntax-entry c "." st))
    ;; String delimiters
    (modify-syntax-entry ?\" "\"" st)
    (modify-syntax-entry ?\\ "\\" st)
    ;; Block comments: (* ... *)
    (modify-syntax-entry ?*  ". 23" st)
    (modify-syntax-entry ?\( "()1n" st)
    (modify-syntax-entry ?\) ")(4n" st)
    ;; Line comments: // ...
    ;; The // style is handled via `comment-start' and font-lock.
    ;; The syntax table handles (* *) natively so that
    ;; `forward-comment' and `comment-dwim' work on block comments.
    st)
  "Syntax table in use in fsharp-ts-mode buffers.")

;;;; Mode setup

(defun fsharp-ts--setup-mode (language)
  "Common tree-sitter mode setup for LANGUAGE.
LANGUAGE should be `fsharp' or `fsharp-signature'."
  (when (treesit-ready-p language)
    (let ((parser (treesit-parser-create language)))
      (when (boundp 'treesit-primary-parser)
        (setq-local treesit-primary-parser parser)))

    (when fsharp-ts--debug
      (setq-local treesit--indent-verbose t)
      (when (eq fsharp-ts--debug 'font-lock)
        (setq-local treesit--font-lock-verbose t))
      (treesit-inspect-mode))

    (treesit-major-mode-setup)))

(define-derived-mode fsharp-ts-base-mode prog-mode "F#"
  "Base major mode for F# files, providing shared setup.
This mode is not intended to be used directly.  Use `fsharp-ts-mode'
for .fs files and `fsharp-ts-signature-mode' for .fsi files."
  :syntax-table fsharp-ts-base-mode-syntax-table

  ;; Comment settings: F# primarily uses // line comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+\\s-*")

  ;; Electric indentation on delimiters
  (setq-local electric-indent-chars
              (append "{}()" electric-indent-chars))

  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword string type)
                (attribute builtin constant escape-sequence number)
                (operator bracket delimiter variable property function)))

  (setq-local indent-line-function #'treesit-indent)

  ;; which-func-mode / add-log integration
  (setq-local add-log-current-defun-function #'treesit-add-log-current-defun)

  ;; ff-find-other-file setup
  (setq-local ff-other-file-alist fsharp-ts-other-file-alist))

;;;###autoload
(define-derived-mode fsharp-ts-mode fsharp-ts-base-mode "F#"
  "Major mode for editing F# code.

\\{fsharp-ts-base-mode-map}"
  (fsharp-ts--setup-mode 'fsharp))

;;;###autoload
(define-derived-mode fsharp-ts-signature-mode fsharp-ts-base-mode "F#[Sig]"
  "Major mode for editing F# signature (fsi) code.

\\{fsharp-ts-base-mode-map}"
  (fsharp-ts--setup-mode 'fsharp-signature))

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.fs\\'" . fsharp-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.fsx\\'" . fsharp-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.fsi\\'" . fsharp-ts-signature-mode)))

;; Hide F# build artifacts from find-file completion
(dolist (ext '(".dll" ".exe" ".pdb"))
  (add-to-list 'completion-ignored-extensions ext))

;; Eglot integration: set the language IDs that fsautocomplete expects.
(put 'fsharp-ts-mode 'eglot-language-id "fsharp")
(put 'fsharp-ts-signature-mode 'eglot-language-id "fsharp")

(provide 'fsharp-ts-mode)

;;; fsharp-ts-mode.el ends here
