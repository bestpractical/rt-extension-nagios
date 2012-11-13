use warnings;
use strict;

package RT::Extension::Nagios;

=head1 NAME

RT::Extension::Nagios - Merge and resolve Nagios tickets

=cut

our $VERSION = '0.06';

1;

=head1 DESCRIPTION

Based on http://wiki.bestpractical.com/view/AutoCloseOnNagiosRecoveryMessages,
thanks, Todd Chapman!

Nagios( L<http://www.nagios.org> ) is a powerful monitoring system that enables
organizations to identify and resolve IT infrastructure problems before they
affect critical business processes.

Once you create Nagios tickets by piping Nagio's email notifications, this
extension helps you merge and resolve them.

We identify email by its subject, so please keep it as the
default one or alike, i.e. subject should pass the regex:

C<<< qr{(PROBLEM|RECOVERY|ACKNOWLEDGEMENT)\s+(Service|Host) Alert: ([^/]+)/?(.*)\s+is\s+(\w+)}i >>>

e.g.  "PROBLEM Service Alert: localhost/Root Partition is WARNING":

There are 5 useful parts in subject( we call them type, category, host,
problem_type and problem_severity ):

PROBLEM, Service, localhost, Root Partition and WARNING

( Currently, we don't make use of problem_severity actually )

After the new ticket is created, the following is done:

1. find all the other active tickets in the same queue( unless
C<<< RT->Config->Get('NagiosSearchAllQueues') >>> is true, which will cause
to search all the queues ) with the same values of $category, $host and
$problem_type.

2. if C<< RT->Config->Get('NagiosMergeTickets') >> is true, merge all of
them. if $type is 'RECOVERY', resolve the merged ticket.

if C<< RT->Config->Get('NagiosMergeTickets') >> is false and $type is
'RECOVERY', resolve all them.

NOTE:

config items like C<NagiosSearchAllQueues> and C<NagiosMergeTickets> can be set
in etc/RT_SiteConfig.pm like this:

    Set($NagiosSearchAllQueues, 1); # true
    Set($NagiosMergeTickets, 0); # false, don't merge
    Set($NagiosMergeTickets, 1); # merge into the newest ticket.
    Set($NagiosMergeTickets, -1); # merge into the oldest ticket.
    Set($NagiosResolveTickets, 0) # don't resolve tickets on recovery, just merge (maybe)
    Set($NagiosResolveTickets, 1) # Default, resolve tickets on recovery

by default, tickets will be resolved with status C<resolved>, you can
customize this via config item C<NagiosResolvedStatus>, e.g.

    Set($NagiosResolvedStatus, "recovered");

=head1 AUTHOR

sunnavy  C<< <sunnavy@bestpractical.com> >>

=head1 LICENCE AND COPYRIGHT

RT-Extension-Nagios is Copyright 2009-2011 Best Practical Solutions, LLC.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

