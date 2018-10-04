package App::CpanfileSlipstop::CLI;
use strict;
use warnings;

use Carton::Snapshot;
use Module::CPANfile;
use Getopt::Long qw/:config posix_default no_ignore_case gnu_compat bundling auto_help/;

use App::CpanfileSlipstop::Resolver;
use App::CpanfileSlipstop::Writer;

sub new {
    my ($class) = @_;

    # defaults
    bless +{
        command   => 'feedback',
        cpanfile  => 'cpanfile',
        snapshot  => 'cpanfile.snapshot',
        stopper   => 'exact', # or minimum, maximmu
        dry_run   => 0,
        with_core => 0,
        silent    => 0,
    }, $class;
}

sub run {
    my ($self, @argv) = @_;

    $self->parse_options(@argv);

    return $self->cmd_feedback;
}

sub parse_options {
    my ($self, @argv) = @_;

    GetOptions(
        'cpanfile=s' => \($self->{cpanfile}),
        'snapshot=s' => \($self->{snapshot}),
        'stopper=s'  => \($self->{stopper}),
        'dry-run'    => \($self->{dry_run}),
        'with-core'  => \($self->{with_core}),
        'silent'     => \($self->{silent}),
    );
}

sub cmd_feedback {
    my ($self) = @_;

    my $cpanfile = Module::CPANfile->load($self->{cpanfile});
    my $snapshot = Carton::Snapshot->new(path => $self->{snapshot});
    $snapshot->load;

    my $resolver =  App::CpanfileSlipstop::Resolver->new(
        cpanfile  => $cpanfile,
        snapshot  => $snapshot,
        with_core => $self->{with_core},
    );
    $resolver->read_cpanfile_requirements;
    $resolver->merge_snapshot_versions($self->versioning_method, $self->{with_core});

    my $writer = App::CpanfileSlipstop::Writer->new(
        cpanfile_path => $self->{cpanfile},
        dry_run       => $self->{dry_run},
    );
    $writer->set_versions(
        sub { $resolver->get_version_range($_[0]) },
        sub { !$self->{silent} && $self->log(@_) },
    );

    return 0;
}

sub versioning_method {
    my ($self) = @_;

    return +{
        minimum => 'add_minimum',
        maximum => 'add_maximum',
        exact   => 'exact_version',
    }->{$self->{stopper}};
}

sub log {
    my ($self, $log) = @_;

    return if ($log->{before} || '') eq ($log->{after} || '');

    my $quote = $log->{quote};
    print sprintf "%s: %s -> %s\n",
        $log->{module},
        $log->{before} ? sprintf("$quote%s$quote", $log->{before}) : '(unspecified)',
        $log->{after}  ? sprintf("$quote%s$quote", $log->{after})  : '(unspecified)';
}

1;
