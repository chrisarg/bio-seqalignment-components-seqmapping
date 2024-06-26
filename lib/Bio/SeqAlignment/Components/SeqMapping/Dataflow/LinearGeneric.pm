
package Bio::SeqAlignment::Components::SeqMapping::Dataflow::LinearGeneric;
$Bio::SeqAlignment::Components::SeqMapping::Dataflow::LinearGeneric::VERSION = '0.03';
use strict;
use warnings;

use Moose::Role;
use Carp;
use MCE;
use MCE::Candy;
use namespace::autoclean;

requires 'seq_align';    ## the method that does (pseudo)alignment mapping & reductions
requires 'cleanup';

sub sim_seq_search {

    my ( $self, $workload, %args ) = @_;

    croak 'expect an array(ref) as workload' unless ref $workload eq 'ARRAY';

    my $max_workers = $args{max_workers}
      // 1;    # set default value if not defined
    my $chunk_size = $args{chunk_size} // 1;  # set default value if not defined
    my $cleanup    = $args{cleanup}    // 1;  # set default value if not defined
    my @results;

    if ( $max_workers == 1 ) {
        foreach my $chunk ( @{$workload} ) {
            my $reduced_metric = $self->seq_align->($chunk);
            push @results, $reduced_metric->@*;    ## append to the results
            $self->cleanup->($reduced_metric) if $cleanup;
        }
        return \@results;
    }
    else {
        my $mce = MCE->new(
            max_workers => $max_workers,
            chunk_size  => $chunk_size,
            gather      => MCE::Candy::out_iter_array( \@results ),
            posix_exit  => 1,
            user_func   => sub {
                my ( $mce, $chunk_ref, $chunk_id ) = @_;
                my @chunk_results;
                foreach my $chunk ( @{$chunk_ref} ) {
                    my $reduced_metric = $self->seq_align->($chunk);
                    push @chunk_results, $reduced_metric->@*;
                    $self->cleanup->($reduced_metric) if $cleanup;
                }
                $mce->gather( $chunk_id, @chunk_results );
            }
        );
        $mce->process($workload);
        $mce->shutdown();
    }
    return \@results;
}

1;

=head1 NAME

Bio::SeqAlignment::Components::SeqMapping::Dataflow::LinearGeneric - A role to implement a linear dataflow for a Generic Mapper

=head1 VERSION

version 0.03

=head1 DESCRIPTION

This role provides a linear dataflow for sequence mapping. By that we
mean that the input, i.e. a reference to a (list) of any object that can hold 
biological sequences such as BioX::Seq objects, FASTA files, etc) undergoes a
single step process for mapping, i.e. similarity search, usually through a 
(pseudo)alignment method and mapping to a single best candidate, which is the
final (?definitive) step of similarity search. 
The module is intended to be B<applied> as a role to the class 
Bio::SeqAlignment::Components::SeqMapping::Mapper::Generic
The latter is pluggable Moose mapper that provides the necessary logic to  
implement the methods required by this role module.

The method requires the implementation of the following methods by the 
GenericMapper class to which the role will be applied:

* seq_align : aligns an atomic unit of work provided as the single argument 
    and returns the similarity metric and the match result. This method is 
    passed only one argument:  
        1.  The atomic unit of work
    This function returns a reference to an array containing the sequence ID, 
    the reference sequence that was mapped to and the similarity metric used to
    decide which reference sequence to map to. In essence this method performs
    ALL the steps of the similarity search and mapping in one go (as opposed to
    the linear-linear dataflow where the similarity search, extraction of 
    similarity measures, their reduction and mapping are distinct steps.
* cleanup : does any cleanup necessary after the mapping has been done if the
    user desires so. The function will be provided with a single argument:
        1. the output of the seq_align method

Note that these functions are provided as code references to the constructor of
the class that composes the role. The role does not provide any default 
implementation for these methods, as they are highly dependent on the
implementation of the similarity search and the similarity metric reduction
steps. The user is free to implement these methods in any way they see fit,
e.g. using BioPerl, BioX, BioPython, command line and use Perl to wrap them
into functions that are provided as arguments to:
Bio::SeqAlignment::Components::SeqMapping::Mapper::Generic


=head1 METHODS

=head2 sim_seq_search

This is the single L<public> method provided by the role. It takes the following
arguments:
* $workload : an array reference containing the atomic units of work to be
    processed. The atomic units of work can be any object that can hold a 
    biological sequence, and the format depends entirely on the class composing
    the role. This gives immense flexibility to the user to define the space
    the dataflow operates in, e.g. in-memory, on-disk, etc.
* %args : a hash containing the following optional arguments, that control 
    parallelization and cleanup after the mapping has been done. The keys are:
    * max_workers : the number of workers to use for parallelization. Default
        value is 1, i.e. no parallelization.
    * chunk_size : the number of atomic units of work to be processed by each
        worker. Default value is 1.
    * cleanup : a boolean value that indicates whether to do cleanup after the
        mapping has been done. Default value is 1, i.e. cleanup after the mess.

    $mapper->sim_seq_search(
        $workload,
        max_workers => 4,
        chunk_size  => 10,
        cleanup     => 1
    );

=head1 SEE ALSO

=over 4

=item * L<Bio::SeqAlignment::Components::SeqMapping::Mapper::Generic|https://metacpan.org/pod/Bio::SeqAlignment::Components::SeqMapping::Mapper::Generic>

Documentation of the Generic Mapper class that uses this role.

=item * L<Bio::SeqAlignment::Examples::EnhancingEdlib|https://metacpan.org/pod/Bio::SeqAlignment::Examples::EnhancingEdlib>

Example of how to use the Generic Mapper with the LinearLinearGeneric and the 
LinearGeneric Dataflow roles, along with the Edlib alignment library.

=back

=head1 AUTHOR

Christos Argyropoulos, C<< <chrisarg at cpan.org> >>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Christos Argyropoulos.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut
