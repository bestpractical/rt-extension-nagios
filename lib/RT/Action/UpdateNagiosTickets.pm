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
        m{(PROBLEM|RECOVERY)\s+(Service|Host) Alert: ([^/]+)/(.*)\s+is\s+(\w+)}i
      )
    {
        $RT::Logger->info(
"Extracted type, category, host, problem_type and problem_severity from
subject with values $type, $category, $host, $problem_type and $problem_severity"
        );
        my $tickets = RT::Tickets->new( $self->CurrentUser );
        $tickets->LimitQueue( VALUE => $new_ticket->Queue )
          unless RT->Config->Get('NagiosSearchAllQueues');
        $tickets->LimitSubject(
            VALUE    => "$category Alert: $host/$problem_type",
            OPERATOR => 'LIKE',
        );
        $tickets->LimitStatus(
            VALUE           => 'new',
            OPERATOR        => '=',
            ENTRYAGGREGATOR => 'or'
        );
        $tickets->LimitStatus(
            VALUE           => 'open',
            OPERATOR        => '=',
            ENTRYAGGREGATOR => 'or'
        );
        $tickets->LimitStatus( VALUE => 'stalled', OPERATOR => '=' );
        if ( RT->Config->Get('NagiosMergeTickets') ) {
            while ( my $ticket = $tickets->Next ) {
                next if $ticket->id == $new_ticket_id;
                my ( $ret, $msg ) = $ticket->MergeInto($new_ticket_id);
                if ( !$ret ) {
                    $RT::Logger->error( 'failed to merge ticket '
                          . $ticket->id
                          . " into $new_ticket_id: $msg" );
                }
            }

            if ( $type eq 'RECOVERY' ) {
                my ( $ret, $msg ) = $new_ticket->Resolve();
                if ( !$ret ) {
                    $RT::Logger->error( 'failed to resolve ticket '
                          . $new_ticket->id
                          . ":$msg" );
                }
            }
        }
        elsif ( $type eq 'RECOVERY' ) {
            while ( my $ticket = $tickets->Next ) {
                my ( $ret, $msg ) = $ticket->Comment(
                    Content => 'going to be resolved by ' . $new_ticket_id,
                    Status => 'resolved',
                    );
                if ( !$ret ) {
                    $RT::Logger->error(
                        'failed to comment ticket ' . $ticket->id . ": $msg" );
                }

                ( $ret, $msg ) = $ticket->Resolve();
                if ( !$ret ) {
                    $RT::Logger->error(
                        'failed to resolve ticket ' . $ticket->id . ": $msg" );
                }
            }
            my ( $ret, $msg ) = $new_ticket->Resolve();
            if ( !$ret ) {
                $RT::Logger->error(
                    'failed to resolve ticket ' . $new_ticket->id . ":$msg" );
            }
        }
    }
}

1;
