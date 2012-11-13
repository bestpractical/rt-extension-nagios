package RT::Action::UpdateNagiosTickets;

use strict;
use warnings;

use base qw(RT::Action);

sub Describe {
    my $self = shift;
    return ( ref $self );
}

sub Prepare {
    return (1);
}

sub Commit {
    my $self = shift;

    my $attachment = $self->TransactionObj->Attachments->First;
    return 1 unless $attachment;
    my $new_ticket    = $self->TicketObj;
    my $new_ticket_id = $new_ticket->id;

    my $subject = $attachment->GetHeader('Subject');
    return unless $subject;
    if ( my ( $type, $category, $host, $problem_type, $problem_severity ) =
        $subject =~
m{(PROBLEM|RECOVERY|ACKNOWLEDGEMENT)\s+(Service|Host) Alert: ([^/]+)/?(.*)\s+is\s+(\w+)}i
      )
    {
        $problem_type ||= '';
        $RT::Logger->info(
"Extracted type, category, host, problem_type and problem_severity from
subject with values $type, $category, $host, $problem_type and $problem_severity"
        );
        my $tickets = RT::Tickets->new( $self->CurrentUser );
        $tickets->LimitQueue( VALUE => $new_ticket->Queue )
          unless RT->Config->Get('NagiosSearchAllQueues');
        $tickets->LimitSubject(
            VALUE => "$category Alert: $host"
              . ( $problem_type ? "/$problem_type" : '' ),
            OPERATOR => 'LIKE',
        );
        my @active = RT::Queue->ActiveStatusArray();
        for my $active (@active) {
            $tickets->LimitStatus(
                VALUE    => $active,
                OPERATOR => '=',
            );
        }

        my $resolved = RT->Config->Get('NagiosResolvedStatus') || 'resolved';
		my $resolve_tickets = RT->Config->Get('NagiosResolveTickets') || 1;

        if ( my $merge_type = RT->Config->Get('NagiosMergeTickets') ) {
            my $merged_ticket;

            $tickets->OrderBy(
                FIELD => 'Created',
                ORDER => $merge_type > 0 ? 'DESC' : 'ASC',
            );
            $merged_ticket = $tickets->Next;

            while ( my $ticket = $tickets->Next ) {
                my ( $ret, $msg ) = $ticket->MergeInto( $merged_ticket->id );
                if ( !$ret ) {
                    $RT::Logger->error( 'failed to merge ticket '
                          . $ticket->id
                          . " into "
                          . $merged_ticket->id
                          . ": $msg" );
                }
            }

            if ( uc $type eq 'RECOVERY' and $resolve_tickets) {
                my ( $ret, $msg ) = $merged_ticket->SetStatus($resolved);
                if ( !$ret ) {
                    $RT::Logger->error( 'failed to resolve ticket '
                          . $merged_ticket->id
                          . ":$msg" );
                }
            }
        }
        elsif ( uc $type eq 'RECOVERY' and $resolve_tickets ) {
            while ( my $ticket = $tickets->Next ) {
                my ( $ret, $msg ) = $ticket->Comment(
                    Content => 'going to be resolved by ' . $new_ticket_id,
                    Status  => $resolved,
                );
                if ( !$ret ) {
                    $RT::Logger->error(
                        'failed to comment ticket ' . $ticket->id . ": $msg" );
                }

                ( $ret, $msg ) = $ticket->SetStatus($resolved);
                if ( !$ret ) {
                    $RT::Logger->error(
                        'failed to resolve ticket ' . $ticket->id . ": $msg" );
                }
            }
            my ( $ret, $msg ) = $new_ticket->SetStatus($resolved);
            if ( !$ret ) {
                $RT::Logger->error(
                    'failed to resolve ticket ' . $new_ticket->id . ":$msg" );
            }
        }
    }
}

1;
