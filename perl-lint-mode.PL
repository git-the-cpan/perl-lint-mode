#!perl -w
use strict;

scalar(@ARGV) == 1
    or die "Usage: $0 base-name\nSee ExtUtils::MakeMaker PL_FILES.";

# Fetch the default interpreter right from whatever is installing this
# thing.
my %tags = ( '$perl-lint-bin$' => $^X );

my $tags_rx = join '|', map quotemeta, keys %tags;
$tags_rx = qr/$tags_rx/;
my $out_file = "$ARGV[0].el";
open OUT, "> $out_file\0" or die "Can't open '$out_file' for writing: $!";
while ( my $line = <DATA> ) {
    $line =~ s/($tags_rx)/$tags{$1}/g;
    print OUT $line or die "Can't write to '$out_file': $!";
}
close OUT or die "Can't flush '$out_file': $!";

__DATA__
;;; perl-lint-mode.el --- Minor mode to require B::Lint clean perl.

;;; B::Lint is a module in core perl.

;;; Copyright 2006 Joshua ben Jore

;;; Author: Joshua ben Jore <jjore@cpan.org>
;;; Version: 0.02
;;; CVS Version: $Id$
;;; Keywords: perl B::Lint
;;; X-URL: http://search.cpan.org/~jjore/perl-lint-mode/

;;; This program is free software; you can redistribute it and/or
;;; modify it under the same terms as Perl itself.

;;; To use this, add the following code to your .emacs file and copy
;;; perl-lint-mode.el to your ~/.site-lisp/ directory.
;;;
;;;   (add-to-list 'load-path "~/.site-lisp/")
;;;   (autoload 'perl-lint "perl-lint-mode" nil t)
;;;   (autoload 'perl-lint-mode "perl-lint-mode" nil t)
;;;
;;; To use this automatically when cperl-mode is enabled, also add the
;;; following code to your .emacs file.
;;;
;;;   ; Automatically enable perl-lint-mode for cperl-mode
;;;   (eval-after-load "cperl-mode"
;;;     '(add-hook 'cperl-mode-hook 'perl-lint-mode))


(require 'cl)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                           Lint checking
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar perl-lint-bin "$perl-lint-bin$"
  "The perl binary used to check for lint.")

(defvar perl-lint-checks (list "all" "no-bare-subs")
  "...")

(defvar perl-lint-ignore-bad-checks nil
  "Ignore non-existant checks.")

(defun perl-lint ()
  "Returns a either nil or t depending on whether the current buffer
passes perl's lint check. If there's a failure, the failures are
displayed in an adjacent buffer."
  (interactive)

  (save-restriction
    (widen)
    (save-excursion
      (let ((input-buf (current-buffer))
            (lint-buf (get-buffer-create "*Lint check*"))
            (interpreter (progn
                           ; Steal the shebang or use a default.
                           (goto-char (point-min))
                           (if (looking-at auto-mode-interpreter-regexp)
                               (match-string 2)
                             perl-lint-bin))))
        

        ; Clear the lint buffer if it needs it.
        (if (zerop (buffer-size lint-buf))
            nil
          (set-buffer lint-buf)
          (erase-buffer))
        
        ; Run B::Lint on the current buffer using whatever checks the
        ; user would like.
        (set-buffer input-buf)
        (let ((rc (call-process-region
                   (point-min) (point-max)
                   interpreter nil
                   (list lint-buf t) nil
                   (reduce (lambda (l r) (concat l "," r))
                           (cons "-MO=Lint" perl-lint-checks)))))
          
          ; Check that the B::Lint succeeded or clean up the error
          ; messages it posted.
          (set-buffer lint-buf)
          (goto-char (point-min))
          (if (numberp rc)
              (if (not (zerop rc))
                  ; A non-zero exit, likely a syntax error. I'll leave
                  ; anything in the lint-buffer there.
                  t

                ; If I get this far, it is at least syntactically
                ; valid.

                ; I'm frequently switching between different
                ; Lints with different abilities so I've set
                ; checks that don't always exist. This just
                ; removes the warning.
                (or perl-lint-ignore-bad-checks
                    (delete-matching-lines "^No such check: "))
                ; Remove all the Lint lines for things that are in
                ; files named anything other than "-". When I feed the
                ; buffer to Lint, the file is named - because it comes
                ; from STDIN.  Also remove the "Syntax ok" message.
                (call-process-region
                 (point-min) (point-max)
                 interpreter t
                 (list lint-buf t)
                 t "-0777" "-pe"
                 (concat "s/.+ at (?!-).+ line \\d+\\.?\\n//g"
                         ";"
                         "s/^- syntax OK\\n//")))
            ; Sometimes non-numeric results come back. I'm just
            ; bailing and inserting them for the user
            ; to deal with.
            (insert rc "\n"))
          
          ; Clean up or call for help.
          (let ((lint-ok (and (numberp rc)
                              (zerop rc)
                              (zerop (buffer-size)))))
            (if lint-ok (kill-buffer lint-buf)
              (display-buffer lint-buf))
            
            ; Oh yeah. Return a boolean too.
            lint-ok))))))





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                              Lint mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar perl-lint-mode nil
  "Check perl lint before saving.")
(make-variable-buffer-local 'perl-lint-mode)

(defun perl-lint-write-hook ()
  "Check perl lint during `write-file-hooks' for `perl-lint-mode'"
  (if perl-lint-mode
      (save-restriction
        (widen)
        (save-excursion
          (mark-whole-buffer)
          ; Impede the save if perl-lint fails
          (not (perl-lint))))
    ; Don't impede the save.
    nil))

(defun perl-lint-mode (&optional arg)
  "Perl lint checking minor mode."
  (interactive "P")

  ; Cargo-culted from the Extending Emacs book.
  (setq perl-lint-mode (if (null arg)
                           ; Toggle it on and off.
                           (not perl-lint-mode)
                         ; Enable if >0.
                         (> (prefix-numeric-value arg) 0)))

  (make-local-hook 'write-file-hooks)
  (funcall (if perl-lint-mode #'add-hook #'remove-hook)
           'write-file-hooks 'perl-lint-write-hook))

; Add this to the list of minor modes.
(if (not (assq 'perl-lint-mode minor-mode-alist))
    (setq minor-mode-alist
          (cons '(perl-lint-mode " Lint")
                minor-mode-alist)))


(provide 'perl-lint-mode)
