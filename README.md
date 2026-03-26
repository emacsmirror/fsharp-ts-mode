# fsharp-ts-mode

A tree-sitter-based Emacs major mode for [F#](https://fsharp.org) development.

**Requires Emacs 29.1+** with tree-sitter support.

## Installation

### Manual

Clone the repository and add it to your `load-path`:

```emacs-lisp
(add-to-list 'load-path "/path/to/fsharp-ts-mode")
(require 'fsharp-ts-mode)
```

### package-vc (Emacs 30+)

```emacs-lisp
(package-vc-install "https://github.com/bbatsov/fsharp-ts-mode")
```

## Grammar Installation

Install the required F# tree-sitter grammars:

```
M-x fsharp-ts-mode-install-grammars
```

This installs both the `fsharp` grammar (for `.fs` and `.fsx` files) and
the `fsharp-signature` grammar (for `.fsi` files).

## Features

- Syntax highlighting (font-lock) via tree-sitter
- Indentation via tree-sitter
- Imenu support
- Navigation (beginning/end of defun, forward-sexp)
- Eglot integration (F# Language Server)

## Configuration

```emacs-lisp
;; Change indentation offset (default: 4)
(setq fsharp-ts-indent-offset 2)
```

## License

Copyright (C) 2026 Bozhidar Batsov

Distributed under the GNU General Public License, version 3.
