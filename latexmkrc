# latexmk setup: XeLaTeX, with citeproc-lua (citation-style-language) doing
# the job BibTeX would, and output in the style of `typst compile` / `typst watch`.
#
# citeproc-lua reads main.aux and the bibliography resources named in it and
# writes main.bbl, which the next XeLaTeX pass typesets. It runs after every
# XeLaTeX pass, so a changed .bib, .yml, .json or .csl is picked up as well as a
# changed citation: latexmk sees main.bbl change and runs XeLaTeX again until
# nothing moves.
#
# Output: latexmk's own chatter and XeLaTeX's transcript go to
# .tw-thesis-build/latexmk.out and .tw-thesis-build/aux/main.log. The terminal
# only gets what matters:
#   compile  nothing on success; errors and warnings
#   watch    "[time] compiling ...", "[time] compiled successfully in N ms",
#            and the errors and warnings of that build
# Set TW_VERBOSE=1 to see everything latexmk prints, NO_COLOR=1 for plain text.
use strict;
no strict 'vars';        # latexmk's own settings below are plain globals
use File::Path qw(make_path);
use POSIX qw(strftime);
use Time::HiRes qw(time);

$| = 1;                  # flush at once so watch mode stays live
$pdf_mode = 5;           # xelatex
$bibtex_use = 0;         # citeproc below replaces BibTeX
$aux_dir = '.tw-thesis-build/aux';   # .aux .log .toc ... stay out of the project root
$out_dir = '.';                      # main.pdf stays in it
$xelatex = 'internal tw_xelatex %O %S';
$success_cmd = 'internal tw_success';
$failure_cmd = 'internal tw_failure';
$clean_ext .= ' bbl xdv';

# ---- terminal output --------------------------------------------------------

my $use_color = (-t STDOUT) && !$ENV{NO_COLOR};
my ($BLUE, $RED, $YELLOW, $OFF) = $use_color ? ("\e[1;34m", "\e[1;31m", "\e[1;33m", "\e[0m") : ('', '', '', '');
open(my $term, '>&', \*STDOUT) or die "cannot keep the terminal: $!\n";
$term->autoflush(1);
unless ($ENV{TW_VERBOSE}) {
  make_path('.tw-thesis-build');
  open(STDOUT, '>', '.tw-thesis-build/latexmk.out');
  open(STDERR, '>&', \*STDOUT);
  STDOUT->autoflush(1);
}

my ($cycle_start, $tw_base);
my @tw_errors;           # blocks collected while a build runs, shown when it ends

sub stamp { return strftime('[%H:%M:%S]', localtime); }
sub duration {
  my $ms = (time - $_[0]) * 1000;
  return $ms < 1000 ? sprintf('%.2f ms', $ms) : sprintf('%.2f s', $ms / 1000);
}
sub status { print $term "${BLUE}", stamp(), " $_[0]${OFF}\n"; }

# a Typst-like diagnostic: label, message, and the place it points at
sub diagnostic {
  my ($label, $color, $message, $where, $line, $text) = @_;
  my $out = "\n$color$label${OFF}: $message\n";
  if (defined $where) {
    my $pad = ' ' x length($line // '');
    $out .= "$pad ${BLUE}┌─${OFF} $where\n";
    if (defined $text) {
      $out .= "$pad ${BLUE}│${OFF}\n${BLUE}$line │${OFF} $text\n";
    }
  }
  return $out;
}

# errors from a TeX log run with -file-line-error:  ./file.tex:196: message / l.196 source line
sub tex_errors {
  my ($log) = @_;
  my @found;
  open(my $fh, '<', $log) or return @found;
  my @lines = <$fh>;
  close $fh;
  for my $i (0 .. $#lines) {
    next unless $lines[$i] =~ m{^(?:\./)?(.+?):(\d+): (.*)$};
    my ($file, $line, $message) = ($1, $2, $3);
    my $source;
    for my $j ($i + 1 .. ($i + 8 > $#lines ? $#lines : $i + 8)) {
      if ($lines[$j] =~ /^l\.\d+ (.*)$/) {
        $source = $1 . ($lines[$j + 1] // '');
        $source =~ s/\s+$//;
        last;
      }
    }
    push @found, diagnostic('error', $RED, $message, "$file:$line", $line, $source);
  }
  if (!@found) {   # no file:line form, e.g. "! Emergency stop."
    for my $i (0 .. $#lines) {
      next unless $lines[$i] =~ /^! (.*)$/;
      push @found, diagnostic('error', $RED, $1);
    }
  }
  return @found;
}

# references and citations that stay unresolved are the warnings worth showing
sub tex_warnings {
  my ($log) = @_;
  my (@found, %seen);
  open(my $fh, '<', $log) or return @found;
  my $text = do { local $/; <$fh> };
  close $fh;
  while ($text =~ /LaTeX Warning: (Reference|Citation) `([^']*)' on page (\d+) undefined on input line (\d+)/g) {
    my ($kind, $key, $page, $line) = (lc $1, $2, $3, $4);
    next if $seen{"$kind $key"}++;
    push @found, diagnostic('warning', $YELLOW, "undefined $kind `$key`", "page $page, line $line");
  }
  return @found;
}

# ---- build steps ------------------------------------------------------------

# Run a command with its output captured. On failure the blocks describing what
# went wrong are queued for tw_failure, never printed in the middle of a build.
sub run_captured {
  my ($log, @command) = @_;
  open(my $pipe, '-|', @command) or die "cannot run $command[0]: $!\n";
  my @output = <$pipe>;
  close $pipe;
  my $status = $?;
  if ($status != 0) {
    my @blocks = $log ? tex_errors($log) : ();
    if (!@blocks) {
      my @tail = @output[($#output > 20 ? $#output - 20 : 0) .. $#output];
      push @blocks, diagnostic('error', $RED, "$command[0] failed") . join('', @tail);
    }
    push @tw_errors, @blocks;
  }
  return $status;
}

sub tw_xelatex {
  my ($tex) = grep { !/^-/ } reverse @_;             # main.tex, or \def...\input{main.tex}
  $tex = $1 if $tex =~ /\\input\{([^}]*)\}/;
  (my $base = $tex) =~ s/\.tex$//;
  my ($dir) = map { /^-output-directory=(.*)/ ? $1 : () } @_;   # where latexmk put the aux files
  (my $bare = $base) =~ s/\.tex$//;
  $base = "$dir/$base" if defined $dir && $dir ne '.';
  $tw_base = $base;
  if (!defined $cycle_start) {
    $cycle_start = time;
    @tw_errors = ();
    status('compiling ...') if $preview_continuous_mode;
  }
  # a .bbl left by BibTeX/natbib (in the project root, which TeX reads first, or
  # in the aux directory) would stop the pass; citeproc output always has \csl
  for my $old_bbl ("$bare.bbl", "$base.bbl") {
    next unless -s $old_bbl && open(my $old, '<', $old_bbl);
    my $made_by_citeproc = grep { /^\\csl/ } <$old>;
    close $old;
    unlink $old_bbl unless $made_by_citeproc;
  }
  my $status = run_captured("$base.log", 'xelatex', '-file-line-error', @_);
  return $status if $status != 0;
  return 0 unless -f "$base.aux";
  open(my $fh, '<', "$base.aux") or return 0;
  my $uses_csl = grep { /^\\csl\@aux\@data/ } <$fh>;
  close $fh;
  return 0 unless $uses_csl;
  my $script = `kpsewhich -format=texmfscripts citation-style-language/citeproc-lua.lua`;
  chomp $script;
  die "citeproc-lua not found: install the TeX Live package citation-style-language\n"
    unless $script;
  return run_captured(undef, 'texlua', $script, $base);
}

sub tw_success {
  my @warnings = $tw_base ? tex_warnings("$tw_base.log") : ();
  if (defined $cycle_start) {
    if ($preview_continuous_mode) {
      status(@warnings ? 'compiled with warnings in ' . duration($cycle_start)
                       : 'compiled successfully in ' . duration($cycle_start));
    }
  } elsif ($preview_continuous_mode) {
    status('up to date');
  }
  print $term @warnings;
  undef $cycle_start;
  return 0;
}

sub tw_failure {
  status('compiled with errors in ' . duration($cycle_start // time)) if $preview_continuous_mode;
  if (!@tw_errors) {   # latexmk itself failed before TeX ran
    push @tw_errors, diagnostic('error', $RED, 'the build failed; see .tw-thesis-build/latexmk.out');
  }
  print $term @tw_errors;
  print $term "\n";
  undef $cycle_start;
  return 0;
}
