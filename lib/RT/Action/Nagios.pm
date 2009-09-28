package RT::Action::Nagios;

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
        $tickets->LimitQueue( VALUE => $new_ticket->Queue );
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

        while ( my $ticket = $tickets->Next ) {
            next if $ticket->id == $new_ticket_id;
            my ( $ret, $msg ) = $ticket->MergeInto($new_ticket_id);
            if ( !$ret ) {
                $RT::Logger->error( 'failed to merge ticket '
                      . $ticket->id
                      . " into $new_ticket_id:$msg" );
            }

        }

        if ( $type eq 'RECOVERY' ) {
            my ( $ret, $msg ) = $new_ticket->Resolve();
            if ( !$ret ) {
                $RT::Logger->error(
                    'failed to resolve ticket ' . $new_ticket->id . ":$msg" );
            }
        }

    }
}

1;
