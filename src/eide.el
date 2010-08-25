;;; eide.el --- Emacs-IDE

;; Copyright (C) 2005-2009 Cédric Marie

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

;; *****************************************************************************
;; * MEMO                                                                      *
;; *****************************************************************************

;; options : M-x customize
;; M-x replace-string C-Q 0 0 1 5 : pour supprimer les ^M
;; C-h C-f : fonction
;; C-h   v : variable
;; C-h   b : liste des raccourcis claviers

;;     M-. tag
;; C-u M-. prochain tag

;; M-x list-faces-display : liste des styles utilisés
;; M-x list-colors-display : liste des couleurs disponibles

;; ^M
;;(setq comint-output-filter-functions (remove 'comint-carriage-motion 'comint-output-filter-functions))

(if (featurep 'xemacs)
  (progn
    (read-string "Sorry, XEmacs is not supported by Emacs-IDE, press <ENTER> to exit...")
    (kill-emacs)))


;;;; ==========================================================================
;;;; SETTINGS
;;;; ==========================================================================

(defvar eide-version "1.2")
(defvar eide-release-date "08/2009")

(defvar eide-options-file       ".emacs-ide.options")
(defvar eide-project-file       ".emacs-ide.project")
(defvar eide-project-notes-file ".emacs-ide.project_notes")
;;(defvar eide-project-lock-file  ".emacs-ide.project_lock")

(defvar eide-root-directory nil)
(defvar eide-current-buffer nil)


;;;; ==========================================================================
;;;; INTERNAL FUNCTIONS
;;;; ==========================================================================

;; ----------------------------------------------------------------------------
;; Cleaning before exit
;; ----------------------------------------------------------------------------
;;(defun eide-kill-emacs-hook ()
;;  (if (and eide-project-name (not eide-project-already-open-flag))
;;    ;; "Unlock" project
;;    (shell-command (concat "rm -f " eide-root-directory eide-project-lock-file)))
;;  (if (string-equal (buffer-name) eide-project-file)
;;    ;; Rebuild project configuration file (because project_type might be lost
;;    ;; otherwise !)
;;    (progn
;;      (save-buffer)
;;      (eide-config-rebuild-project-file))))


;;;; ==========================================================================
;;;; LIBRARIES
;;;; ==========================================================================

(require 'desktop)
(require 'hideshow)
(require 'imenu)
(require 'mwheel)

;;(require 'gud)


;;;; ==========================================================================
;;;; ENVIRONMENT SPECIFIC SETTINGS
;;;; ==========================================================================

;; Directory for including other modules
;; file-truename follows symbolic link .emacs (if any)
;; file-name-directory retrieves directory path (removes file name)
;; directory-file-name removes final "/"
(defvar eide-emacs-path (directory-file-name (file-name-directory (file-truename user-init-file))))
(add-to-list 'load-path eide-emacs-path)

(require 'eide-config)
(require 'eide-project)
(require 'eide-edit)
(require 'eide-search)
(require 'eide-compare)

(require 'eide-popup)
(require 'eide-menu)
(require 'eide-windows)
(require 'eide-help)

(require 'eide-keys)

;; ----------------------------------------------------------------------------
;; Open shell.
;;
;; output : eide-windows-update-result-buffer-id : "s" for "shell".
;; ----------------------------------------------------------------------------
(defun eide-shell-open ()
  (interactive)
  (eide-windows-select-window-file t)
  (let ((l-buffer-directory (file-name-directory (buffer-file-name))))
    (eide-windows-select-window-results)
    ;; Sometimes does not compile when a grep buffer is displayed
    ;; "compilation finished" is displayed in grep buffer !
    (switch-to-buffer "*results*")
    ;; Shell buffer name will be updated in eide-l-windows-display-buffer-function
    (setq eide-windows-update-result-buffer-id "s")
    (shell)
    (send-invisible (concat "cd " l-buffer-directory " ; echo"))))


;;;; ==========================================================================
;;;; PREFERENCES
;;;; ==========================================================================

;; Do not display startup message
(setq inhibit-startup-message t)

;; Disable warning for large files (especially for TAGS)
(setq large-file-warning-threshold nil)

;; Do not save backup files (~)
(setq make-backup-files nil)

;; Do not save place in .emacs-places
(setq-default save-place nil)

;; No confirmation when refreshing buffer
(setq revert-without-query '(".*"))

;; Use 'y' and 'n' instead of 'yes' and 'no' for minibuffer questions
(fset 'yes-or-no-p 'y-or-n-p) 

;; Use mouse wheel (default for Windows but not for Linux)
(mouse-wheel-mode 1)
;; Mouse wheel should scroll the window over which the mouse is
(setq mouse-wheel-follow-mouse t)
;; Set mouse wheel scrolling speed
(if (equal (safe-length mouse-wheel-scroll-amount) 1)
  ;; Old API
  (setq mouse-wheel-scroll-amount '(4 . 1))
  ;; New API
  (setq mouse-wheel-scroll-amount '(4 ((shift) . 1) ((control)))))
;; Disable mouse wheel progressive speed
(setq mouse-wheel-progressive-speed nil)

;; Keep cursor position when moving page up/down
(setq scroll-preserve-screen-position t)

;; Paper type for printing
(setq ps-paper-type 'a4)

;; Show end of buffer
;;(setq-default indicate-empty-lines t)

;; No menu bar
(if window-system
  (progn
    (menu-bar-mode -1)
    (tool-bar-mode -1)))

;; "One line at a time" scrolling (default value is 0, which moves active line
;; to center - High value is necessary, otherwise it sometimes doesn't work !)
(setq-default scroll-conservatively 2000)

;; Four line margin for scrolling
(setq scroll-margin 4)

;; Display line and column numbers
(setq line-number-mode t)
(setq column-number-mode t)

;; Disable beep
;;(setq visible-bell t)
(setq ring-bell-function (lambda() ()))

;; Vertical scroll bar on the right
;; (default value : right for Windows, left for Linux)
(set-scroll-bar-mode 'right)

;; Ignore invisible lines when moving cursor in project configuration
(setq line-move-ignore-invisible t)


;;;; ==========================================================================
;;;; CONFIGURATION
;;;; ==========================================================================

;; Project directory
;; On Windows : it is necessary to open a temporary file for the directory path
;; to be correct (Windows standard vs Unix)
;; On Linux : it is also useful to expand path (~ => /home/xxx/).
;; NB : "temp" was first used as a temporary filename, but it causes the project
;; directory to be changed to "temp" if "temp" already exists and is a
;; directory !... Hence a filename that can not exist !! :-)

(let ((l-temp-file "this-is-a-temporary-file-for-emacs-ide"))
  (find-file l-temp-file)
  (setq eide-root-directory default-directory)
  (kill-buffer l-temp-file))

(if eide-option-use-cscope-flag
  (progn
    (cscope-set-initial-directory eide-root-directory)
    ;;(setq cscope-do-not-update-database t)
    ))

;; init a virer si possible :
;;(setq eide-project-already-open-flag nil)

;; Load options file (it will be closed at the end of "rebuild", so that
;; current buffer - from .emacs.desktop - is not changed)
(find-file-noselect (concat "~/" eide-options-file))

;; Options file must be rebuilt before calling eide-project-start-with-project
;; (which may read this file to create current project config file)
(eide-config-rebuild-options-file)

;; Test if a project is defined
(if (file-exists-p eide-project-file)
  (progn
    ;; Check if this project is already open
    ;;(if (file-exists-p (concat eide-root-directory eide-project-lock-file))
    ;;  (if (eide-popup-question-yes-or-no-p "WARNING : This project is already open (or has not exited properly)\nDo you want to continue ?")
    ;;    (setq eide-project-already-open-flag t)
    ;;    (kill-emacs)))
    (find-file-noselect eide-project-file)
    (eide-project-start-with-project)))

;; Update frame title and menu
(eide-project-update-frame-title)

;; Frame size and position
(if window-system
  (if (eq system-type 'windows-nt)
    ;; Windows
    (setq initial-frame-alist '((top . 0) (left . 0) (width . 122) (height . 39)))
    ;; Linux
    (setq initial-frame-alist '((top . 30) (left . 0) (width . 120) (height . 48)))))

;;(make-frame '((fullscreen . fullboth)))
;;(modify-frame-parameters nil '((fullscreen . nil)))
;;(modify-frame-parameters nil '((fullscreen . fullboth)))
;;(set-frame-parameter nil 'fullscreen 'fullboth)

;; Start with "editor" mode
(eide-keys-configure-for-editor)


;;;; ==========================================================================
;;;; PREFERENCES FOR CODE
;;;; ==========================================================================

;; Display current function (relating to cursor position) in info line
;; (if possible with current major mode)
(which-function-mode)

;; "Warning" color highlight when possible error is detected
;;(global-cwarn-mode)

;; Do not prompt for updating tag file if necessary
(setq tags-revert-without-query t)

;; Augmenter le nombre de fonctions dans le menu pop up "liste des fonctions"
;; (sinon, elles sont parfois inutilement regroupées dans des sous-menus)
;; (default : 25)
;; no longer used (personal popup menu)
(setq imenu-max-items 40)

;; Augmenter le nombre de buffers dans le menu pop up "liste des buffers"
;; (sinon, elles sont parfois inutilement regroupées dans des sous-menus)
;; (default : 20)
;; no longer used (personal popup menu)
(setq mouse-buffer-menu-maxlen 40)

;; Highlight matching parentheses (when cursor on "(" or just after ")")
(show-paren-mode 1)

;; moved to major mode hooks ! no effect on emacs linux, if here
;; (but used again, because no effect in hook !!!)


;;;; ==========================================================================
;;;; EDIFF
;;;; ==========================================================================

(require 'ediff)

;; Highlight current diff only
;;(setq ediff-highlight-all-diffs nil)

;; Control panel in the same frame
(ediff-toggle-multiframe)

;; Split horizontally for buffer comparison
(setq ediff-split-window-function 'split-window-horizontally)


;;;; ==========================================================================
;;;; IMENU (LIST OF FUNCTIONS)
;;;; ==========================================================================

;; Construction de la liste des fonctions (imenu)
;; Utilisation d'expressions régulières
;; (il faut pour cela laisser imenu-extract-index-name-function = nil)
;; Il faut redéfinir les expressions, car les expressions par défaut amènent
;; beaucoup d'erreurs : du code est parfois interprété à tort comme une
;; définition de fonction)


(setq eide-regex-word              "[a-zA-Z_][a-zA-Z0-9_:<>~]*")
(setq eide-regex-word-no-underscore "[a-zA-Z][a-zA-Z0-9_:<>~]*")
(setq eide-regex-space "[ \t]+")
(setq eide-regex-space-or-crlf "[ \t\n\r]+")
(setq eide-regex-space-or-crlf-or-nothing "[ \t\n\r]*")
(setq eide-regex-space-or-crlf-or-comment-or-nothing "[ \t\n\r]*\\(//\\)*[^\n\r]*[ \t\n\r]*")
;;(setq eide-regex-space-or-crlf-or-comment-or-nothing "[ \t\n\r]*\\(//\\)*[^\n\r]*[\n\r][ \t\n\r]*")
(setq eide-regex-space-or-nothing "[ \t]*")

(setq eide-cc-imenu-c-macro
      (concat
       "^#define" eide-regex-space
       "\\(" eide-regex-word "\\)("
       )
      )

(setq eide-cc-imenu-c-struct
      (concat
       "^typedef"  eide-regex-space "struct" eide-regex-space-or-crlf-or-nothing
       "{[^{]+}" eide-regex-space-or-nothing
       "\\(" eide-regex-word "\\)" ))

(setq eide-cc-imenu-c-enum
      (concat
       "^typedef" eide-regex-space "enum" eide-regex-space-or-crlf-or-nothing
       "{[^{]+}" eide-regex-space-or-nothing
       "\\(" eide-regex-word "\\)" ))

(setq eide-cc-imenu-c-define
      (concat
       "^#define" eide-regex-space
       "\\(" eide-regex-word "\\)" eide-regex-space ))

(setq eide-cc-imenu-c-function
      (concat
       "^\\(?:" eide-regex-word-no-underscore "\\*?" eide-regex-space "\\)*" ; void* my_function(void)
       "\\*?" ; function may return a pointer, e.g. void *my_function(void)
       "\\(" eide-regex-word "\\)"
       eide-regex-space-or-crlf-or-nothing "("
       eide-regex-space-or-crlf-or-nothing "\\([^ \t(*][^)]*\\)?)" ; the arg list must not start
       ;;"[ \t]*[^ \t;(]"                       ; with an asterisk or parentheses
       eide-regex-space-or-crlf-or-comment-or-nothing "{" ))

(if nil
  (progn
    ;; temp : remplace la définition au-dessus
    (setq eide-cc-imenu-c-function
          (concat
           "^\\(?:" eide-regex-word eide-regex-space "\\)*"
           "\\(" eide-regex-word "\\)"
           eide-regex-space-or-nothing "("
           "\\(" eide-regex-space-or-crlf-or-nothing eide-regex-word "\\)*)"
           ;;eide-regex-space-or-nothing "\\([^ \t(*][^)]*\\)?)"   ; the arg list must not start
           ;;"[ \t]*[^ \t;(]"                       ; with an asterisk or parentheses
           eide-regex-space-or-crlf-or-nothing "{" ))
    ))

;;cc-imenu-c-generic-expression's value is 
;;((nil "^\\<.*[^a-zA-Z0-9_:<>~]\\(\\([a-zA-Z0-9_:<>~]*::\\)?operator\\>[   ]*\\(()\\|[^(]*\\)\\)[  ]*([^)]*)[  ]*[^  ;]" 1)
;; (nil "^\\([a-zA-Z_][a-zA-Z0-9_:<>~]*\\)[   ]*([  ]*\\([^   (*][^)]*\\)?)[  ]*[^  ;(]" 1)
;; (nil "^\\<[^()]*[^a-zA-Z0-9_:<>~]\\([a-zA-Z_][a-zA-Z0-9_:<>~]*\\)[   ]*([  ]*\\([^   (*][^)]*\\)?)[  ]*[^  ;(]" 1)
;; ("Class" "^\\(template[  ]*<[^>]+>[  ]*\\)?\\(class\\|struct\\)[   ]+\\([a-zA-Z0-9_]+\\(<[^>]+>\\)?\\)[  \n]*[:{]" 3))
;;cc-imenu-c++-generic-expression's value is 
;;((nil "^\\<.*[^a-zA-Z0-9_:<>~]\\(\\([a-zA-Z0-9_:<>~]*::\\)?operator\\>[   ]*\\(()\\|[^(]*\\)\\)[  ]*([^)]*)[  ]*[^  ;]" 1)
;; (nil "^\\([a-zA-Z_][a-zA-Z0-9_:<>~]*\\)[   ]*([  ]*\\([^   (*][^)]*\\)?)[  ]*[^  ;(]" 1)
;; (nil "^\\<[^()]*[^a-zA-Z0-9_:<>~]\\([a-zA-Z_][a-zA-Z0-9_:<>~]*\\)[   ]*([  ]*\\([^   (*][^)]*\\)?)[  ]*[^  ;(]" 1)
;; ("Class" "^\\(template[  ]*<[^>]+>[  ]*\\)?\\(class\\|struct\\)[   ]+\\([a-zA-Z0-9_]+\\(<[^>]+>\\)?\\)[  \n]*[:{]" 3))


(setq eide-cc-imenu-c-interrupt
      (concat
       "\\(__interrupt"  eide-regex-space
       "\\(" eide-regex-word eide-regex-space "\\)*"
       eide-regex-word "\\)"
       eide-regex-space-or-nothing "("
       eide-regex-space-or-nothing "\\([^ \t(*][^)]*\\)?)" ; the arg list must not start
       "[ \t]*[^ \t;(]"              ; with an asterisk or parentheses
       ))

(setq eide-cc-imenu-c-generic-expression
      `(
        ;; General functions
        (nil          , eide-cc-imenu-c-function 1)

        ;; Interrupts
        ;;("--function" , eide-cc-imenu-c-interrupt 1)
        ;;("Interrupts" , eide-cc-imenu-c-interrupt 1)
        ;;(nil          , eide-cc-imenu-c-interrupt 1)

        ;; Macros
        ;;("--function" , eide-cc-imenu-c-macro 1)
        ;;("Macros"     , eide-cc-imenu-c-macro 1)

        ;; struct
        ;;("--var"      , eide-cc-imenu-c-struct 1)
        ;;("struct"     , eide-cc-imenu-c-struct 1)

        ;; enum
        ;;("--var"      , eide-cc-imenu-c-enum 1)
        ;;("enum"       , eide-cc-imenu-c-enum 1)

        ;; Defines
        ;;("--var"      , eide-cc-imenu-c-define 1)
        ;;("#define"    , eide-cc-imenu-c-define 1)
        ))


;;;; ==========================================================================
;;;; SETTINGS FOR FUNDAMENTAL MAJOR MODE
;;;; ==========================================================================

(setq-default indent-tabs-mode t)
(setq-default tab-width 4)


;;;; ==========================================================================
;;;; SETTINGS FOR MAJOR MODE "C" and "C++"
;;;; ==========================================================================

(require 'cc-mode)

(if eide-option-select-whole-symbol-flag
  ;; "_" should not be a word delimiter
  (modify-syntax-entry ?_ "w" c-mode-syntax-table))

(add-hook
 'c-mode-hook
 '(lambda()
    (setq indent-tabs-mode nil) ; Indentation : insert spaces instead of tabs
    (setq tab-width eide-c-indent-offset) ; Tab display : number of char for one tab (default value : 8)

    (c-set-style "K&R")                 ; Indentation style
    (setq c-basic-offset eide-c-indent-offset) ; Indentation offset (default value : 5)
    (c-set-offset 'case-label '+) ; Case/default in a switch (default value : 0)

    ;; Autofill minor mode
    ;; (automatic line feed beyond 80th column)
    ;;(auto-fill-mode 1)
    ;;(set-fill-column 80)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))

    ;; Turn hide/show mode on
    (if (not hs-minor-mode)
      (hs-minor-mode))
    ;; Do not hide comments when hidding all
    (setq hs-hide-comments-when-hiding-all nil)

    ;; Turn ifdef mode on (does not work very well with ^M turned into empty lines)
    (hide-ifdef-mode 1)

    ;; Add Imenu in the menu ("Index")
    ;; (useless here because menu-bar is hidden)
    ;;(imenu-add-menubar-index)

    ;; Imenu regex
    (setq cc-imenu-c++-generic-expression eide-cc-imenu-c-generic-expression)
    (setq cc-imenu-c-generic-expression   eide-cc-imenu-c-generic-expression)

    ;; Pour savoir si du texte est sélectionné ou non
    (setq mark-even-if-inactive nil)))

(add-hook
 'c++-mode-hook
 '(lambda()
    (setq indent-tabs-mode nil) ; Indentation : insert spaces instead of tabs
    (setq tab-width eide-c-indent-offset) ; Tab display : number of char for one tab (default value : 8)

    (c-set-style "K&R")                 ; Indentation style
    (setq c-basic-offset eide-c-indent-offset) ; Indentation offset (default value : 5)
    (c-set-offset 'case-label '+) ; Case/default in a switch (default value : 0)

    ;; Autofill minor mode
    ;; (automatic line feed beyond 80th column)
    ;;(auto-fill-mode 1)
    ;;(set-fill-column 80)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))

    ;; Turn hide/show mode on
    (if (not hs-minor-mode)
      (hs-minor-mode))
    ;; Do not hide comments when hidding all
    (setq hs-hide-comments-when-hiding-all nil)

    ;; Turn ifdef mode on (does not work very well with ^M turned into empty lines)
    (hide-ifdef-mode 1)

    ;; Add Imenu in the menu ("Index")
    ;; (useless here because menu-bar is hidden)
    ;;(imenu-add-menubar-index)

    ;; Imenu regex
    (setq cc-imenu-c++-generic-expression eide-cc-imenu-c-generic-expression)
    (setq cc-imenu-c-generic-expression   eide-cc-imenu-c-generic-expression)

    ;; Pour savoir si du texte est sélectionné ou non
    (setq mark-even-if-inactive nil)))

(font-lock-add-keywords
 'c-mode
 '(("
   ;;("__interrupt" . font-lock-keyword-face)

   ("uint8" . font-lock-type-face)
   ("uint16" . font-lock-type-face)
   ("uint32" . font-lock-type-face)
   ("int8" . font-lock-type-face)
   ("int16" . font-lock-type-face)
   ("int32" . font-lock-type-face)
   ("TODO" . font-lock-warning-face)))


;;;; ==========================================================================
;;;; SETTINGS FOR MAJOR MODE "EMACS LISP"
;;;; ==========================================================================

(if eide-option-select-whole-symbol-flag
  ;; "-" should not be a word delimiter
  (modify-syntax-entry ?- "w" emacs-lisp-mode-syntax-table))

(add-hook
 'emacs-lisp-mode-hook
 '(lambda()
    ;; Indentation : insert spaces instead of tabs
    (setq indent-tabs-mode nil)
    (setq tab-width 2)
    (setq lisp-body-indent 2)

    ;; Indentation after "if" (with default behaviour, the "then" statement is
    ;; more indented than the "else" statement)
    (put 'if 'lisp-indent-function 1)

    ;; Autofill minor mode
    ;; (pour ne pas dépasser la 80ème colonne)
    ;;(auto-fill-mode 1)
    ;;(set-fill-column 80)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))))


;;;; ==========================================================================
;;;; SETTINGS FOR MAJOR MODE "SGML" (HTML, XML...)
;;;; ==========================================================================

(add-hook
 'sgml-mode-hook
 '(lambda()
    ;; Indentation : insert spaces instead of tabs
    (setq indent-tabs-mode nil)
    (setq tab-width 2)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))))


;;;; ==========================================================================
;;;; SETTINGS FOR MAJOR MODE "SHELL SCRIPT"
;;;; ==========================================================================

(add-hook
 'shell-mode-hook
 '(lambda()
    ;; Indentation : insert spaces instead of tabs
    (setq indent-tabs-mode nil)
    (setq tab-width 2)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))))

;;;; ==========================================================================
;;;; SETTINGS FOR MAJOR MODE "PERL"
;;;; ==========================================================================

(add-hook
 'perl-mode-hook
 '(lambda()
    ;; Indentation : insert spaces instead of tabs
    (setq indent-tabs-mode nil)
    (setq tab-width 2)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))))


;;;; ==========================================================================
;;;; SETTINGS FOR MAJOR MODE "PYTHON"
;;;; ==========================================================================

(add-hook
 'python-mode-hook
 '(lambda()
    ;; Indentation : insert tabs
    (setq indent-tabs-mode t)
    (setq tab-width 4)

    ;; Show trailing spaces if enabled in options
    (if eide-config-show-trailing-spaces
      (setq show-trailing-whitespace t))))


;;;; ==========================================================================
;;;; WINDOWS SETTINGS
;;;; ==========================================================================

;; Since "config rebuild" functions have closed their buffers, and
;; eide-options-file has just been closed, we are back in directory from which
;; emacs has been launched : we can use desktop-read
;; NB : it is important to execute desktop-read after mode-hooks have been
;; defined, otherwise mode-hooks may not apply
(desktop-read)

;; eide-options-file might be present in desktop (in case emacs was closed
;; while editing options) : we must close it again.
(if (get-buffer eide-options-file)
  (kill-buffer eide-options-file))

;; Close temporary buffers from ediff sessions (if emacs has been closed during
;; an ediff session, .emacs.desktop contains temporary buffers (.ref or .new
;; files) and they have been loaded in this new emacs session).
(let ((l-buffer-name-list (mapcar 'buffer-name (buffer-list))))
  (dolist (l-buffer-name l-buffer-name-list)
    (if (or (string-match "^\* (REF)" l-buffer-name) (string-match "^\* (NEW)" l-buffer-name))
      ;; this is a "useless" buffer (.ref or .new)
      (kill-buffer l-buffer-name))))

(setq eide-current-buffer (buffer-name))
(eide-menu-init)
(eide-windows-init)

;;(add-hook 'kill-emacs-hook 'eide-kill-emacs-hook)

(provide 'eide)

;;; init.el ends here